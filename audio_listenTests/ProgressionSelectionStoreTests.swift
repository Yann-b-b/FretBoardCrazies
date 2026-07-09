// audio_listenTests/ProgressionSelectionStoreTests.swift
import Foundation
import Testing
@testable import audio_listen

struct ProgressionSelectionStoreTests {
    private func makeStore() -> (ProgressionSelectionStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (ProgressionSelectionStore(defaults: defaults), defaults, suite)
    }

    @Test func defaultsWhenEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.progression.id == "major-ii-v-i")
        #expect(store.tonic == .c)
        #expect(store.rootString == .e6)
        #expect(store.displayMode == .nameAndFingering)
    }

    @Test func roundTripsSelection() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(progressionId: "turnaround", tonic: .g, rootString: .a5, displayMode: .nameOnly)
        #expect(store.progression.id == "turnaround")
        #expect(store.tonic == .g)
        #expect(store.rootString == .a5)
        #expect(store.displayMode == .nameOnly)
    }

    @Test func unknownProgressionFallsBackToDefault() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(progressionId: "nope", tonic: .c, rootString: .e6, displayMode: .nameAndFingering)
        #expect(store.progression.id == "major-ii-v-i")
    }

    @Test func corruptRootStringFallsBackToE6() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("bogus", forKey: "audio_listen_chord_root_string")
        #expect(store.rootString == .e6)
    }
}
