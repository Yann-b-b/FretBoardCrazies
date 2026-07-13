import Testing
@testable import audio_listen

struct SuggestionRankerTests {
    private let cMajor = Key(tonic: .c, mode: .major)

    @Test func resolutionOutranksSecondaryDominantOutranksColor() {
        let current = ChordSymbol(degree: 7, qualityId: "7")
        let resolution = ChordSuggestion(chord: ChordSymbol(degree: 0, qualityId: "maj7"), ruleId: .resolveDominant, keyShiftTonicize: nil)
        let secondaryDominant = ChordSuggestion(chord: ChordSymbol(degree: 2, qualityId: "7"), ruleId: .secondaryDominant, keyShiftTonicize: 7)
        let color = ChordSuggestion(chord: ChordSymbol(degree: 7, qualityId: "9"), ruleId: .dominantUpgrade, keyShiftTonicize: nil)

        let result = SuggestionRanker.rank([color, secondaryDominant, resolution], current: current, key: cMajor)

        #expect(result == [resolution, secondaryDominant, color])
    }

    @Test func secondaryDominantsAreCappedToTwo() {
        let current = ChordSymbol(degree: 0, qualityId: "maj7")
        let candidates = [2, 4, 5, 7, 9].map { target in
            ChordSuggestion(chord: ChordSymbol(degree: (target + 7) % 12, qualityId: "7"), ruleId: .secondaryDominant, keyShiftTonicize: target)
        }

        let result = SuggestionRanker.rank(candidates, current: current, key: cMajor)

        #expect(result.filter { $0.ruleId == .secondaryDominant }.count == 2)
    }

    @Test func secondaryDominantsKeepVOfVThenVOfIi() {
        let current = ChordSymbol(degree: 0, qualityId: "maj7")
        let candidates = [2, 4, 5, 7, 9].map { target in
            ChordSuggestion(chord: ChordSymbol(degree: (target + 7) % 12, qualityId: "7"), ruleId: .secondaryDominant, keyShiftTonicize: target)
        }

        let result = SuggestionRanker.rank(candidates, current: current, key: cMajor)
        let survivingTargets = Set(result.filter { $0.ruleId == .secondaryDominant }.map { $0.keyShiftTonicize })

        #expect(survivingTargets == [7, 2])
    }

    @Test func dedupKeepsTheHighestPriorityRuleId() {
        let current = ChordSymbol(degree: 7, qualityId: "7")
        let chord = ChordSymbol(degree: 0, qualityId: "maj7")
        let lowerPriority = ChordSuggestion(chord: chord, ruleId: .dominantUpgrade, keyShiftTonicize: nil)
        let higherPriority = ChordSuggestion(chord: chord, ruleId: .resolveDominant, keyShiftTonicize: nil)

        let result = SuggestionRanker.rank([lowerPriority, higherPriority], current: current, key: cMajor)

        #expect(result == [higherPriority])
    }

    @Test func tiebreakPrefersTheTonicResolutionOverDownAFifthWhenTheHalfStepLandsHome() {
        let current = ChordSymbol(degree: 1, qualityId: "7")
        let downFifth = ChordSuggestion(chord: ChordSymbol(degree: 6, qualityId: "maj7"), ruleId: .resolveDominant, keyShiftTonicize: nil)
        let downHalfToTonic = ChordSuggestion(chord: ChordSymbol(degree: 0, qualityId: "maj7"), ruleId: .resolveDominant, keyShiftTonicize: nil)

        let result = SuggestionRanker.rank([downFifth, downHalfToTonic], current: current, key: cMajor)

        #expect(result.first == downHalfToTonic)
    }

    @Test func outputIsCappedAtFive() {
        let current = ChordSymbol(degree: 0, qualityId: "maj7")
        let result = SuggestionRanker.rank(SuggestionGenerators.all(current: current, key: cMajor), current: current, key: cMajor)

        #expect(result.count <= 5)
    }

    @Test func outputHasAtLeastThreeWhenEnoughCandidatesExist() {
        let current = ChordSymbol(degree: 0, qualityId: "maj7")
        let result = SuggestionRanker.rank(SuggestionGenerators.all(current: current, key: cMajor), current: current, key: cMajor)

        #expect(result.count >= 3)
    }
}
