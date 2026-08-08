import Foundation
import Testing
@testable import audio_listen

private func makeStore(_ name: String) -> (InputModeStore, UserDefaults) {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (InputModeStore(defaults: defaults), defaults)
}

struct RootViewModelTests {
    @Test @MainActor func startsOnWelcome() {
        let (store, _) = makeStore("RootViewModelTests.start")
        #expect(RootViewModel(inputModeStore: store).route == .welcome)
    }

    @Test @MainActor func enteringToPlayAnInstrumentRoutesToMainWithoutTouchMode() {
        let (store, defaults) = makeStore("RootViewModelTests.instrument")
        defaults.set(true, forKey: GameSettingsKeys.touchMode)
        let viewModel = RootViewModel(inputModeStore: store)
        viewModel.enterApp(using: .instrument)
        #expect(viewModel.route == .main)
        #expect(!defaults.bool(forKey: GameSettingsKeys.touchMode))
    }

    @Test @MainActor func enteringToTapRoutesToMainWithTouchMode() {
        let (store, defaults) = makeStore("RootViewModelTests.tapping")
        let viewModel = RootViewModel(inputModeStore: store)
        viewModel.enterApp(using: .tapping)
        #expect(viewModel.route == .main)
        #expect(defaults.bool(forKey: GameSettingsKeys.touchMode))
    }
}
