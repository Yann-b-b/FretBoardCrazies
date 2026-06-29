import Foundation

final class DrillStateMachine {
    private(set) var state: DrillState = .idle
    var onStateChange: ((DrillState) -> Void)?

    @discardableResult
    func transition(to newState: DrillState) -> Bool {
        switch (state, newState) {
        case (.idle, .countdown), (.idle, .playing),
             (.countdown, .playing), (.countdown, .idle),
             (.playing, .success), (.playing, .idle),
             (.success, .playing), (.success, .idle):
            break
        default:
            return false
        }
        state = newState
        onStateChange?(newState)
        return true
    }
}
