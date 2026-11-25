import Foundation

public enum ChosenPlaceKind: String, Sendable {
    case risky
    case safe
}

public struct ChosenPlace: Sendable, Equatable {
    public let id: Int64
    public let kind: ChosenPlaceKind
    public let latitude: Double
    public let longitude: Double
}

public final class ChosenPlaceStore {
    private let database: Database
    private let config: StoreConfig

    /// `path` is the chosen-place database file, or `:memory:` for tests.
    public init(path: String, config: StoreConfig = .standard) throws {
        database = try Database(path: path)
        self.config = config

        switch try database.run("PRAGMA user_version") {
        case [[.real(0)]]:
            try database.run(
                """
                CREATE TABLE IF NOT EXISTS chosen_place
                (id INTEGER PRIMARY KEY, kind TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL)
                """)
            try database.run("PRAGMA user_version = 1")
        case [[.real(1)]]:
            break
        default:
            throw StoreError(message: "the database was written by a newer version of PTP")
        }
    }

    @discardableResult
    public func add(_ kind: ChosenPlaceKind, latitude: Double, longitude: Double) throws -> ChosenPlace {
        let scale = pow(10, Double(config.chosenPlaceDecimals))
        let latitude = (latitude * scale).rounded() / scale
        let longitude = (longitude * scale).rounded() / scale
        // One transaction: a failed insert must not leave the replaced marking deleted.
        try database.run("BEGIN IMMEDIATE")
        do {
            // The newest marking wins: a spot marked safe stops being risky, and the other way round.
            // Twice the radius, so no two circles overlap and no spot is both risky and safe.
            for place in try places() where distance(place, latitude, longitude) <= 2 * config.chosenPlaceRadius {
                try database.run("DELETE FROM chosen_place WHERE id = ?", [.real(Double(place.id))])
            }
            try database.run(
                """
                INSERT INTO chosen_place (kind, latitude, longitude)
                SELECT ?, ?, ? WHERE (SELECT COUNT(*) FROM chosen_place) < ?
                """,
                [.text(kind.rawValue), .real(latitude), .real(longitude), .real(Double(config.maxChosenPlaces))])
            guard try database.run("SELECT changes()") == [[.real(1)]] else {
                throw StoreError(message: "too many chosen places")
            }
            try database.run("COMMIT")
        } catch {
            try? database.run("ROLLBACK")
            throw error
        }
        guard case .real(let id)? = try database.run("SELECT last_insert_rowid()").first?.first else {
            throw StoreError(message: "missing chosen-place ID")
        }
        return ChosenPlace(id: Int64(id), kind: kind, latitude: latitude, longitude: longitude)
    }

    public func places() throws -> [ChosenPlace] {
        try database.run("SELECT id, kind, latitude, longitude FROM chosen_place ORDER BY id").map { row in
            guard case .real(let id) = row[0], case .text(let rawKind) = row[1],
                let kind = ChosenPlaceKind(rawValue: rawKind),
                case .real(let latitude) = row[2], case .real(let longitude) = row[3]
            else {
                throw StoreError(message: "invalid chosen place")
            }
            return ChosenPlace(id: Int64(id), kind: kind, latitude: latitude, longitude: longitude)
        }
    }

    public func deleteAll() throws {
        try database.run("DELETE FROM chosen_place")
    }

    public func place(containingLatitude latitude: Double, longitude: Double) throws -> ChosenPlace? {
        try places().first { distance($0, latitude, longitude) <= config.chosenPlaceRadius }
    }

    /// Metres from a stored place to a point.
    // ponytail: flat-earth distance over at most 20 rows; fine for a 150 m radius, wrong across the poles.
    private func distance(_ place: ChosenPlace, _ latitude: Double, _ longitude: Double) -> Double {
        let radiansPerDegree = Double.pi / 180
        let latitudeDelta = (latitude - place.latitude) * radiansPerDegree
        let longitudeDelta = (longitude - place.longitude).remainder(dividingBy: 360) * radiansPerDegree
        let meanLatitude = (latitude + place.latitude) * radiansPerDegree / 2
        return 6_371_000 * hypot(latitudeDelta, longitudeDelta * cos(meanLatitude))
    }
}
