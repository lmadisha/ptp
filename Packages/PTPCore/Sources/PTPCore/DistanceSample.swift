public struct DistanceSample: Sendable, Equatable {
    /// A heartbeat has no distance.
    public var meters: Float?
    public var source: ReadingSource
    /// Elapsed time since the session or trace started.
    public var time: Duration

    public init(meters: Float?, source: ReadingSource, time: Duration) {
        self.meters = meters
        self.source = source
        self.time = time
    }
}

public enum ReadingSource: String, Sendable {
    case uwb, ble
}
