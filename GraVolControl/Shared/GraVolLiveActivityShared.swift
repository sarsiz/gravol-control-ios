import ActivityKit
import Foundation

enum GraVolControlRemoteStore {
    static let appGroupID = "group.com.sarsiz.GraVolControl"
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    private static let triggerAngleKey = "gravol_trigger_angle_degrees"
    private static let defaultTriggerAngleKey = "gravol_default_trigger_angle_degrees"
    private static let recenterCommandKey = "gravol_recenter_command_id"
    private static let armedStateKey = "gravol_armed_state"
    private static let setArmedCommandIDKey = "gravol_set_armed_command_id"
    private static let setArmedValueKey = "gravol_set_armed_command_value"
    private static let volumePresetCommandIDKey = "gravol_volume_preset_command_id"
    private static let volumePresetValueKey = "gravol_volume_preset_command_value"

    static func triggerAngleDegrees(defaultValue: Double) -> Double {
        guard defaults.object(forKey: triggerAngleKey) != nil else { return defaultValue }
        return defaults.double(forKey: triggerAngleKey)
    }

    static func setTriggerAngleDegrees(_ value: Double) {
        defaults.set(value, forKey: triggerAngleKey)
    }

    static func defaultTriggerAngleDegrees(defaultValue: Double) -> Double {
        guard defaults.object(forKey: defaultTriggerAngleKey) != nil else { return defaultValue }
        return defaults.double(forKey: defaultTriggerAngleKey)
    }

    static func setDefaultTriggerAngleDegrees(_ value: Double) {
        defaults.set(value, forKey: defaultTriggerAngleKey)
    }

    static func armedState(defaultValue: Bool) -> Bool {
        if defaults.object(forKey: armedStateKey) == nil { return defaultValue }
        return defaults.bool(forKey: armedStateKey)
    }

    static func setArmedState(_ value: Bool) {
        defaults.set(value, forKey: armedStateKey)
    }

    static func issueRecenterCommand() {
        let next = defaults.integer(forKey: recenterCommandKey) + 1
        defaults.set(next, forKey: recenterCommandKey)
    }

    static func consumeRecenterCommand(lastSeenID: inout Int) -> Bool {
        let current = defaults.integer(forKey: recenterCommandKey)
        guard current > lastSeenID else { return false }
        lastSeenID = current
        return true
    }

    static func issueSetArmedCommand(_ value: Bool) {
        defaults.set(value, forKey: setArmedValueKey)
        let next = defaults.integer(forKey: setArmedCommandIDKey) + 1
        defaults.set(next, forKey: setArmedCommandIDKey)
        setArmedState(value)
    }

    static func consumeSetArmedCommand(lastSeenID: inout Int) -> Bool? {
        let current = defaults.integer(forKey: setArmedCommandIDKey)
        guard current > lastSeenID else { return nil }
        lastSeenID = current
        return defaults.bool(forKey: setArmedValueKey)
    }

    static func issueVolumePresetCommand(_ value: Float) {
        defaults.set(value, forKey: volumePresetValueKey)
        let next = defaults.integer(forKey: volumePresetCommandIDKey) + 1
        defaults.set(next, forKey: volumePresetCommandIDKey)
    }

    static func consumeVolumePresetCommand(lastSeenID: inout Int) -> Float? {
        let current = defaults.integer(forKey: volumePresetCommandIDKey)
        guard current > lastSeenID else { return nil }
        lastSeenID = current
        return defaults.float(forKey: volumePresetValueKey)
    }
}

@available(iOS 16.1, *)
struct GraVolLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tiltDegrees: Double
        var triggerDegrees: Double
        var isArmed: Bool
    }

    var title: String = "GraVol Control"
}
