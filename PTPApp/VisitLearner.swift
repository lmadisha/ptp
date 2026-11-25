import CoreLocation
import Foundation
import Observation
import PTPStore
import UIKit

@MainActor
@Observable
final class VisitLearner: NSObject, CLLocationManagerDelegate {
    private(set) var areas = 0
    private(set) var isLearning = false
    /// iOS asks only once; after a refusal or "Keep Only While Using" the owner must use Settings.
    private(set) var needsSettings = false

    private let manager = CLLocationManager()
    private let store: PlaceStore?

    override init() {
        let folder = URL.applicationSupportDirectory
        var file = folder.appending(path: "places.sqlite")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = try? PlaceStore(path: file.path, now: .now)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? file.setResourceValues(values)

        super.init()
        areas = (try? store?.areaCount()) ?? 0
        manager.delegate = self
        updateMonitoring()
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }

    func deleteAll() {
        guard let store, (try? store.deleteAll()) != nil else { return }
        areas = 0
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.updateMonitoring()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let arrival = visit.arrivalDate
        // iOS may report a visit at arrival, again at departure, or only once it is over.
        // The store keeps one row per area and day, so a repeat counts once.
        guard arrival != .distantPast else { return }
        let area = PlaceStore.area(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)

        Task { @MainActor [weak self] in
            guard let self, isLearning, let store else { return }
            try? store.recordVisit(area: area, arrival: arrival, now: .now)
            areas = (try? store.areaCount()) ?? areas
        }
    }

    private func updateMonitoring() {
        let authorized = manager.authorizationStatus == .authorizedAlways
        needsSettings = !authorized && manager.authorizationStatus != .notDetermined
        guard authorized != isLearning else { return }
        if authorized {
            manager.startMonitoringVisits()
        } else {
            manager.stopMonitoringVisits()
        }
        isLearning = authorized
    }
}
