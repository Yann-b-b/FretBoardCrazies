//
//  audio_listenTests.swift
//  audio_listenTests
//

import Combine
import Foundation
import Testing
@testable import audio_listen

// MARK: - GameSessionConfiguration

struct GameSessionConfigurationTests {
    @Test func defaultAllStringsIsValid() {
        let c = GameSessionConfiguration.defaultAllStrings()
        #expect(c.isValid)
        #expect(c.allowedStrings == Set(1...6))
        #expect(c.showStringAndFret)
    }

    @Test func validatedAcceptsSingleString() throws {
        let c = GameSessionConfiguration(showStringAndFret: false, allowedStrings: Set([3]))
        _ = try c.validated()
    }

    @Test func emptyAllowedStringsInvalid() {
        let c = GameSessionConfiguration(allowedStrings: Set())
        #expect(!c.isValid)
        #expect(throws: GameSessionConfiguration.ValidationError.self) {
            try c.validated()
        }
    }

    @Test func outOfRangeStringInvalid() {
        let c = GameSessionConfiguration(allowedStrings: Set([1, 7]))
        #expect(!c.isValid)
        do {
            _ = try c.validated()
            Issue.record("Expected validation to throw")
        } catch let e as GameSessionConfiguration.ValidationError {
            #expect(e == .stringOutOfRange(7))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func codableRoundTrip() throws {
        let original = try GameSessionConfiguration(showStringAndFret: false, allowedStrings: Set([1, 4])).validated()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GameSessionConfiguration.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - GameTargetPrompt

struct GameTargetPromptTests {
    @Test func playingLineUsesLetterAndStringNumber() {
        let line = GameTargetPrompt.playingLine(note: Note(.cSharp, octave: 4), string: 2)
        #expect(line == "C# string 2")
    }

    @Test func playingLineOmitsOctave() {
        let line = GameTargetPrompt.playingLine(note: Note(.a, octave: 2), string: 6)
        #expect(line == "A string 6")
        #expect(!line.contains("2"))
    }

    @Test func playingLineWithOpenStringAppendsOpen() {
        let line = GameTargetPrompt.playingLine(
            note: Note(.e, octave: 2),
            position: FretPosition(string: 6, fret: 0)
        )
        #expect(line == "E string 6 open")
    }

    @Test func playingLineWithFrettedNoteNoOpenSuffix() {
        let line = GameTargetPrompt.playingLine(
            note: Note(.g, octave: 3),
            position: FretPosition(string: 3, fret: 0)
        )
        #expect(line == "G string 3 open")
        let fretted = GameTargetPrompt.playingLine(
            note: Note(.a, octave: 3),
            position: FretPosition(string: 4, fret: 7)
        )
        #expect(fretted == "A string 4")
    }
}

// MARK: - WrongAttemptCounter

struct WrongAttemptCounterTests {
    @Test func countsDistinctWrongNotesOnceEach() {
        var c = WrongAttemptCounter()
        let target = Note(.c, octave: 4)
        c.registerDetection(target: target, detected: Note(.d, octave: 4))
        #expect(c.wrongAttemptsBeforeSuccess == 1)
        c.registerDetection(target: target, detected: Note(.d, octave: 4))
        #expect(c.wrongAttemptsBeforeSuccess == 1)
        c.registerDetection(target: target, detected: Note(.e, octave: 4))
        #expect(c.wrongAttemptsBeforeSuccess == 2)
    }

    @Test func ignoresCorrectDetection() {
        var c = WrongAttemptCounter()
        let target = Note(.g, octave: 3)
        c.registerDetection(target: target, detected: target)
        #expect(c.wrongAttemptsBeforeSuccess == 0)
    }

    @Test func resetClears() {
        var c = WrongAttemptCounter()
        c.registerDetection(target: Note(.a, octave: 4), detected: Note(.b, octave: 4))
        c.reset()
        #expect(c.wrongAttemptsBeforeSuccess == 0)
    }
}

// MARK: - NoteMetrics

struct NoteMetricsTests {
    @Test func emptyRoundsYieldsEmptyAverages() {
        #expect(NoteMetrics.averageWrongAttemptsPerTargetNote(rounds: []).isEmpty)
    }

    @Test func averagesWrongAttemptsPerTargetNote() {
        let n1 = Note(.c, octave: 4)
        let n2 = Note(.d, octave: 4)
        let rounds = [
            GameRound(targetNote: n1, targetPosition: FretPosition(string: 2, fret: 1), reactionTime: 1, playedAt: Date(), wrongAttemptsBeforeSuccess: 2),
            GameRound(targetNote: n1, targetPosition: FretPosition(string: 3, fret: 0), reactionTime: 1, playedAt: Date(), wrongAttemptsBeforeSuccess: 4),
            GameRound(targetNote: n2, targetPosition: FretPosition(string: 3, fret: 2), reactionTime: 1, playedAt: Date(), wrongAttemptsBeforeSuccess: 1)
        ]
        let avg = NoteMetrics.averageWrongAttemptsPerTargetNote(rounds: rounds)
        #expect(avg[n1] == 3.0)
        #expect(avg[n2] == 1.0)
    }
}

// MARK: - PersistedGameRound / playedAt migration

struct PersistedGameRoundTests {
    @Test func legacyJsonWithoutPlayedAtMapsToDistantPast() throws {
        let json = """
        [{"targetNoteNameRawValue":4,"targetNoteOctave":4,"targetString":1,"targetFret":0,"reactionTime":1.2}]
        """
        let decoded = try JSONDecoder().decode([PersistedGameRound].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        let round = decoded[0].toGameRound()
        #expect(round.playedAt == .distantPast)
        #expect(round.targetNote == Note(.e, octave: 4))
        #expect(round.reactionTime == 1.2)
        #expect(round.wrongAttemptsBeforeSuccess == 0)
    }

    @Test func roundTripPreservesPlayedAt() throws {
        let playedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let round = GameRound(
            targetNote: Note(.a, octave: 3),
            targetPosition: FretPosition(string: 5, fret: 2),
            reactionTime: 0.42,
            playedAt: playedAt
        )
        let data = try JSONEncoder().encode([PersistedGameRound(from: round)])
        let back = try JSONDecoder().decode([PersistedGameRound].self, from: data)
        let restored = back[0].toGameRound()
        #expect(restored.playedAt.timeIntervalSince1970 == playedAt.timeIntervalSince1970)
        #expect(restored.targetNote == round.targetNote)
        #expect(restored.targetPosition == round.targetPosition)
        #expect(restored.reactionTime == round.reactionTime)
        #expect(restored.wrongAttemptsBeforeSuccess == 0)
    }

    @Test func roundTripPreservesWrongAttempts() throws {
        let round = GameRound(
            targetNote: Note(.c, octave: 4),
            targetPosition: FretPosition(string: 2, fret: 1),
            reactionTime: 1.0,
            playedAt: Date(),
            wrongAttemptsBeforeSuccess: 4
        )
        let data = try JSONEncoder().encode([PersistedGameRound(from: round)])
        let back = try JSONDecoder().decode([PersistedGameRound].self, from: data)
        #expect(back[0].toGameRound().wrongAttemptsBeforeSuccess == 4)
    }
}

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

// MARK: - FretPositionSelection

struct FretPositionSelectionTests {
    @Test func prefersLowestFret() {
        let positions = [
            FretPosition(string: 6, fret: 15),
            FretPosition(string: 3, fret: 0),
            FretPosition(string: 4, fret: 5)
        ]
        let chosen = FretPositionSelection.preferredForPractice(positions)
        #expect(chosen == FretPosition(string: 3, fret: 0))
    }

    @Test func tieBreaksToLowerStringNumber() {
        let positions = [
            FretPosition(string: 5, fret: 3),
            FretPosition(string: 2, fret: 3)
        ]
        let chosen = FretPositionSelection.preferredForPractice(positions)
        #expect(chosen == FretPosition(string: 2, fret: 3))
    }

    @Test func emptyReturnsNil() {
        #expect(FretPositionSelection.preferredForPractice([]) == nil)
    }
}

// MARK: - UserDefaultsMaxFretProvider

struct UserDefaultsMaxFretProviderTests {
    @Test func missingKeyMeansCap11() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let provider = UserDefaultsMaxFretProvider(defaults: defaults)
        #expect(provider.maxFretInclusive == GameTargetFretBounds.limitedMaxFretInclusive)
    }

    @Test func explicitFalseMeansFullFretboard() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(false, forKey: GameSettingsKeys.limitFretsToTwelve)
        let provider = UserDefaultsMaxFretProvider(defaults: defaults)
        #expect(provider.maxFretInclusive == GuitarFretboard.fretCount)
    }

    @Test func explicitTrueMeansCap11() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: GameSettingsKeys.limitFretsToTwelve)
        let provider = UserDefaultsMaxFretProvider(defaults: defaults)
        #expect(provider.maxFretInclusive == GameTargetFretBounds.limitedMaxFretInclusive)
    }
}

// MARK: - RandomNoteStrategy.filterPositions

struct RandomNoteStrategyFilterTests {
    @Test func filterKeepsOnlyAllowedStrings() {
        let positions = [
            FretPosition(string: 1, fret: 0),
            FretPosition(string: 3, fret: 2),
            FretPosition(string: 6, fret: 0)
        ]
        let allowed: Set<Int> = [1, 6]
        let out = RandomNoteStrategy.filterPositions(positions, allowed: allowed)
        #expect(out.count == 2)
        #expect(out.contains(FretPosition(string: 1, fret: 0)))
        #expect(out.contains(FretPosition(string: 6, fret: 0)))
    }

    @Test func filterEmptyAllowedYieldsEmpty() {
        let positions = [FretPosition(string: 2, fret: 0)]
        let out = RandomNoteStrategy.filterPositions(positions, allowed: [])
        #expect(out.isEmpty)
    }
}

// MARK: - GameAllowedStringsStore

struct GameAllowedStringsStoreTests {
    @Test func roundTripPersistsSubset() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        let original: Set<Int> = [1, 4, 6]
        store.save(original)
        let loaded = store.load()
        #expect(loaded == original)
    }

    @Test func missingKeyDefaultsToAllStrings() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load() == Set(1...6))
    }

    @Test func emptyArrayRoundTripIsEmpty() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([Int]()), forKey: GameAllowedStringsStore.userDefaultsKey)
        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load().isEmpty)
    }

    @Test func onlyOutOfRangeValuesFallsBackToAll() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([0, 7, 99]), forKey: GameAllowedStringsStore.userDefaultsKey)
        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load() == Set(1...6))
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

    @Test func maxFret11ExcludesFret12() {
        let target = Note(.e, octave: 3)
        let at12 = GuitarFretboard.positions(for: target, maxFretInclusive: 12)
        let at11 = GuitarFretboard.positions(for: target, maxFretInclusive: 11)
        #expect(at12.contains(where: { $0.fret == 12 }))
        #expect(!at11.contains(where: { $0.fret == 12 }))
        #expect(at11.count < at12.count)
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
