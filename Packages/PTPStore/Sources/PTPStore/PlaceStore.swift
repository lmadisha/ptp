import Foundation

/// Stores only the rounded area and UTC day of each visit, at most one per area and day (ADR-0010).
public final class PlaceStore {
    private let database: Database
    private let retention: TimeInterval

    public static func area(latitude: Double, longitude: Double, config: StoreConfig = .standard) -> String {
        let latitudeIndex = Int(floor(latitude / config.placeGridDegrees))
        let longitudeIndex = Int(floor(longitude / config.placeGridDegrees))
        return "\(latitudeIndex):\(longitudeIndex)"
    }

    /// `path` is the place database file, or `:memory:` for tests.
    public init(path: String, config: StoreConfig = .standard, now: Date) throws {
        database = try Database(path: path)
        let components = config.placeRetention.components
        retention = TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18

        switch try database.run("PRAGMA user_version") {
        case [[.real(0)]]:
            // Opening again is safe if the first open stopped before writing the version.
            try database.run(
                """
                CREATE TABLE IF NOT EXISTS place_visit
                (id INTEGER PRIMARY KEY, area TEXT NOT NULL, visited_day REAL NOT NULL, UNIQUE (area, visited_day))
                """)
            try database.run("PRAGMA user_version = 1")
        case [[.real(1)]]:
            break
        default:
            throw StoreError(message: "the database was written by a newer version of PTP")
        }
        try deleteExpired(now: now)
    }

    /// `arrival` sets the stored day; `now` decides what has expired. iOS can report a visit days after its
    /// arrival, so an arrival already past the retention is deleted straight away.
    public func recordVisit(area: String, arrival: Date, now: Date) throws {
        let secondsPerDay: TimeInterval = 86_400
        let visitedDay = floor(arrival.timeIntervalSince1970 / secondsPerDay) * secondsPerDay
        try database.run(
            "INSERT OR IGNORE INTO place_visit (area, visited_day) VALUES (?, ?)",
            [.text(area), .real(visitedDay)])
        try deleteExpired(now: now)
    }

    public func visitCount(area: String, now: Date) throws -> Int {
        let seconds = now.timeIntervalSince1970
        let rows = try database.run(
            "SELECT COUNT(*) FROM place_visit WHERE area = ? AND visited_day BETWEEN ? AND ?",
            [.text(area), .real(seconds - retention), .real(seconds + retention)])
        guard case .real(let count)? = rows.first?.first else { return 0 }
        return Int(count)
    }

    public func areaCount() throws -> Int {
        let rows = try database.run("SELECT COUNT(DISTINCT area) FROM place_visit")
        guard case .real(let count)? = rows.first?.first else { return 0 }
        return Int(count)
    }

    public func deleteAll() throws {
        try database.run("DELETE FROM place_visit")
    }

    private func deleteExpired(now: Date) throws {
        let seconds = now.timeIntervalSince1970
        try database.run(
            "DELETE FROM place_visit WHERE visited_day < ? OR visited_day > ?",
            [.real(seconds - retention), .real(seconds + retention)])
    }
}
