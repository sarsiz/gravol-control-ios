import ActivityKit
import Foundation

enum GraVolControlRemoteStore {
    static let appGroupID = "group.com.sarsiz.GraVolControl"
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    private static let triggerAngleKey = "gravol_trigger_angle_degrees"
    private static let defaultTriggerAngleKey = "gravol_default_trigger_angle_degrees"
    private static let downTriggerAngleKey = "gravol_down_trigger_angle_degrees"
    private static let defaultDownTriggerAngleKey = "gravol_default_down_trigger_angle_degrees"
    private static let recenterCommandKey = "gravol_recenter_command_id"
    private static let armedStateKey = "gravol_armed_state"
    private static let setArmedCommandIDKey = "gravol_set_armed_command_id"
    private static let setArmedValueKey = "gravol_set_armed_command_value"
    private static let volumePresetCommandIDKey = "gravol_volume_preset_command_id"
    private static let volumePresetValueKey = "gravol_volume_preset_command_value"
    private static let mutedStateKey = "gravol_muted_state"
    private static let lastAudibleVolumeKey = "gravol_last_audible_volume"
    private static let stepSizeKey = "gravol_step_size"

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

    static func downTriggerAngleDegrees(defaultValue: Double) -> Double {
        guard defaults.object(forKey: downTriggerAngleKey) != nil else { return defaultValue }
        return defaults.double(forKey: downTriggerAngleKey)
    }

    static func setDownTriggerAngleDegrees(_ value: Double) {
        defaults.set(value, forKey: downTriggerAngleKey)
    }

    static func defaultDownTriggerAngleDegrees(defaultValue: Double) -> Double {
        guard defaults.object(forKey: defaultDownTriggerAngleKey) != nil else { return defaultValue }
        return defaults.double(forKey: defaultDownTriggerAngleKey)
    }

    static func setDefaultDownTriggerAngleDegrees(_ value: Double) {
        defaults.set(value, forKey: defaultDownTriggerAngleKey)
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

    static func currentRecenterCommandID() -> Int {
        defaults.integer(forKey: recenterCommandKey)
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

    static func currentSetArmedCommandID() -> Int {
        defaults.integer(forKey: setArmedCommandIDKey)
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

    static func currentVolumePresetCommandID() -> Int {
        defaults.integer(forKey: volumePresetCommandIDKey)
    }

    static func mutedState(defaultValue: Bool) -> Bool {
        if defaults.object(forKey: mutedStateKey) == nil { return defaultValue }
        return defaults.bool(forKey: mutedStateKey)
    }

    static func setMutedState(_ value: Bool) {
        defaults.set(value, forKey: mutedStateKey)
    }

    static func lastAudibleVolume(defaultValue: Float) -> Float {
        if defaults.object(forKey: lastAudibleVolumeKey) == nil { return defaultValue }
        return defaults.float(forKey: lastAudibleVolumeKey)
    }

    static func setLastAudibleVolume(_ value: Float) {
        defaults.set(min(max(value, 0.0), 1.0), forKey: lastAudibleVolumeKey)
    }

    static func stepSize(defaultValue: Double) -> Double {
        guard defaults.object(forKey: stepSizeKey) != nil else { return defaultValue }
        return defaults.double(forKey: stepSizeKey)
    }

    static func setStepSize(_ value: Double) {
        defaults.set(value, forKey: stepSizeKey)
    }

}

@available(iOS 16.1, *)
struct GraVolLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tiltDegrees: Double
        var upTriggerDegrees: Double
        var downTriggerDegrees: Double
        var isArmed: Bool
    }

    var title: String = "GraVol Control"
}
