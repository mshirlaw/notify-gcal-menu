import Foundation

enum Constants {
    static let defaultLeadMinutes = 1
    static let checkPeriodSeconds: TimeInterval = 30
    static let notifiedEventTTL: TimeInterval = 24 * 60 * 60
    static let calendarReadonlyScope = "https://www.googleapis.com/auth/calendar.readonly"
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let revokeEndpoint = "https://oauth2.googleapis.com/revoke"
    static let eventsEndpoint = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    static let joinMeetingActionId = "JOIN_MEETING"
    static let eventNotificationCategoryId = "EVENT_NOTIFICATION"
}
