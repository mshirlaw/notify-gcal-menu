import XCTest
@testable import NotifyGCalMenu

@MainActor
final class UpdaterManagerTests: XCTestCase {

    func testIsDisabledWhenKeyIsThePlaceholder() {
        let updater = UpdaterManager(publicKey: "YOUR_SPARKLE_PUBLIC_KEY")

        XCTAssertFalse(updater.isEnabled)
    }

    func testIsDisabledWhenKeyIsEmpty() {
        let updater = UpdaterManager(publicKey: "")

        XCTAssertFalse(updater.isEnabled)
    }

    // A "real key" case isn't tested here: once isEnabled is true, init constructs a real
    // SPUStandardUpdaterController, which expects a proper host app bundle (SUFeedURL, etc.)
    // rather than the XCTest runner's bundle. Exercising that path in a unit test risks
    // background XPC/timer state outliving the test and destabilizing CI, for no real
    // assurance gained — this is verified manually instead (see README, "Enabling
    // Auto-Update").
}
