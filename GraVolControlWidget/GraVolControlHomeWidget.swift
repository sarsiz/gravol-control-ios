import SwiftUI
import WidgetKit

private struct GraVolEntry: TimelineEntry {
    let date: Date
    let angle: Double
    let isArmed: Bool
}

private struct GraVolProvider: TimelineProvider {
    func placeholder(in context: Context) -> GraVolEntry {
        GraVolEntry(date: Date(), angle: 21, isArmed: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GraVolEntry) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 21)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        completion(GraVolEntry(date: Date(), angle: angle, isArmed: isArmed))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GraVolEntry>) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 21)
        let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        let entry = GraVolEntry(date: Date(), angle: angle, isArmed: isArmed)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(180))))
    }
}

struct GraVolControlHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GraVolControlHomeWidget", provider: GraVolProvider()) { entry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.35, blue: 0.36), Color(red: 0.06, green: 0.16, blue: 0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GraVol")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(entry.isArmed ? "Tilt On" : "Tilt Off")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text("Trigger \(Int(entry.angle))°")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.92))

                    HStack(spacing: 6) {
                        Button(intent: ToggleTiltArmedIntent()) { chip("Pause/Run") }
                        Button(intent: MuteVolumeIntent()) { chip("Mute") }
                        Button(intent: Volume30Intent()) { chip("30%") }
                    }

                    HStack(spacing: 6) {
                        Button(intent: Volume50Intent()) { chip("50%") }
                        Button(intent: Volume80Intent()) { chip("80%") }
                        Button(intent: RecenterTiltIntent()) { chip("Recenter") }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            }
        }
        .configurationDisplayName("GraVol")
        .description("Quick view of current trigger angle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
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
