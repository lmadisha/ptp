import CoreBluetooth

@MainActor
enum Heartbeat {
    static let service = CBUUID(string: "9F918EF8-AF85-43BD-B3CD-FA85A74C384D")
    static let characteristic = CBUUID(string: "B926291F-325C-48A1-9258-0C4EC1E72C25")
}
