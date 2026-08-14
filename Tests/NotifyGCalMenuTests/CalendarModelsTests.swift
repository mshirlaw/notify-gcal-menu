import XCTest
@testable import NotifyGCalMenu

final class CalendarModelsTests: XCTestCase {

    func testTitleFallsBackToPlaceholderWhenSummaryIsNil() throws {
        let event = try decode(#"{ "id": "1", "summary": null }"#)

        XCTAssertEqual(event.title, "(No title)")
    }

    func testTitleFallsBackToPlaceholderWhenSummaryIsEmpty() throws {
        let event = try decode(#"{ "id": "1", "summary": "" }"#)

        XCTAssertEqual(event.title, "(No title)")
    }

    func testTitleUsesSummaryWhenPresent() throws {
        let event = try decode(#"{ "id": "1", "summary": "Team sync" }"#)

        XCTAssertEqual(event.title, "Team sync")
    }

    func testStartDateParsesTimestampWithFractionalSeconds() throws {
        let event = try decode(#"{ "id": "1", "start": { "dateTime": "2026-08-14T16:00:00.123Z" } }"#)

        XCTAssertNotNil(event.startDate)
    }

    func testStartDateParsesTimestampWithoutFractionalSeconds() throws {
        let event = try decode(#"{ "id": "1", "start": { "dateTime": "2026-08-14T16:00:00Z" } }"#)

        XCTAssertNotNil(event.startDate)
    }

    func testStartDateIsNilForAllDayEvent() throws {
        let event = try decode(#"{ "id": "1", "start": { "date": "2026-08-14" } }"#)

        XCTAssertNil(event.startDate)
    }

    func testStartLabelFallsBackToAllDayWhenStartDateIsNil() throws {
        let event = try decode(#"{ "id": "1", "start": { "date": "2026-08-14" } }"#)

        XCTAssertEqual(event.startLabel, "All day")
    }

    func testVideoConferenceLinkPrefersHangoutLink() throws {
        let event = try decode("""
        {
            "id": "1",
            "hangoutLink": "https://meet.google.com/abc-defg-hij",
            "conferenceData": { "entryPoints": [{ "entryPointType": "video", "uri": "https://example.com/other" }] }
        }
        """)

        XCTAssertEqual(event.videoConferenceLink, "https://meet.google.com/abc-defg-hij")
    }

    func testVideoConferenceLinkFallsBackToConferenceDataVideoEntry() throws {
        let event = try decode("""
        {
            "id": "1",
            "conferenceData": { "entryPoints": [
                { "entryPointType": "phone", "uri": "tel:+1-555-0100" },
                { "entryPointType": "video", "uri": "https://example.com/video" }
            ] }
        }
        """)

        XCTAssertEqual(event.videoConferenceLink, "https://example.com/video")
    }

    func testVideoConferenceLinkIsNilWhenNoneAvailable() throws {
        let event = try decode(#"{ "id": "1" }"#)

        XCTAssertNil(event.videoConferenceLink)
    }

    private func decode(_ json: String) throws -> CalendarEvent {
        try JSONDecoder().decode(CalendarEvent.self, from: Data(json.utf8))
    }
}
