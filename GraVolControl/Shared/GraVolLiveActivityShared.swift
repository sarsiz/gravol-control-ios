import ActivityKit
import Foundation

enum GraVolControlRemoteStore {
    static let appGroupID = "group.com.sarsiz.GraVolControl"
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    private static let triggerAngleKey = "gravol_trigger_angle_degrees"
    private static let recenterCommandKey = "gravol_recenter_command_id"

    static func triggerAngleDegrees(defaultValue: Double) -> Double {
        let raw = defaults.double(forKey: triggerAngleKey)
        return raw == 0 ? defaultValue : raw
    }

    static func setTriggerAngleDegrees(_ value: Double) {
        defaults.set(value, forKey: triggerAngleKey)
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
