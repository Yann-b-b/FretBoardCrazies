import Testing
@testable import audio_listen

struct SuggestionGeneratorsTests {
    private let cMajor = Key(tonic: .c, mode: .major)
    private let aMinor = Key(tonic: .a, mode: .minor)

    private func candidates(_ ruleId: SuggestionRuleId, _ current: ChordSymbol, _ key: Key) -> [ChordSymbol] {
        SuggestionGenerators.all(current: current, key: key)
            .filter { $0.ruleId == ruleId }
            .map(\.chord)
    }

    @Test func resolveDominantDownAFifthLandsOnTonicColor() {
        let result = candidates(.resolveDominant, ChordSymbol(degree: 7, qualityId: "7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 0, qualityId: "maj7")))
    }

    @Test func resolveDominantDownAFifthFromANonTonicDominant() {
        let result = candidates(.resolveDominant, ChordSymbol(degree: 9, qualityId: "7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 2, qualityId: "m7")))
    }

    @Test func resolveDominantDownAHalfStepToTheTonic() {
        let result = candidates(.resolveDominant, ChordSymbol(degree: 1, qualityId: "7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 0, qualityId: "maj7")))
    }

    @Test func resolveDominantBackdoorFromFlatSeven() {
        let result = candidates(.resolveDominant, ChordSymbol(degree: 10, qualityId: "7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 0, qualityId: "maj7")))
    }

    @Test func resolveDominantSkipsNonFunctionalDownHalfStepLanding() {
        let result = candidates(.resolveDominant, ChordSymbol(degree: 2, qualityId: "7"), cMajor)
        #expect(!result.contains(ChordSymbol(degree: 1, qualityId: "maj7")))
    }

    @Test func iiToVFromTheHomeIiOffersTheV() {
        let result = candidates(.iiToV, ChordSymbol(degree: 2, qualityId: "m7"), cMajor)
        #expect(result == [ChordSymbol(degree: 7, qualityId: "7")])
    }

    @Test func iiToVFromAHalfDiminishedIiOffersAMinorDominant() {
        let result = candidates(.iiToV, ChordSymbol(degree: 2, qualityId: "m7b5"), cMajor)
        #expect(result == [ChordSymbol(degree: 7, qualityId: "7b9")])
    }

    @Test func iiToVExcludesTheTonic() {
        let result = candidates(.iiToV, ChordSymbol(degree: 0, qualityId: "m7"), cMajor)
        #expect(result.isEmpty)
    }

    @Test func diatonicMotionFromTheTonicOffersIvAndV() {
        let result = candidates(.diatonicMotion, ChordSymbol(degree: 0, qualityId: "maj7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 5, qualityId: "maj7")))
        #expect(result.contains(ChordSymbol(degree: 7, qualityId: "7")))
    }

    @Test func diatonicMotionIsGatedOnTheChordBeingDiatonic() {
        let result = candidates(.diatonicMotion, ChordSymbol(degree: 2, qualityId: "7"), cMajor)
        #expect(result.isEmpty)
    }

    @Test func tonicColorOnMajorTonic() {
        let result = candidates(.tonicColor, ChordSymbol(degree: 0, qualityId: "maj7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 0, qualityId: "6/9"),
            ChordSymbol(degree: 0, qualityId: "maj9"),
            ChordSymbol(degree: 0, qualityId: "maj7#11"),
        ])
    }

    @Test func tonicColorOnMinorTonic() {
        let result = candidates(.tonicColor, ChordSymbol(degree: 0, qualityId: "m7"), aMinor)
        #expect(Set(result) == [
            ChordSymbol(degree: 0, qualityId: "m6"),
            ChordSymbol(degree: 0, qualityId: "m(maj7)"),
            ChordSymbol(degree: 0, qualityId: "m6/9"),
        ])
    }

    @Test func dominantUpgradeOffersNineAndThirteen() {
        let result = candidates(.dominantUpgrade, ChordSymbol(degree: 7, qualityId: "7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 7, qualityId: "9"),
            ChordSymbol(degree: 7, qualityId: "13"),
        ])
    }

    @Test func dominantUpgradeDoesNotFireOnAPlainNine() {
        let result = candidates(.dominantUpgrade, ChordSymbol(degree: 7, qualityId: "9"), cMajor)
        #expect(result.isEmpty)
    }

    @Test func secondaryDominantFromTheTonicOffersVOfIiAndVOfV() {
        let result = SuggestionGenerators.all(current: ChordSymbol(degree: 0, qualityId: "maj7"), key: cMajor)
            .filter { $0.ruleId == .secondaryDominant }
        let chords = result.map(\.chord)
        #expect(chords.contains(ChordSymbol(degree: 9, qualityId: "7")))
        #expect(chords.contains(ChordSymbol(degree: 2, qualityId: "7")))
        let vOfIi = result.first { $0.chord == ChordSymbol(degree: 9, qualityId: "7") }
        #expect(vOfIi?.keyShiftTonicize == 2)
        let vOfV = result.first { $0.chord == ChordSymbol(degree: 2, qualityId: "7") }
        #expect(vOfV?.keyShiftTonicize == 7)
    }

    @Test func secondaryDominantDoesNotFireOnANonDiatonicChord() {
        let result = candidates(.secondaryDominant, ChordSymbol(degree: 9, qualityId: "7"), cMajor)
        #expect(result.isEmpty)
    }

    @Test func tritoneSubOffersTheFlatTwoDominant() {
        let result = candidates(.tritoneSub, ChordSymbol(degree: 7, qualityId: "7"), cMajor)
        #expect(result == [ChordSymbol(degree: 1, qualityId: "7")])
    }

    @Test func modeMixtureIiHalfDimBorrowsTheFlatSix() {
        let result = candidates(.modeMixtureIiHalfDim, ChordSymbol(degree: 2, qualityId: "m7"), cMajor)
        #expect(result == [ChordSymbol(degree: 2, qualityId: "m7b5")])
    }

    @Test func modeMixtureIvOnTheMajorTonic() {
        let result = candidates(.modeMixtureIv, ChordSymbol(degree: 0, qualityId: "maj7"), cMajor)
        #expect(result == [ChordSymbol(degree: 5, qualityId: "m7")])
    }

    @Test func dominantAlterOnTheVOffersAlteredDominants() {
        let result = candidates(.dominantAlter, ChordSymbol(degree: 7, qualityId: "7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 7, qualityId: "7b9"),
            ChordSymbol(degree: 7, qualityId: "7#9"),
            ChordSymbol(degree: 7, qualityId: "7#5"),
            ChordSymbol(degree: 7, qualityId: "7alt"),
        ])
    }

    @Test func minorLineClicheAdvancesFromMSixToMMajSeven() {
        let result = candidates(.minorLineCliche, ChordSymbol(degree: 0, qualityId: "m6"), aMinor)
        #expect(result == [ChordSymbol(degree: 0, qualityId: "m(maj7)")])
    }

    @Test func minorLineClicheAdvancesFromMMajSevenToMSeven() {
        let result = candidates(.minorLineCliche, ChordSymbol(degree: 0, qualityId: "m(maj7)"), aMinor)
        #expect(result == [ChordSymbol(degree: 0, qualityId: "m7")])
    }

    @Test func dimPassingOffersTheSharpOneDim7WhenIiIsAWholeStepUp() {
        let result = candidates(.dimPassing, ChordSymbol(degree: 0, qualityId: "maj7"), cMajor)
        #expect(result.contains(ChordSymbol(degree: 1, qualityId: "dim7")))
    }

    @Test func dimPassingIsGuardedAgainstHalfStepPairs() {
        let result = candidates(.dimPassing, ChordSymbol(degree: 4, qualityId: "m7"), cMajor)
        #expect(result.isEmpty)
    }

    @Test func dimResolveStepsUpAHalfStep() {
        let result = candidates(.dimResolve, ChordSymbol(degree: 1, qualityId: "dim7"), cMajor)
        #expect(result == [ChordSymbol(degree: 2, qualityId: "m7")])
    }

    @Test func susDelayOffersSusVariantsOnTheV() {
        let result = candidates(.susDelay, ChordSymbol(degree: 7, qualityId: "7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 7, qualityId: "7sus4"),
            ChordSymbol(degree: 7, qualityId: "9sus4"),
        ])
    }

    @Test func extendedColorOnAMinorSeventhIiOffersExtensions() {
        let result = candidates(.extendedColor, ChordSymbol(degree: 2, qualityId: "m7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 2, qualityId: "m9"),
            ChordSymbol(degree: 2, qualityId: "m11"),
            ChordSymbol(degree: 2, qualityId: "m13"),
        ])
    }

    @Test func extendedColorOnTheMajorTonicOffersMaj9AndSharpEleven() {
        let result = candidates(.extendedColor, ChordSymbol(degree: 0, qualityId: "maj7"), cMajor)
        #expect(Set(result) == [
            ChordSymbol(degree: 0, qualityId: "maj9"),
            ChordSymbol(degree: 0, qualityId: "maj7#11"),
        ])
    }
}
