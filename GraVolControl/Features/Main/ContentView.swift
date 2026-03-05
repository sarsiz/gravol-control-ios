import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSheet: ActiveSheet?
    @State private var infoDetent: PresentationDetent = .medium
    @State private var upPulse = false
    @State private var downPulse = false

    private let islandBadgeTopGap: CGFloat = 6
    private let islandBadgeHeight: CGFloat = 38
    private let islandBadgeSpacingToHeader: CGFloat = 10

    var body: some View {
        ZStack {
            // ✅ Always paint edge-to-edge (fixes black bars top/bottom).
            backgroundLayer
                .ignoresSafeArea()

            GeometryReader { geo in
                let bottomInset = geo.safeAreaInsets.bottom
                let badgeTop = geo.safeAreaInsets.top + islandBadgeTopGap
                let contentTopInset = badgeTop + islandBadgeHeight + islandBadgeSpacingToHeader

                ZStack(alignment: .bottomLeading) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            header
                            volumeCard
                            controlsCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, contentTopInset)
                        .padding(.bottom, max(14, bottomInset + 8))
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    infoButton
                        .padding(.leading, 16)
                        .padding(.bottom, max(8, bottomInset + 4))
                }
                .overlay(alignment: .top) {
                    islandAngleBadge
                        .padding(.top, badgeTop)
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
            .frame(width: 120, height: 30)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .opacity(0.01)
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
            Text(String(format: "U +%.0f°", model.triggerAngleDegrees))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(String(format: "D -%.0f°", model.downTriggerAngleDegrees))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.55))
                    .frame(width: 204, height: 204)
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

                Circle()
                    .trim(from: 0, to: CGFloat(model.currentVolume))
                    .stroke(
                        LinearGradient(
                            colors: volumeRingColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 178, height: 178)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.85), value: model.currentVolume)

                VStack(spacing: 4) {
                    Text("\(Int(model.currentVolume * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !model.lastAction.isEmpty {
                        Text(model.lastAction)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: model.lastAction)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        updateVolumeFromDial(drag.location, size: CGSize(width: 204, height: 204))
                    }
            )
            .scaleEffect(model.didLaunchAnimate ? 1 : 0.92)
            .opacity(model.didLaunchAnimate ? 1 : 0.4)
            .animation(.spring(response: 0.62, dampingFraction: 0.82), value: model.didLaunchAnimate)

            Text(model.isVolumeControlReady ? "Bridge Ready" : "Setting up volume bridge...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))

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
                Button(model.currentVolume <= 0.001 ? "Unmute" : "Mute") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.toggleMute()
                    }
                }
                .buttonStyle(ChipStyle())
                .animation(.easeInOut(duration: 0.2), value: model.currentVolume)
                Button("50%") { model.setVolumePreset(0.5) }.buttonStyle(ChipStyle())
                Button("80%") { model.setVolumePreset(0.8) }.buttonStyle(ChipStyle())
            }
            .opacity(model.isVolumeControlReady ? 1 : 0.82)

            stepRail
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(cardGlass)
    }

    private var controlsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Recenter Baseline") { model.recenterTiltReference() }.buttonStyle(ChipStyle())
            }
            Text("Recenter sets your current phone angle as neutral to reduce false tilt triggers.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                DualTriggerAngleDial(
                    upValue: Binding(
                        get: { model.triggerAngleDegrees },
                        set: { model.updateTriggerAngleDegrees($0) }
                    ),
                    downValue: Binding(
                        get: { model.downTriggerAngleDegrees },
                        set: { model.updateDownTriggerAngleDegrees($0) }
                    ),
                    range: 0...60,
                    currentTilt: model.currentTiltDegrees,
                    tiltLearnEnabled: model.isTiltLearnMode
                )
                .frame(width: 204, height: 204)
                .contentShape(Circle())

                VStack(alignment: .trailing, spacing: 5) {
                    Text(String(format: "Up +%.0f°", model.triggerAngleDegrees))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text(String(format: "Down -%.0f°", model.downTriggerAngleDegrees))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(String(format: "Tilt %+.1f°", model.currentTiltDegrees))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text(String(format: "Defaults +%.0f° / -%.0f°", model.defaultTriggerAngleDegrees, model.defaultDownTriggerAngleDegrees))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(model.tiltStatus)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Toggle(isOn: Binding(
                get: { model.isTiltLearnMode },
                set: { model.setTiltLearnMode($0) }
            )) {
                Text("Set Triggers By Moving Phone")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .tint(.mint)

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    model.setArmed(!model.isArmed)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.isArmed ? "pause.fill" : "play.fill")
                        .font(.footnote.weight(.bold))
                        .frame(width: 16, height: 16)
                        .padding(2)
                        .background(
                            Circle()
                                .fill(.white.opacity(model.isArmed ? 0.22 : 0.28))
                        )
                    Text(model.isArmed ? "Pause Tilt" : "Resume Tilt")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
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

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Increment %")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(String(format: "%.2f%%", model.stepSize))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                Button("-") { model.updateStepSize(model.stepSize - 0.01) }
                    .buttonStyle(ChipStyle())

                GeometryReader { geo in
                    let progress = CGFloat((model.stepSize - 0.01) / (5.0 - 0.01))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.mint.opacity(0.9), .cyan.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, geo.size.width * progress))
                    }
                    .overlay(
                        Capsule().stroke(.white.opacity(0.24), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let x = min(max(0, drag.location.x), geo.size.width)
                                let raw = 0.01 + (Double(x / geo.size.width) * (5.0 - 0.01))
                                let snapped = (raw / 0.01).rounded() * 0.01
                                model.updateStepSize(max(0.01, min(5.0, snapped)))
                            }
                    )
                }
                .frame(height: 26)

                Button("+") { model.updateStepSize(model.stepSize + 0.01) }
                    .buttonStyle(ChipStyle())
            }
        }
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
                    Text("5. Use Recenter Baseline to reset neutral angle when your grip changes.")
                    Text("6. Tap Pause Tilt when done.")
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

    private var volumeRingColors: [Color] {
        let maxTrigger = max(model.triggerAngleDegrees, model.downTriggerAngleDegrees, 1)
        let intensity = min(max(abs(model.currentTiltDegrees) / maxTrigger, 0), 1)
        return [
            Color(red: 0.30 - 0.08 * intensity, green: 0.76 + 0.16 * intensity, blue: 0.78 + 0.14 * intensity),
            Color(red: 0.18 + 0.14 * intensity, green: 0.62 + 0.14 * intensity, blue: 0.96),
            Color.white.opacity(0.78 + 0.22 * intensity)
        ]
    }

    private func updateVolumeFromDial(_ location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi + 90
        if angle < 0 { angle += 360 }
        var normalized = min(max(Float(angle / 360), 0), 1)

        // Prevent seam wrap at the top (100% <-> 0%) while dragging.
        let seam: Float = 0.08
        let current = model.currentVolume
        if current > (1 - seam) && normalized < seam {
            normalized = 1
        } else if current < seam && normalized > (1 - seam) {
            normalized = 0
        }

        model.setVolumeDirect(normalized)
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

private struct DualTriggerAngleDial: View {
    @Binding var upValue: Double
    @Binding var downValue: Double
    let range: ClosedRange<Double>
    let currentTilt: Double
    let tiltLearnEnabled: Bool
    @State private var isDragging = false

    private let startAngle: Double = -135
    private let endAngle: Double = 135

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth: CGFloat = 11
            let maxValue = max(range.upperBound, 1)
            let tiltIntensity = min(max(abs(currentTilt) / maxValue, 0), 1)

            let upAngle = (upValue / maxValue) * endAngle
            let downAngle = -(downValue / maxValue) * abs(startAngle)
            let tiltAngle = signedAngle(for: currentTilt, maxValue: maxValue)
            let upProgress = min(max(upValue / maxValue, 0), 1)
            let downProgress = min(max(downValue / maxValue, 0), 1)

            ZStack {
                ArcSegment(startAngle: .degrees(startAngle), endAngle: .degrees(0))
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                ArcSegment(startAngle: .degrees(0), endAngle: .degrees(endAngle))
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                ArcSegment(startAngle: .degrees(0), endAngle: .degrees(upAngle))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.75 + 0.20 * upProgress, blue: 0.78 + 0.18 * upProgress),
                                Color(red: 0.16 + 0.20 * tiltIntensity, green: 0.55 + 0.35 * upProgress, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                ArcSegment(startAngle: .degrees(downAngle), endAngle: .degrees(0))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.45 + 0.35 * downProgress, blue: 0.22 + 0.20 * downProgress),
                                Color(red: 1.0, green: 0.30 + 0.30 * downProgress, blue: 0.40 + 0.30 * tiltIntensity)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                if tiltLearnEnabled {
                    ArcSegment(startAngle: .degrees(tiltAngle), endAngle: .degrees(tiltAngle + 0.8))
                        .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .animation(.easeOut(duration: 0.12), value: tiltAngle)
                }

                VStack(spacing: 5) {
                    Text(String(format: "-%.0f°  |  +%.0f°", downValue, upValue))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                    if tiltLearnEnabled {
                        Text("Move phone to set")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                .padding(.top, 8)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .animation(
                isDragging ? .linear(duration: 0.04) : .interactiveSpring(response: 0.24, dampingFraction: 0.82),
                value: upValue
            )
            .animation(
                isDragging ? .linear(duration: 0.04) : .interactiveSpring(response: 0.24, dampingFraction: 0.82),
                value: downValue
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        let signed = signedDragAngle(dx: dx, dy: dy)
                        let mapped = min(max(abs(signed) / abs(endAngle) * maxValue, range.lowerBound), range.upperBound)
                        if signed >= 0 {
                            upValue = mapped
                        } else {
                            downValue = mapped
                        }
                    }
                    .onEnded { _ in isDragging = false }
            , including: .gesture)
        }
    }

    private func signedDragAngle(dx: CGFloat, dy: CGFloat) -> Double {
        var theta = atan2(dy, dx) * 180 / .pi + 90
        if theta > 180 { theta -= 360 }
        return min(max(theta, startAngle), endAngle)
    }

    private func signedAngle(for tilt: Double, maxValue: Double) -> Double {
        let clamped = min(max(tilt, -maxValue), maxValue)
        return (clamped / maxValue) * endAngle
    }
}

private struct ArcSegment: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle - .degrees(90),
            endAngle: endAngle - .degrees(90),
            clockwise: false
        )
        return path
    }
}

private struct InnerChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 100)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.24 : 0.14))
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
