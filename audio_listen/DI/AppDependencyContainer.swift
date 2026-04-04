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

    private let pitchDetector: PitchDetectorProtocol
    private let noteGenerator: NoteGeneratorProtocol
    private let scoreRepository: ScoreRepositoryProtocol
    private let allowedStringsProvider: AllowedStringsProviding

    private init() {
        allowedStringsStore = GameAllowedStringsStore()
        allowedStringsProvider = UserDefaultsAllowedStringsProvider(store: allowedStringsStore)

        let adapter = AudioKitPitchAdapter()
        pitchDetector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        noteGenerator = RandomNoteStrategy(allowedStringsProvider: allowedStringsProvider)
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
        return GameViewModel(
            pitchDetector: pitchDetector,
            generateNoteUseCase: GenerateTargetNoteUseCase(noteGenerator: noteGenerator),
            validateNoteUseCase: ValidateNoteUseCase(),
            stateMachine: GameStateMachine(),
            scoreRepository: scoreRepository,
            allowedStringsProvider: allowedStringsProvider,
            countdownEnabled: countdown
        )
    }
}
