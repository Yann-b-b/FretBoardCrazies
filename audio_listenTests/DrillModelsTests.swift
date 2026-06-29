import Foundation
import Testing
@testable import audio_listen

struct GameSettingsKeysTests {
    @Test func countdownKeyValueIsStable() {
        #expect(GameSettingsKeys.countdownEnabled == "countdownEnabled")
    }
}

struct DrillModelTests {
    @Test func itemKeyRoundTripsCodable() throws {
        let key = DrillItemKey(noteName: .fSharp, string: 5)
        let data = try JSONEncoder().encode(key)
        let back = try JSONDecoder().decode(DrillItemKey.self, from: data)
        #expect(back == key)
    }

    @Test func promptDerivesItemKeyFromNoteAndString() {
        let prompt = DrillPrompt(direction: .findPosition, targetNote: Note(.c, octave: 3), string: 5)
        #expect(prompt.itemKey == DrillItemKey(noteName: .c, string: 5))
    }

    @Test func itemStatsRoundTripsCodable() throws {
        let stats = ItemStats(box: 2, attempts: 5, correct: 4, lastReactionTime: 0.9, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(stats)
        let back = try JSONDecoder().decode(ItemStats.self, from: data)
        #expect(back == stats)
    }

    @Test func masteryUnseenWhenNoAttempts() {
        #expect(MasteryLevel.from(box: 0, attempts: 0, masteredBox: 4) == .unseen)
    }

    @Test func masteryLearningBelowMasteredBox() {
        #expect(MasteryLevel.from(box: 2, attempts: 3, masteredBox: 4) == .learning)
    }

    @Test func masteryMasteredAtOrAboveBox() {
        #expect(MasteryLevel.from(box: 4, attempts: 10, masteredBox: 4) == .mastered)
    }
}
