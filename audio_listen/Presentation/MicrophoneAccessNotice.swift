import SwiftUI

struct MicrophoneAccessNotice: View {
    var body: some View {
        VStack(spacing: 10) {
            Text(MicrophonePermissionCopy.denied)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("Open Settings") { openSystemSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #else
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
        #endif
    }
}
