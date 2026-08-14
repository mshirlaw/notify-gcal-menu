import AppKit
import Sparkle

/**
 * Thin wrapper around `SPUStandardUpdaterController` so no other file imports Sparkle.
 *
 * Follows Sparkle's "Programmatic Setup" guide
 * (https://sparkle-project.org/documentation/programmatic-setup/), which this app uses
 * instead of the MainMenu.xib-based setup since it's SwiftUI with no xib. Per that guide,
 * constructing `SPUStandardUpdaterController` with `startingUpdater: true` is enough — no
 * further API calls are required for Sparkle to check for updates automatically.
 *
 * Stays dormant until `SUPublicEDKey` in Info.plist is replaced with a real EdDSA public
 * key (see README, "Enabling Auto-Update"). That guard is not cosmetic:
 * `SPUStandardUpdaterController` treats an unparseable key as a fatal startup error and
 * puts a modal alert on screen a second after every launch.
 */
@MainActor
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    /**
     * Mirrors the `YOUR_*` placeholder convention used by Resources/Secrets.plist.example.
     */
    private static let publicKeyPlaceholder = "YOUR_SPARKLE_PUBLIC_KEY"

    /**
     * False until a real public key is configured; the popover hides its update row.
     */
    let isEnabled: Bool

    private var controller: SPUStandardUpdaterController?

    convenience override init() {
        let key = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(publicKey: key)
    }

    /**
     * Takes the public key directly (rather than always reading Bundle.main) so the
     * placeholder-detection logic is unit-testable without needing a real Info.plist key.
     */
    init(publicKey: String) {
        isEnabled = !publicKey.isEmpty && publicKey != Self.publicKeyPlaceholder
        super.init()

        guard isEnabled else {
            Log.updates.notice("Sparkle disabled: SUPublicEDKey is still the placeholder")
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /**
     * Manual check. Shows Sparkle's UI even when the app is already up to date.
     */
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    /**
     * Not part of Sparkle's documented setup — this is a general AppKit fact for this app
     * specifically. An `LSUIElement` app has no Dock icon and can't bring a window forward
     * without activating itself first; without this, Sparkle's update dialog opens behind
     * every other window and a check looks like it silently did nothing. This lives on the
     * delegate rather than only in `checkForUpdates()` so scheduled background checks
     * (which can also surface an update dialog) are covered too.
     */
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
    }
}
