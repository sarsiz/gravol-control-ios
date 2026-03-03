import AppIntents
import ActivityKit

struct StartGraVolIntent: AppIntent {
    static var title: LocalizedStringResource = "Start GraVol"
    static var description = IntentDescription("Open GraVol Control so tilt-based volume control can start.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct IncreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        let next = min(current + 1, 60)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        if #available(iOS 16.1, *) {
            let state = GraVolLiveActivityAttributes.ContentState(
                tiltDegrees: 0,
                triggerDegrees: next,
                isArmed: true
            )
            await GraVolLiveActivityController.shared.startOrUpdate(state)
        }
        return .result()
    }
}

struct DecreaseTriggerAngleIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Trigger Angle"

    func perform() async throws -> some IntentResult {
        let current = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: 12)
        let next = max(current - 1, 5)
        GraVolControlRemoteStore.setTriggerAngleDegrees(next)
        if #available(iOS 16.1, *) {
            let state = GraVolLiveActivityAttributes.ContentState(
                tiltDegrees: 0,
                triggerDegrees: next,
                isArmed: true
            )
            await GraVolLiveActivityController.shared.startOrUpdate(state)
        }
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
