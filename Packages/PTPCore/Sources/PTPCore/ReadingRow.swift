import Foundation

public struct ReadingRow: Sendable, Equatable {
    public static let csvHeader = "t_ms,distance_m,source,app_state,battery_pct,rssi_dbm"

    public let tMs: Int64
    public let distanceMeters: Float?
    public let source: ReadingSource
    public let appState: String
    public let batteryPercent: Int?
    public let rssi: Int?

    public init(
        tMs: Int64, distanceMeters: Float?, source: ReadingSource,
        appState: String, batteryPercent: Int?, rssi: Int? = nil
    ) {
        self.tMs = tMs
        self.distanceMeters = distanceMeters
        self.source = source
        self.appState = appState
        self.batteryPercent = batteryPercent
        self.rssi = rssi
    }

    public var csvLine: String {
        let distance = distanceMeters.map {
            String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double($0))
        } ?? ""
        let battery = batteryPercent.map { String($0) } ?? ""
        let signal = rssi.map { String($0) } ?? ""
        return "\(tMs),\(distance),\(source.rawValue),\(appState),\(battery),\(signal)"
    }
}
