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
    @Published var downTriggerAngleDegrees: Double = 15
    @Published var defaultDownTriggerAngleDegrees: Double = 15
    @Published var currentTiltDegrees: Double = 0
    @Published var stepSize: Double = 0.2
    @Published var isTiltLearnMode = false
    @Published var didLaunchAnimate = false
    @Published var isVolumeControlReady = false

    private let volumeManager = VolumeManager()
    private var volumeRefreshTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lastSeenRecenterCommandID = 0
    private var lastSeenSetArmedCommandID = 0
    private var lastSeenVolumePresetCommandID = 0
    private var lastLiveActivitySync = Date.distantPast
    private let triggerAngleRange: ClosedRange<Double> = 0...60
    private let muteThreshold: Float = 0.001
    private let firstLaunchFlagKey = "gravol_has_launched_once"
    private let tiltLearnModeKey = "gravol_tilt_learn_mode"

    private lazy var tiltController: TiltVolumeController = {
        let upThreshold = Self.degreesToRadians(triggerAngleDegrees)
        let downThreshold = Self.degreesToRadians(downTriggerAngleDegrees)
        return TiltVolumeController(
            towardPitchThreshold: upThreshold,
            awayPitchThreshold: downThreshold,
            towardHysteresis: max(abs(upThreshold) * 0.45, Self.degreesToRadians(1)),
            awayHysteresis: max(abs(downThreshold) * 0.45, Self.degreesToRadians(1)),
            stepInterval: 0.15
        )
    }()

    init() {
        volumeManager.configureAudioSession()

        if !UserDefaults.standard.bool(forKey: firstLaunchFlagKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchFlagKey)
            defaultTriggerAngleDegrees = 15
            triggerAngleDegrees = 15
            defaultDownTriggerAngleDegrees = 15
            downTriggerAngleDegrees = 15
            stepSize = 0.2
            isArmed = true
            GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
            GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
            GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
            GraVolControlRemoteStore.setStepSize(stepSize)
            GraVolControlRemoteStore.setArmedState(isArmed)
        } else {
            defaultTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.defaultTriggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            triggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            defaultDownTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.defaultDownTriggerAngleDegrees(defaultValue: defaultDownTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            downTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: defaultDownTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            stepSize = min(max(GraVolControlRemoteStore.stepSize(defaultValue: stepSize), 0.01), 5.0)
            isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        }

        lastSeenRecenterCommandID = GraVolControlRemoteStore.currentRecenterCommandID()
        lastSeenSetArmedCommandID = GraVolControlRemoteStore.currentSetArmedCommandID()
        lastSeenVolumePresetCommandID = GraVolControlRemoteStore.currentVolumePresetCommandID()
        isTiltLearnMode = UserDefaults.standard.bool(forKey: tiltLearnModeKey)
        refreshCurrentVolume()
        startVolumeRefreshTimer()

        tiltController.onDirection = { [weak self] direction in
            guard let self else { return }
            switch direction {
            case .towardUser:
                self.applyVolumeChange(delta: Float(self.stepSize / 100.0), action: "Tilt Up")
            case .awayFromUser:
                self.applyVolumeChange(delta: -Float(self.stepSize / 100.0), action: "Tilt Down")
            }
        }

        tiltController.onTiltDeltaChanged = { [weak self] deltaPitch in
            guard let self else { return }
            let tilt = Self.radiansToDegrees(deltaPitch)
            self.currentTiltDegrees = tilt
            if self.isTiltLearnMode {
                self.applyTiltAsTrigger(tilt)
            }
            self.syncLiveActivity(force: true)
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
        triggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
        updateTiltThresholds()
        syncLiveActivity(force: true)
    }

    func updateDefaultTriggerAngleDegrees(_ value: Double) {
        defaultTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
    }

    func resetTriggerToDefault() {
        updateTriggerAngleDegrees(defaultTriggerAngleDegrees)
    }

    func updateDownTriggerAngleDegrees(_ value: Double) {
        downTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
        updateTiltThresholds()
        syncLiveActivity(force: true)
    }

    func updateDefaultDownTriggerAngleDegrees(_ value: Double) {
        defaultDownTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
    }

    func resetDownTriggerToDefault() {
        updateDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
    }

    func updateStepSize(_ value: Double) {
        stepSize = min(max(value, 0.01), 5.0)
        GraVolControlRemoteStore.setStepSize(stepSize)
    }

    func setTiltLearnMode(_ enabled: Bool) {
        isTiltLearnMode = enabled
        UserDefaults.standard.set(enabled, forKey: tiltLearnModeKey)
        if !enabled {
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
            GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
            WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
            syncLiveActivity(force: true)
        }
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
        isVolumeControlReady = true
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
            endBackgroundTaskIfNeeded()
            startVolumeRefreshTimer()
            refreshCurrentVolume()
            if isArmed { tiltController.start() }
            syncLiveActivity(force: true)
        case .inactive:
            if isArmed {
                tiltController.start()
                startVolumeRefreshTimer()
            }
        case .background:
            // Best effort: keep updates alive briefly while app transitions.
            beginBackgroundTaskIfNeeded()
            if isArmed {
                tiltController.start()
                startVolumeRefreshTimer()
                syncLiveActivity(force: true)
            } else {
                tiltController.stop()
                stopVolumeRefreshTimer()
            }
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
            triggerAngleDegrees = min(max(abs(sharedAngle), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            updateTiltThresholds()
        }

        let sharedDownAngle = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: downTriggerAngleDegrees)
        if abs(sharedDownAngle - downTriggerAngleDegrees) > 0.001 {
            downTriggerAngleDegrees = min(max(abs(sharedDownAngle), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            updateTiltThresholds()
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
        if !force, now.timeIntervalSince(lastLiveActivitySync) < 0.12 {
            return
        }
        lastLiveActivitySync = now

        let content = GraVolLiveActivityAttributes.ContentState(
            tiltDegrees: currentTiltDegrees,
            upTriggerDegrees: triggerAngleDegrees,
            downTriggerDegrees: downTriggerAngleDegrees,
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

    private func updateTiltThresholds() {
        let upThreshold = Self.degreesToRadians(triggerAngleDegrees)
        let downThreshold = Self.degreesToRadians(downTriggerAngleDegrees)
        tiltController.updateThresholds(
            towardPitchThreshold: upThreshold,
            awayPitchThreshold: downThreshold,
            towardHysteresis: max(abs(upThreshold) * 0.45, Self.degreesToRadians(1)),
            awayHysteresis: max(abs(downThreshold) * 0.45, Self.degreesToRadians(1))
        )
    }

    private func applyTiltAsTrigger(_ tiltDegrees: Double) {
        let minLearnAngle = 1.0
        guard abs(tiltDegrees) >= minLearnAngle else { return }

        let mapped = min(max(abs(tiltDegrees), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        if tiltDegrees >= 0 {
            triggerAngleDegrees = mapped
        } else {
            downTriggerAngleDegrees = mapped
        }
        updateTiltThresholds()
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GraVolTiltLiveActivity") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
                self?.tiltController.stop()
                self?.stopVolumeRefreshTimer()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
