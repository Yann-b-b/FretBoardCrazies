import Combine
import Testing
@testable import audio_listen

private final class StubDetector: PitchDetectorProtocol {
    let subject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> { subject.eraseToAnyPublisher() }
    func start() throws {}
    func stop() {}
}

struct InputSourceTests {
    @Test func micSourceEmitsTheDetectedNote() {
        let detector = StubDetector()
        let source = MicNoteSource(detector: detector)
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        detector.subject.send(DetectedPitch(note: Note(.g, octave: 3), frequency: 196, amplitude: 0.2))
        c.cancel()
        #expect(received == [Note(.g, octave: 3)])
    }

    @Test func touchSourceEmitsNoteAtTappedPosition() {
        let source = TouchInputSource()
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        source.submit(FretPosition(string: 6, fret: 1))
        c.cancel()
        #expect(received == [Note(.f, octave: 2)])
    }

    @Test func touchSourceIgnoresOutOfRangePosition() {
        let source = TouchInputSource()
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        source.submit(FretPosition(string: 9, fret: 0))
        c.cancel()
        #expect(received.isEmpty)
    }
}
