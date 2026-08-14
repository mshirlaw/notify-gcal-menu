import SwiftUI

@main
struct NotifyGCalMenuApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var updater = UpdaterManager()

    var body: some Scene {
        MenuBarExtra("Notify GCal", systemImage: appModel.isSignedIn ? "bell.fill" : "bell") {
            MenuBarContentView(appModel: appModel, updater: updater)
        }
        .menuBarExtraStyle(.window)
    }
}
