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

            actionRow(title: "Sync Now", systemImage: "arrow.clockwise", shortcut: "⌘S") {
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

            actionRow(title: "Quit", systemImage: "power", shortcut: "⌘Q", emphasized: false) {
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
                Button {
                    Task { await appModel.signOut() }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            } else {
                Button {
                    Task { await appModel.signIn() }
                } label: {
                    Label("Sign in with Google", systemImage: "person.crop.circle.badge.checkmark")
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
                .accessibilityAddTraits(.isHeader)

            Label("Notify me", systemImage: "bell")

            Picker(
                "",
                selection: Binding(
                    get: { appModel.leadMinutes },
                    set: { appModel.setLeadMinutes($0) }
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
            // Its visual label above is a separate Text, not a SwiftUI Label, so
            // .labelsHidden() leaves VoiceOver with no context for the picker on its own.
            .accessibilityLabel("Notify me")
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
    }

    /**
     * `emphasized` lowers the row's text/icon weight for lower-priority or terminal
     * actions (e.g. Quit), so it doesn't compete visually with everyday actions like
     * Sync Now — differentiating by consequence rather than by identical styling.
     */
    private func actionRow(
        title: String,
        systemImage: String,
        shortcut: String,
        emphasized: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HoverHighlight {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        // Decorative: the real shortcut is wired via .keyboardShortcut
                        // below. Reading the glyph aloud adds noise, not information.
                        .accessibilityHidden(true)
                }
                .foregroundStyle(emphasized ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

/**
 * Adds a subtle hover background to menu-style rows, since `.buttonStyle(.plain)`
 * otherwise gives no feedback that a row is interactive.
 */
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
