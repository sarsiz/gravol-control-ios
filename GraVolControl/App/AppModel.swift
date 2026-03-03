import Foundation
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var isArmed = true
    @Published var lastAction: String = "Idle"
    @Published var currentVolume: Float = 0
    @Published var triggerAngleDegrees: Double = 15
    @Published var defaultTriggerAngleDegrees: Double = 15
    @Published var currentTiltDegrees: Double = 0
    @Published var stepSize: Double = 0.2
    @Published var didLaunchAnimate = false
    @Published var isVolumeControlReady = false

    private let volumeManager = VolumeManager()
    private var volumeRefreshTimer: Timer?
    private var lastSeenRecenterCommandID = 0
    private var lastSeenSetArmedCommandID = 0
    private var lastSeenVolumePresetCommandID = 0
    private var lastLiveActivitySync = Date.distantPast
    private var pendingPreferredVolumeRestore: Float?
    private var preferredRestoreAttempts = 0
    private let triggerAngleRange: ClosedRange<Double> = 0...60
    private let muteThreshold: Float = 0.001
    private let firstLaunchFlagKey = "gravol_has_launched_once"

    private lazy var tiltController: TiltVolumeController = {
        let threshold = Self.degreesToRadians(triggerAngleDegrees)
        return TiltVolumeController(
            pitchThreshold: threshold,
            hysteresis: threshold * 0.45,
            stepInterval: 0.15
        )
    }()

    init() {
        volumeManager.configureAudioSession()

        if !UserDefaults.standard.bool(forKey: firstLaunchFlagKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchFlagKey)
            defaultTriggerAngleDegrees = 15
            triggerAngleDegrees = 15
            stepSize = 0.2
            isArmed = true
            GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
            GraVolControlRemoteStore.setStepSize(stepSize)
            GraVolControlRemoteStore.setArmedState(isArmed)
        } else {
            defaultTriggerAngleDegrees = GraVolControlRemoteStore.defaultTriggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)
            triggerAngleDegrees = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)
            stepSize = min(max(GraVolControlRemoteStore.stepSize(defaultValue: stepSize), 0.01), 5.0)
            isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        }

        if GraVolControlRemoteStore.hasPreferredVolume() {
            pendingPreferredVolumeRestore = GraVolControlRemoteStore.preferredVolume(defaultValue: currentVolume)
        }
        refreshCurrentVolume()
        startVolumeRefreshTimer()

        tiltController.onDirection = { [weak self] direction in
            guard let self else { return }
            switch direction {
            case .towardUser:
                self.applyVolumeChange(delta: Float(self.stepSize), action: "Tilt Up")
            case .awayFromUser:
                self.applyVolumeChange(delta: -Float(self.stepSize), action: "Tilt Down")
            }
        }

        tiltController.onTiltDeltaChanged = { [weak self] deltaPitch in
            guard let self else { return }
            self.currentTiltDegrees = Self.radiansToDegrees(deltaPitch)
        }
    }

    func setArmed(_ value: Bool) {
        isArmed = value
        GraVolControlRemoteStore.setArmedState(value)
        if value {
            tiltController.start()
            tiltController.recenterBaseline()
            lastAction = "Tilt Ready"
            syncLiveActivity(force: true)
        } else {
            tiltController.stop()
            lastAction = "Paused"
            endLiveActivity()
        }
    }

    func updateTriggerAngleDegrees(_ value: Double) {
        triggerAngleDegrees = min(max(value, triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
        let threshold = Self.degreesToRadians(triggerAngleDegrees)
        tiltController.updateThresholds(
            pitchThreshold: threshold,
            hysteresis: threshold * 0.45
        )
        syncLiveActivity(force: true)
    }

    func updateDefaultTriggerAngleDegrees(_ value: Double) {
        defaultTriggerAngleDegrees = min(max(value, triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
    }

    func resetTriggerToDefault() {
        updateTriggerAngleDegrees(defaultTriggerAngleDegrees)
    }

    func updateStepSize(_ value: Double) {
        stepSize = min(max(value, 0.01), 5.0)
        GraVolControlRemoteStore.setStepSize(stepSize)
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
        isVolumeControlReady = true
        attemptPreferredVolumeRestore()
    }

    func nudgeUp() {
        applyVolumeChange(delta: 0.05, action: "Manual Up")
    }

    func nudgeDown() {
        applyVolumeChange(delta: -0.05, action: "Manual Down")
    }

    func setVolumeDirect(_ value: Float) {
        guard volumeManager.isReady() else {
            isVolumeControlReady = false
            lastAction = "Volume Bridge Loading"
            return
        }
        _ = volumeManager.setVolume(value)
        currentVolume = volumeManager.currentOutputVolume()
        lastAction = "Dial \(Int(currentVolume * 100))%"
        syncMuteState(for: currentVolume)
        GraVolControlRemoteStore.setPreferredVolume(currentVolume)
        pendingPreferredVolumeRestore = currentVolume
        preferredRestoreAttempts = 0
    }

    func setVolumePreset(_ value: Float) {
        guard volumeManager.isReady() else {
            isVolumeControlReady = false
            lastAction = "Volume Bridge Loading"
            return
        }
        _ = volumeManager.setVolume(value)
        currentVolume = volumeManager.currentOutputVolume()
        lastAction = "Set \(Int(value * 100))%"
        syncMuteState(for: currentVolume)
        GraVolControlRemoteStore.setPreferredVolume(currentVolume)
        pendingPreferredVolumeRestore = currentVolume
        preferredRestoreAttempts = 0
    }

    func toggleMute() {
        if currentVolume <= muteThreshold {
            let restore = max(0.01, GraVolControlRemoteStore.lastAudibleVolume(defaultValue: 0.5))
            setVolumePreset(restore)
            lastAction = "Unmuted"
        } else {
            GraVolControlRemoteStore.setLastAudibleVolume(max(currentVolume, 0.05))
            setVolumePreset(0.0)
            lastAction = "Muted"
        }
    }

    func triggerLaunchAnimationIfNeeded() {
        guard !didLaunchAnimate else { return }
        didLaunchAnimate = true
    }

    func recenterTiltReference() {
        tiltController.recenterBaseline()
        lastAction = "Recentered"
        syncLiveActivity(force: true)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startVolumeRefreshTimer()
            refreshCurrentVolume()
            attemptPreferredVolumeRestore()
            if isArmed { tiltController.start() }
            syncLiveActivity(force: true)
        case .inactive, .background:
            tiltController.stop()
            stopVolumeRefreshTimer()
        @unknown default:
            tiltController.stop()
            stopVolumeRefreshTimer()
        }
    }

    private func applyVolumeChange(delta: Float, action: String) {
        guard volumeManager.isReady() else {
            isVolumeControlReady = false
            lastAction = "Volume Bridge Loading"
            return
        }
        isVolumeControlReady = true
        let before = volumeManager.currentOutputVolume()
        let after = volumeManager.changeVolume(by: delta)
        currentVolume = after
        syncMuteState(for: after)
        GraVolControlRemoteStore.setPreferredVolume(after)
        pendingPreferredVolumeRestore = after
        preferredRestoreAttempts = 0
        if abs(after - before) > 0.0001 {
            lastAction = action
        } else if after <= 0.001 {
            lastAction = "Already at Min"
        } else if after >= 0.999 {
            lastAction = "Already at Max"
        }
        syncLiveActivity()
    }

    private func refreshCurrentVolume() {
        isVolumeControlReady = volumeManager.isReady()
        currentVolume = volumeManager.currentOutputVolume()
        syncMuteState(for: currentVolume)
        attemptPreferredVolumeRestore()
    }

    private func startVolumeRefreshTimer() {
        guard volumeRefreshTimer == nil else { return }
        volumeRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCurrentVolume()
                self?.applyRemoteCommands()
                self?.syncLiveActivity()
            }
        }
        if let volumeRefreshTimer {
            RunLoop.main.add(volumeRefreshTimer, forMode: .common)
        }
    }

    private func stopVolumeRefreshTimer() {
        volumeRefreshTimer?.invalidate()
        volumeRefreshTimer = nil
    }

    deinit {
        volumeRefreshTimer?.invalidate()
    }

    private func applyRemoteCommands() {
        let sharedAngle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: triggerAngleDegrees)
        if abs(sharedAngle - triggerAngleDegrees) > 0.001 {
            let threshold = Self.degreesToRadians(sharedAngle)
            triggerAngleDegrees = min(max(sharedAngle, triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            tiltController.updateThresholds(
                pitchThreshold: threshold,
                hysteresis: threshold * 0.45
            )
        }

        if GraVolControlRemoteStore.consumeRecenterCommand(lastSeenID: &lastSeenRecenterCommandID) {
            recenterTiltReference()
        }

        if let remoteArmed = GraVolControlRemoteStore.consumeSetArmedCommand(lastSeenID: &lastSeenSetArmedCommandID),
           remoteArmed != isArmed {
            setArmed(remoteArmed)
        }

        if let volumePreset = GraVolControlRemoteStore.consumeVolumePresetCommand(lastSeenID: &lastSeenVolumePresetCommandID) {
            setVolumePreset(volumePreset)
        }
    }

    private func syncLiveActivity(force: Bool = false) {
        guard #available(iOS 16.1, *) else { return }
        guard isArmed else { return }

        let now = Date()
        if !force, now.timeIntervalSince(lastLiveActivitySync) < 0.35 {
            return
        }
        lastLiveActivitySync = now

        let content = GraVolLiveActivityAttributes.ContentState(
            tiltDegrees: currentTiltDegrees,
            triggerDegrees: triggerAngleDegrees,
            isArmed: isArmed
        )
        Task {
            await GraVolLiveActivityController.shared.startOrUpdate(content)
        }
    }

    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        Task {
            await GraVolLiveActivityController.shared.endAll()
        }
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }

    private func syncMuteState(for volume: Float) {
        if volume <= muteThreshold {
            GraVolControlRemoteStore.setMutedState(true)
        } else {
            GraVolControlRemoteStore.setMutedState(false)
            GraVolControlRemoteStore.setLastAudibleVolume(volume)
        }
    }

    private func attemptPreferredVolumeRestore() {
        guard let target = pendingPreferredVolumeRestore else { return }
        guard volumeManager.isReady() else { return }

        let current = volumeManager.rawOutputVolume()
        if abs(current - target) <= 0.02 {
            pendingPreferredVolumeRestore = nil
            preferredRestoreAttempts = 0
            return
        }

        guard preferredRestoreAttempts < 24 else {
            pendingPreferredVolumeRestore = nil
            preferredRestoreAttempts = 0
            return
        }

        preferredRestoreAttempts += 1
        _ = volumeManager.setVolume(target)
        currentVolume = target
    }
}
