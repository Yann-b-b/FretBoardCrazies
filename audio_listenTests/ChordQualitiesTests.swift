import Testing
@testable import audio_listen

struct ChordQualitiesTests {
    @Test func catalogContainsTheSixBaseQualities() {
        let baseQualities = ["maj7", "m7", "7", "m7b5", "6", "m6"]
        for id in baseQualities {
            #expect(ChordQualities.byId(id) != nil, "Base quality \(id) should exist in catalog")
        }
    }

    @Test func formulasAreCorrectIntervalSets() {
        #expect(Set(ChordQualities.byId("maj7")!.formula) == [0, 4, 7, 11])
        #expect(Set(ChordQualities.byId("m7")!.formula) == [0, 3, 7, 10])
        #expect(Set(ChordQualities.byId("7")!.formula) == [0, 4, 7, 10])
        #expect(Set(ChordQualities.byId("m7b5")!.formula) == [0, 3, 6, 10])
        #expect(Set(ChordQualities.byId("6")!.formula) == [0, 4, 7, 9])
        #expect(Set(ChordQualities.byId("m6")!.formula) == [0, 3, 7, 9])
    }

    @Test func symbolsRenderChordNames() {
        #expect(ChordQualities.byId("7")!.symbol == "7")
        #expect(ChordQualities.byId("m7b5")!.symbol == "m7♭5")
    }

    @Test func byIdReturnsNilForUnknown() {
        #expect(ChordQualities.byId("13#11") == nil)
    }
}
