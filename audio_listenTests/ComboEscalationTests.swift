import CoreGraphics
import Testing
@testable import audio_listen

struct ComboEscalationTests {
    @Test func tierBoundaries() {
        #expect(ComboTier.tier(for: 1) == .none)
        #expect(ComboTier.tier(for: 2) == .one)
        #expect(ComboTier.tier(for: 14) == .one)
        #expect(ComboTier.tier(for: 15) == .two)
        #expect(ComboTier.tier(for: 24) == .two)
        #expect(ComboTier.tier(for: 25) == .three)
        #expect(ComboTier.tier(for: 49) == .three)
        #expect(ComboTier.tier(for: 50) == .four)
    }

    @Test func flameAssetByTier() {
        #expect(ComboEscalation.visual(for: 2).flameAsset == "flame-small")
        #expect(ComboEscalation.visual(for: 14).flameAsset == "flame-small")
        #expect(ComboEscalation.visual(for: 15).flameAsset == "flame-large")
        #expect(ComboEscalation.visual(for: 50).flameAsset == "flame-large")
    }

    @Test func rainbowOnlyAtTierFour() {
        #expect(ComboEscalation.visual(for: 49).rainbow == false)
        #expect(ComboEscalation.visual(for: 50).rainbow == true)
    }

    @Test func wiggleResetsAtMotionTierEntryAndGrows() {
        #expect(ComboEscalation.visual(for: 2).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 14).wiggleAmplitude > ComboEscalation.visual(for: 2).wiggleAmplitude)
        #expect(ComboEscalation.visual(for: 15).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 25).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 49).wiggleAmplitude > ComboEscalation.visual(for: 25).wiggleAmplitude)
        #expect(ComboEscalation.visual(for: 50).wiggleAmplitude == ComboEscalation.maxWiggle)
    }
}
