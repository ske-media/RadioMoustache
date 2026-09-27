import Foundation
import Testing
@testable import RadioMoustache

struct SessionConfigStoreTests {
    /// Chaque test utilise son propre domaine UserDefaults, supprimé à la fin.
    private func makeStore() throws -> (store: UserDefaultsSessionConfigStore, defaults: UserDefaults, suite: String) {
        let suite = "RadioMoustacheTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (UserDefaultsSessionConfigStore(defaults: defaults), defaults, suite)
    }

    @Test func returnsNothingBeforeTheFirstSession() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(store.loadLastSelection() == nil)
    }

    @Test func remembersTheConfirmedSelection() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        var selection = DeviceSelection()
        selection.inputUID = "AppleUSBAudioEngine:Shure:MV7:1"
        selection.inputChannels = .stereo(first: 2)
        selection.mainOutputUID = "00-11-22-33-44-55:output"
        selection.monitorOutputUID = "BuiltInHeadphoneOutputDevice"
        selection.bufferFrameSize = 128
        store.saveLastSelection(selection)

        #expect(store.loadLastSelection() == selection)
    }

    @Test func ignoresUnreadableData() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(Data("pas du JSON".utf8), forKey: UserDefaultsSessionConfigStore.key)

        #expect(store.loadLastSelection() == nil)
    }
}
