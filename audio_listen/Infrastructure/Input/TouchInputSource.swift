import Combine

final class TouchInputSource: NoteInputSource {
    private let subject = PassthroughSubject<Note, Never>()

    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }

    func start() throws {}
    func stop() {}

    func submit(_ position: FretPosition) {
        if let note = GuitarFretboard.note(at: position.string, fret: position.fret) {
            subject.send(note)
        }
    }
}
