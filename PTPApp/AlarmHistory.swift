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
        let folder = URL.applicationSupportDirectory
        var file = folder.appending(path: "ptp.sqlite")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // If the log can't be opened the app still runs; it just doesn't log.
        log = try? AlarmLog(path: file.path, now: .now)
        // Writable while locked, because alarms arrive then. Never in a backup.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? file.setResourceValues(values)

        let events = (try? log?.events()) ?? []
        count = events.count
        // So a relaunch during an Alarm doesn't log it a second time.
        last = events.first.flatMap { PTPState(rawValue: $0.kind) }
    }

    func watchStateChanged(to state: PTPState?) {
        guard let state else { return }
        defer { last = state }
        guard let entry = state.alarmLogEntry(after: last), let log else { return }
        try? log.record(entry, at: .now)
        count = (try? log.events().count) ?? count
    }
}
