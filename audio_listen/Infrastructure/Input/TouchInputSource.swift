import AVFoundation
import Combine

final class TouchInputSource: NoteInputSource {
    private let subject = PassthroughSubject<Note, Never>()
    private let instrument: Instrument

    init(instrument: Instrument = Instruments.guitar) {
        self.instrument = instrument
    }

    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }

    func start() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.ambient)
        #endif
    }
    func stop() {}

    func submit(_ position: FretPosition) {
        if let note = instrument.note(at: position.string, fret: position.fret) {
            subject.send(note)
        }
    }
}
