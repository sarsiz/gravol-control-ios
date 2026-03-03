import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var isArmed = true
    @Published var lastAction: String = "Idle"
    @Published var currentVolume: Float = 0
    @Published var triggerAngleDegrees: Double = 21
    @Published var defaultTriggerAngleDegrees: Double = 21
    @Published var currentTiltDegrees: Double = 0
    @Published var stepSize: Double = 0.04
    @Published var didLaunchAnimate = false
    @Published var isVolumeControlReady = false

    private let volumeManager = VolumeManager()
    private var volumeRefreshTimer: Timer?
    private var lastSeenRecenterCommandID = 0
    private var lastSeenSetArmedCommandID = 0
    private var lastSeenVolumePresetCommandID = 0
    private var lastLiveActivitySync = Date.distantPast
    private let triggerAngleRange: ClosedRange<Double> = 0...60

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
        defaultTriggerAngleDegrees = GraVolControlRemoteStore.defaultTriggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)
        triggerAngleDegrees = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)
        isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
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
    }

    func resetTriggerToDefault() {
        updateTriggerAngleDegrees(defaultTriggerAngleDegrees)
        lastAction = "Default \(Int(defaultTriggerAngleDegrees))°"
    }

    func updateStepSize(_ value: Double) {
        stepSize = value
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
        isVolumeControlReady = true
    }

    func nudgeUp() {
        applyVolumeChange(delta: Float(stepSize), action: "Manual Up")
    }

    func nudgeDown() {
        applyVolumeChange(delta: -Float(stepSize), action: "Manual Down")
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
}
