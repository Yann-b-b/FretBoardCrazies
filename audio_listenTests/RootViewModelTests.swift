import Testing
@testable import audio_listen

struct RootViewModelTests {
    @Test @MainActor func startsOnWelcome() {
        let viewModel = RootViewModel()
        #expect(viewModel.route == .welcome)
    }

    @Test @MainActor func enterAppTransitionsToMain() {
        let viewModel = RootViewModel()
        viewModel.enterApp()
        #expect(viewModel.route == .main)
    }
}
