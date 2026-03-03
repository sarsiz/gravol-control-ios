import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSheet: ActiveSheet?
    @State private var infoDetent: PresentationDetent = .medium

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                backgroundLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        volumeCard
                        controlsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 24)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                infoButton
                    .padding(.leading, 16)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    islandAngleBadge
                    header
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .background(Color.clear)
            }
        }
        .sheet(item: $activeSheet) { item in
            switch item {
            case .info:
                infoSheet
                    .presentationDetents([.medium, .large], selection: $infoDetent)
                    .presentationDragIndicator(.visible)
            case .setup:
                setupSheet
                    .presentationDetents([.fraction(0.48), .medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
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
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.15, blue: 0.24),
                Color(red: 0.04, green: 0.30, blue: 0.32),
                Color(red: 0.03, green: 0.08, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.16)
        )
    }

    private var islandAngleBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "angle")
            Text(String(format: "%+.1f°", model.currentTiltDegrees))
                .font(.footnote.monospacedDigit().weight(.semibold))
            Text("Trigger \(Int(model.triggerAngleDegrees))°")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GraVol")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tilt controls system volume")
                    .font(.footnote)
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

    private var volumeCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.55))
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
            .disabled(!model.isVolumeControlReady)
            .opacity(model.isVolumeControlReady ? 1 : 0.55)

            HStack(spacing: 12) {
                CircularAngleSlider(
                    value: Binding(
                        get: { model.triggerAngleDegrees },
                        set: { model.updateTriggerAngleDegrees($0) }
                    ),
                    range: 0...60
                )
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trigger Angle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("\(Int(model.triggerAngleDegrees))°")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(tiltDirectionLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }

            Button {
                model.setArmed(!model.isArmed)
            } label: {
                Label(model.isArmed ? "Pause Tilt" : "Resume Tilt", systemImage: model.isArmed ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MainButtonStyle(accent: .orange.opacity(0.24)))

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

                Button { activeSheet = .setup } label: {
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
            .fill(.ultraThinMaterial.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
    }

    private var infoButton: some View {
        Button {
            activeSheet = .info
            infoDetent = .medium
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.85))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("How It Works")
                    .font(.title3.bold())

                Group {
                    Text("1. Open app from Shortcut, Action Button, widget, or Back Tap.")
                    Text("2. Keep the phone near horizontal (0° reference).")
                    Text("3. Tilt up positive, down negative.")
                    Text("4. Trigger angle controls when tilt starts changing volume.")
                    Text("5. Tap Pause Tilt when done.")
                }
                .font(.body)
                .onTapGesture {
                    infoDetent = .large
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    }

    private var tiltDirectionLabel: String {
        String(format: "Tilt %+.1f°", model.currentTiltDegrees)
    }
}

private enum ActiveSheet: String, Identifiable {
    case info
    case setup
    var id: String { rawValue }
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

private struct CircularAngleSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let startAngle: Double = -135
    private let endAngle: Double = 135

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth: CGFloat = 8
            let radius = size / 2 - lineWidth / 2
            let sweep = endAngle - startAngle
            let progress = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
            let knobAngle = startAngle + sweep * progress

            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(sweep / 360))
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(startAngle))

                Circle()
                    .trim(from: 0, to: CGFloat((sweep / 360) * progress))
                    .stroke(
                        LinearGradient(colors: [.mint, .cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(startAngle))

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: cos(knobAngle * .pi / 180) * radius,
                        y: sin(knobAngle * .pi / 180) * radius
                    )
                    .shadow(radius: 2)

                Text("\(Int(value))°")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        let angle = atan2(dy, dx) * 180 / .pi
                        let clampedAngle = min(max(angle, startAngle), endAngle)
                        let localProgress = (clampedAngle - startAngle) / (endAngle - startAngle)
                        value = range.lowerBound + localProgress * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}
