import Foundation
import Testing
@testable import audio_listen

struct TierProgressTests {
    @Test func rollingAverageIsNilWithNoSamples() {
        let progress = TierProgress()
        #expect(progress.rollingAverage == nil)
    }

    @Test func singleFastSampleDoesNotUnlock() {
        var progress = TierProgress()
        progress.record(timeToPlay: 1.0, at: 0)
        #expect(progress.level == 1)
    }

    @Test func fastTimesAcrossEnoughSamplesAdvanceLevel() {
        var progress = TierProgress()
        for i in 0..<TierProgress.minimumSampleCount {
            progress.record(timeToPlay: 1.0, at: TimeInterval(i))
        }
        #expect(progress.level == 2)
    }

    @Test func slowTimesNeverAdvanceLevel() {
        var progress = TierProgress()
        for i in 0..<20 {
            progress.record(timeToPlay: 3.0, at: TimeInterval(i))
        }
        #expect(progress.level == 1)
    }

    @Test func rollingWindowDropsSamplesOlderThanSustainWindow() {
        var progress = TierProgress()
        progress.record(timeToPlay: 5.0, at: 0)
        progress.record(timeToPlay: 5.0, at: 1)
        progress.record(timeToPlay: 5.0, at: 2)
        progress.record(timeToPlay: 1.0, at: 700)
        progress.record(timeToPlay: 1.0, at: 701)
        progress.record(timeToPlay: 1.0, at: 702)
        #expect(progress.rollingAverage == 1.0)
    }

    @Test func levelCapsAtMaxLevel() {
        var progress = TierProgress()
        for i in 0..<30 {
            progress.record(timeToPlay: 1.0, at: TimeInterval(i))
        }
        #expect(progress.level == TierProgress.maxLevel)
    }

    @Test func maxLevelMatchesTierCount() {
        #expect(TierProgress.maxLevel == Tiers.all.count)
    }
}
