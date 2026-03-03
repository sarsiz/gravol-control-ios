import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showInfo = false
    @State private var showSetup = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                backgroundGradient

                VStack(spacing: 16) {
                    titleBar
                    volumeDial
                    controlsCard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                infoButton
                    .padding(.leading, 16)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showInfo) { infoSheet }
        .sheet(isPresented: $showSetup) { setupSheet }
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

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.17, blue: 0.26), Color(red: 0.05, green: 0.38, blue: 0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var titleBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GraVol")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tilt control for system volume")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
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
                .fill(.ultraThinMaterial.opacity(0.45))
                .frame(width: 250, height: 250)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )

            Circle()
                .trim(from: 0, to: CGFloat(model.currentVolume))
                .stroke(
                    LinearGradient(colors: [.mint, .cyan, .white], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.84), value: model.currentVolume)

            VStack(spacing: 6) {
                Text("\(Int(model.currentVolume * 100))%")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.lastAction)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(String(format: "%.0f changes/sec", model.volumeChangeRate))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .scaleEffect(model.didLaunchAnimate ? 1 : 0.9)
        .opacity(model.didLaunchAnimate ? 1 : 0.3)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: model.didLaunchAnimate)
        .frame(maxWidth: .infinity)
    }

    private var controlsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    model.nudgeDown()
                } label: {
                    Label("Down", systemImage: "minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.17)))

                Button {
                    model.nudgeUp()
                } label: {
                    Label("Up", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.22)))
            }

            HStack(spacing: 10) {
                Button("Mute") { model.setVolumePreset(0.0) }
                    .buttonStyle(ChipStyle())
                Button("50%") { model.setVolumePreset(0.5) }
                    .buttonStyle(ChipStyle())
                Button("80%") { model.setVolumePreset(0.8) }
                    .buttonStyle(ChipStyle())
                Button("Recenter") { model.recenterTiltReference() }
                    .buttonStyle(ChipStyle())
            }

            Button {
                model.setArmed(!model.isArmed)
            } label: {
                Label(model.isArmed ? "Pause Tilt" : "Resume Tilt", systemImage: model.isArmed ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MainButtonStyle(accent: .orange.opacity(0.28)))

            sliderRow(
                title: "Sensitivity",
                valueLabel: String(format: "%.2f", model.sensitivity),
                value: Binding(
                    get: { model.sensitivity },
                    set: { model.updateSensitivity($0) }
                ),
                range: 0.10...0.45
            )

            sliderRow(
                title: "Step",
                valueLabel: String(format: "%.2f", model.stepSize),
                value: Binding(
                    get: { model.stepSize },
                    set: { model.updateStepSize($0) }
                ),
                range: 0.01...0.10
            )

            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Shortcuts", systemImage: "bolt.horizontal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .mint.opacity(0.26)))

                Button {
                    showSetup = true
                } label: {
                    Label("Setup Trigger", systemImage: "app.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .cyan.opacity(0.24)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var infoButton: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.7))
                )
        }
    }

    private func sliderRow(
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
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(.white)
        }
        .foregroundStyle(.white)
    }

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How GraVol Works")
                .font(.title3.bold())
            Text("1. Keep phone in your normal hold and tap Recenter.")
            Text("2. Enable Tilt Ready using the top-right toggle.")
            Text("3. Tilt toward you to increase volume, away to decrease.")
            Text("4. Motion filtering ignores fast random movement and only reacts to sustained tilt.")
            Text("5. Turn off the toggle anytime to stop control immediately.")
            Spacer()
        }
        .padding(20)
        .presentationDetents([.fraction(0.46), .medium])
    }

    private var setupSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcut, Widget, and Action Button")
                .font(.title3.bold())
            Text("1. In Shortcuts, create 'Start GraVol' with action: Open App -> GraVol Control.")
            Text("2. Add Shortcuts widget on Home Screen and choose that shortcut.")
            Text("3. Action Button (iPhone 15 Pro and newer):")
            Text("   Settings -> Action Button -> Shortcut -> Start GraVol")
            Text("4. Back Tap option: Settings -> Accessibility -> Touch -> Back Tap -> Start GraVol")
            Spacer()
        }
        .padding(20)
        .presentationDetents([.fraction(0.48), .medium])
    }
}

private struct MainButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.65 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.24 : 0.16))
                    .overlay(Capsule().stroke(.white.opacity(0.33), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
