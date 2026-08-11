import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notify GCal")
                .font(.headline)

            Text(appModel.isSignedIn ? "Connected to Google Calendar" : "Not signed in")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if appModel.isSignedIn {
                Button("Sign out") {
                    Task { await appModel.signOut() }
                }
            } else {
                Button("Sign in with Google") {
                    Task { await appModel.signIn() }
                }
            }

            Picker(
                "Notify me",
                selection: Binding(
                    get: { appModel.leadMinutes },
                    set: { appModel.leadMinutesChanged(to: $0) }
                )
            ) {
                Text("Right when it starts").tag(0)
                Text("1 minute before").tag(1)
                Text("2 minutes before").tag(2)
                Text("5 minutes before").tag(5)
                Text("10 minutes before").tag(10)
            }

            Button("Check now") {
                Task { await appModel.checkNow() }
            }
            .disabled(!appModel.isSignedIn)

            if let statusMessage = appModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appModel.todaysEvents.isEmpty {
                Divider()
                ForEach(appModel.todaysEvents) { event in
                    Text("\(event.startLabel) - \(event.title)")
                        .font(.caption)
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
