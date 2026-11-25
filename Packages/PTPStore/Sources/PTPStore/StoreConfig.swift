/// Retention periods and place grid size for the on-device stores (ADR-0005).
public struct StoreConfig: Sendable, Equatable {
    /// Alarm events older than this are deleted.
    public var alarmLogRetention: Duration
    /// Visits with a stored day older than this are deleted.
    public var placeRetention: Duration = .seconds(60 * 24 * 60 * 60)
    /// Width and height of an area cell in degrees.
    public var placeGridDegrees: Double = 0.0025

    public static let standard = StoreConfig(alarmLogRetention: .seconds(30 * 24 * 60 * 60))
}
