import Foundation

struct UpdateItemStatsUseCase {
    let maxBox: Int
    let fastReactionSeconds: TimeInterval

    init(maxBox: Int = DrillTuning.maxBox, fastReactionSeconds: TimeInterval = DrillTuning.fastReactionSeconds) {
        self.maxBox = maxBox
        self.fastReactionSeconds = fastReactionSeconds
    }

    func applyCorrect(to stats: ItemStats, reactionTime: TimeInterval, now: Date) -> ItemStats {
        var next = stats
        next.attempts += 1
        next.correct += 1
        next.lastReactionTime = reactionTime
        next.lastSeenAt = now
        if reactionTime <= fastReactionSeconds {
            next.box = min(maxBox, next.box + 1)
        }
        return next
    }

    func applyMiss(to stats: ItemStats, now: Date) -> ItemStats {
        var next = stats
        next.attempts += 1
        next.lastSeenAt = now
        next.box = max(0, next.box - 1)
        return next
    }
}
