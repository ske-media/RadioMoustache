import Foundation

/// Mémorise la dernière configuration validée (UID des périphériques, canal d'entrée, buffer)
/// et la page du journal de bord (date et noms des appareils de la dernière émission).
protocol SessionConfigStore {
    func loadLastSelection() -> DeviceSelection?
    func saveLastSelection(_ selection: DeviceSelection)
    func loadLogbookEntry() -> LogbookEntry?
    func saveLogbookEntry(_ entry: LogbookEntry)
}

/// Stockage dans UserDefaults, encodé en JSON.
struct UserDefaultsSessionConfigStore: SessionConfigStore {
    static let key = "session.lastSelection"
    static let logbookKey = "session.logbook"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLastSelection() -> DeviceSelection? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        // Une donnée illisible (ancien format…) est ignorée : on repart des périphériques par défaut.
        return try? JSONDecoder().decode(DeviceSelection.self, from: data)
    }

    func saveLastSelection(_ selection: DeviceSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func loadLogbookEntry() -> LogbookEntry? {
        guard let data = defaults.data(forKey: Self.logbookKey) else { return nil }
        return try? JSONDecoder().decode(LogbookEntry.self, from: data)
    }

    func saveLogbookEntry(_ entry: LogbookEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: Self.logbookKey)
    }
}
