import Testing
@testable import audio_listen

@MainActor
struct ChordSuggesterSessionTests {
    @Test func startsOnTheTonicMajor7() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 1)
        #expect(session.current == ChordSymbol(degree: 0, qualityId: "maj7"))
        #expect(session.lastRuleId == nil)
    }

    @Test func everyLandedChordHasAPlayableVoicing() {
        let session = ChordSuggesterSession(tonic: .g, tierLevel: 4)
        for _ in 0..<64 {
            session.advance()
            #expect(Voicings.voicing(qualityId: session.current.qualityId, rootString: .e6) != nil)
        }
    }

    @Test func neverStallsOnASingleChord() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 2)
        var landed: [ChordSymbol] = []
        for _ in 0..<24 {
            session.advance()
            landed.append(session.current)
        }
        #expect(Set(landed).count >= 4)
        #expect(!landed.allSatisfy { $0 == landed.first })
    }

    @Test func resetReturnsToTheTonic() {
        let session = ChordSuggesterSession(tonic: .d, tierLevel: 3)
        session.advance()
        session.advance()
        session.resetToTonic()
        #expect(session.current == ChordSymbol(degree: 0, qualityId: "maj7"))
        #expect(session.lastRuleId == nil)
    }

    @Test func tierFourReachesAColorLockedAtTierOne() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 4)
        var seenQualities: Set<String> = []
        for _ in 0..<48 {
            session.advance()
            seenQualities.insert(session.current.qualityId)
        }
        let tierOneQualities = Tiers.unlocked(atLevel: 1).qualityIds
        #expect(!seenQualities.isSubset(of: tierOneQualities))
    }
}
