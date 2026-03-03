import ActivityKit

@available(iOS 16.1, *)
actor GraVolLiveActivityController {
    static let shared = GraVolLiveActivityController()

    func startOrUpdate(_ state: GraVolLiveActivityAttributes.ContentState) async {
        if let activity = Activity<GraVolLiveActivityAttributes>.activities.first {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
            return
        }

        let attributes = GraVolLiveActivityAttributes()
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        } else {
            _ = try? Activity.request(attributes: attributes, contentState: state, pushType: nil)
        }
    }

    func endAll() async {
        for activity in Activity<GraVolLiveActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
