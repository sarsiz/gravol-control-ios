import AppIntents
import ActivityKit

struct IncreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        let next = min(current + 1, 60)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        await syncActivity(triggerDegrees: next)
        return .result()
    }
}

struct DecreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        let next = max(current - 1, 0)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        await syncActivity(triggerDegrees: next)
        return .result()
    }
}

struct RecenterTiltIntent: AppIntent {
    static var title: LocalizedStringResource = "Recenter Tilt"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueRecenterCommand()
        return .result()
    }
}

private func syncActivity(triggerDegrees: Double) async {
    guard #available(iOS 16.1, *) else { return }
    let state = GraVolLiveActivityAttributes.ContentState(
        tiltDegrees: 0,
        triggerDegrees: triggerDegrees,
        isArmed: true
    )
    if let activity = Activity<GraVolLiveActivityAttributes>.activities.first {
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        } else {
            await activity.update(using: state)
        }
    } else {
        let attributes = GraVolLiveActivityAttributes()
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        } else {
            _ = try? Activity.request(attributes: attributes, contentState: state, pushType: nil)
        }
    }
}
