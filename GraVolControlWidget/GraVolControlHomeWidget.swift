import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
private struct GraVolEntry: TimelineEntry {
    let date: Date
    let angle: Double
    let isArmed: Bool
    let isMuted: Bool
}

@available(iOSApplicationExtension 17.0, *)
private struct GraVolProvider: TimelineProvider {
    func placeholder(in context: Context) -> GraVolEntry {
        GraVolEntry(date: Date(), angle: 15, isArmed: true, isMuted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (GraVolEntry) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        let isMuted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        completion(GraVolEntry(date: Date(), angle: angle, isArmed: isArmed, isMuted: isMuted))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GraVolEntry>) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        let isMuted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        let entry = GraVolEntry(date: Date(), angle: angle, isArmed: isArmed, isMuted: isMuted)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(180))))
    }
}

@available(iOSApplicationExtension 17.0, *)
struct GraVolControlHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GraVolControlHomeWidget", provider: GraVolProvider()) { entry in
            GraVolHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("GraVol")
        .description("Quick view of current trigger angle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct GraVolHomeWidgetView: View {
    let entry: GraVolEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.33, blue: 0.38), Color(red: 0.05, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.ultraThinMaterial.opacity(0.22))

            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge:
                largeLayout
            default:
                mediumLayout
            }
        }
    }

    private var header: some View {
        HStack {
            Text("GraVol")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text(entry.isArmed ? "Tilt On" : "Tilt Off")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var statusLine: some View {
        Text("Trigger \(Int(entry.angle))°")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.white.opacity(0.92))
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            statusLine
            Spacer(minLength: 0)
            controlGrid(includeTriggerStep: false)
        }
        .padding(10)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack {
                statusLine
                Spacer()
                triggerStepChips
            }
            Spacer(minLength: 0)
            controlGrid(includeTriggerStep: false)
        }
        .padding(10)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            HStack {
                statusLine
                Spacer()
                triggerStepChips
            }
            Spacer(minLength: 0)
            controlGrid(includeTriggerStep: true)
        }
        .padding(12)
    }

    private var triggerStepChips: some View {
        HStack(spacing: 6) {
            Button(intent: DecreaseTriggerAngleIntent()) { chip("−T", fullWidth: false) }
            Button(intent: IncreaseTriggerAngleIntent()) { chip("+T", fullWidth: false) }
        }
    }

    @ViewBuilder
    private func controlGrid(includeTriggerStep: Bool) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 6),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 6),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 6)
        ]

        LazyVGrid(columns: columns, spacing: 6) {
            Button(intent: ToggleTiltArmedIntent()) { chip(entry.isArmed ? "Pause" : "Resume") }
            Button(intent: MuteVolumeIntent()) { chip(entry.isMuted ? "Unmute" : "Mute") }
            Button(intent: RecenterTiltIntent()) { chip("Recenter") }
            if includeTriggerStep {
                Button(intent: DecreaseTriggerAngleIntent()) { chip("−T") }
                Button(intent: IncreaseTriggerAngleIntent()) { chip("+T") }
            }
        }
    }

    private func chip(_ title: String, fullWidth: Bool = true) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.white.opacity(0.16))
                    .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
