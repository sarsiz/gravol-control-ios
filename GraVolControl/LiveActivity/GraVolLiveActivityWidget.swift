#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct GraVolLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GraVolLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text("GraVol Control")
                    .font(.headline)
                Text(String(format: "Tilt: %+.1f°", context.state.tiltDegrees))
                    .font(.subheadline.monospacedDigit())
                Text("Trigger: \(Int(context.state.triggerDegrees))°")
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
                    Text("T \(Int(context.state.triggerDegrees))°")
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
                Text("T\(Int(context.state.triggerDegrees))")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isArmed ? "gyroscope" : "pause.fill")
            }
        }
    }
}
#endif
