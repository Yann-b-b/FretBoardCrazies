import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            Image("bg-welcome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            FloatingBeltsView()

            VStack(spacing: compact ? 12 : 20) {
                Text("FretboardCrazies")
                    .font(.system(size: compact ? 34 : 48, weight: .bold))
                Text("Learn every note on the fretboard, one drill at a time.")
                    .font(compact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Image("flame-small")
                        .resizable()
                        .scaledToFit()
                        .frame(height: compact ? 36 : 48)
                    Button("Get started", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Image("flame-large")
                        .resizable()
                        .scaledToFit()
                        .frame(height: compact ? 44 : 60)
                }
            }
            .padding(compact ? 20 : 40)
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
