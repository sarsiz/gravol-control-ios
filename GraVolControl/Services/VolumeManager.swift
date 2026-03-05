import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class VolumeManager {
    private let audioSession = AVAudioSession.sharedInstance()
    private var systemSlider: UISlider?
    private let bridgeVolumeView: MPVolumeView = {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.showsVolumeSlider = true
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        return view
    }()
    private var isBridgeMounted = false
    private var loggedMissingSlider = false
    private var lastLoggedSystemVolume: Float = -1
    private var writeGeneration: Int = 0
    #if targetEnvironment(simulator)
    private var simulatorVolumeOverride: Float?
    private var simulatorOverrideBaselineSystem: Float?
    #endif

    func configureAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            // Keep running; reading output volume still works in most cases.
        }
    }

    func prepareBridge() {
        mountBridgeIfNeeded()
        attachSliderIfNeeded()
    }

    func currentOutputVolume() -> Float {
        let system = systemOutputVolume()
        #if targetEnvironment(simulator)
        // Simulator often ignores MPVolumeView writes; keep controls usable with a local proxy.
        if let override = simulatorVolumeOverride {
            if let baseline = simulatorOverrideBaselineSystem {
                let delta = system - baseline
                if abs(delta) > 0.02 {
                    // Simulator can batch hardware button changes; snap to consistent 5% logical steps.
                    let step: Float = 0.05
                    let steppedDelta = (delta / step).rounded(.toNearestOrAwayFromZero) * step
                    let mapped = min(max(override + steppedDelta, 0.0), 1.0)
                    simulatorVolumeOverride = mapped
                    simulatorOverrideBaselineSystem = system
                    VolumeDiagnostics.log("sim.override adjustedByPhysical delta=\(Int(delta * 100)) stepped=\(Int(steppedDelta * 100)) mapped=\(Int(mapped * 100))%")
                    return mapped
                }
            }
            return override
        }
        #endif
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
        loggedMissingSlider = false
        VolumeDiagnostics.log("bridge.attach.external slider attached")
    }

    func isReady() -> Bool {
        systemSlider != nil
    }

    @discardableResult
    func setVolume(_ value: Float) -> Float {
        prepareBridge()
        let clamped = min(max(value, 0.0), 1.0)
        guard let slider = systemSlider else {
            if !loggedMissingSlider {
                VolumeDiagnostics.log("write.blocked noSlider target=\(Int(clamped * 100))%")
                loggedMissingSlider = true
            }
            return systemOutputVolume()
        }
        loggedMissingSlider = false
        let before = systemOutputVolume()
        VolumeDiagnostics.log("write.start before=\(Int(before * 100))% target=\(Int(clamped * 100))%")
        #if targetEnvironment(simulator)
        // Apply immediately to avoid UI snap-back while waiting for retry timing.
        simulatorVolumeOverride = clamped
        simulatorOverrideBaselineSystem = before
        #endif
        writeGeneration += 1
        let generation = writeGeneration

        configureAudioSession()
        setSliderValue(slider, to: clamped)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard
                let self,
                let slider = self.systemSlider
            else { return }
            guard generation == self.writeGeneration else {
                VolumeDiagnostics.log("write.skip stale target=\(Int(clamped * 100))%")
                return
            }
            if abs(self.systemOutputVolume() - clamped) > 0.02 {
                self.setSliderValue(slider, to: clamped)
                VolumeDiagnostics.log("write.retry target=\(Int(clamped * 100))% actual=\(Int(self.systemOutputVolume() * 100))%")
            }
            #if targetEnvironment(simulator)
            if abs(self.systemOutputVolume() - clamped) > 0.02 {
                self.simulatorVolumeOverride = clamped
                VolumeDiagnostics.log("sim.override set=\(Int(clamped * 100))%")
            } else {
                self.simulatorVolumeOverride = nil
                self.simulatorOverrideBaselineSystem = nil
            }
            #endif
            VolumeDiagnostics.log("write.done target=\(Int(clamped * 100))% actual=\(Int(self.systemOutputVolume() * 100))%")
        }

        return clamped
    }

    private func setSliderValue(_ slider: UISlider, to value: Float) {
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
        slider.sendActions(for: .touchUpInside)
    }

    private func mountBridgeIfNeeded() {
        if isBridgeMounted, bridgeVolumeView.superview != nil {
            return
        }
        guard let window = activeWindow() else { return }
        if bridgeVolumeView.superview !== window {
            bridgeVolumeView.removeFromSuperview()
            window.addSubview(bridgeVolumeView)
        }
        isBridgeMounted = true
        VolumeDiagnostics.log("bridge.mount ok")
    }

    private func attachSliderIfNeeded() {
        if systemSlider != nil { return }
        if let slider = findSlider(in: bridgeVolumeView) {
            systemSlider = slider
            loggedMissingSlider = false
            VolumeDiagnostics.log("bridge.attach.internal immediate")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.systemSlider == nil else { return }
            self.systemSlider = self.findSlider(in: self.bridgeVolumeView)
            if self.systemSlider != nil {
                self.loggedMissingSlider = false
                VolumeDiagnostics.log("bridge.attach.internal delayed")
            } else if !self.loggedMissingSlider {
                VolumeDiagnostics.log("bridge.attach.failed sliderNotFound")
                self.loggedMissingSlider = true
            }
        }
    }

    private func findSlider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider {
            return slider
        }
        for subview in view.subviews {
            if let slider = findSlider(in: subview) {
                return slider
            }
        }
        return nil
    }

    private func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        for scene in scenes {
            if let key = scene.windows.first(where: \.isKeyWindow) {
                return key
            }
            if let first = scene.windows.first {
                return first
            }
        }
        return nil
    }

    func logSystemVolumeIfChanged(source: String) {
        let current = systemOutputVolume()
        guard abs(current - lastLoggedSystemVolume) > 0.009 else { return }
        lastLoggedSystemVolume = current
        VolumeDiagnostics.log("system.read source=\(source) value=\(Int(current * 100))%")
    }
}
