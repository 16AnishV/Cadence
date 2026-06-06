import AppKit
import UserNotifications

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    private let categoryID = "RECKONING_WARNING"
    private let delayActionID = "DELAY_RECKONING"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("Cadence notification auth error: \(error)")
            }
            NSLog("Cadence notification auth granted: \(granted)")
        }
    }

    func registerCategories() {
        let delayAction = UNNotificationAction(
            identifier: delayActionID,
            title: "Delay reckoning…",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [delayAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Schedule T-20 and T-10 warnings before the reckoning time.
    /// Always cancels existing pending warnings first.
    func scheduleReckoningWarnings(at reckoningTime: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["cadence.warning.t20", "cadence.warning.t10"])
        guard let target = reckoningTime else { return }
        let now = Date()

        let t20 = target.addingTimeInterval(-20 * 60)
        if t20 > now {
            schedule(id: "cadence.warning.t20", at: t20, title: "Reckoning in 20 minutes", body: "Time to wrap up. You can delay if you're deep in something.")
        }
        let t10 = target.addingTimeInterval(-10 * 60)
        if t10 > now {
            schedule(id: "cadence.warning.t10", at: t10, title: "Reckoning in 10 minutes", body: "Final warning before reckoning. Delay if needed.")
        }
    }

    private func schedule(id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryID

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                NSLog("Cadence schedule notif error: \(error)")
            }
        }
    }

    // Show notifications even when app is foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == delayActionID {
            // Open the popover so user can pick a new time
            DispatchQueue.main.async {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.coordinator.refreshState()
                    delegate.showPopoverProgrammatically()
                }
                NotificationCenter.default.post(name: .cadenceOpenDelayPicker, object: nil)
            }
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let cadenceOpenDelayPicker = Notification.Name("cadenceOpenDelayPicker")
}
