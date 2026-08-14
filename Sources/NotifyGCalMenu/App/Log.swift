import os

/**
 * Unified-logging categories for this app. View with Console.app (filter by process
 * "NotifyGCalMenu") or `log stream --predicate 'subsystem == "com.notifygcalmenu.app"'`.
 */
enum Log {
    static let auth = Logger(subsystem: "com.notifygcalmenu.app", category: "auth")
    static let calendar = Logger(subsystem: "com.notifygcalmenu.app", category: "calendar")
    static let notifications = Logger(subsystem: "com.notifygcalmenu.app", category: "notifications")
    static let updates = Logger(subsystem: "com.notifygcalmenu.app", category: "updates")
}
