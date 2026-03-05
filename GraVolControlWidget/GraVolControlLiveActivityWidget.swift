import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct GraVolControlLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GraVolLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text("GraVol Control")
                    .font(.headline)
                Text(String(format: "Tilt: %+.1f°", context.state.tiltDegrees))
                    .font(.subheadline.monospacedDigit())
                Text(String(format: "U +%.0f°  D -%.0f°", context.state.upTriggerDegrees, context.state.downTriggerDegrees))
                    .font(.caption)
            }
            .padding(12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(String(format: "%+.1f°", context.state.tiltDegrees))
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "U +%.0f°", context.state.upTriggerDegrees))
                        Text(String(format: "D -%.0f°", context.state.downTriggerDegrees))
                    }
                        .font(.subheadline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if #available(iOSApplicationExtension 17.0, *) {
                            Button(intent: DecreaseTriggerAngleIntent()) {
                                Image(systemName: "minus.circle.fill")
                            }
                            Button(intent: IncreaseTriggerAngleIntent()) {
                                Image(systemName: "plus.circle.fill")
                            }
                            Button(intent: RecenterTiltIntent()) {
                                Image(systemName: "dot.scope")
                            }
                        } else {
                            Text("Open app for controls")
                                .font(.caption)
                        }
                    }
                }
            } compactLeading: {
                Text(String(format: "%+.0f°", context.state.tiltDegrees))
                    .font(.caption2.monospacedDigit())
            } compactTrailing: {
                Text(String(format: "+%.0f/-%.0f", context.state.upTriggerDegrees, context.state.downTriggerDegrees))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isArmed ? "gyroscope" : "pause.fill")
            }
        }
    }
}
