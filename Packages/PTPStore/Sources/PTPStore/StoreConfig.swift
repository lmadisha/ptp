/// Retention periods for the on-device stores (ADR-0005). Nothing in the stores is hard-coded.
public struct StoreConfig: Sendable, Equatable {
    /// Alarm events older than this are deleted.
    public var alarmLogRetention: Duration

    public static let standard = StoreConfig(alarmLogRetention: .seconds(30 * 24 * 60 * 60))
}
