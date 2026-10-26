import Foundation
import UserNotifications

/// One notification for everything that changed in a refresh, asking for permission the first time. None while
/// Notifications is off in Settings.
func notify(_ changes: [Change]) {
    guard UserDefaults.standard.bool(forKey: "notifications") else { return }
    Task {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tallynn"
        content.body = notificationBody(changes)
        content.sound = .default
        // A new id each time, so earlier changes stay in Notification Center.
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Clicking "… is available" checks again, which offers Update now.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler done: @escaping () -> Void) {
        if response.notification.request.identifier == "update" { Task { @MainActor in self.checkNow() } }
        done()
    }

    /// Shown even while the menu is open, which makes the app frontmost.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound, .list])
    }
}
