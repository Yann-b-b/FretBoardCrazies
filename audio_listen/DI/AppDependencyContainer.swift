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
    let dailyHistoryStore = DailyHistoryStore()

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
    }

    @MainActor
    func makeTunerViewModel() -> TunerViewModel {
        let adapter = AudioKitPitchAdapter()
        let detector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
        return TunerViewModel(pitchDetector: detector)
    }

    @MainActor
    func makeDrillViewModel() -> DrillViewModel {
        let strings = allowedStringsProvider
        let names = allowedNoteNamesProvider
        let maxFret = maxFretProvider
        let touchMode = UserDefaults.standard.bool(forKey: GameSettingsKeys.touchMode)

        let input: NoteInputSource
        let touchSubmit: ((FretPosition) -> Void)?
        let nameNoteProbability: Double
        if touchMode {
            let touch = TouchInputSource()
            input = touch
            touchSubmit = { [weak touch] position in touch?.submit(position) }
            nameNoteProbability = 0
        } else {
            let adapter = AudioKitPitchAdapter()
            let detector = DebouncedPitchDetector(wrapping: adapter, stabilityDuration: 0.10)
            input = MicNoteSource(detector: detector)
            touchSubmit = nil
            nameNoteProbability = 0.25
        }

        return DrillViewModel(
            input: input,
            touchSubmit: touchSubmit,
            selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: nameNoteProbability),
            updateStats: UpdateItemStatsUseCase(),
            validateNote: ValidateNoteUseCase(),
            stateMachine: DrillStateMachine(),
            progressRepository: drillProgressRepository,
            dailyHistoryStore: dailyHistoryStore,
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
