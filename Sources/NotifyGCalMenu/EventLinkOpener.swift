import Foundation
import AppKit

/// Opens an event's video call link, falling back to its Calendar page, the same
/// resolution order the extension used for notification clicks.
enum EventLinkOpener {
    static func openLink(forEventId eventId: String) async {
        guard let event = try? await CalendarService().fetchEvent(id: eventId) else { return }
        guard let link = event.videoConferenceLink ?? event.htmlLink, let url = URL(string: link) else { return }
        await MainActor.run {
            _ = NSWorkspace.shared.open(url)
        }
    }
}
