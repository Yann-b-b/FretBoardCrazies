import Testing
@testable import audio_listen

struct TierTests {
    @Test func tierOneMatchesTheQualitiesAndRuleIdsInTheSpec() {
        let t1 = Tiers.all[0]
        #expect(t1.level == 1)
        #expect(t1.qualityIds == ["maj7", "m7", "7", "m7b5", "6", "m6", "6/9"])
        #expect(t1.ruleIds == [.resolveDominant, .iiToV, .diatonicMotion, .tonicColor])
    }

    @Test func tierTwoAddsDominantColorAndSecondaryMotion() {
        let t2 = Tiers.all[1]
        #expect(t2.level == 2)
        #expect(t2.qualityIds == ["9", "13", "maj9"])
        #expect(t2.ruleIds == [.dominantUpgrade, .secondaryDominant])
    }

    @Test func tierThreeAddsAlterationSubsAndMinorColor() {
        let t3 = Tiers.all[2]
        #expect(t3.level == 3)
        #expect(t3.qualityIds == ["7b9", "7#9", "7#5", "7alt", "m(maj7)"])
        #expect(t3.ruleIds == [.tritoneSub, .modeMixtureIiHalfDim, .modeMixtureIv, .dominantAlter, .minorLineCliche])
    }

    @Test func tierFourAddsExtendedAndPassing() {
        let t4 = Tiers.all[3]
        #expect(t4.level == 4)
        #expect(t4.qualityIds == ["maj7#11", "m9", "m11", "m13", "m6/9", "dim7", "7sus4", "9sus4"])
        #expect(t4.ruleIds == [.dimPassing, .dimResolve, .susDelay, .extendedColor])
    }

    @Test func unlockedAtLevelTwoIsTheUnionOfTierOneAndTierTwo() {
        let unlocked = Tiers.unlocked(atLevel: 2)
        #expect(unlocked.level == 2)
        #expect(unlocked.qualityIds == ["maj7", "m7", "7", "m7b5", "6", "m6", "6/9", "9", "13", "maj9"])
        #expect(unlocked.ruleIds == [
            .resolveDominant, .iiToV, .diatonicMotion, .tonicColor,
            .dominantUpgrade, .secondaryDominant,
        ])
    }

    @Test func unlockedAtLevelOneOnlyIncludesTierOne() {
        let unlocked = Tiers.unlocked(atLevel: 1)
        #expect(unlocked.qualityIds == Tiers.all[0].qualityIds)
        #expect(unlocked.ruleIds == Tiers.all[0].ruleIds)
    }

    @Test func isUnlockedGatesOnBothQualityAndRuleId() {
        #expect(Tiers.isUnlocked(qualityId: "9", ruleId: .secondaryDominant, level: 2) == true)
        #expect(Tiers.isUnlocked(qualityId: "dim7", ruleId: .dimPassing, level: 2) == false)
        #expect(Tiers.isUnlocked(qualityId: "7", ruleId: .tritoneSub, level: 2) == false)
        #expect(Tiers.isUnlocked(qualityId: "7", ruleId: .tritoneSub, level: 3) == true)
    }

    @Test func isUnlockedRequiresQualityUnlockedEvenIfRuleIsUnlocked() {
        #expect(Tiers.isUnlocked(qualityId: "dim7", ruleId: .resolveDominant, level: 1) == false)
    }

    @Test func isUnlockedRequiresRuleUnlockedEvenIfQualityIsUnlocked() {
        #expect(Tiers.isUnlocked(qualityId: "maj7", ruleId: .dimPassing, level: 3) == false)
    }

    @Test func everySpecQualityAppearsInExactlyOneTier() {
        let expectedQualityIds: Set<String> = [
            "maj7", "m7", "7", "m7b5", "6", "m6", "6/9",
            "9", "13", "maj9",
            "7b9", "7#9", "7#5", "7alt", "m(maj7)",
            "maj7#11", "m9", "m11", "m13", "m6/9", "dim7", "7sus4", "9sus4",
        ]
        #expect(expectedQualityIds.count == 23)
        let allQualityIds = Tiers.all.flatMap(\.qualityIds)
        #expect(allQualityIds.count == Set(allQualityIds).count)
        #expect(Set(allQualityIds) == expectedQualityIds)
    }

    @Test func everyRuleIdAppearsInExactlyOneTier() {
        #expect(SuggestionRuleId.allCases.count == 15)
        let allRuleIds = Tiers.all.flatMap(\.ruleIds)
        #expect(allRuleIds.count == Set(allRuleIds).count)
        #expect(Set(allRuleIds) == Set(SuggestionRuleId.allCases))
    }

    @Test func suggestionContextAndChordSuggestionAreHashable() {
        let context = SuggestionContext(key: Key(tonic: .c, mode: .major), tierLevel: 2, pendingTonic: 7)
        let suggestion = ChordSuggestion(
            chord: ChordSymbol(degree: 7, qualityId: "7"),
            ruleId: .resolveDominant,
            keyShiftTonicize: 0
        )
        #expect(Set([context]).contains(context))
        #expect(Set([suggestion]).contains(suggestion))
    }
}
