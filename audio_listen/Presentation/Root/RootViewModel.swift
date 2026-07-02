import Combine

enum AppRoute: Equatable {
    case welcome
    case main
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute = .welcome

    func enterApp() {
        route = .main
    }
}
