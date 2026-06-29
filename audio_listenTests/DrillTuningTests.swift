import Foundation
import Testing
@testable import audio_listen

struct DrillTuningTests {
    @Test func valuesAreStable() {
        #expect(DrillTuning.maxBox == 4)
        #expect(DrillTuning.fastReactionSeconds == 3.0)
        #expect(DrillTuning.totalItemCount == 72)
    }
}
