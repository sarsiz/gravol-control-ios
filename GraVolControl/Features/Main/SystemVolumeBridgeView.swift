import MediaPlayer
import SwiftUI
import UIKit

struct SystemVolumeBridgeView: UIViewRepresentable {
    let onSliderReady: (UISlider) -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.isHidden = true

        DispatchQueue.main.async {
            if let slider = view.subviews.compactMap({ $0 as? UISlider }).first {
                onSliderReady(slider)
            }
        }

        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        if let slider = uiView.subviews.compactMap({ $0 as? UISlider }).first {
            onSliderReady(slider)
        }
    }
}
