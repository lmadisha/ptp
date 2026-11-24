public struct DetectionConfig: Sendable, Equatable {
    public var heartbeatInterval: Duration
    public var smoothingWindow: Duration
    /// Pause before a ranging session that ended, or a heartbeat connection without the service, is tried again,
    /// so a link that keeps failing can't spin.
    public var linkRestartDelay: Duration
    /// How often the caller ticks the state machine. A deadline is noticed up to one interval late.
    public var tickInterval: Duration

    public var alertDistance: Float
    public var eventAlertDistance: Float
    public var warningDelay: Duration
    public var alarmDelay: Duration
    /// Gap between alarm haptics.
    public var alarmRepeatInterval: Duration
    public var signalLossDelay: Duration
    /// Silence allowed between arming and the first sample, while the link starts up.
    /// Keep it at least as long as `signalLossDelay`.
    public var linkStartupDelay: Duration

    public static let standard = DetectionConfig(
        heartbeatInterval: .seconds(1),
        smoothingWindow: .seconds(1),
        linkRestartDelay: .seconds(2),
        tickInterval: .milliseconds(500),
        alertDistance: 8,
        eventAlertDistance: 4,
        warningDelay: .seconds(2),
        alarmDelay: .seconds(5),
        alarmRepeatInterval: .seconds(1),
        signalLossDelay: .seconds(3),
        linkStartupDelay: .seconds(10)
    )
}
