import Foundation
import Testing
@testable import audio_listen

struct DailyGoalTests {
    private func makeStore() -> (DailyGoalStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DailyGoalStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)), defaults, suite)
    }

    @Test func startsAtZero() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.todayCount(now: Date(timeIntervalSince1970: 1_700_000_000)) == 0)
    }

    @Test func incrementsWithinSameDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(store.recordCorrect(now: t) == 1)
        #expect(store.recordCorrect(now: t.addingTimeInterval(60)) == 2)
        #expect(store.todayCount(now: t.addingTimeInterval(120)) == 2)
    }

    @Test func resetsOnNewDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        _ = store.recordCorrect(now: day1)
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        #expect(store.todayCount(now: day2) == 0)
        #expect(store.recordCorrect(now: day2) == 1)
    }
}
