import Foundation

/**
 * Central state for the menu bar UI: sign-in status, the lead-time setting, today's 
 * remaining events, and a status message, mirroring popup.js's responsibilities.
 */
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published var leadMinutes: Int
    @Published private(set) var todaysEvents: [EventSummary] = []
    @Published private(set) var statusMessage: String?

    private let auth = GoogleAuthManager.shared
    private let eventChecker = EventChecker()
    private let settings = SettingsStore()
    private var activityToken: NSObjectProtocol?

    init() {
        leadMinutes = settings.leadMinutes
        // Fired from init rather than a SwiftUI `.task` on the dropdown's content view: with
        // MenuBarExtra(.window), that content is only built the first time the user opens the
        // menu, which would leave notifications unconfigured and polling never started until
        // then. Constructing AppModel happens at actual process launch, since MenuBarExtra's
        // label reads `appModel.isSignedIn` immediately to render the status item icon.
        Task { await self.launch() }
    }

    func launch() async {
        // Without a visible window, macOS treats this as a background app and can throttle
        // its timers via App Nap, delaying the poll loop by seconds to minutes.
        activityToken = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Polling Google Calendar for upcoming events")

        NotificationManager.shared.configure()
        await NotificationManager.shared.requestAuthorization()
        await refreshSignedInState()
        if isSignedIn {
            eventChecker.startPolling()
        }
    }

    func signIn() async {
        statusMessage = "Opening Google sign-in..."
        do {
            try await auth.signIn()
            statusMessage = nil
            await refreshSignedInState()
            eventChecker.startPolling()
        } catch {
            statusMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        await auth.signOut()
        eventChecker.stopPolling()
        todaysEvents = []
        statusMessage = "Signed out"
        await refreshSignedInState()
    }

    func checkNow() async {
        statusMessage = "Checking calendar..."
        do {
            let events = try await eventChecker.checkNow()
            todaysEvents = events
            statusMessage = events.isEmpty ? "Checked, no more events today" : "Checked, \(events.count) event(s) left today"
        } catch {
            statusMessage = "Check failed: \(error.localizedDescription)"
            todaysEvents = []
        }
    }

    func setLeadMinutes(_ newValue: Int) {
        leadMinutes = newValue
        settings.leadMinutes = newValue
    }

    private func refreshSignedInState() async {
        isSignedIn = await auth.isSignedIn
    }
}
