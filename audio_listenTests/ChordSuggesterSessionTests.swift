import Testing
@testable import audio_listen

@MainActor
struct ChordSuggesterSessionTests {
    @Test func startsOnTheTonicMajor7() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 1)
        #expect(session.current == ChordSymbol(degree: 0, qualityId: "maj7"))
        #expect(session.lastRuleId == nil)
    }

    @Test func everyRenderedChordHasAPlayableVoicing() {
        let session = ChordSuggesterSession(tonic: .g, tierLevel: 4)
        for _ in 0..<64 {
            session.advance()
            #expect(Voicings.voicing(qualityId: session.display.qualityId, rootString: .e6) != nil)
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

    @Test func tierFourWalkPracticesManyExtendedShapes() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 4)
        var rendered: Set<String> = []
        for _ in 0..<48 {
            session.advance()
            rendered.insert(session.display.qualityId)
        }
        #expect(rendered.count >= 8)
        #expect(!rendered.isSubset(of: Tiers.unlocked(atLevel: 1).qualityIds))
    }

    @Test func tierOneStaysWithinItsUnlockedPalette() {
        let session = ChordSuggesterSession(tonic: .c, tierLevel: 1)
        let tierOne = Tiers.unlocked(atLevel: 1).qualityIds
        for _ in 0..<48 {
            session.advance()
            #expect(tierOne.contains(session.display.qualityId))
        }
    }
}
