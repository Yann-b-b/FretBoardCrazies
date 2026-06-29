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
    let drillProgressRepository: DrillProgressRepositoryProtocol
    let dailyGoalStore = DailyGoalStore()

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
        drillProgressRepository = UserDefaultsDrillProgressRepository()

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
    func makeDrillViewModel() -> DrillViewModel {
        let adapter = AudioKitPitchAdapter()
        let detector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        let strings = allowedStringsProvider
        let names = allowedNoteNamesProvider
        let maxFret = maxFretProvider
        return DrillViewModel(
            pitchDetector: detector,
            selectNextPrompt: SelectNextPromptUseCase(),
            updateStats: UpdateItemStatsUseCase(),
            validateNote: ValidateNoteUseCase(),
            stateMachine: DrillStateMachine(),
            progressRepository: drillProgressRepository,
            dailyGoalStore: dailyGoalStore,
            clock: SystemClock(),
            scheduler: TimerDrillScheduler(),
            allowedStrings: { strings.allowedStrings },
            allowedNoteNames: { names.allowedNoteNames },
            maxFretInclusive: { maxFret.maxFretInclusive },
            countdownEnabled: UserDefaults.standard.bool(forKey: GameSettingsKeys.countdownEnabled),
            randomUnit: { Double.random(in: 0..<1) }
        )
    }
}
