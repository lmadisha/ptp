public struct DetectionConfig: Sendable, Equatable {
    public var heartbeatInterval: Duration
    public var smoothingWindow: Duration

    public var alertDistance: Float
    public var eventAlertDistance: Float
    public var warningDelay: Duration
    public var alarmDelay: Duration
    public var signalLossDelay: Duration

    public static let standard = DetectionConfig(
        heartbeatInterval: .seconds(1),
        smoothingWindow: .seconds(1),
        alertDistance: 8,
        eventAlertDistance: 4,
        warningDelay: .seconds(2),
        alarmDelay: .seconds(5),
        signalLossDelay: .seconds(3)
    )
}
