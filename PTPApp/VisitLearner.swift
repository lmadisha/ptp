import CoreLocation
import Foundation
import Observation
import PTPStore
import UIKit
import UserNotifications

@MainActor
@Observable
final class VisitLearner: NSObject, CLLocationManagerDelegate {
    private(set) var areas = 0
    private(set) var isLearning = false
    /// iOS asks only once; after a refusal or "Keep Only While Using" the owner must use Settings.
    private(set) var needsSettings = false
    var isInChosenPlace: ((Double, Double) -> Bool)?

    private let manager = CLLocationManager()
    private let store: PlaceStore?

    override init() {
        store = openStore("places.sqlite") { try PlaceStore(path: $0, now: .now) }

        super.init()
        // iOS shows the iPhone's actions on a notification it forwards to the watch, so "Arm" is registered here too.
        // Chosen on the watch it runs in the watch app (NewAreaPrompt); chosen on the phone it only opens PTP,
        // because the phone never arms the watch (ADR-0008).
        let arm = UNNotificationAction(identifier: "ARM", title: "Arm", options: [.foreground])
        let category = UNNotificationCategory(identifier: "NEW_AREA", actions: [arm], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        areas = (try? store?.areaCount()) ?? 0
        manager.delegate = self
        updateMonitoring()

        #if DEBUG
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        // A standalone flag has no value in the defaults argument domain.
        if arguments["demoNewArea"] != nil || ProcessInfo.processInfo.arguments.contains("-demoNewArea") {
            postNewAreaPrompt(trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        }
        #endif
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
        let isArrival = visit.departureDate == .distantFuture
        let latitude = visit.coordinate.latitude
        let longitude = visit.coordinate.longitude
        let area = PlaceStore.area(latitude: latitude, longitude: longitude)

        Task { @MainActor [weak self] in
            guard let self, isLearning, let store else { return }
            let now = Date.now
            let isNew = isArrival && ((try? store.isNewArea(area, now: now)) ?? false)
            try? store.recordVisit(area: area, arrival: arrival, now: now)
            if isNew, isInChosenPlace?(latitude, longitude) != true, SettingsView.isOn(SettingsView.promptNewAreasKey) {
                postNewAreaPrompt()
            }
            areas = (try? store.areaCount()) ?? areas
        }
    }

    private func postNewAreaPrompt(trigger: UNNotificationTrigger? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "New area"
        content.body = "Arm PTP on your watch?"
        content.categoryIdentifier = "NEW_AREA"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "new-area", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func updateMonitoring() {
        let authorized = manager.authorizationStatus == .authorizedAlways
        needsSettings = !authorized && manager.authorizationStatus != .notDetermined
        guard authorized != isLearning else { return }
        if authorized {
            manager.startMonitoringVisits()
            // Asked once learning runs, also for owners who allowed location before the prompt existed.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        } else {
            manager.stopMonitoringVisits()
        }
        isLearning = authorized
    }
}
