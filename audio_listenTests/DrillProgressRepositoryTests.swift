import Foundation
import Testing
@testable import audio_listen

struct DrillProgressRepositoryTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func missingKeyLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll().isEmpty)
    }

    @Test func roundTripsStats() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        let key = DrillItemKey(noteName: .g, string: 3)
        let stats = ItemStats(box: 1, attempts: 2, correct: 1, lastReactionTime: 1.1, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        repo.save([key: stats])
        let loaded = repo.loadAll()
        #expect(loaded[key] == stats)
        #expect(loaded.count == 1)
    }

    @Test func corruptDataLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: UserDefaultsDrillProgressRepository.userDefaultsKey)
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll().isEmpty)
    }

    @Test func perInstrumentKeysAreIndependent() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        let key = DrillItemKey(noteName: .g, string: 3)
        let stats = ItemStats(box: 2, attempts: 3, correct: 2, lastReactionTime: 1.0, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        repo.save([key: stats], for: Instruments.guitar)
        #expect(repo.loadAll(for: Instruments.guitar) == [key: stats])
        #expect(repo.loadAll(for: Instruments.bass).isEmpty)
    }

    @Test func missingPerInstrumentKeyLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll(for: Instruments.guitar).isEmpty)
    }

    @Test func corruptPerInstrumentDataLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: UserDefaultsDrillProgressRepository.userDefaultsKey(for: Instruments.guitar))
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll(for: Instruments.guitar).isEmpty)
    }
}
