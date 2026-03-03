import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showInfo = false
    @State private var showSetup = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    volumeCard
                    controlsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            infoButton
                .padding(.leading, 16)
                .padding(.bottom, 18)
        }
        .ignoresSafeArea()
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
            .frame(width: 1, height: 1)
        )
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.34), Color.blue.opacity(0.34), Color.teal.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.35)
            )

            Circle()
                .fill(.white.opacity(0.18))
                .blur(radius: 60)
                .frame(width: 240, height: 240)
                .offset(x: -120, y: -280)

            Circle()
                .fill(.cyan.opacity(0.2))
                .blur(radius: 70)
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 300)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GraVol")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tilt controls system volume")
                    .font(.footnote)
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

    private var volumeCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
                    .frame(width: 210, height: 210)
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

                Circle()
                    .trim(from: 0, to: CGFloat(model.currentVolume))
                    .stroke(
                        LinearGradient(colors: [.mint, .cyan, .white], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 184, height: 184)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.85), value: model.currentVolume)

                VStack(spacing: 4) {
                    Text("\(Int(model.currentVolume * 100))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(model.lastAction)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(String(format: "%.0f/s", model.volumeChangeRate))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .scaleEffect(model.didLaunchAnimate ? 1 : 0.92)
            .opacity(model.didLaunchAnimate ? 1 : 0.4)
            .animation(.spring(response: 0.62, dampingFraction: 0.82), value: model.didLaunchAnimate)

            Text(model.isVolumeControlReady ? "Bridge Ready" : "Setting up volume bridge...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(cardGlass)
    }

    private var controlsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { model.nudgeDown() } label: {
                    Label("Down", systemImage: "minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.16)))

                Button { model.nudgeUp() } label: {
                    Label("Up", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.2)))
            }

            HStack(spacing: 8) {
                Button("Mute") { model.setVolumePreset(0.0) }.buttonStyle(ChipStyle())
                Button("50%") { model.setVolumePreset(0.5) }.buttonStyle(ChipStyle())
                Button("80%") { model.setVolumePreset(0.8) }.buttonStyle(ChipStyle())
                Button("Recenter") { model.recenterTiltReference() }.buttonStyle(ChipStyle())
            }

            Button {
                model.setArmed(!model.isArmed)
            } label: {
                Label(model.isArmed ? "Pause Tilt" : "Resume Tilt", systemImage: model.isArmed ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MainButtonStyle(accent: .orange.opacity(0.24)))

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
                .buttonStyle(MainButtonStyle(accent: .mint.opacity(0.24)))

                Button { showSetup = true } label: {
                    Label("Setup Trigger", systemImage: "app.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .cyan.opacity(0.22)))
            }
        }
        .padding(14)
        .background(cardGlass)
    }

    private var cardGlass: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.72)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
    }

    private var infoButton: some View {
        Button { showInfo = true } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.85)
                )
        }
    }

    private func sliderRow(
        title: String,
        valueLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.footnote.weight(.semibold))
                Spacer()
                Text(valueLabel).font(.caption.weight(.bold))
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(.white)
        }
        .foregroundStyle(.white)
    }

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How It Works")
                .font(.title3.bold())
            Text("1. Open app from Shortcut, Action Button, widget, or Back Tap.")
            Text("2. Tap Recenter in your natural hand position.")
            Text("3. Tilt toward you to raise volume, away to lower volume.")
            Text("4. Tap Pause Tilt when done to prevent accidental changes.")
            Spacer()
        }
        .padding(20)
        .presentationDetents([.fraction(0.42), .medium])
    }

    private var setupSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trigger Setup")
                .font(.title3.bold())
            Text("Shortcut: create 'Start GraVol' using Open App -> GraVol.")
            Text("Widget: add Shortcuts widget and pick Start GraVol.")
            Text("Action Button (supported models): Settings -> Action Button -> Shortcut -> Start GraVol.")
            Text("Back Tap: Settings -> Accessibility -> Touch -> Back Tap -> Start GraVol.")
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.65 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.23 : 0.15))
                    .overlay(Capsule().stroke(.white.opacity(0.34), lineWidth: 1))
            )
    }
}
