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
        systemOutputVolume()
    }

    func systemOutputVolume() -> Float {
        min(max(audioSession.outputVolume, 0.0), 1.0)
    }

    @discardableResult
    func changeVolume(by delta: Float) -> Float {
        let current = currentOutputVolume()
        if delta == 0 { return current }
        return setVolume(current + delta)
    }

    func attachSystemSlider(_ slider: UISlider) {
        systemSlider = slider
    }

    func isReady() -> Bool {
        guard let slider = systemSlider else { return false }
        return slider.superview != nil
    }

    @discardableResult
    func setVolume(_ value: Float) -> Float {
        let clamped = min(max(value, 0.0), 1.0)
        guard let slider = systemSlider else {
            return systemOutputVolume()
        }
        if slider.superview == nil {
            return systemOutputVolume()
        }

        configureAudioSession()
        setSliderValue(slider, to: clamped)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak slider] in
            guard
                let self,
                let slider
            else { return }
            guard slider.superview != nil else { return }
            if abs(self.systemOutputVolume() - clamped) > 0.02 {
                self.setSliderValue(slider, to: clamped)
            }
        }

        return clamped
    }

    private func setSliderValue(_ slider: UISlider, to value: Float) {
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
    }
}
