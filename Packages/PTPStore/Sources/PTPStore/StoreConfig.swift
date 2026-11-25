/// Retention and place learning settings for the on-device stores (ADR-0005).
public struct StoreConfig: Sendable, Equatable {
    /// Alarm events older than this are deleted.
    public var alarmLogRetention: Duration
    /// Visits with a stored day older than this are deleted.
    public var placeRetention: Duration = .seconds(60 * 24 * 60 * 60)
    /// Width and height of an area cell in degrees.
    public var placeGridDegrees: Double = 0.0025
    /// Minimum distinct visit days within retention for an area to be familiar.
    public var newAreaMinVisits: Int = 3
    /// Decimal places retained for chosen-place coordinates.
    public var chosenPlaceDecimals: Int = 3
    /// Radius of a chosen place in metres.
    public var chosenPlaceRadius: Double = 150
    /// Maximum number of chosen places stored and monitored.
    public var maxChosenPlaces: Int = 20

    public static let standard = StoreConfig(alarmLogRetention: .seconds(30 * 24 * 60 * 60))
}
