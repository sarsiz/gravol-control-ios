import ActivityKit

@available(iOS 16.1, *)
actor GraVolLiveActivityController {
    static let shared = GraVolLiveActivityController()

    func startOrUpdate(_ state: GraVolLiveActivityAttributes.ContentState) async {
        if let activity = Activity<GraVolLiveActivityAttributes>.activities.first {
            await activity.update(using: state)
            return
        }

        let attributes = GraVolLiveActivityAttributes()
        _ = try? Activity.request(attributes: attributes, contentState: state, pushType: nil)
    }

    func endAll() async {
        for activity in Activity<GraVolLiveActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
