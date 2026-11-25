import CoreLocation
import Foundation
import Observation
import PTPStore

@MainActor
@Observable
final class VisitLearner: NSObject, CLLocationManagerDelegate {
    private(set) var areas = 0
    private(set) var isLearning = false

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
        // iOS grants While Using first; asking again once that is granted offers the upgrade to Always.
        if manager.authorizationStatus != .authorizedAlways {
            manager.requestAlwaysAuthorization()
        }
        updateMonitoring()
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
            try? store.recordVisit(area: area, at: arrival)
            areas = (try? store.areaCount()) ?? areas
        }
    }

    private func updateMonitoring() {
        let authorized = manager.authorizationStatus == .authorizedAlways
        guard authorized != isLearning else { return }
        if authorized {
            manager.startMonitoringVisits()
        } else {
            manager.stopMonitoringVisits()
        }
        isLearning = authorized
    }
}
