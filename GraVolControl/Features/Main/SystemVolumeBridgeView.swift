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
        attachSliderIfAvailable(from: view, coordinator: context.coordinator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            attachSliderIfAvailable(from: view, coordinator: context.coordinator)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            attachSliderIfAvailable(from: view, coordinator: context.coordinator)
        }

        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        attachSliderIfAvailable(from: uiView, coordinator: context.coordinator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            attachSliderIfAvailable(from: uiView, coordinator: context.coordinator)
        }
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
}
