import Foundation

struct ItemStats: Codable, Equatable {
    var box: Int
    var attempts: Int
    var correct: Int
    var lastReactionTime: TimeInterval?
    var lastSeenAt: Date

    static func unseen(at date: Date) -> ItemStats {
        ItemStats(box: 0, attempts: 0, correct: 0, lastReactionTime: nil, lastSeenAt: date)
    }
}
