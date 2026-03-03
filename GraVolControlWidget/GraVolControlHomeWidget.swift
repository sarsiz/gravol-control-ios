import SwiftUI
import WidgetKit

private struct GraVolEntry: TimelineEntry {
    let date: Date
    let angle: Double
}

private struct GraVolProvider: TimelineProvider {
    func placeholder(in context: Context) -> GraVolEntry {
        GraVolEntry(date: Date(), angle: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (GraVolEntry) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        completion(GraVolEntry(date: Date(), angle: angle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GraVolEntry>) -> Void) {
        let angle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        let entry = GraVolEntry(date: Date(), angle: angle)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900))))
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("GraVol")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Trigger \(Int(entry.angle))°")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(10)
            }
        }
        .configurationDisplayName("GraVol")
        .description("Quick view of current trigger angle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
