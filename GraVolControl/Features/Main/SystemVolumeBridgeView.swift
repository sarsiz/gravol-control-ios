import MediaPlayer
import SwiftUI
import UIKit

struct SystemVolumeBridgeView: UIViewRepresentable {
    let onSliderReady: (UISlider) -> Void

    final class Coordinator {
        var didAttachSlider = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
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
        // Avoid publishing observable changes during SwiftUI's update cycle.
        DispatchQueue.main.async {
            attachSliderIfAvailable(from: uiView, coordinator: context.coordinator)
        }
    }

    private func attachSliderIfAvailable(from volumeView: MPVolumeView, coordinator: Coordinator) {
        guard !coordinator.didAttachSlider else { return }
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            coordinator.didAttachSlider = true
            onSliderReady(slider)
        }
    }
}
