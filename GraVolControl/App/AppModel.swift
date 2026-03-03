import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var isArmed = true
    @Published var lastAction: String = "Idle"
    @Published var sensitivity: Double = 0.22
    @Published var stepSize: Double = 0.04

    private let volumeManager = VolumeManager()
    private lazy var tiltController: TiltVolumeController = {
        TiltVolumeController(
            pitchThreshold: sensitivity,
            hysteresis: sensitivity * 0.5,
            stepInterval: 0.15
        )
    }()

    init() {
        volumeManager.configureAudioSession()
        tiltController.onDirection = { [weak self] direction in
            guard let self else { return }
            switch direction {
            case .towardUser:
                self.volumeManager.changeVolume(by: Float(self.stepSize))
                self.lastAction = "Volume Up"
            case .awayFromUser:
                self.volumeManager.changeVolume(by: -Float(self.stepSize))
                self.lastAction = "Volume Down"
            }
        }
    }

    func setArmed(_ value: Bool) {
        isArmed = value
        value ? tiltController.start() : tiltController.stop()
    }

    func updateSensitivity(_ value: Double) {
        sensitivity = value
        tiltController.updateThresholds(
            pitchThreshold: value,
            hysteresis: value * 0.5
        )
    }

    func updateStepSize(_ value: Double) {
        stepSize = value
    }

    func currentVolume() -> Float {
        volumeManager.currentOutputVolume()
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if isArmed { tiltController.start() }
        case .inactive, .background:
            tiltController.stop()
        @unknown default:
            tiltController.stop()
        }
    }
}
