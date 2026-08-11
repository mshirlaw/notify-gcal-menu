import SwiftUI

@main
struct NotifyGCalMenuApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Notify GCal", systemImage: appModel.isSignedIn ? "bell.fill" : "bell") {
            MenuBarContentView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
