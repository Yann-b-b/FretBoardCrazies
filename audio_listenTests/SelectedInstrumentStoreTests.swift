import Foundation
import Testing
@testable import audio_listen

struct SelectedInstrumentStoreTests {
    private func makeStore() -> (SelectedInstrumentStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SelectedInstrumentStore(defaults: defaults), defaults, suite)
    }

    @Test func missingKeyDefaultsToGuitar() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.selectedInstrument.id == "guitar")
    }

    @Test func roundTripsSavedInstrumentId() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save("bass")
        #expect(store.selectedInstrument.id == "bass")
    }

    @Test func unknownIdFallsBackToGuitar() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save("theremin")
        #expect(store.selectedInstrument.id == "guitar")
    }
}
