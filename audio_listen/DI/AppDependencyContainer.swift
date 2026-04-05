//
//  AppDependencyContainer.swift
//  audio_listen
//
//  Assembles dependencies for the app (Factory / DI).
//

import Foundation

/// Container that creates and holds app dependencies.
final class AppDependencyContainer {
    static let shared = AppDependencyContainer()

    let allowedStringsStore: GameAllowedStringsStore
    let allowedNoteNamesStore: GameAllowedNoteNamesStore

    private let pitchDetector: PitchDetectorProtocol
    private let noteGenerator: NoteGeneratorProtocol
    private let noteNamePositionGenerator: NoteGeneratorProtocol
    private let scoreRepository: ScoreRepositoryProtocol
    private let allowedStringsProvider: AllowedStringsProviding
    private let allowedNoteNamesProvider: AllowedNoteNamesProviding
    private let maxFretProvider: MaxFretProviding

    private init() {
        allowedStringsStore = GameAllowedStringsStore()
        allowedNoteNamesStore = GameAllowedNoteNamesStore()
        allowedStringsProvider = UserDefaultsAllowedStringsProvider(store: allowedStringsStore)
        allowedNoteNamesProvider = UserDefaultsAllowedNoteNamesProvider(store: allowedNoteNamesStore)
        maxFretProvider = UserDefaultsMaxFretProvider()

        let adapter = AudioKitPitchAdapter()
        pitchDetector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        noteGenerator = RandomNoteStrategy(
            allowedStringsProvider: allowedStringsProvider,
            maxFretProvider: maxFretProvider
        )
        noteNamePositionGenerator = RandomNoteNamePositionStrategy(
            allowedNoteNamesProvider: allowedNoteNamesProvider,
            maxFretProvider: maxFretProvider
        )
        scoreRepository = UserDefaultsScoreRepository()
    }

    @MainActor
    func makeTunerViewModel() -> TunerViewModel {
        let adapter = AudioKitPitchAdapter()
        let detector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        return TunerViewModel(pitchDetector: detector)
    }
    
    @MainActor
    func makeGameViewModel() -> GameViewModel {
        let countdown = UserDefaults.standard.bool(forKey: "countdownEnabled")
        let stringsProvider = allowedStringsProvider
        return GameViewModel(
            pitchDetector: pitchDetector,
            generateNoteUseCase: GenerateTargetNoteUseCase(noteGenerator: noteGenerator),
            validateNoteUseCase: ValidateNoteUseCase(),
            stateMachine: GameStateMachine(),
            scoreRepository: scoreRepository,
            startGate: {
                stringsProvider.allowedStrings.isEmpty
                    ? "Select at least one string to practice."
                    : nil
            },
            countdownEnabled: countdown
        )
    }

    @MainActor
    func makeNoteNameGameViewModel() -> GameViewModel {
        let countdown = UserDefaults.standard.bool(forKey: "countdownEnabled")
        let namesProvider = allowedNoteNamesProvider
        return GameViewModel(
            pitchDetector: pitchDetector,
            generateNoteUseCase: GenerateTargetNoteUseCase(noteGenerator: noteNamePositionGenerator),
            validateNoteUseCase: ValidateNoteUseCase(),
            stateMachine: GameStateMachine(),
            scoreRepository: scoreRepository,
            startGate: {
                namesProvider.allowedNoteNames.isEmpty
                    ? "Select at least one note name to practice."
                    : nil
            },
            countdownEnabled: countdown
        )
    }
}
