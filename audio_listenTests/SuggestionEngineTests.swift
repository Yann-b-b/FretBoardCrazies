import Testing
@testable import audio_listen

struct SuggestionEngineTests {
    private let cMajor = Key(tonic: .c, mode: .major)
    private let aMinor = Key(tonic: .a, mode: .minor)

    private func contains(_ suggestions: [ChordSuggestion], degree: Int, quality: String) -> Bool {
        suggestions.contains { $0.chord == ChordSymbol(degree: degree, qualityId: quality) }
    }

    @Test func deadEndsD7ResolvesToG7() {
        let context = SuggestionContext(key: cMajor, tierLevel: 2, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 2, qualityId: "7"), context: context)

        #expect(contains(result, degree: 7, quality: "7"))
    }

    @Test func deadEndsA7ResolvesToDm7() {
        let context = SuggestionContext(key: cMajor, tierLevel: 2, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 9, qualityId: "7"), context: context)

        #expect(contains(result, degree: 2, quality: "m7"))
    }

    @Test func idiomContinuesFm7ToBFlat7() {
        let context = SuggestionContext(key: cMajor, tierLevel: 4, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 5, qualityId: "m7"), context: context)

        #expect(contains(result, degree: 10, quality: "7"))
    }

    @Test func idiomContinuesBFlat7BackdoorsToTonic() {
        let context = SuggestionContext(key: cMajor, tierLevel: 4, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 10, qualityId: "7"), context: context)

        #expect(contains(result, degree: 0, quality: "maj7"))
    }

    @Test func idiomContinuesDiminishedResolvesToTheIi() {
        let context = SuggestionContext(key: cMajor, tierLevel: 4, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 1, qualityId: "dim7"), context: context)

        #expect(contains(result, degree: 2, quality: "m7"))
    }

    @Test func backdoorEntryIsGenerated() {
        let candidates = SuggestionGenerators.all(current: ChordSymbol(degree: 0, qualityId: "maj7"), key: cMajor)

        #expect(candidates.contains { $0.chord == ChordSymbol(degree: 5, qualityId: "m7") && $0.ruleId == .modeMixtureIv })
        // Continuation once entered (Fm7 -> Bb7 -> Cmaj7) is covered by
        // idiomContinuesFm7ToBFlat7 and idiomContinuesBFlat7BackdoorsToTonic above.
    }

    @Test func minorCadenceResolvesToTonicColorNotBareM7() {
        let context = SuggestionContext(key: aMinor, tierLevel: 3, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 7, qualityId: "7b9"), context: context)

        #expect(contains(result, degree: 0, quality: "m6"))
        #expect(!contains(result, degree: 0, quality: "m7"))
    }

    @Test func tierOneFromTonicHasNoSecondaryDominants() {
        let context = SuggestionContext(key: cMajor, tierLevel: 1, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 0, qualityId: "maj7"), context: context)

        #expect(!result.contains { $0.ruleId == .secondaryDominant })
    }

    @Test func tierOneFromTonicOnlyUnlocksTierOneSuggestions() {
        let context = SuggestionContext(key: cMajor, tierLevel: 1, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 0, qualityId: "maj7"), context: context)

        for suggestion in result {
            #expect(Tiers.isUnlocked(qualityId: suggestion.chord.qualityId, ruleId: suggestion.ruleId, level: 1))
        }
    }

    @Test func tierOneFromTonicReturnsThreeToFiveSuggestions() {
        let context = SuggestionContext(key: cMajor, tierLevel: 1, pendingTonic: nil)
        let result = SuggestionEngine.suggest(current: ChordSymbol(degree: 0, qualityId: "maj7"), context: context)

        #expect((3...5).contains(result.count))
    }

    @Test func keyShiftSetsPendingTonicOnSecondaryDominant() {
        let context = SuggestionContext(key: cMajor, tierLevel: 2, pendingTonic: nil)
        let shifted = SuggestionEngine.applyKeyShift(context: context, played: ChordSymbol(degree: 9, qualityId: "7"))

        #expect(shifted.pendingTonic == 2)
        #expect(shifted.key == cMajor)
    }

    @Test func keyShiftClearsPendingTonicOnResolutionAndStaysHome() {
        let context = SuggestionContext(key: cMajor, tierLevel: 2, pendingTonic: 2)
        let resolved = SuggestionEngine.applyKeyShift(context: context, played: ChordSymbol(degree: 2, qualityId: "m7"))

        #expect(resolved.pendingTonic == nil)
        #expect(resolved.key == cMajor)
    }
}
