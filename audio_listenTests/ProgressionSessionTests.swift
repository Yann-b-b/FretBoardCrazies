// audio_listenTests/ProgressionSessionTests.swift
import Testing
@testable import audio_listen

@MainActor
struct ProgressionSessionTests {
    private func session(_ mode: ProgressionSession.DisplayMode) -> ProgressionSession {
        ProgressionSession(progression: Progressions.byId("major-ii-v-i")!, tonic: .c, rootString: .e6, displayMode: mode)
    }

    @Test func advanceWrapsAtLoopBoundary() {
        let s = session(.nameAndFingering)
        #expect(s.index == 0)
        s.advance(); s.advance()
        #expect(s.index == 2)
        s.advance()
        #expect(s.index == 0)
    }

    @Test func nextStepWrapsToFirst() {
        let s = session(.nameAndFingering)
        s.advance(); s.advance() // index 2 (last)
        #expect(s.nextStep == s.progression.steps[0])
    }

    @Test func fingeringModeIsAlwaysRevealed() {
        let s = session(.nameAndFingering)
        #expect(s.revealed == true)
        s.primaryAction() // advances
        #expect(s.index == 1)
        #expect(s.revealed == true)
    }

    @Test func recallModeRevealsThenAdvances() {
        let s = session(.nameOnly)
        #expect(s.revealed == false)
        s.primaryAction() // reveals, does not advance
        #expect(s.index == 0)
        #expect(s.revealed == true)
        s.primaryAction() // advances, re-hides
        #expect(s.index == 1)
        #expect(s.revealed == false)
    }

    @Test func switchingToRecallModeHidesTheGrip() {
        let s = session(.nameAndFingering)
        s.displayMode = .nameOnly
        #expect(s.revealed == false)
    }

    @Test func previousWraps() {
        let s = session(.nameAndFingering)
        s.previous()
        #expect(s.index == 2)
    }
}
