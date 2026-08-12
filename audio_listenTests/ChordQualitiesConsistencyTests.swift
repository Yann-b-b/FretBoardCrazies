import Testing
@testable import audio_listen

struct ChordQualitiesConsistencyTests {
    @Test func catalogHasAllTwentyThreeEngineQualities() {
        #expect(ChordQualities.all.count == 23)
        for engineQuality in EngineQualities.all {
            #expect(ChordQualities.byId(engineQuality.id) != nil, "missing quality \(engineQuality.id)")
        }
    }

    @Test func everyQualityAgreesWithItsEngineCounterpartOnPitchClasses() {
        for engineQuality in EngineQualities.all {
            let catalogQuality = ChordQualities.byId(engineQuality.id)!
            let catalogPitchClasses = Set(catalogQuality.formula.map { (($0 % 12) + 12) % 12 })
            let enginePitchClasses = Set(engineQuality.formula.map { (($0 % 12) + 12) % 12 })
            #expect(
                catalogPitchClasses == enginePitchClasses,
                "\(engineQuality.id): catalog \(catalogPitchClasses.sorted()) != engine \(enginePitchClasses.sorted())"
            )
        }
    }

    @Test func everyQualityHasANonEmptyNameAndSymbol() {
        for quality in ChordQualities.all {
            #expect(!quality.name.isEmpty, "\(quality.id) has an empty name")
            #expect(!quality.symbol.isEmpty, "\(quality.id) has an empty symbol")
        }
    }
}
