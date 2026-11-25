import Foundation
import UserNotifications

@MainActor
final class NewAreaPrompt: NSObject, UNUserNotificationCenterDelegate {
    private let session: WatchSession

    init(session: WatchSession) {
        self.session = session
        super.init()

        let action = UNNotificationAction(identifier: "ARM", title: "Arm", options: [.foreground])
        let category = UNNotificationCategory(
            identifier: "NEW_AREA", actions: [action], intentIdentifiers: [], options: [])
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        guard response.actionIdentifier == "ARM" else {
            completionHandler()
            return
        }

        Task { @MainActor in
            // A cold launch from the action can come before the view restores a stored Alarm, Lost or event.
            session.restore()
            session.arm(.normal)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
