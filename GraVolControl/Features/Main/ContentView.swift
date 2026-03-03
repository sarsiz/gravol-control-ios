import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showWidgetSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.1, blue: 0.25), Color(red: 0.05, green: 0.35, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                volumeDial
                Spacer(minLength: 12)
                thumbControls
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showWidgetSheet) {
            widgetHelpSheet
                .presentationDetents([.fraction(0.42), .medium])
        }
        .onAppear {
            model.triggerLaunchAnimationIfNeeded()
            model.setArmed(model.isArmed)
        }
        .background(
            SystemVolumeBridgeView { slider in
                model.attachSystemVolumeSlider(slider)
            }
            .frame(width: 0, height: 0)
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GraVol")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tilt toward you up, tilt away down")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.isArmed },
                set: { model.setArmed($0) }
            ))
            .labelsHidden()
            .tint(.mint)
        }
    }

    private var volumeDial: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 16)
                .frame(width: 230, height: 230)

            Circle()
                .trim(from: 0, to: CGFloat(model.currentVolume))
                .stroke(
                    AngularGradient(
                        colors: [.mint, .cyan, .yellow],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 230, height: 230)
                .animation(.easeOut(duration: 0.2), value: model.currentVolume)

            VStack(spacing: 6) {
                Text("\(Int(model.currentVolume * 100))%")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.lastAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(String(format: "Speed %.0f/s", model.volumeChangeRate))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .scaleEffect(model.didLaunchAnimate ? 1 : 0.86)
        .opacity(model.didLaunchAnimate ? 1 : 0.55)
        .animation(.spring(response: 0.75, dampingFraction: 0.72), value: model.didLaunchAnimate)
    }

    private var thumbControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    model.nudgeDown()
                } label: {
                    Label("Down", systemImage: "minus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: Color.white.opacity(0.16)))

                Button {
                    model.nudgeUp()
                } label: {
                    Label("Up", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: Color.white.opacity(0.22)))
            }

            HStack(spacing: 10) {
                Button("Mute") { model.setVolumePreset(0.0) }
                    .buttonStyle(ChipButtonStyle())
                Button("50%") { model.setVolumePreset(0.5) }
                    .buttonStyle(ChipButtonStyle())
                Button("80%") { model.setVolumePreset(0.8) }
                    .buttonStyle(ChipButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                controlSlider(
                    title: "Sensitivity",
                    valueLabel: String(format: "%.2f", model.sensitivity),
                    value: Binding(
                        get: { model.sensitivity },
                        set: { model.updateSensitivity($0) }
                    ),
                    range: 0.10...0.45
                )

                controlSlider(
                    title: "Step",
                    valueLabel: String(format: "%.2f", model.stepSize),
                    value: Binding(
                        get: { model.stepSize },
                        set: { model.updateStepSize($0) }
                    ),
                    range: 0.01...0.10
                )
            }

            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Shortcuts", systemImage: "bolt.horizontal.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: Color.mint.opacity(0.28)))

                Button {
                    showWidgetSheet = true
                } label: {
                    Label("Widget Help", systemImage: "rectangle.grid.2x2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: Color.cyan.opacity(0.24)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func controlSlider(
        title: String,
        valueLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(.white)
        }
        .foregroundStyle(.white)
    }

    private var widgetHelpSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Shortcut and Widget")
                .font(.title3.bold())
            Text("1. Open Shortcuts and add action 'Open App' -> GraVol.")
            Text("2. Save as 'Start GraVol'.")
            Text("3. Add Shortcuts widget to Home Screen, then choose that shortcut.")
            Text("4. Optional: Settings -> Accessibility -> Touch -> Back Tap -> Start GraVol.")
            Spacer()
        }
        .padding(20)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.65 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
