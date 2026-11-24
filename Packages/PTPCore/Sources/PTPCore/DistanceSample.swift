public struct DistanceSample: Sendable, Equatable {
    /// A heartbeat has no distance.
    public var meters: Float?
    public var source: ReadingSource
    /// Signal strength of the heartbeat connection in dBm (more negative is weaker), when it was read.
    public var rssi: Int?
    /// Elapsed time since the session or trace started.
    public var time: Duration

    public init(meters: Float?, source: ReadingSource, time: Duration, rssi: Int? = nil) {
        self.meters = meters
        self.source = source
        self.rssi = rssi
        self.time = time
    }
}

public enum ReadingSource: String, Sendable {
    case uwb, ble
}
