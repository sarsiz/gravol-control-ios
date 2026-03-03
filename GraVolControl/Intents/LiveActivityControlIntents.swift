import AppIntents
import ActivityKit
import WidgetKit

struct IncreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let next = min(current + 1, 60)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity(triggerDegrees: next)
        return .result()
    }
}

struct DecreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let next = max(current - 1, 0)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity(triggerDegrees: next)
        return .result()
    }
}

struct RecenterTiltIntent: AppIntent {
    static var title: LocalizedStringResource = "Recenter Tilt"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueRecenterCommand()
        reloadWidgets()
        return .result()
    }
}

struct ToggleTiltArmedIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause or Resume Tilt"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.armedState(defaultValue: true)
        GraVolControlRemoteStore.issueSetArmedCommand(!current)
        reloadWidgets()
        return .result()
    }
}

struct MuteVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Mute Volume"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueVolumePresetCommand(0.0)
        reloadWidgets()
        return .result()
    }
}

struct Volume30Intent: AppIntent {
    static var title: LocalizedStringResource = "Set Volume 30 Percent"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueVolumePresetCommand(0.3)
        reloadWidgets()
        return .result()
    }
}

struct Volume50Intent: AppIntent {
    static var title: LocalizedStringResource = "Set Volume 50 Percent"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueVolumePresetCommand(0.5)
        reloadWidgets()
        return .result()
    }
}

struct Volume80Intent: AppIntent {
    static var title: LocalizedStringResource = "Set Volume 80 Percent"

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueVolumePresetCommand(0.8)
        reloadWidgets()
        return .result()
    }
}

private func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
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
