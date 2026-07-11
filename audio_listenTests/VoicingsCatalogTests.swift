import Testing
@testable import audio_listen

struct VoicingsCatalogTests {
    @Test func everyV1QualityHasAnE6Voicing() {
        for quality in ChordQualities.all {
            #expect(Voicings.voicing(qualityId: quality.id, rootString: .e6) != nil)
        }
    }

    @Test func everyVoicingHasExactlyOneRootAtOffsetZeroOnItsRootString() {
        for voicing in Voicings.all {
            let roots = voicing.positions.filter {
                $0.string == voicing.rootString.stringNumber && $0.fretOffset == 0
            }
            #expect(roots.count == 1)
        }
    }

    @Test func rootStringMapsToStringNumber() {
        #expect(RootString.e6.stringNumber == 6)
        #expect(RootString.a5.stringNumber == 5)
        #expect(RootString.d4.stringNumber == 4)
    }

    @Test func fretOffsetsAreNonNegativeAndFingersAreOneToFour() {
        for voicing in Voicings.all {
            for position in voicing.positions {
                #expect(position.fretOffset >= 0)
                #expect((1...4).contains(position.finger))
            }
        }
    }
}
