import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class VolumeManager {
    private let audioSession = AVAudioSession.sharedInstance()
    private var systemSlider: UISlider?
    private var lastLoggedSystemVolume: Float = -1
    private var pendingVolume: Float?

    func configureAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch { }
    }

    func prepareBridge() {}

    func currentOutputVolume() -> Float {
        let system = systemOutputVolume()
        if let pending = pendingVolume {
            if abs(system - pending) < 0.02 {
                pendingVolume = nil
            }
            return pending
        }

        return system
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
        let hasWindow = slider.window != nil
        let hasSuperview = slider.superview != nil
        VolumeDiagnostics.log("bridge.attach.external slider attached window=\(hasWindow) superview=\(hasSuperview)")
    }

    func isReady() -> Bool {
        guard let slider = systemSlider else { return false }
        return slider.superview != nil && slider.window != nil
    }

    @discardableResult
    func setVolume(_ value: Float) -> Float {
        let clamped = min(max(value, 0.0), 1.0)
        do {
            try audioSession.setActive(true)
        } catch {
            VolumeDiagnostics.log("audio.activate.failed")
        }
        guard let slider = systemSlider else {
            VolumeDiagnostics.log("write.blocked noSlider target=\(Int(clamped * 100))%")
            return currentOutputVolume()
        }
        guard slider.superview != nil, slider.window != nil else {
            VolumeDiagnostics.log("write.blocked sliderDetached target=\(Int(clamped * 100))%")
            return currentOutputVolume()
        }

        let before = systemOutputVolume()
        VolumeDiagnostics.log("write.start before=\(Int(before * 100))% target=\(Int(clamped * 100))%")
        pendingVolume = clamped
        setSliderValue(slider, to: clamped)
        let actual = systemOutputVolume()
        if abs(actual - clamped) > 0.02 {
            VolumeDiagnostics.log("write.retry target=\(Int(clamped * 100))% actual=\(Int(actual * 100))%")
        }
        VolumeDiagnostics.log("write.done target=\(Int(clamped * 100))% actual=\(Int(actual * 100))%")
        return clamped
    }

    private func setSliderValue(_ slider: UISlider, to value: Float) {
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
    }

    func logSystemVolumeIfChanged(source: String) {
        let current = systemOutputVolume()
        guard abs(current - lastLoggedSystemVolume) > 0.009 else { return }
        lastLoggedSystemVolume = current
        VolumeDiagnostics.log("system.read source=\(source) value=\(Int(current * 100))%")
    }
}
