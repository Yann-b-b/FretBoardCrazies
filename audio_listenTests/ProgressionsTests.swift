import Testing
@testable import audio_listen

struct ProgressionsTests {
    @Test func majorTwoFiveOneUsesM7Then7ThenMaj7() {
        let steps = Progressions.byId("major-ii-v-i")!.steps
        #expect(steps.map(\.qualityId) == ["m7", "7", "maj7"])
        #expect(steps.map(\.degree) == [2, 7, 0])
    }

    @Test func chordNamesResolveInCMajor() {
        let ii251 = Progressions.byId("major-ii-v-i")!
        let names = ii251.steps.map { ChordNaming.displayName(step: $0, tonic: .c) }
        #expect(names == ["Dm7", "G7", "Cmaj7"])
    }

    @Test func chordNamesTransposeToEveryKey() {
        let ii251 = Progressions.byId("major-ii-v-i")!
        // In G: ii=Am7, V=D7, I=Gmaj7
        let names = ii251.steps.map { ChordNaming.displayName(step: $0, tonic: .g) }
        #expect(names == ["Am7", "D7", "Gmaj7"])
    }

    @Test func everyProgressionStepQualityIsInTheV1Catalog() {
        let allowed = Set(ChordQualities.all.map(\.id))
        for progression in Progressions.all {
            for step in progression.steps {
                #expect(allowed.contains(step.qualityId))
            }
        }
    }

    @Test func catalogHasTheSixV1Progressions() {
        #expect(Progressions.all.map(\.id) == [
            "major-ii-v-i", "turnaround", "minor-ii-v-i", "sixth-loop", "dominant-blues", "minor-six-tonic",
        ])
    }
}
