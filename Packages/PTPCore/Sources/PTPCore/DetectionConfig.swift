public struct DetectionConfig: Sendable, Equatable {
    public var heartbeatInterval: Duration
    public var smoothingWindow: Duration
    /// Pause before a ranging session that ended, or a heartbeat connection without the service, is tried again,
    /// so a link that keeps failing can't spin.
    public var linkRestartDelay: Duration
    /// How often the caller ticks the state machine. A deadline is noticed up to one interval late.
    public var tickInterval: Duration

    /// A UWB distance older than this no longer decides; the heartbeat's signal strength does (ADR-0009).
    public var uwbFreshness: Duration
    /// Signal strength is judged by its median over this window. It is noisy, so the window is long.
    public var rssiWindow: Duration
    /// Fewer signal readings than this in the window decide nothing.
    public var rssiMinSamples: Int
    /// Median signal weaker than this (dBm) counts as out of range. Provisional: tune from device logs.
    public var farRSSI: Int
    /// Median signal stronger than this (dBm) counts as in range. Between the two, the last verdict stands.
    public var nearRSSI: Int

    public var alertDistance: Float
    public var eventAlertDistance: Float
    /// The alert distances the owner may choose in Settings, and the step between choices.
    public var alertDistanceRange: ClosedRange<Float>
    public var eventAlertDistanceRange: ClosedRange<Float>
    public var ownerDistanceStep: Float
    /// The lengths the owner can pick for Event mode.
    public var eventDurations: [Duration]
    /// For this long after an event's end the watch first confirms the phone is still there before it disarms.
    /// Later than that it just disarms: the owner has long moved on, and the phone may rightly be elsewhere.
    public var eventEndGrace: Duration
    public var warningDelay: Duration
    public var alarmDelay: Duration
    /// Gap between alarm haptics.
    public var alarmRepeatInterval: Duration
    public var signalLossDelay: Duration
    /// Silence allowed between arming and the first sample, while the link starts up.
    /// Keep it at least as long as `signalLossDelay`.
    public var linkStartupDelay: Duration
    /// A gap between two calls into the session longer than this means the app was not running.
    /// Keep it at least as long as `signalLossDelay`, so a late tick can't pass for a suspension.
    public var suspensionGap: Duration

    public static let standard = DetectionConfig(
        heartbeatInterval: .seconds(1),
        smoothingWindow: .seconds(1),
        linkRestartDelay: .seconds(2),
        tickInterval: .milliseconds(500),
        uwbFreshness: .seconds(2),
        rssiWindow: .seconds(5),
        rssiMinSamples: 3,
        farRSSI: -85,
        nearRSSI: -70,
        alertDistance: 8,
        eventAlertDistance: 4,
        alertDistanceRange: 5...15,
        eventAlertDistanceRange: 2...8,
        ownerDistanceStep: 1,
        eventDurations: [.seconds(2 * 60 * 60), .seconds(4 * 60 * 60)],
        eventEndGrace: .seconds(15 * 60),
        warningDelay: .seconds(2),
        alarmDelay: .seconds(5),
        alarmRepeatInterval: .seconds(1),
        signalLossDelay: .seconds(3),
        linkStartupDelay: .seconds(10),
        suspensionGap: .seconds(3)
    )

    /// This config with the owner's alert distances, clamped to the allowed ranges. Nil keeps the current value.
    /// The values come from the phone, so the watch never trusts them as they are.
    public func withOwnerDistances(alert: Float?, event: Float?) -> DetectionConfig {
        var config = self
        if let alert, alert.isFinite { config.alertDistance = alert.clamped(to: alertDistanceRange) }
        if let event, event.isFinite { config.eventAlertDistance = event.clamped(to: eventAlertDistanceRange) }
        return config
    }
}

extension Float {
    fileprivate func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
