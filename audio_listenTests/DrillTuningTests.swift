import Foundation
import Testing
@testable import audio_listen

struct DrillTuningTests {
    @Test func valuesAreStable() {
        #expect(DrillTuning.maxBox == 4)
        #expect(DrillTuning.fastReactionSeconds == 3.0)
    }

    @Test func universeSizeScalesWithStringCount() {
        #expect(DrillTuning.universeSize(for: Instruments.guitar) == 72)
        #expect(DrillTuning.universeSize(for: Instruments.bass) == 48)
    }
}
