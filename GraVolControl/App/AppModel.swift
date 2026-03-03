import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var isArmed = true
    @Published var lastAction: String = "Idle"
    @Published var currentVolume: Float = 0
    @Published var triggerAngleDegrees: Double = 12
    @Published var currentTiltDegrees: Double = 0
    @Published var stepSize: Double = 0.04
    @Published var volumeChangeRate: Double = 0
    @Published var didLaunchAnimate = false
    @Published var isVolumeControlReady = false

    private let volumeManager = VolumeManager()
    private var volumeRefreshTimer: Timer?
    private var recentChangeTimes: [Date] = []

    private lazy var tiltController: TiltVolumeController = {
        let threshold = Self.degreesToRadians(triggerAngleDegrees)
        TiltVolumeController(
            pitchThreshold: threshold,
            hysteresis: threshold * 0.45,
            stepInterval: 0.15
        )
    }()

    init() {
        volumeManager.configureAudioSession()
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
        if value {
            tiltController.start()
            tiltController.recenterBaseline()
            lastAction = "Tilt Ready"
        } else {
            tiltController.stop()
            lastAction = "Paused"
        }
    }

    func updateTriggerAngleDegrees(_ value: Double) {
        triggerAngleDegrees = min(max(value, 5), 35)
        let threshold = Self.degreesToRadians(triggerAngleDegrees)
        tiltController.updateThresholds(
            pitchThreshold: threshold,
            hysteresis: threshold * 0.45
        )
    }

    func updateStepSize(_ value: Double) {
        stepSize = value
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
        isVolumeControlReady = volumeManager.isReady()
        refreshCurrentVolume()
    }

    func nudgeUp() {
        applyVolumeChange(delta: Float(stepSize), action: "Manual Up")
    }

    func nudgeDown() {
        applyVolumeChange(delta: -Float(stepSize), action: "Manual Down")
    }

    func setVolumePreset(_ value: Float) {
        _ = volumeManager.setVolume(value)
        currentVolume = volumeManager.currentOutputVolume()
        lastAction = "Set \(Int(value * 100))%"
        registerVolumeChange()
    }

    func triggerLaunchAnimationIfNeeded() {
        guard !didLaunchAnimate else { return }
        didLaunchAnimate = true
    }

    func recenterTiltReference() {
        tiltController.recenterBaseline()
        lastAction = "Recentered"
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startVolumeRefreshTimer()
            refreshCurrentVolume()
            if isArmed { tiltController.start() }
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
            registerVolumeChange()
        }
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
                self?.trimVolumeRateWindow()
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

    private func registerVolumeChange() {
        recentChangeTimes.append(Date())
        trimVolumeRateWindow()
    }

    private func trimVolumeRateWindow() {
        let cutoff = Date().addingTimeInterval(-1.2)
        recentChangeTimes.removeAll { $0 < cutoff }
        volumeChangeRate = Double(recentChangeTimes.count)
    }

    deinit {
        volumeRefreshTimer?.invalidate()
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }
}
