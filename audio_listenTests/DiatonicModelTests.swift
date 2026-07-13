import Testing
@testable import audio_listen

struct DiatonicModelTests {
    @Test func majorCHasSevenDiatonicChords() {
        let key = Key(tonic: .c, mode: .major)
        #expect(DiatonicModel.diatonic(key) == [
            ChordSymbol(degree: 0, qualityId: "maj7"),
            ChordSymbol(degree: 2, qualityId: "m7"),
            ChordSymbol(degree: 4, qualityId: "m7"),
            ChordSymbol(degree: 5, qualityId: "maj7"),
            ChordSymbol(degree: 7, qualityId: "7"),
            ChordSymbol(degree: 9, qualityId: "m7"),
            ChordSymbol(degree: 11, qualityId: "m7b5"),
        ])
    }

    @Test func minorAHasEightDiatonicChords() {
        let key = Key(tonic: .a, mode: .minor)
        #expect(DiatonicModel.diatonic(key) == [
            ChordSymbol(degree: 0, qualityId: "m7"),
            ChordSymbol(degree: 2, qualityId: "m7b5"),
            ChordSymbol(degree: 3, qualityId: "maj7"),
            ChordSymbol(degree: 5, qualityId: "m7"),
            ChordSymbol(degree: 7, qualityId: "7"),
            ChordSymbol(degree: 8, qualityId: "maj7"),
            ChordSymbol(degree: 10, qualityId: "7"),
            ChordSymbol(degree: 11, qualityId: "dim7"),
        ])
    }

    @Test func isDiatonicMatchesDegreeAndQuality() {
        let key = Key(tonic: .c, mode: .major)
        #expect(DiatonicModel.isDiatonic(ChordSymbol(degree: 2, qualityId: "m7"), key) == true)
        #expect(DiatonicModel.isDiatonic(ChordSymbol(degree: 2, qualityId: "7"), key) == false)
    }

    @Test func isTonicHereIsDegreeZero() {
        #expect(DiatonicModel.isTonicHere(ChordSymbol(degree: 0, qualityId: "m6")) == true)
        #expect(DiatonicModel.isTonicHere(ChordSymbol(degree: 7, qualityId: "7")) == false)
    }

    @Test func targetsAreTheTonicizableDegrees() {
        #expect(DiatonicModel.targets(Key(tonic: .c, mode: .major)) == [2, 4, 5, 7, 9])
        #expect(DiatonicModel.targets(Key(tonic: .a, mode: .minor)) == [3, 5, 7, 8, 10])
    }

    @Test func resolutionQualityAtGivesTheTonicItsColor() {
        #expect(DiatonicModel.resolutionQualityAt(0, Key(tonic: .c, mode: .major)) == "maj7")
        #expect(DiatonicModel.resolutionQualityAt(0, Key(tonic: .a, mode: .minor)) == "m6")
        #expect(DiatonicModel.resolutionQualityAt(7, Key(tonic: .c, mode: .major)) == "7")
    }
}
