import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel

    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            accountRow

            Divider()

            notificationsSection

            Divider()

            actionRow(title: "Sync Now", shortcut: "⌘S") {
                Task { await appModel.checkNow() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!appModel.isSignedIn)

            if let statusMessage = appModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 8)
            }

            if !appModel.todaysEvents.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(appModel.todaysEvents) { event in
                        Text("\(event.startLabel) - \(event.title)")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
            }

            Divider()

            actionRow(title: "Quit", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 12)
        .frame(width: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notify GCal")
                .font(.headline)
                .fontWeight(.semibold)
            Text(appModel.isSignedIn ? "Connected to Google Calendar" : "Not signed in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 12)
    }

    private var accountRow: some View {
        HStack {
            Text("Account")
                .foregroundStyle(.secondary)
            Spacer()
            if appModel.isSignedIn {
                Button("Sign out") {
                    Task { await appModel.signOut() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            } else {
                Button("Sign in with Google") {
                    Task { await appModel.signIn() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTIFICATIONS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Label("Notify me", systemImage: "bell")

            Picker(
                "",
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
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
    }

    private func actionRow(title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HoverHighlight {
                HStack {
                    Text(title)
                    Spacer()
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

/// Adds a subtle hover background to menu-style rows, since `.buttonStyle(.plain)`
/// otherwise gives no feedback that a row is interactive.
private struct HoverHighlight<Content: View>: View {
    @State private var isHovering = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            .onHover { isHovering = $0 }
    }
}
