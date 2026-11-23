import ActivityKit

@MainActor
final class LiveActivityController {
    private var activityID: String?
    private var lastState: PTPActivityAttributes.ContentState?

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activityID == nil else { return }

        let initialState = PTPActivityAttributes.ContentState(
            state: "Waiting to range…", distanceMeters: nil)
        let activity = Activity<PTPActivityAttributes>.activities.first
            ?? (try? Activity.request(
                attributes: PTPActivityAttributes(),
                content: .init(state: initialState, staleDate: nil),
                pushType: nil))
        guard let activity else { return }
        activityID = activity.id
        lastState = activity.content.state
    }

    func update(state: String, distance: Float?) {
        guard let activityID else { return }
        let contentState = PTPActivityAttributes.ContentState(
            state: state, distanceMeters: distance.map { ($0 * 10).rounded() / 10 })
        guard contentState != lastState else { return }

        lastState = contentState
        Task { @MainActor in
            guard let activity = Self.activity(withID: activityID) else { return }
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    // Look up the handle outside actor isolation so it can be transferred to the async update.
    nonisolated private static func activity(withID id: String) -> sending Activity<PTPActivityAttributes>? {
        Activity<PTPActivityAttributes>.activities.first { $0.id == id }
    }
}
