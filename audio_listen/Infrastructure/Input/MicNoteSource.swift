import Combine

final class MicNoteSource: NoteInputSource {
    private let detector: PitchDetectorProtocol

    init(detector: PitchDetectorProtocol) {
        self.detector = detector
    }

    var notes: AnyPublisher<Note, Never> {
        detector.currentPitch.map { $0.note }.eraseToAnyPublisher()
    }

    func start() throws { try detector.start() }
    func stop() { detector.stop() }
}
