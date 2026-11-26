import Foundation
import Observation
import PTPCore
import PTPStore

/// Writes the alarm log on the iPhone (ADR-0005). The log is only as complete as the state the watch reports (ADR-0008).
@MainActor
@Observable
final class AlarmHistory {
    private(set) var count = 0
    private let log: AlarmLog?
    private var last: PTPState?

    init() {
        // If the log can't be opened the app still runs; it just doesn't log.
        log = openStore("ptp.sqlite") { try AlarmLog(path: $0, now: .now) }

        let events = (try? log?.events()) ?? []
        count = events.count
        // So a relaunch during an Alarm doesn't log it a second time. "ihaveit" rows aren't states.
        last = events.lazy.compactMap { PTPState(rawValue: $0.kind) }.first
    }

    func watchStateChanged(to state: PTPState?) {
        guard let state else { return }
        defer { last = state }
        guard let entry = state.alarmLogEntry(after: last) else { return }
        record(entry, at: .now)
    }

    /// The owner's "I have it" on the watch, timed by the watch: a Warning or an Alarm they say was false.
    func iHaveIt(at time: Date) {
        record("ihaveit", at: time)
    }

    private func record(_ kind: String, at time: Date) {
        guard let log else { return }
        try? log.record(kind, at: time)
        count = (try? log.events().count) ?? count
    }
}

/// Opens an SQLite store in Application Support. The file stays writable while the phone is locked, because
/// alarms and region events arrive then, and is never in a backup (docs/PRIVACY.md).
func openStore<Store>(_ name: String, _ open: (String) throws -> Store) -> Store? {
    let folder = URL.applicationSupportDirectory
    var file = folder.appending(path: name)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let store = try? open(file.path)
    try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? file.setResourceValues(values)
    return store
}
