import ActivityKit

struct PTPActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var state: String
        var distanceMeters: Float?
        /// The watch's `PTPState` raw value, as last reported to the phone. It may be stale (ADR-0008).
        var watchState: String?

        var isAlarm: Bool { watchState == "alarm" }
    }
}
