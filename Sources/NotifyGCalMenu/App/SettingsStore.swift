import Foundation

/**
 * Persists the notification lead time and the set of already-notified event IDs,
 * mirroring the extension's chrome.storage.sync/local usage.
 */
struct SettingsStore {
    private let defaults: UserDefaults
    private let leadMinutesKey = "leadMinutes"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notifiedEventIdsKey = "notifiedEventIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var leadMinutes: Int {
        get {
            let value = defaults.integer(forKey: leadMinutesKey)
            return defaults.object(forKey: leadMinutesKey) != nil ? value : Constants.defaultLeadMinutes
        }
        nonmutating set { defaults.set(newValue, forKey: leadMinutesKey) }
    }

    var notificationsEnabled: Bool {
        get {
            defaults.object(forKey: notificationsEnabledKey) != nil
                ? defaults.bool(forKey: notificationsEnabledKey)
                : true
        }
        nonmutating set { defaults.set(newValue, forKey: notificationsEnabledKey) }
    }

    /**
     * Map of event ID to the timestamp it was notified.
     */
    func notifiedEventIds() -> [String: Date] {
        guard let stored = defaults.dictionary(forKey: notifiedEventIdsKey) as? [String: Double] else { return [:] }
        return stored.mapValues { Date(timeIntervalSince1970: $0) }
    }

    func saveNotifiedEventIds(_ ids: [String: Date]) {
        let stored = ids.mapValues { $0.timeIntervalSince1970 }
        defaults.set(stored, forKey: notifiedEventIdsKey)
    }

    /**
     * Removes entries older than the TTL and returns the pruned map.
     */
    func prunedNotifiedEventIds() -> [String: Date] {
        let cutoff = Date().addingTimeInterval(-Constants.notifiedEventTTL)
        return notifiedEventIds().filter { $0.value > cutoff }
    }
}
