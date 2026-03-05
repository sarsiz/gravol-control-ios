import SwiftUI
import WidgetKit

private struct GraVolEntry: TimelineEntry {
    let date: Date
    let upAngle: Double
    let downAngle: Double
    let isArmed: Bool
    let isMuted: Bool
}

private struct GraVolProvider: TimelineProvider {
    func placeholder(in context: Context) -> GraVolEntry {
        GraVolEntry(date: Date(), upAngle: 15, downAngle: 15, isArmed: true, isMuted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (GraVolEntry) -> Void) {
        let upAngle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let downAngle = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: 15)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        let isMuted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        completion(GraVolEntry(date: Date(), upAngle: upAngle, downAngle: downAngle, isArmed: isArmed, isMuted: isMuted))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GraVolEntry>) -> Void) {
        let upAngle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let downAngle = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: 15)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        let isMuted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        let entry = GraVolEntry(date: Date(), upAngle: upAngle, downAngle: downAngle, isArmed: isArmed, isMuted: isMuted)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(180))))
    }
}

struct GraVolControlHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GraVolControlHomeWidget", provider: GraVolProvider()) { entry in
            GraVolHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("GraVol")
        .description("Quick view of current trigger angle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private struct GraVolHomeWidgetView: View {
    let entry: GraVolEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
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
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.33, blue: 0.38), Color(red: 0.05, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.ultraThinMaterial.opacity(0.22))
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
        Text(String(format: "U +%.0f°  D -%.0f°", entry.upAngle, entry.downAngle))
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
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: DecreaseTriggerAngleIntent()) { chip("−T", fullWidth: false) }
                Button(intent: IncreaseTriggerAngleIntent()) { chip("+T", fullWidth: false) }
                Button(intent: DecreaseDownTriggerAngleIntent()) { chip("−D", fullWidth: false) }
                Button(intent: IncreaseDownTriggerAngleIntent()) { chip("+D", fullWidth: false) }
            } else {
                chip("Open App", fullWidth: false)
            }
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
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: ToggleTiltArmedIntent()) { chip(entry.isArmed ? "Pause" : "Resume") }
                Button(intent: MuteVolumeIntent()) { chip(entry.isMuted ? "Unmute" : "Mute") }
                Button(intent: RecenterTiltIntent()) { chip("Recenter") }
                if includeTriggerStep {
                    Button(intent: DecreaseTriggerAngleIntent()) { chip("−T") }
                    Button(intent: IncreaseTriggerAngleIntent()) { chip("+T") }
                    Button(intent: DecreaseDownTriggerAngleIntent()) { chip("−D") }
                    Button(intent: IncreaseDownTriggerAngleIntent()) { chip("+D") }
                }
            } else {
                chip(entry.isArmed ? "Tilt On" : "Tilt Off")
                chip(entry.isMuted ? "Muted" : "Sound On")
                chip("Open App")
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
