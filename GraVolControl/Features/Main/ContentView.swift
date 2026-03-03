import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Text("GraVol Control")
                .font(.largeTitle.bold())

            Toggle("Arm Tilt Volume", isOn: Binding(
                get: { model.isArmed },
                set: { model.setArmed($0) }
            ))
            .toggleStyle(SwitchToggleStyle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Tilt Sensitivity")
                Slider(
                    value: Binding(
                        get: { model.sensitivity },
                        set: { model.updateSensitivity($0) }
                    ),
                    in: 0.10...0.45,
                    step: 0.01
                )
                Text(String(format: "%.2f rad", model.sensitivity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Volume Step")
                Slider(
                    value: Binding(
                        get: { model.stepSize },
                        set: { model.updateStepSize($0) }
                    ),
                    in: 0.01...0.10,
                    step: 0.01
                )
                Text(String(format: "%.2f", model.stepSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Current Volume: \(Int(model.currentVolume() * 100))%")
                .font(.headline)
                .padding(.top, 8)

            Text("Last Action: \(model.lastAction)")
                .foregroundStyle(.secondary)

            Text("Back Tap cannot be read directly by apps. Configure Back Tap to run a Shortcut that opens this app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(24)
        .onAppear {
            model.setArmed(model.isArmed)
        }
        .background(
            SystemVolumeBridgeView { slider in
                model.attachSystemVolumeSlider(slider)
            }
            .frame(width: 0, height: 0)
        )
    }
}
