import Combine
import Foundation
import Testing
@testable import audio_listen

final class FakeClock: Clock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class FakeScheduler: DrillScheduler {
    private(set) var repeatingTicks: [() -> Void] = []
    private(set) var pendingAfter: [() -> Void] = []
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable {
        repeatingTicks.append(tick)
        return AnyCancellable { [weak self] in self?.repeatingTicks.removeAll() }
    }
    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable {
        pendingAfter.append(run)
        return AnyCancellable { [weak self] in self?.pendingAfter.removeAll() }
    }
    func fireRepeatingTick() {
        let ticks = repeatingTicks
        ticks.forEach { $0() }
    }
    func firePendingAfter() {
        let runs = pendingAfter
        pendingAfter.removeAll()
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
