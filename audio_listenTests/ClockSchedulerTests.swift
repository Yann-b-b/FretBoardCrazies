import Combine
import Foundation
import Testing
@testable import audio_listen

final class FakeClock: Clock {
    private(set) var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class FakeScheduler: DrillScheduler {
    private var repeatingEntries: [(id: UUID, tick: () -> Void)] = []
    private var pendingEntries: [(id: UUID, run: () -> Void)] = []
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable {
        let id = UUID()
        repeatingEntries.append((id, tick))
        return AnyCancellable { [weak self] in self?.repeatingEntries.removeAll { $0.id == id } }
    }
    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable {
        let id = UUID()
        pendingEntries.append((id, run))
        return AnyCancellable { [weak self] in self?.pendingEntries.removeAll { $0.id == id } }
    }
    func fireRepeatingTick() {
        let ticks = repeatingEntries.map(\.tick)
        ticks.forEach { $0() }
    }
    func firePendingAfter() {
        let runs = pendingEntries.map(\.run)
        pendingEntries.removeAll()
        runs.forEach { $0() }
    }
}

struct ClockSchedulerTests {
    @Test func fakeClockAdvances() {
        let c = FakeClock()
        let t0 = c.now()
        c.advance(by: 2.5)
        #expect(c.now().timeIntervalSince(t0) == 2.5)
    }

    @Test func fakeSchedulerFiresAfter() {
        let s = FakeScheduler()
        var fired = false
        let token = s.scheduleAfter(1.0) { fired = true }
        #expect(!fired)
        s.firePendingAfter()
        #expect(fired)
        withExtendedLifetime(token) {}
    }

    @Test func cancellingAfterPreventsFire() {
        let s = FakeScheduler()
        var fired = false
        let token = s.scheduleAfter(1.0) { fired = true }
        token.cancel()
        s.firePendingAfter()
        #expect(!fired)
    }
}
