import AppIntents
import ActivityKit
import WidgetKit

struct IncreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Trigger Angle"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let next = min(current + 1, 60)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct DecreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Trigger Angle"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
        let next = max(current - 1, 0)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct IncreaseDownTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Down Trigger Angle"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: 15)
        let next = min(current + 1, 60)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct DecreaseDownTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Down Trigger Angle"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: 15)
        let next = max(current - 1, 0)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(next)
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct RecenterTiltIntent: AppIntent {
    static var title: LocalizedStringResource = "Recenter Tilt"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        GraVolControlRemoteStore.issueRecenterCommand()
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct ToggleTiltArmedIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause or Resume Tilt"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.armedState(defaultValue: true)
        GraVolControlRemoteStore.issueSetArmedCommand(!current)
        reloadWidgets()
        await syncActivity()
        return .result()
    }
}

struct MuteVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Mute or Unmute Volume"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let isMuted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        if isMuted {
            let restore = max(0.01, GraVolControlRemoteStore.lastAudibleVolume(defaultValue: 0.5))
            GraVolControlRemoteStore.setMutedState(false)
            GraVolControlRemoteStore.issueVolumePresetCommand(restore)
        } else {
            GraVolControlRemoteStore.setMutedState(true)
            GraVolControlRemoteStore.issueVolumePresetCommand(0.0)
        }
        reloadWidgets()
        await syncActivity()
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
    WidgetCenter.shared.reloadAllTimelines()
}

private func syncActivity() async {
    guard #available(iOS 16.1, *) else { return }
    let upTrigger = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 15)
    let downTrigger = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: 15)
    let isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
    let existingTilt = Activity<GraVolLiveActivityAttributes>.activities.first?.content.state.tiltDegrees ?? 0
    let state = GraVolLiveActivityAttributes.ContentState(
        tiltDegrees: existingTilt,
        upTriggerDegrees: upTrigger,
        downTriggerDegrees: downTrigger,
        isArmed: isArmed
    )
    if !isArmed {
        for activity in Activity<GraVolLiveActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                let finalContent = ActivityContent(state: state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        return
    }
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
