import Foundation
import Testing
@testable import audio_listen

struct BeltRankTests {
    private func stats(boxes: [Int]) -> [DrillItemKey: ItemStats] {
        var d: [DrillItemKey: ItemStats] = [:]
        for (i, box) in boxes.enumerated() {
            let key = DrillItemKey(noteName: NoteName(rawValue: i / 6)!, string: (i % 6) + 1)
            d[key] = ItemStats(box: box, attempts: 1, correct: 1, lastReactionTime: 1.0, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        }
        return d
    }

    @Test func emptyStatsIsWhiteAtZero() {
        let r = BeltRank.from(stats: [:], maxBox: 4, universeSize: 72)
        #expect(r.belt == .white)
        #expect(r.fraction == 0)
        #expect(r.fractionToNext == 0)
    }

    @Test func fullStatsIsBlack() {
        let boxes = Array(repeating: 4, count: 72)
        let r = BeltRank.from(stats: stats(boxes: boxes), maxBox: 4, universeSize: 72)
        #expect(r.belt == .black)
        #expect(r.fraction == 1.0)
        #expect(r.fractionToNext == 1.0)
    }

    @Test func fractionAtOrangeThreshold() {
        // 18 items at box 4 = 72 points / 288 = 0.25 -> Orange (threshold 0.25)
        var boxes = Array(repeating: 4, count: 18)
        boxes += Array(repeating: 0, count: 54)
        let r = BeltRank.from(stats: stats(boxes: boxes), maxBox: 4, universeSize: 72)
        #expect(r.belt == .orange)
        #expect(abs(r.fraction - 0.25) < 0.0001)
        #expect(r.fractionToNext < 0.05)
    }

    @Test func clampsBoxAboveMax() {
        let r = BeltRank.from(stats: stats(boxes: [99]), maxBox: 4, universeSize: 72)
        #expect(r.fraction == 4.0 / 288.0)
    }

    @Test func displayNamesCoverAllBelts() {
        #expect(Belt.allCases.map(\.displayName) == ["White","Yellow","Orange","Green","Blue","Purple","Brown","Black"])
    }
}
