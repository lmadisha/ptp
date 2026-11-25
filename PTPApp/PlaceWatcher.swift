import CoreLocation
import Foundation
import Observation
import PTPStore
import UIKit
import UserNotifications

@MainActor
@Observable
final class PlaceWatcher: NSObject, CLLocationManagerDelegate {
    private(set) var riskyCount = 0
    private(set) var safeCount = 0
    private(set) var isLocating = false

    private let manager = CLLocationManager()
    private let config = StoreConfig.standard
    private let store: ChosenPlaceStore?
    private var pendingKind: ChosenPlaceKind?
    private var isRemoving = false
    private var monitor: CLMonitor?
    private var monitorStartup: Task<Void, Never>?

    override init() {
        let folder = URL.applicationSupportDirectory
        var file = folder.appending(path: "chosen-places.sqlite")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = try? ChosenPlaceStore(path: file.path)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? file.setResourceValues(values)

        super.init()
        manager.delegate = self
        refreshCounts()

        let startup = Task { [weak self] in
            let monitor = await CLMonitor("PTPPlaces")  // Letters only: CLMonitor rejects "ptp-places" at launch.
            guard let self else { return }
            self.monitor = monitor
            guard let places = try? store?.places() else { return }
            let identifiers = Set(await monitor.identifiers)
            let storedIdentifiers = Set(places.map(identifier(for:)))
            for identifier in identifiers.subtracting(storedIdentifiers) {
                await monitor.remove(identifier)
            }
            for place in places where !identifiers.contains(identifier(for: place)) {
                await monitor.add(condition(for: place), identifier: identifier(for: place))
            }
        }
        monitorStartup = startup

        Task { [weak self] in
            await startup.value
            guard let monitor = self?.monitor else { return }
            do {
                for try await event in await monitor.events {
                    guard let self else { return }
                    guard !isRemoving, event.identifier.hasPrefix("risky-"), event.state == .satisfied,
                        let places = try? store?.places(),
                        places.contains(where: { identifier(for: $0) == event.identifier })
                    else { continue }
                    postRiskyPlacePrompt()
                }
            } catch {
                return
            }
        }
    }

    func mark(_ kind: ChosenPlaceKind) {
        guard !isLocating, !isRemoving, manager.authorizationStatus == .authorizedAlways else { return }
        pendingKind = kind
        isLocating = true
        manager.requestLocation()
    }

    func deleteAll() {
        guard !isLocating, !isRemoving, let store, (try? store.deleteAll()) != nil else { return }
        isRemoving = true
        refreshCounts()
        Task { [weak self] in
            guard let self else { return }
            defer { isRemoving = false }
            await monitorStartup?.value
            guard let monitor else { return }
            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
        }
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        (try? store?.place(containingLatitude: latitude, longitude: longitude)) != nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latitude = locations.last?.coordinate.latitude
        let longitude = locations.last?.coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self, let kind = pendingKind else { return }
            pendingKind = nil
            defer { isLocating = false }
            guard let latitude, let longitude else { return }
            await monitorStartup?.value
            guard let place = try? store?.add(kind, latitude: latitude, longitude: longitude) else { return }
            await monitor?.add(condition(for: place), identifier: identifier(for: place), assuming: .satisfied)
            refreshCounts()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in
            guard let self, pendingKind != nil else { return }
            pendingKind = nil
            isLocating = false
        }
    }

    private func refreshCounts() {
        guard let places = try? store?.places() else { return }
        riskyCount = places.count { $0.kind == .risky }
        safeCount = places.count - riskyCount
    }

    private func identifier(for place: ChosenPlace) -> String {
        "\(place.kind.rawValue)-\(place.id)"
    }

    private func condition(for place: ChosenPlace) -> CLMonitor.CircularGeographicCondition {
        CLMonitor.CircularGeographicCondition(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            radius: config.chosenPlaceRadius)
    }

    private func postRiskyPlacePrompt() {
        let content = UNMutableNotificationContent()
        content.title = "Risky place"
        content.body = "Arm PTP on your watch?"
        content.categoryIdentifier = "NEW_AREA"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "risky-place", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
