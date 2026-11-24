import Foundation
import SQLite3

public struct StoreError: Error, Equatable {
    public let message: String
}

/// A thin wrapper over the system SQLite library (ADR-0005). Use it from one thread at a time.
final class Database {
    enum Value: Equatable {
        case real(Double)
        case text(String)
    }

    private let handle: OpaquePointer

    /// `path` is a file path, or `:memory:` for tests.
    init(path: String) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open(path, &handle)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            sqlite3_close(handle)
            throw StoreError(message: message)
        }
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Runs one statement and returns its rows. Values are always bound, never spliced into the SQL.
    /// A column that isn't text is read as a number, so NULL comes back as 0: keep columns `NOT NULL`.
    @discardableResult
    func run(_ sql: String, _ values: [Value] = []) throws -> [[Value]] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        try sql.withCString { text in
            var rest: UnsafePointer<CChar>?
            guard sqlite3_prepare_v2(handle, text, -1, &statement, &rest) == SQLITE_OK else { throw lastError() }
            // SQLite would silently skip a second statement.
            guard rest.map({ String(cString: $0).allSatisfy(\.isWhitespace) }) ?? true else {
                throw StoreError(message: "one statement per call")
            }
        }

        // SQLite must copy the text, because the Swift string doesn't outlive the call.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result =
                switch value {
                case .real(let number): sqlite3_bind_double(statement, position, number)
                case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
                }
            guard result == SQLITE_OK else { throw lastError() }
        }

        var rows: [[Value]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                rows.append(
                    (0..<sqlite3_column_count(statement)).map { column in
                        sqlite3_column_type(statement, column) == SQLITE_TEXT
                            ? .text(String(cString: sqlite3_column_text(statement, column)))
                            : .real(sqlite3_column_double(statement, column))
                    })
            case SQLITE_DONE:
                return rows
            default:
                throw lastError()
            }
        }
    }

    private func lastError() -> StoreError {
        StoreError(message: String(cString: sqlite3_errmsg(handle)))
    }
}
