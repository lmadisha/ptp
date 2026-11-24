public struct MedianSmoother: Sendable {
    private let window: Duration
    private var newestTime: Duration?
    private var readings: [(time: Duration, meters: Float)] = []

    public init(window: Duration) {
        self.window = window
    }

    /// Adds the sample and returns the median distance in the window ending at
    /// the newest time seen, or nil if the window contains no distances.
    public mutating func add(_ sample: DistanceSample) -> Float? {
        let newest = max(newestTime ?? sample.time, sample.time)
        newestTime = newest
        if let meters = sample.meters, meters.isFinite {
            readings.append((sample.time, meters))
        }

        let cutoff = newest - window
        readings.removeAll { $0.time <= cutoff }
        guard !readings.isEmpty else { return nil }

        // ponytail: Sorting each time is fine for the roughly ten readings at typical UWB rates.
        let sorted = readings.map(\.meters).sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Float((Double(sorted[middle - 1]) + Double(sorted[middle])) / 2)
        }
        return sorted[middle]
    }
}
