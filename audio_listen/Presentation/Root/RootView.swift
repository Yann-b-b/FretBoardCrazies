import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppDependencyContainer.shared.makeRootViewModel()

    var body: some View {
        switch viewModel.route {
        case .welcome:
            WelcomeView(onStart: { mode in
                withAnimation(.easeInOut) { viewModel.enterApp(using: mode) }
            })
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
