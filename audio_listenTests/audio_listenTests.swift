//
//  audio_listenTests.swift
//  audio_listenTests
//

import Combine
import Foundation
import Testing
@testable import audio_listen

// MARK: - NoteConverter

struct NoteConverterTests {
    @Test func a440MapsToA4() {
        let result = NoteConverter.frequencyToNote(440, amplitude: 0.1, minAmplitude: 0.01)
        guard case .success(let note) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(note.name == .a)
        #expect(note.octave == 4)
    }

    @Test func belowMinAmplitudeFails() {
        let result = NoteConverter.frequencyToNote(440, amplitude: 0.001, minAmplitude: 0.01)
        guard case .failure(let err) = result else {
            Issue.record("Expected failure")
            return
        }
        #expect(err == .belowThreshold)
    }

    @Test func lowOpenELikeFrequency() {
        let result = NoteConverter.frequencyToNote(82.41, amplitude: 0.05, minAmplitude: 0.01)
        guard case .success(let note) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(note.name == .e)
        #expect(note.octave == 2)
    }
}

// MARK: - GuitarFretboard

struct GuitarFretboardTests {
    @Test func openLowEIsE2() {
        let note = GuitarFretboard.note(at: 6, fret: 0)
        #expect(note?.name == .e)
        #expect(note?.octave == 2)
    }

    @Test func positionsRoundTrip() {
        let target = Note(.g, octave: 3)
        let positions = GuitarFretboard.positions(for: target)
        for pos in positions {
            let n = GuitarFretboard.note(at: pos.string, fret: pos.fret)
            #expect(n == target)
        }
    }

    @Test func maxFret12ExcludesHighFretPositions() {
        let target = Note(.e, octave: 5)
        let allPos = GuitarFretboard.positions(for: target, maxFretInclusive: 24)
        let capped = GuitarFretboard.positions(for: target, maxFretInclusive: 12)
        #expect(!allPos.isEmpty)
        #expect(!capped.isEmpty)
        #expect(capped.allSatisfy { $0.fret <= 12 })
        if allPos.contains(where: { $0.fret > 12 }) {
            #expect(capped.count < allPos.count)
        }
    }
}

// MARK: - ValidateNoteUseCase

struct ValidateNoteUseCaseTests {
    @Test func matchesWhenEqual() {
        let uc = ValidateNoteUseCase()
        let n = Note(.c, octave: 4)
        #expect(uc.execute(detected: n, target: n))
    }

    @Test func rejectsDifferentOctave() {
        let uc = ValidateNoteUseCase()
        #expect(!uc.execute(detected: Note(.c, octave: 3), target: Note(.c, octave: 4)))
    }
}

// MARK: - DebouncedPitchDetector

private final class MockPitchDetector: PitchDetectorProtocol {
    let subject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> { subject.eraseToAnyPublisher() }

    func start() throws {}
    func stop() {}
}

struct DebouncedPitchDetectorTests {
    @Test @MainActor
    func emitsAfterStableSameNote() async throws {
        let mock = MockPitchDetector()
        let debounced = DebouncedPitchDetector(wrapping: mock, stabilityDuration: 0.05, scheduler: .main)
        var received: [Note] = []
        var cancellables = Set<AnyCancellable>()
        debounced.currentPitch
            .sink { received.append($0.note) }
            .store(in: &cancellables)

        try debounced.start()
        let n = Note(.a, octave: 4)
        mock.subject.send(DetectedPitch(note: n, frequency: 440, amplitude: 0.1))
        try await Task.sleep(for: .milliseconds(60))
        mock.subject.send(DetectedPitch(note: n, frequency: 440, amplitude: 0.1))
        try await Task.sleep(for: .milliseconds(50))
        debounced.stop()
        #expect(received.count == 1)
        #expect(received[0] == n)
    }
}
