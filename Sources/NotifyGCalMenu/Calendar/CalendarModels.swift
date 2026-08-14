import Foundation

/**
 * A Calendar API event resource, trimmed to the fields this app uses.
 */
struct CalendarEvent: Codable, Identifiable {
    struct EventDateTime: Codable {
        let dateTime: String?
        let date: String?
    }

    struct ConferenceEntryPoint: Codable {
        let entryPointType: String
        let uri: String
    }

    struct ConferenceData: Codable {
        let entryPoints: [ConferenceEntryPoint]?
    }

    let id: String
    let summary: String?
    let location: String?
    let start: EventDateTime?
    let htmlLink: String?
    let hangoutLink: String?
    let conferenceData: ConferenceData?

    private enum CodingKeys: String, CodingKey {
        case id, summary, location, start, htmlLink, hangoutLink, conferenceData
    }

    var title: String {
        summary?.isEmpty == false ? summary! : "(No title)"
    }

    var startDate: Date? {
        guard let dateTime = start?.dateTime else { return nil }
        return ISO8601DateFormatter.calendarFormatterWithFractionalSeconds.date(from: dateTime)
            ?? ISO8601DateFormatter.calendarFormatter.date(from: dateTime)
    }

    /**
     * The video call link, covering Google Meet and other conferencing providers.
     */
    var videoConferenceLink: String? {
        if let hangoutLink { return hangoutLink }
        return conferenceData?.entryPoints?.first { $0.entryPointType == "video" }?.uri
    }

    var startLabel: String {
        guard let startDate else { return "All day" }
        return DateFormatter.eventStartTime.string(from: startDate)
    }
}

extension ISO8601DateFormatter {
    static let calendarFormatter = ISO8601DateFormatter()

    static let calendarFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension DateFormatter {
    static let eventStartTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

/**
 * A display-ready summary of an event, without exposing the full API resource.
 */
struct EventSummary: Identifiable {
    let id: String
    let title: String
    let startLabel: String

    init(event: CalendarEvent) {
        id = event.id
        title = event.title
        startLabel = event.startLabel
    }
}
