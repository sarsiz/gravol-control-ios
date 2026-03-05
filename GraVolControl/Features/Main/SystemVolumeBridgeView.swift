import MediaPlayer
import SwiftUI
import UIKit

struct SystemVolumeBridgeView: UIViewRepresentable {
    let onSliderReady: (UISlider) -> Void

    final class Coordinator {
        weak var attachedSlider: UISlider?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 120, height: 30))
        view.alpha = 0.01
        attachSliderWithRetries(from: view, coordinator: context.coordinator, attempts: 20)

        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        attachSliderIfAvailable(from: uiView, coordinator: context.coordinator)
        attachSliderWithRetries(from: uiView, coordinator: context.coordinator, attempts: 8)
    }

    private func attachSliderIfAvailable(from volumeView: MPVolumeView, coordinator: Coordinator) {
        if let slider = findSlider(in: volumeView),
           coordinator.attachedSlider !== slider {
            coordinator.attachedSlider = slider
            onSliderReady(slider)
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

    private func attachSliderWithRetries(from volumeView: MPVolumeView, coordinator: Coordinator, attempts: Int) {
        attachSliderIfAvailable(from: volumeView, coordinator: coordinator)
        guard coordinator.attachedSlider == nil, attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            attachSliderWithRetries(from: volumeView, coordinator: coordinator, attempts: attempts - 1)
        }
    }
}
