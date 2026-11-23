import Foundation
import Observation
import PTPCore

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

@MainActor
@Observable
final class ReadingLog {
    static let shared = ReadingLog()

    private(set) var rows = 0
    private(set) var fileURL: URL?

    @ObservationIgnored private var handle: FileHandle?

    private init() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #elseif os(watchOS)
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        #endif
    }

    func log(distance: Float?, source: ReadingSource) {
        let timestamp = Date.now.timeIntervalSince1970
        let row = ReadingRow(
            tMs: Int64(timestamp * 1_000), distanceMeters: distance, source: source,
            appState: appState, batteryPercent: batteryPercent)
        do {
            if handle == nil { try openLog(unixSeconds: Int64(timestamp)) }
            guard let handle else { return }
            try handle.write(contentsOf: Data((row.csvLine + "\n").utf8))
            rows += 1
        } catch {
            // A failed write does not count as a recorded reading.
        }
    }

    private func openLog(unixSeconds: Int64) throws {
        #if os(iOS)
        let device = "phone"
        #elseif os(watchOS)
        let device = "watch"
        #endif
        let documents = URL.documentsDirectory
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        var url = documents.appending(path: "ptp-\(device)-\(unixSeconds).diagnostics.csv")
        try Data((ReadingRow.csvHeader + "\n").utf8).write(
            to: url, options: [.withoutOverwriting, .completeFileProtectionUntilFirstUserAuthentication])
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            self.handle = handle
            fileURL = url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private var appState: String {
        #if os(iOS)
        let state = UIApplication.shared.applicationState
        #elseif os(watchOS)
        let state = WKApplication.shared().applicationState
        #endif
        switch state {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private var batteryPercent: Int? {
        #if os(iOS)
        let level = UIDevice.current.batteryLevel
        #elseif os(watchOS)
        let level = WKInterfaceDevice.current().batteryLevel
        #endif
        guard (0...1).contains(level) else { return nil }
        return Int((level * 100).rounded())
    }
}
