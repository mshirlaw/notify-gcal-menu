import XCTest
@testable import NotifyGCalMenu

final class KeychainStoreTests: XCTestCase {
    private let account = "KeychainStoreTests.test-account"

    override func tearDown() {
        KeychainStore.delete(account: account)
        super.tearDown()
    }

    func testReadReturnsNilWhenNothingStored() {
        XCTAssertNil(KeychainStore.read(account: account))
    }

    func testSaveThenReadRoundTrips() {
        KeychainStore.save("test-refresh-token", account: account)

        XCTAssertEqual(KeychainStore.read(account: account), "test-refresh-token")
    }

    func testSaveOverwritesExistingValue() {
        KeychainStore.save("first-token", account: account)
        KeychainStore.save("second-token", account: account)

        XCTAssertEqual(KeychainStore.read(account: account), "second-token")
    }

    func testDeleteRemovesStoredValue() {
        KeychainStore.save("test-refresh-token", account: account)

        KeychainStore.delete(account: account)

        XCTAssertNil(KeychainStore.read(account: account))
    }
}
