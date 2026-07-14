import Testing
@testable import audio_listen

struct VoicingsCatalogTests {
    @Test func catalogHasExactlyTwentyThreeVoicings() {
        #expect(Voicings.all.count == 23)
    }

    @Test func everyEngineQualityHasAnE6Voicing() {
        for quality in EngineQualities.all {
            #expect(Voicings.voicing(qualityId: quality.id, rootString: .e6) != nil)
        }
    }

    @Test func noDuplicateQualityIds() {
        let ids = Voicings.all.map(\.qualityId)
        #expect(ids.count == Set(ids).count)
    }
}
