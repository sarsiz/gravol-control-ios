import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSheet: ActiveSheet?
    @State private var infoDetent: PresentationDetent = .medium
    @State private var upPulse = false
    @State private var downPulse = false

    // Tweak these if you want the pill/header tighter/looser.
    private let islandBadgeTopGap: CGFloat = 4
    private let islandBadgeHeight: CGFloat = 34
    private let badgeContentSpacing: CGFloat = 10

    var body: some View {
        ZStack {
            // ✅ Always paint edge-to-edge (fixes black bars top/bottom).
            backgroundLayer
                .ignoresSafeArea()

            GeometryReader { geo in
                let bottomInset = geo.safeAreaInsets.bottom
                let badgeTopY = max(islandBadgeTopGap, geo.safeAreaInsets.top - 50)
                let reservedTop = badgeTopY + islandBadgeHeight + badgeContentSpacing

                ZStack(alignment: .bottomLeading) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            header
                            volumeCard
                            controlsCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, reservedTop)
                        .padding(.bottom, max(2, bottomInset - 6))
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    infoButton
                        .padding(.leading, 16)
                        .padding(.bottom, max(4, bottomInset - 4))
                }
                .overlay(alignment: .top) {
                    islandAngleBadge
                        .padding(.top, badgeTopY)
                        .padding(.horizontal, 16)
                }
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
                Text("Gravity Volume")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Tilt controls system volume")
                    .font(.caption)
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
                Button {
                    animateNudge(isUp: false)
                    model.nudgeDown()
                } label: {
                    Label("Down", systemImage: "minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.16)))
                .scaleEffect(downPulse ? 0.96 : 1)
                .animation(.spring(response: 0.20, dampingFraction: 0.72), value: downPulse)

                Button {
                    animateNudge(isUp: true)
                    model.nudgeUp()
                } label: {
                    Label("Up", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MainButtonStyle(accent: .white.opacity(0.2)))
                .scaleEffect(upPulse ? 0.96 : 1)
                .animation(.spring(response: 0.20, dampingFraction: 0.72), value: upPulse)
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
                    range: 0...60,
                    onUseDefault: { model.resetTriggerToDefault() },
                    onSetDefault: { model.updateDefaultTriggerAngleDegrees(model.triggerAngleDegrees) }
                )
                .frame(width: 140, height: 140)
                .frame(width: 146, alignment: .center)
                .offset(x: 14)
                .contentShape(Rectangle())

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Trigger Angle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("\(Int(model.triggerAngleDegrees))°")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(String(format: "Tilt %+.1f°", model.currentTiltDegrees))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("Default \(Int(model.defaultTriggerAngleDegrees))°")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    model.setArmed(!model.isArmed)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.isArmed ? "pause.fill" : "play.fill")
                        .font(.footnote.weight(.bold))
                        .frame(width: 16, height: 16)
                        .padding(3)
                        .background(
                            Circle()
                                .fill(.white.opacity(model.isArmed ? 0.22 : 0.28))
                        )
                    Text(model.isArmed ? "Pause Tilt" : "Resume Tilt")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(.white.opacity(0.26), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: model.isArmed
                                            ? [Color.white.opacity(0.08), Color.orange.opacity(0.22)]
                                            : [Color.white.opacity(0.10), Color.mint.opacity(0.22)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                )
                .scaleEffect(model.isArmed ? 1 : 0.995)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.isArmed)
            }
            .buttonStyle(.plain)

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
                .onTapGesture { infoDetent = .large }
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

    private func animateNudge(isUp: Bool) {
        if isUp {
            upPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { upPulse = false }
        } else {
            downPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { downPulse = false }
        }
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
    let onUseDefault: () -> Void
    let onSetDefault: () -> Void
    @State private var isDragging = false

    private let startAngle: Double = -135
    private let endAngle: Double = 135

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth: CGFloat = 8
            let sweep = endAngle - startAngle
            let progress = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)

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

                VStack(spacing: 6) {
                    Text("\(Int(value))°")
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                    VStack(spacing: 5) {
                        Button("Default") { onUseDefault() }
                            .buttonStyle(InnerChipStyle())
                        Button("Set Default") { onSetDefault() }
                            .buttonStyle(InnerChipStyle())
                    }
                }
            }
            .frame(width: size, height: size, alignment: .center)
            .contentShape(Circle())
            .animation(
                isDragging
                    ? .linear(duration: 0.04)
                    : .interactiveSpring(response: 0.24, dampingFraction: 0.82),
                value: value
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        value = range.lowerBound + progressForDrag(dx: dx, dy: dy) * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in isDragging = false }
            , including: .gesture)
        }
    }

    private func progressForDrag(dx: CGFloat, dy: CGFloat) -> Double {
        var theta = atan2(dy, dx) * 180 / .pi
        if theta < 0 { theta += 360 }
        let sweepStart = 225.0
        let sweepEnd = 495.0
        if theta < sweepStart { theta += 360 }
        let clamped = min(max(theta, sweepStart), sweepEnd)
        return (clamped - sweepStart) / (sweepEnd - sweepStart)
    }
}

private struct InnerChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 86)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.24 : 0.14))
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
