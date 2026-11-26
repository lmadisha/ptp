import CoreTransferable
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
    nonisolated static let fileName = "ptp.sqlite"

    init() {
        // If the log can't be opened the app still runs; it just doesn't log.
        log = openStore(Self.fileName) { try AlarmLog(path: $0, now: .now) }

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

/// The alarm log as `ptp-alarm-log.csv`: times and words only (docs/PRIVACY.md). It leaves the phone only if the
/// owner shares it, and is read then, not on every screen update.
struct AlarmLogExport: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { _ in
            let file = URL.applicationSupportDirectory.appending(path: AlarmHistory.fileName)
            let log = try AlarmLog(path: file.path, now: .now)
            return Data(AlarmLog.csv(try log.events()).utf8)
        }
        .suggestedFileName("ptp-alarm-log.csv")
    }
}
