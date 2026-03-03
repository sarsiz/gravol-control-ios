import MediaPlayer
import SwiftUI
import UIKit

struct SystemVolumeBridgeView: UIViewRepresentable {
    let onSliderReady: (UISlider) -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.showsRouteButton = false
        view.alpha = 0.01
        attachSliderIfAvailable(from: view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            attachSliderIfAvailable(from: view)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            attachSliderIfAvailable(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        attachSliderIfAvailable(from: uiView)
    }

    private func attachSliderIfAvailable(from volumeView: MPVolumeView) {
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            onSliderReady(slider)
        }
    }
}
