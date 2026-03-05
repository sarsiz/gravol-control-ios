import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class VolumeManager {
    private let audioSession = AVAudioSession.sharedInstance()
    private var systemSlider: UISlider?
    private var pendingVolume: Float?

    func configureAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            // Keep running; reading output volume still works in most cases.
        }
    }

    func currentOutputVolume() -> Float {
        let systemValue = audioSession.outputVolume
        guard let pending = pendingVolume else { return systemValue }
        if abs(systemValue - pending) < 0.02 {
            pendingVolume = nil
            return systemValue
        }
        return pending
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
        systemSlider != nil
    }

    @discardableResult
    func setVolume(_ value: Float) -> Float {
        let clamped = min(max(value, 0.0), 1.0)
        guard let slider = systemSlider else { return currentOutputVolume() }
        slider.setValue(clamped, animated: false)
        slider.sendActions(for: .valueChanged)
        pendingVolume = clamped
        return clamped
    }
}
