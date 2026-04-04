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
    
    private let pitchDetector: PitchDetectorProtocol
    private let noteGenerator: NoteGeneratorProtocol
    private let scoreRepository: ScoreRepositoryProtocol
    
    private init() {
        let adapter = AudioKitPitchAdapter()
        pitchDetector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        noteGenerator = RandomNoteStrategy()
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
        let timeout = UserDefaults.standard.object(forKey: "timeoutSeconds") as? Double ?? 5
        let countdown = UserDefaults.standard.bool(forKey: "countdownEnabled")
        return GameViewModel(
            pitchDetector: pitchDetector,
            generateNoteUseCase: GenerateTargetNoteUseCase(noteGenerator: noteGenerator),
            validateNoteUseCase: ValidateNoteUseCase(),
            stateMachine: GameStateMachine(),
            scoreRepository: scoreRepository,
            timeoutSeconds: timeout,
            countdownEnabled: countdown
        )
    }
}
