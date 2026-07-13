import Testing
@testable import audio_listen

struct ExplanationsTests {
    @Test func everyRuleIdHasNonEmptyShortAndLong() {
        for ruleId in SuggestionRuleId.allCases {
            let text = Explanations.text(for: ruleId)
            #expect(!text.short.isEmpty)
            #expect(!text.long.isEmpty)
        }
    }

    @Test func iiToVLongMentionsTheHalfStepFall() {
        #expect(Explanations.text(for: .iiToV).long.contains("falls a half-step"))
    }

    @Test func tritoneSubShortMentionsTritone() {
        let short = Explanations.text(for: .tritoneSub).short
        #expect(short.contains("tritone") || short.contains("♭II7"))
    }

    @Test func resolveDominantShortIsTheResolutionPhrase() {
        #expect(Explanations.text(for: .resolveDominant).short == "resolves home")
    }
}
