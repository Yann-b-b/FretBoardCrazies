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
        #expect(provider.maxFretInclusive == Instruments.guitar.fretCount)
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

// MARK: - GameAllowedStringsStore (per instrument)

struct PerInstrumentAllowedStringsStoreTests {
    private let guitar = Instruments.guitar
    private let bass = Instrument(
        id: "bass",
        name: "Bass",
        strings: [
            Note(.g, octave: 2), Note(.d, octave: 2),
            Note(.a, octave: 1), Note(.e, octave: 1)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 24
    )

    @Test func roundTripPersistsSubsetForInstrument() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        let original: Set<Int> = [1, 4, 6]
        store.save(original, for: guitar)
        #expect(store.load(for: guitar) == original)
    }

    @Test func keysAreIndependentAcrossInstruments() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        store.save([6, 5], for: guitar)
        store.save([4], for: bass)
        #expect(store.load(for: guitar) == Set([6, 5]))
        #expect(store.load(for: bass) == Set([4]))
    }

    @Test func missingKeyDefaultsToInstrumentDefaultChoice() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load(for: guitar) == guitar.defaultStringChoice.strings)
        #expect(store.load(for: bass) == bass.defaultStringChoice.strings)
    }

    @Test func outOfRangeValuesClampToInstrumentRange() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        defaults.set(try JSONEncoder().encode([3, 5, 6]), forKey: GameAllowedStringsStore.userDefaultsKey(for: bass))
        #expect(store.load(for: bass) == Set([3]))
    }

    @Test func onlyOutOfRangeValuesFallBackToDefault() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        defaults.set(try JSONEncoder().encode([7, 8, 99]), forKey: GameAllowedStringsStore.userDefaultsKey(for: bass))
        #expect(store.load(for: bass) == bass.defaultStringChoice.strings)
    }

    @Test func storedEmptyArrayLoadsAsEmptySet() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([Int]()), forKey: GameAllowedStringsStore.userDefaultsKey(for: guitar))
        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load(for: guitar).isEmpty)
    }
}

// MARK: - GameAllowedNoteNamesStore

struct GameAllowedNoteNamesStoreTests {
    @Test func roundTripPersistsSubset() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedNoteNamesStore(defaults: defaults)
        let original: Set<NoteName> = [.c, .fSharp, .b]
        store.save(original)
        let loaded = store.load()
        #expect(loaded == original)
    }

    @Test func missingKeyDefaultsToAllNoteNames() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedNoteNamesStore(defaults: defaults)
        #expect(store.load() == Set(NoteName.allCases))
    }

    @Test func emptyArrayRoundTripIsEmpty() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([Int]()), forKey: GameAllowedNoteNamesStore.userDefaultsKey)
        let store = GameAllowedNoteNamesStore(defaults: defaults)
        #expect(store.load().isEmpty)
    }

    @Test func onlyOutOfRangeValuesFallsBackToAll() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([99, 100]), forKey: GameAllowedNoteNamesStore.userDefaultsKey)
        let store = GameAllowedNoteNamesStore(defaults: defaults)
        #expect(store.load() == Set(NoteName.allCases))
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
