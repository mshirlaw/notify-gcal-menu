import Foundation

/**
 * Polls the primary calendar for events starting soon and fires a notification for each
 * one not already notified, mirroring background.js's checkUpcomingEvents.
 */
@MainActor
final class EventChecker {
    private let calendarService = CalendarService()
    private let settings = SettingsStore()
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await runCheck()
                try? await Task.sleep(for: .seconds(Constants.checkPeriodSeconds))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /**
     * Forgets previously notified events, runs an immediate check, and returns today's
     * remaining events so the menu can show what was seen.
     */
    func checkNow() async throws -> [EventSummary] {
        settings.saveNotifiedEventIds([:])
        await runCheck()
        let events = try await calendarService.fetchTodaysRemainingEvents()
        return events.map(EventSummary.init)
    }

    private func runCheck() async {
        guard settings.notificationsEnabled else { return }
        do {
            let leadMinutes = settings.leadMinutes
            let events = try await calendarService.fetchUpcomingEvents(leadMinutes: leadMinutes)
            var notifiedEventIds = settings.prunedNotifiedEventIds()

            for event in events {
                guard notifiedEventIds[event.id] == nil, isEventStartingSoon(event, leadMinutes: leadMinutes) else {
                    continue
                }
                await NotificationManager.shared.showNotification(for: event)
                notifiedEventIds[event.id] = Date()
            }

            settings.saveNotifiedEventIds(notifiedEventIds)
        } catch {
            Log.calendar.error("check failed: \(error.localizedDescription)")
        }
    }

    /**
     * Internal rather than private so it's directly testable via @testable import.
     *
     * All-day events (`startDate == nil`) intentionally never fire: they have no specific
     * start time to apply a lead-time countdown to, so "starting soon" doesn't have a
     * meaningful answer for them. This is a deliberate product decision, not a gap.
     */
    func isEventStartingSoon(_ event: CalendarEvent, leadMinutes: Int) -> Bool {
        guard let start = event.startDate else { return false }
        let secondsUntilStart = start.timeIntervalSinceNow
        return secondsUntilStart <= Double(leadMinutes) * 60 && secondsUntilStart > -60
    }
}
