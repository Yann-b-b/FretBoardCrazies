import Combine

enum AppRoute: Equatable {
    case welcome
    case main
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute = .welcome

    private let inputModeStore: InputModeStore

    init(inputModeStore: InputModeStore) {
        self.inputModeStore = inputModeStore
    }

    func enterApp(using mode: InputMode) {
        inputModeStore.save(mode)
        route = .main
    }
}
