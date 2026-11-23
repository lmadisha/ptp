import ActivityKit

struct PTPActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var state: String
        var distanceMeters: Float?
    }
}
