import Foundation

enum CalendarServiceError: Error, LocalizedError {
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .apiError(let status): return "Calendar API error: \(status)"
        }
    }
}

/// Fetches events from the signed-in user's primary Google Calendar.
struct CalendarService {
    private let auth: GoogleAuthManager

    init(auth: GoogleAuthManager = .shared) {
        self.auth = auth
    }

    /// Fetches events starting within the configured lead-time window.
    func fetchUpcomingEvents(leadMinutes: Int) async throws -> [CalendarEvent] {
        try await fetchEvents(timeMin: Date(), timeMax: Date().addingTimeInterval(TimeInterval(leadMinutes + 1) * 60))
    }

    /// Fetches the remaining events on today's calendar, regardless of lead time.
    func fetchTodaysRemainingEvents() async throws -> [CalendarEvent] {
        var endOfToday = Calendar.current.startOfDay(for: Date())
        endOfToday = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: endOfToday) ?? Date()
        return try await fetchEvents(timeMin: Date(), timeMax: endOfToday)
    }

    func fetchEvent(id: String) async throws -> CalendarEvent? {
        let request = try await authorizedRequest(url: URL(string: "\(Constants.eventsEndpoint)/\(id)")!)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }

    private func fetchEvents(timeMin: Date, timeMax: Date) async throws -> [CalendarEvent] {
        var components = URLComponents(string: Constants.eventsEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: timeMin)),
            URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: timeMax)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
        ]

        var request = try await authorizedRequest(url: components.url!)
        var (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            await auth.invalidateAccessToken()
            request = try await authorizedRequest(url: components.url!)
            (data, response) = try await URLSession.shared.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CalendarServiceError.apiError(status)
        }

        struct EventsListResponse: Decodable { let items: [CalendarEvent]? }
        return try JSONDecoder().decode(EventsListResponse.self, from: data).items ?? []
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        let token = try await auth.validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
