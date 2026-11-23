public struct DetectionConfig: Sendable, Equatable {
    public var heartbeatInterval: Duration

    public static let standard = DetectionConfig(heartbeatInterval: .seconds(1))
}
