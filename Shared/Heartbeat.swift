import CoreBluetooth
import Foundation

@MainActor
enum Heartbeat {
    static let service = CBUUID(string: "9F918EF8-AF85-43BD-B3CD-FA85A74C384D")
    static let characteristic = CBUUID(string: "B926291F-325C-48A1-9258-0C4EC1E72C25")

    nonisolated static let idLength = MemoryLayout<uuid_t>.size

    nonisolated static func encodeID(_ id: UUID) -> Data {
        withUnsafeBytes(of: id.uuid) { Data($0) }
    }

    nonisolated static func decodeID(_ data: Data) -> UUID? {
        guard data.count == idLength else { return nil }
        return data.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
    }
}
