import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppDependencyContainer.shared.makeRootViewModel()

    var body: some View {
        switch viewModel.route {
        case .welcome:
            WelcomeView(onStart: { withAnimation(.easeInOut) { viewModel.enterApp() } })
                .transition(.opacity)
        case .main:
            ContentView()
                .transition(.opacity)
        }
    }
}

#Preview {
    RootView()
}
