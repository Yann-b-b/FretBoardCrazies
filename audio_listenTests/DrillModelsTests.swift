import Foundation
import Testing
@testable import audio_listen

struct GameSettingsKeysTests {
    @Test func countdownKeyValueIsStable() {
        #expect(GameSettingsKeys.countdownEnabled == "countdownEnabled")
    }
}
