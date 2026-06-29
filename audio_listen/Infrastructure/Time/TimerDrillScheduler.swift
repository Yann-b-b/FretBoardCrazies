import Combine
import Foundation

struct TimerDrillScheduler: DrillScheduler {
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in tick() }
        RunLoop.main.add(timer, forMode: .common)
        return AnyCancellable { timer.invalidate() }
    }

    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable {
        let work = DispatchWorkItem(block: run)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return AnyCancellable { work.cancel() }
    }
}
