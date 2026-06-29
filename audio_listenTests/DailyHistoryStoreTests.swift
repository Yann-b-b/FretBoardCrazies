import Foundation
import Testing
@testable import audio_listen

struct DailyHistoryStoreTests {
    private func makeStore() -> (DailyHistoryStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)), defaults, suite)
    }
    let day1 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func missingIsEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.history().isEmpty)
        #expect(store.todayReps(now: day1) == 0)
    }

    @Test func firstRecordThenIncrementSameDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.recordCorrect(now: day1, reactionTime: 2.0, masteredCount: 1) == 1)
        #expect(store.recordCorrect(now: day1.addingTimeInterval(60), reactionTime: 4.0, masteredCount: 2) == 2)
        let today = store.history().first { Calendar(identifier: .gregorian).isDate($0.dayStart, inSameDayAs: day1) }!
        #expect(today.reps == 2)
        #expect(today.averageReaction == 3.0)
        #expect(today.masteredSnapshot == 2)
    }

    @Test func newDayStartsFreshRecord() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = store.recordCorrect(now: day1, reactionTime: 2.0, masteredCount: 1)
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        #expect(store.todayReps(now: day2) == 0)
        #expect(store.recordCorrect(now: day2, reactionTime: 1.0, masteredCount: 3) == 1)
        #expect(store.history().count == 2)
    }

    @Test func historySortedAscending() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        _ = store.recordCorrect(now: day2, reactionTime: 1.0, masteredCount: 1)
        _ = store.recordCorrect(now: day1, reactionTime: 1.0, masteredCount: 1)
        let h = store.history()
        #expect(h.count == 2)
        #expect(h[0].dayStart < h[1].dayStart)
    }

    @Test func corruptDataIsEmpty() {
        let (_, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("nope".utf8), forKey: DailyHistoryStore.userDefaultsKey)
        let store = DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
        #expect(store.history().isEmpty)
    }
}
