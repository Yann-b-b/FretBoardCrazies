import Combine
import Foundation

protocol DrillScheduler {
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable
    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable
}
