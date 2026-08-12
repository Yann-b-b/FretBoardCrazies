import AVFoundation

final class SystemMicrophonePermission: MicrophonePermissionRequesting {
    var status: MicrophonePermissionStatus {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .undetermined
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .undetermined
        @unknown default: return .undetermined
        }
        #endif
    }

    func request() async -> MicrophonePermissionStatus {
        #if os(iOS)
        let granted = await AVAudioApplication.requestRecordPermission()
        #else
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        #endif
        return granted ? .granted : .denied
    }
}
