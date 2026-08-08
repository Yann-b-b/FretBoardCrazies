enum MicrophonePermissionStatus {
    case undetermined
    case granted
    case denied
}

protocol MicrophonePermissionRequesting: Sendable {
    var status: MicrophonePermissionStatus { get }
    func request() async -> MicrophonePermissionStatus
}

extension MicrophonePermissionRequesting {
    func statusRequestingIfNeeded() async -> MicrophonePermissionStatus {
        let current = status
        guard current == .undetermined else { return current }
        return await request()
    }
}

enum MicrophonePermissionCopy {
    static let denied = """
        FretBoard Crazies needs microphone access to hear the notes you play. \
        Turn it on in Settings, then start again.
        """
}
