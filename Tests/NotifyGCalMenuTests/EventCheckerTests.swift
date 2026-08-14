import XCTest
@testable import NotifyGCalMenu

@MainActor
final class EventCheckerTests: XCTestCase {

    func testEventStartingWithinLeadWindowIsStartingSoon() throws {
        let checker = EventChecker()
        let event = try makeEvent(startingIn: 3 * 60)

        XCTAssertTrue(checker.isEventStartingSoon(event, leadMinutes: 5))
    }

    func testEventStartingAfterLeadWindowIsNotStartingSoon() throws {
        let checker = EventChecker()
        let event = try makeEvent(startingIn: 10 * 60)

        XCTAssertFalse(checker.isEventStartingSoon(event, leadMinutes: 5))
    }

    func testEventThatStartedJustNowIsStartingSoon() throws {
        let checker = EventChecker()
        let event = try makeEvent(startingIn: -30)

        XCTAssertTrue(checker.isEventStartingSoon(event, leadMinutes: 5))
    }

    func testEventThatStartedOverAMinuteAgoIsNotStartingSoon() throws {
        let checker = EventChecker()
        let event = try makeEvent(startingIn: -90)

        XCTAssertFalse(checker.isEventStartingSoon(event, leadMinutes: 5))
    }

    func testAllDayEventIsNeverStartingSoon() throws {
        let checker = EventChecker()
        let event = try JSONDecoder().decode(
            CalendarEvent.self,
            from: Data(#"{ "id": "1", "start": { "date": "2026-08-14" } }"#.utf8)
        )

        XCTAssertFalse(checker.isEventStartingSoon(event, leadMinutes: 5))
    }

    private func makeEvent(startingIn seconds: TimeInterval) throws -> CalendarEvent {
        let dateTime = ISO8601DateFormatter.calendarFormatter.string(from: Date().addingTimeInterval(seconds))
        let json = #"{ "id": "1", "start": { "dateTime": "\#(dateTime)" } }"#
        return try JSONDecoder().decode(CalendarEvent.self, from: Data(json.utf8))
    }
}
