import Foundation
import Testing
@testable import audio_listen

struct UpdateItemStatsTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func correctAndFastPromotes() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats.unseen(at: now)
        let out = uc.applyCorrect(to: start, reactionTime: 1.0, now: now)
        #expect(out.box == 1)
        #expect(out.attempts == 1)
        #expect(out.correct == 1)
        #expect(out.lastReactionTime == 1.0)
        #expect(out.lastSeenAt == now)
    }

    @Test func correctButSlowDoesNotPromote() {
        let uc = UpdateItemStatsUseCase(maxBox: 4, fastReactionSeconds: 3.0)
        let start = ItemStats(box: 2, attempts: 3, correct: 3, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyCorrect(to: start, reactionTime: 5.0, now: now)
        #expect(out.box == 2)
        #expect(out.correct == 4)
    }

    @Test func promotionCapsAtMaxBox() {
        let uc = UpdateItemStatsUseCase(maxBox: 4, fastReactionSeconds: 3.0)
        let start = ItemStats(box: 4, attempts: 9, correct: 9, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyCorrect(to: start, reactionTime: 1.0, now: now)
        #expect(out.box == 4)
    }

    @Test func missDemotesAndCountsAttempt() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats(box: 3, attempts: 5, correct: 4, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyMiss(to: start, now: now)
        #expect(out.box == 2)
        #expect(out.attempts == 6)
        #expect(out.correct == 4)
    }

    @Test func missDoesNotGoBelowZero() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats.unseen(at: now)
        let out = uc.applyMiss(to: start, now: now)
        #expect(out.box == 0)
        #expect(out.attempts == 1)
    }
}
