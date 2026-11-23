import ActivityKit

@MainActor
final class LiveActivityController {
    private var activityID: String?
    private var lastState: PTPActivityAttributes.ContentState?
    private var activityObserver: Task<Void, Never>?

    deinit {
        activityObserver?.cancel()
    }

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let activeActivities = Activity<PTPActivityAttributes>.activities.filter {
            !Self.isTerminal($0.activityState)
        }
        if let activityID {
            // The app may resume before the observer processes a terminal state.
            guard !activeActivities.contains(where: { $0.id == activityID }) else { return }
            clearActivity()
        }

        let initialState = PTPActivityAttributes.ContentState(
            state: "Waiting to range…", distanceMeters: nil)
        let activity = activeActivities.first
            ?? (try? Activity.request(
                attributes: PTPActivityAttributes(),
                content: .init(state: initialState, staleDate: nil),
                pushType: nil))
        guard let activity else { return }
        let id = activity.id
        activityID = id
        lastState = activity.content.state
        activityObserver = Task { @MainActor [weak self] in
            let updates = activity.activityStateUpdates
            if !Self.isTerminal(activity.activityState) {
                for await state in updates where Self.isTerminal(state) {
                    break
                }
            }
            guard !Task.isCancelled, self?.activityID == id else { return }
            self?.clearActivity()
        }
    }

    func update(state: String, distance: Float?) {
        guard let activityID else { return }
        let contentState = PTPActivityAttributes.ContentState(
            state: state, distanceMeters: distance.map { ($0 * 10).rounded() / 10 })
        guard contentState != lastState else { return }

        lastState = contentState
        Task { @MainActor in
            guard self.activityID == activityID,
                let activity = Self.activity(withID: activityID)
            else { return }
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    private func clearActivity() {
        activityObserver?.cancel()
        activityObserver = nil
        activityID = nil
        lastState = nil
    }

    private static func isTerminal(_ state: ActivityState) -> Bool {
        state == .dismissed || state == .ended
    }

    // Look up the handle outside actor isolation so it can be transferred to the async update.
    nonisolated private static func activity(withID id: String) -> sending Activity<PTPActivityAttributes>? {
        Activity<PTPActivityAttributes>.activities.first { $0.id == id }
    }
}
