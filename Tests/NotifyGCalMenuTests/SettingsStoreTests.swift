import XCTest
@testable import NotifyGCalMenu

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLeadMinutesDefaultsToConstantsDefaultWhenUnset() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.leadMinutes, Constants.defaultLeadMinutes)
    }

    func testLeadMinutesRoundTripsThroughStorage() {
        let store = SettingsStore(defaults: defaults)

        store.leadMinutes = 5

        XCTAssertEqual(store.leadMinutes, 5)
    }

    func testNotificationsEnabledDefaultsToTrueWhenUnset() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.notificationsEnabled)
    }

    func testNotificationsEnabledRoundTripsThroughStorage() {
        let store = SettingsStore(defaults: defaults)

        store.notificationsEnabled = false

        XCTAssertFalse(store.notificationsEnabled)
    }

    func testNotifiedEventIdsIsEmptyWhenUnset() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.notifiedEventIds().isEmpty)
    }

    func testNotifiedEventIdsRoundTripsThroughStorage() {
        let store = SettingsStore(defaults: defaults)
        let ids = ["event-1": Date(timeIntervalSince1970: 1_000)]

        store.saveNotifiedEventIds(ids)

        XCTAssertEqual(store.notifiedEventIds(), ids)
    }

    func testPrunedNotifiedEventIdsRemovesEntriesOlderThanTTL() {
        let store = SettingsStore(defaults: defaults)
        let old = Date().addingTimeInterval(-Constants.notifiedEventTTL - 60)
        let recent = Date()
        store.saveNotifiedEventIds(["old": old, "recent": recent])

        let pruned = store.prunedNotifiedEventIds()

        XCTAssertEqual(Array(pruned.keys), ["recent"])
    }
}
