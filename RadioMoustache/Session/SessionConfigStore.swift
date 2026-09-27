import Foundation

/// Mémorise la dernière configuration validée (UID des périphériques, canal d'entrée, buffer).
protocol SessionConfigStore {
    func loadLastSelection() -> DeviceSelection?
    func saveLastSelection(_ selection: DeviceSelection)
}

/// Stockage dans UserDefaults, encodé en JSON.
struct UserDefaultsSessionConfigStore: SessionConfigStore {
    static let key = "session.lastSelection"

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
}
