import Foundation
import Testing
@testable import audio_listen

private func makeDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

struct InputModeTests {
    @Test func tappingModePersistsAsTouchMode() {
        let defaults = makeDefaults("InputModeTests.tapping")
        InputModeStore(defaults: defaults).save(.tapping)
        #expect(defaults.bool(forKey: GameSettingsKeys.touchMode))
    }

    @Test func instrumentModeClearsTouchMode() {
        let defaults = makeDefaults("InputModeTests.instrument")
        defaults.set(true, forKey: GameSettingsKeys.touchMode)
        InputModeStore(defaults: defaults).save(.instrument)
        #expect(!defaults.bool(forKey: GameSettingsKeys.touchMode))
    }

    @Test func everyModeOffersAWelcomeScreenTitle() {
        for mode in InputMode.allCases {
            #expect(!mode.title.isEmpty)
        }
    }
}
