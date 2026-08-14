import Foundation
import UserNotifications

/**
 * Shows native macOS notifications for upcoming events, with a "Join Meeting" action
 * when the event has a video call link, plus a chime, matching the extension's behavior.
 */
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    func configure() {
        let joinAction = UNNotificationAction(
            identifier: Constants.joinMeetingActionId,
            title: "Join Meeting",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Constants.eventNotificationCategoryId,
            actions: [joinAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        center.delegate = self
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Log.notifications.notice("Notification authorization granted: \(granted, privacy: .public)")
        } catch {
            Log.notifications.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func showNotification(for event: CalendarEvent) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            Log.notifications.error("Not showing notification for \(event.id, privacy: .public): authorization status is \(String(describing: settings.authorizationStatus), privacy: .public)")
            ToneEngine.shared.playChime()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = event.title

        var messageParts = ["Starts at \(event.startLabel)"]
        if let location = event.location, !location.isEmpty {
            messageParts.append(location)
        }
        content.body = messageParts.joined(separator: " · ")
        content.subtitle = "Google Calendar"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = event.videoConferenceLink != nil ? Constants.eventNotificationCategoryId : ""

        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
        do {
            try await center.add(request)
            Log.notifications.notice("Notification request added for \(event.id, privacy: .public)")
        } catch {
            Log.notifications.error("Failed to add notification for \(event.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        ToneEngine.shared.playChime()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
            completionHandler()
            return
        }
        let eventId = response.notification.request.identifier
        Task {
            await EventLinkOpener.openLink(forEventId: eventId)
            completionHandler()
        }
    }
}
