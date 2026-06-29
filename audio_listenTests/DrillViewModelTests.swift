import Combine
import Foundation
import Testing
@testable import audio_listen

struct DrillStateMachineTests {
    let prompt = DrillPrompt(direction: .findPosition, targetNote: Note(.c, octave: 3), string: 5)

    @Test func acceptsValidTransitionAndFiresCallback() {
        let sm = DrillStateMachine()
        var observed: [DrillState] = []
        sm.onStateChange = { observed.append($0) }
        let ok = sm.transition(to: .countdown(remaining: 3, prompt: prompt))
        #expect(ok)
        #expect(sm.state == .countdown(remaining: 3, prompt: prompt))
        #expect(observed.count == 1)
    }

    @Test func rejectsInvalidTransition() {
        let sm = DrillStateMachine()
        let ok = sm.transition(to: .success(reactionTime: 1, prompt: prompt))
        #expect(!ok)
        #expect(sm.state == .idle)
    }
}
