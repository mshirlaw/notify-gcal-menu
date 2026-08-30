import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var updater: UpdaterManager

    private let horizontalPadding: CGFloat = 16

    private static let leadMinuteOptions: [(minutes: Int, label: String)] = [
        (0, "Right when it starts"),
        (1, "1 minute before"),
        (2, "2 minutes before"),
        (5, "5 minutes before"),
        (10, "10 minutes before"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            accountRow

            Divider().padding(.vertical, 4)

            notificationsSection

            Divider().padding(.vertical, 4)

            if updater.isEnabled {
                actionRow(title: "Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                    updater.checkForUpdates()
                }
            }

            if let statusMessage = appModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 8)
            }

            if !appModel.todaysEvents.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appModel.todaysEvents) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 6, height: 6)
                            Text("\(event.startLabel) - \(event.title)")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
            }

            Divider().padding(.vertical, 4)

            actionRow(title: "Quit", systemImage: "power", shortcut: "⌘Q", emphasized: false) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 14)
        .frame(width: 260)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notify GCal")
                .font(.system(size: 18, weight: .bold))
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
        .padding(.vertical, 10)
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Label("Notify me", systemImage: "bell")
                    .labelStyle(BadgeLabelStyle(tint: Theme.primary, background: Theme.primaryTint, badgeSize: 22))
                Spacer()
                Toggle(
                    "Notify me",
                    isOn: Binding(
                        get: { appModel.notificationsEnabled },
                        set: { appModel.setNotificationsEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.primary)
            }

            leadMinutesMenu
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 10)
    }

    private var leadMinutesLabel: String {
        Self.leadMinuteOptions.first { $0.minutes == appModel.leadMinutes }?.label
            ?? "\(appModel.leadMinutes) minutes before"
    }

    /**
     * A custom `Menu` rather than `Picker(.menu)`: the native menu-style picker sizes
     * itself to fit its content and ignores `.frame(maxWidth: .infinity)`, so it can't
     * be made to span the row the way the design calls for.
     */
    private var leadMinutesMenu: some View {
        Menu {
            ForEach(Self.leadMinuteOptions, id: \.minutes) { option in
                Button(option.label) { appModel.setLeadMinutes(option.minutes) }
            }
        } label: {
            HStack {
                Text(leadMinutesLabel)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(!appModel.notificationsEnabled)
        .accessibilityLabel("Notify me lead time")
        .accessibilityValue(leadMinutesLabel)
    }

    /**
     * `emphasized` lowers the row's text/icon weight for lower-priority or terminal
     * actions (e.g. Quit), so it doesn't compete visually with everyday actions like
     * Check for Updates — differentiating by consequence rather than by identical styling.
     */
    private func actionRow(
        title: String,
        systemImage: String,
        shortcut: String? = nil,
        emphasized: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HoverHighlight {
                HStack {
                    if emphasized {
                        Label(title, systemImage: systemImage)
                            .labelStyle(BadgeLabelStyle(tint: .primary, background: Color.primary.opacity(0.08), badgeSize: 22))
                    } else {
                        Label(title, systemImage: systemImage)
                    }
                    Spacer()
                    if let shortcut {
                        Text(shortcut)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.primary.opacity(0.15))
                            )
                            // Decorative: the real shortcut is wired via .keyboardShortcut
                            // below. Reading the glyph aloud adds noise, not information.
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(emphasized ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

/**
 * Renders a Label's icon inside a filled circular badge, for rows that need visual
 * weight (everyday actions) without breaking the icon+title accessibility grouping
 * that `Label` already provides.
 */
private struct BadgeLabelStyle: LabelStyle {
    let tint: Color
    let background: Color
    let badgeSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .foregroundStyle(tint)
                .frame(width: badgeSize, height: badgeSize)
                .background(Circle().fill(background))
            configuration.title
        }
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
