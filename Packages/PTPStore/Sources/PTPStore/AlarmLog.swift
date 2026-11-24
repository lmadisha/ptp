import Foundation

/// One line of alarm history: a time and one word. No distance, no location (docs/PRIVACY.md).
public struct AlarmEvent: Sendable, Equatable {
    public let time: Date
    public let kind: String
}

/// The alarm event log (ADR-0005). The caller passes the time, so tests need no clock.
public final class AlarmLog {
    private let database: Database
    private let retention: TimeInterval

    /// `path` is the database file, or `:memory:` for tests. Old events are deleted on opening.
    public init(path: String, config: StoreConfig = .standard, now: Date) throws {
        database = try Database(path: path)
        let components = config.alarmLogRetention.components
        retention = TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18

        switch try database.run("PRAGMA user_version") {
        case [[.real(0)]]:
            // IF NOT EXISTS: a crash before the version is written must not break every later open.
            try database.run(
                """
                CREATE TABLE IF NOT EXISTS alarm_event
                (id INTEGER PRIMARY KEY, created_at REAL NOT NULL, kind TEXT NOT NULL)
                """)
            try database.run("PRAGMA user_version = 1")
        case [[.real(1)]]:
            break
        default:
            throw StoreError(message: "the database was written by a newer version of PTP")
        }
        try deleteExpired(now: now)
    }

    public func record(_ kind: String, at time: Date) throws {
        try database.run(
            "INSERT INTO alarm_event (created_at, kind) VALUES (?, ?)",
            [.real(time.timeIntervalSince1970), .text(kind)])
        try deleteExpired(now: time)
    }

    /// Newest first.
    public func events() throws -> [AlarmEvent] {
        try database.run("SELECT created_at, kind FROM alarm_event ORDER BY created_at DESC, id DESC").compactMap {
            guard case .real(let seconds) = $0[0], case .text(let kind) = $0[1] else { return nil }
            return AlarmEvent(time: Date(timeIntervalSince1970: seconds), kind: kind)
        }
    }

    private func deleteExpired(now: Date) throws {
        // Also drop events dated far in the future (a wrong device clock), or they would never expire.
        let seconds = now.timeIntervalSince1970
        try database.run(
            "DELETE FROM alarm_event WHERE created_at < ? OR created_at > ?",
            [.real(seconds - retention), .real(seconds + retention)])
    }
}
