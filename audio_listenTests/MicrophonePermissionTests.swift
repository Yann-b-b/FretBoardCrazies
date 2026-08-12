import Testing
@testable import audio_listen

private final class FakeMicrophonePermission: MicrophonePermissionRequesting, @unchecked Sendable {
    private(set) var requestCount = 0
    private var current: MicrophonePermissionStatus
    private let resolvesTo: MicrophonePermissionStatus

    init(status: MicrophonePermissionStatus, resolvesTo: MicrophonePermissionStatus = .denied) {
        self.current = status
        self.resolvesTo = resolvesTo
    }

    var status: MicrophonePermissionStatus { current }

    func request() async -> MicrophonePermissionStatus {
        requestCount += 1
        current = resolvesTo
        return resolvesTo
    }
}

struct MicrophonePermissionTests {
    @Test func grantedStatusSkipsThePrompt() async {
        let permission = FakeMicrophonePermission(status: .granted)
        let resolved = await permission.statusRequestingIfNeeded()
        #expect(resolved == .granted)
        #expect(permission.requestCount == 0)
    }

    @Test func deniedStatusSkipsThePrompt() async {
        let permission = FakeMicrophonePermission(status: .denied)
        let resolved = await permission.statusRequestingIfNeeded()
        #expect(resolved == .denied)
        #expect(permission.requestCount == 0)
    }

    @Test func undeterminedStatusPromptsOnceAndResolvesToGranted() async {
        let permission = FakeMicrophonePermission(status: .undetermined, resolvesTo: .granted)
        let resolved = await permission.statusRequestingIfNeeded()
        #expect(resolved == .granted)
        #expect(permission.requestCount == 1)
    }

    @Test func undeterminedStatusResolvingToDeniedIsReported() async {
        let permission = FakeMicrophonePermission(status: .undetermined, resolvesTo: .denied)
        let resolved = await permission.statusRequestingIfNeeded()
        #expect(resolved == .denied)
        #expect(permission.requestCount == 1)
    }

    @Test func deniedCopyNamesTheAppAndPointsToSettings() {
        #expect(MicrophonePermissionCopy.denied.contains("FretBoardMastery"))
        #expect(MicrophonePermissionCopy.denied.contains("Settings"))
    }
}
