import AppKit
import Sparkle

/// Thin wrapper around `SPUStandardUpdaterController` so no other file imports Sparkle.
///
/// Stays dormant until `SUPublicEDKey` in Info.plist is replaced with a real EdDSA public
/// key (see README, "Enabling Auto-Update"). That guard is not cosmetic:
/// `SPUStandardUpdaterController` treats an unparseable key as a fatal startup error and
/// puts a modal alert on screen a second after every launch.
@MainActor
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    /// Mirrors the `YOUR_*` placeholder convention used by Resources/Secrets.plist.example.
    private static let publicKeyPlaceholder = "YOUR_SPARKLE_PUBLIC_KEY"

    /// False until a real public key is configured; the popover hides its update row.
    let isEnabled: Bool

    private var controller: SPUStandardUpdaterController?

    override init() {
        let key = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isEnabled = !key.isEmpty && key != Self.publicKeyPlaceholder
        super.init()

        guard isEnabled else {
            Log.updates.notice("Sparkle disabled: SUPublicEDKey is still the placeholder")
            return
        }

        // With SUEnableAutomaticChecks and SUScheduledCheckInterval set in Info.plist,
        // constructing this is enough — Sparkle checks on launch and daily thereafter and
        // presents its own UI.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /// Manual check. Shows Sparkle's UI even when the app is already up to date.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    /// An `LSUIElement` app has no Dock icon and can't bring a window forward without
    /// activating itself first — without this, Sparkle's Software Update dialog opens
    /// behind every other window and the check looks like it did nothing. This lives on
    /// the delegate rather than only in `checkForUpdates()` so scheduled background checks
    /// are covered too.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
    }
}
