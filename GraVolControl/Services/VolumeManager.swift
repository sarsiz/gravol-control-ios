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

    @discardableResult
    func changeVolume(by delta: Float) -> Float {
        let current = currentOutputVolume()
        return setVolume(current + delta)
    }

    func attachSystemSlider(_ slider: UISlider) {
        systemSlider = slider
    }

    @discardableResult
    func setVolume(_ value: Float) -> Float {
        let clamped = min(max(value, 0.0), 1.0)
        guard let slider = systemSlider else { return currentOutputVolume() }
        slider.value = clamped
        slider.sendActions(for: .valueChanged)
        return clamped
    }
}
