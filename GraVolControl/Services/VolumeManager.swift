import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class VolumeManager {
    private let audioSession = AVAudioSession.sharedInstance()
    private weak var systemSlider: UISlider?

    func configureAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            // Keep running; reading output volume still works in most cases.
        }
    }

    func currentOutputVolume() -> Float {
        audioSession.outputVolume
    }

    func changeVolume(by delta: Float) {
        let current = currentOutputVolume()
        setVolume(current + delta)
    }

    func attachSystemSlider(_ slider: UISlider) {
        systemSlider = slider
    }

    func setVolume(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)
        guard let slider = systemSlider else { return }
        slider.value = clamped
        slider.sendActions(for: .valueChanged)
    }
}
