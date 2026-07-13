import Foundation

struct TierProgress: Hashable {
    private struct Sample: Hashable {
        let timestamp: TimeInterval
        let timeToPlay: TimeInterval
    }

    private(set) var level: Int
    private var samples: [Sample] = []

    static let targetTimePerChord: TimeInterval = 1.5
    static let sustainWindowSeconds: TimeInterval = 600
    static let minimumSampleCount: Int = 5
    static let maxLevel: Int = Tiers.all.count

    init(level: Int = 1) {
        self.level = level
    }

    mutating func record(timeToPlay: TimeInterval, at now: TimeInterval) {
        samples.append(Sample(timestamp: now, timeToPlay: timeToPlay))
        samples.removeAll { now - $0.timestamp > Self.sustainWindowSeconds }
        guard level < Self.maxLevel,
              samples.count >= Self.minimumSampleCount,
              let average = rollingAverage,
              average <= Self.targetTimePerChord
        else { return }
        level += 1
        samples.removeAll()
    }

    var rollingAverage: TimeInterval? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.timeToPlay } / TimeInterval(samples.count)
    }
}
