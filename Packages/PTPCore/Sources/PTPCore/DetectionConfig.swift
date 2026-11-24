public struct DetectionConfig: Sendable, Equatable {
    public var heartbeatInterval: Duration
    public var smoothingWindow: Duration

    public static let standard = DetectionConfig(
        heartbeatInterval: .seconds(1),
        smoothingWindow: .seconds(1)
    )
}
