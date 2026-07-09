import Testing
@testable import audio_listen

@MainActor
struct AutoAdvanceTests {
    @Test func defaultsToPausedAtTwoSeconds() {
        let a = AutoAdvance()
        #expect(a.isPlaying == false)
        #expect(a.pace == 2.0)
    }

    @Test func clampsPaceBelowMinToOne() {
        let a = AutoAdvance()
        a.pace = 0.2
        #expect(a.pace == 1.0)
    }

    @Test func clampsPaceAboveMaxToSix() {
        let a = AutoAdvance()
        a.pace = 99
        #expect(a.pace == 6.0)
    }

    @Test func keepsPaceInRange() {
        let a = AutoAdvance()
        a.pace = 3.5
        #expect(a.pace == 3.5)
    }

    @Test func initClampsOutOfRangePace() {
        #expect(AutoAdvance(pace: 100).pace == 6.0)
        #expect(AutoAdvance(pace: 0).pace == 1.0)
    }
}
