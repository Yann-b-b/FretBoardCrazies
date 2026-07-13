import Testing
@testable import audio_listen

struct EngineQualityTests {
    @Test func allTwentyThreeQualityIdsArePresent() {
        let expectedIds = [
            "maj7", "m7", "7", "m7b5", "6", "m6", "6/9", "maj9", "maj7#11",
            "9", "13", "7b9", "7#9", "7#5", "7alt", "7sus4", "9sus4",
            "dim7", "m9", "m11", "m13", "m(maj7)", "m6/9",
        ]
        #expect(EngineQualities.all.count == 23)
        #expect(Set(EngineQualities.all.map(\.id)) == Set(expectedIds))
    }

    @Test func spotCheckFormulas() {
        #expect(EngineQualities.byId("7alt")?.formula == [0, 4, 10, 13, 15, 18, 20])
        #expect(EngineQualities.byId("maj7#11")?.formula == [0, 4, 7, 11, 18])
        #expect(EngineQualities.byId("6/9")?.formula == [0, 4, 7, 9, 14])
        #expect(EngineQualities.byId("dim7")?.formula == [0, 3, 6, 9])
        #expect(EngineQualities.byId("13")?.formula == [0, 4, 7, 10, 14, 21])
    }

    @Test func isDominantClassification() {
        #expect(EngineQualities.isDominant("7") == true)
        #expect(EngineQualities.isDominant("9sus4") == true)
        #expect(EngineQualities.isDominant("m7") == false)
    }

    @Test func isMinorSeventhClassification() {
        #expect(EngineQualities.isMinorSeventh("m7b5") == true)
        #expect(EngineQualities.isMinorSeventh("m9") == true)
        #expect(EngineQualities.isMinorSeventh("m6") == false)
    }

    @Test func formulasCrossCheckWithChordQualitiesModuloOctave() {
        for engineQuality in EngineQualities.all {
            guard let voicingQuality = ChordQualities.byId(engineQuality.id) else { continue }
            let enginePitchClasses = Set(engineQuality.formula.map { ($0 % 12 + 12) % 12 })
            let voicingPitchClasses = Set(voicingQuality.formula.map { ($0 % 12 + 12) % 12 })
            #expect(enginePitchClasses == voicingPitchClasses)
        }
    }
}
