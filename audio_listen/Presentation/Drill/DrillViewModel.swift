import Combine
import Foundation

@MainActor
final class DrillViewModel: ObservableObject {
    @Published private(set) var state: DrillState = .idle
    @Published private(set) var detectedNote: String = "—"
    @Published private(set) var todayCount: Int = 0
    @Published var errorMessage: String?

    private let pitchDetector: PitchDetectorProtocol
    private let selectNextPrompt: SelectNextPromptUseCase
    private let updateStats: UpdateItemStatsUseCase
    private let validateNote: ValidateNoteUseCase
    private let stateMachine: DrillStateMachine
    private let progressRepository: DrillProgressRepositoryProtocol
    private let dailyHistoryStore: DailyHistoryStore
    private let clock: Clock
    private let scheduler: DrillScheduler
    private let allowedStrings: () -> Set<Int>
    private let allowedNoteNames: () -> Set<NoteName>
    private let maxFretInclusive: () -> Int
    private let countdownEnabled: Bool
    private let randomUnit: () -> Double

    private var pitchSubscription: AnyCancellable?
    private var countdownToken: AnyCancellable?
    private var autoAdvanceToken: AnyCancellable?
    private var engineStarted = false
    private var countdownRemaining = 0

    init(
        pitchDetector: PitchDetectorProtocol,
        selectNextPrompt: SelectNextPromptUseCase,
        updateStats: UpdateItemStatsUseCase,
        validateNote: ValidateNoteUseCase,
        stateMachine: DrillStateMachine,
        progressRepository: DrillProgressRepositoryProtocol,
        dailyHistoryStore: DailyHistoryStore,
        clock: Clock,
        scheduler: DrillScheduler,
        allowedStrings: @escaping () -> Set<Int>,
        allowedNoteNames: @escaping () -> Set<NoteName>,
        maxFretInclusive: @escaping () -> Int,
        countdownEnabled: Bool,
        randomUnit: @escaping () -> Double
    ) {
        self.pitchDetector = pitchDetector
        self.selectNextPrompt = selectNextPrompt
        self.updateStats = updateStats
        self.validateNote = validateNote
        self.stateMachine = stateMachine
        self.progressRepository = progressRepository
        self.dailyHistoryStore = dailyHistoryStore
        self.clock = clock
        self.scheduler = scheduler
        self.allowedStrings = allowedStrings
        self.allowedNoteNames = allowedNoteNames
        self.maxFretInclusive = maxFretInclusive
        self.countdownEnabled = countdownEnabled
        self.randomUnit = randomUnit
        self.todayCount = dailyHistoryStore.todayReps(now: clock.now())

        stateMachine.onStateChange = { [weak self] newState in
            self?.state = newState
        }
    }

    func start() {
        countdownToken = nil
        autoAdvanceToken = nil
        errorMessage = nil
        guard let prompt = nextPrompt() else {
            errorMessage = "Select at least one string and note to practice."
            return
        }
        if countdownEnabled {
            beginCountdown(prompt: prompt)
        } else {
            beginPlaying(prompt: prompt)
        }
    }

    func stop() {
        countdownToken = nil
        autoAdvanceToken = nil
        stopListening()
        stateMachine.transition(to: .idle)
        detectedNote = "—"
    }

    func skip() {
        if case .playing(_, let prompt) = state {
            recordMiss(for: prompt)
        }
        advance()
    }

    private func nextPrompt() -> DrillPrompt? {
        selectNextPrompt.next(
            allowedStrings: allowedStrings(),
            allowedNoteNames: allowedNoteNames(),
            maxFretInclusive: maxFretInclusive(),
            stats: progressRepository.loadAll(),
            now: clock.now(),
            randomUnit: randomUnit
        )
    }

    private func beginCountdown(prompt: DrillPrompt) {
        countdownRemaining = 3
        stateMachine.transition(to: .countdown(remaining: countdownRemaining, prompt: prompt))
        countdownToken = scheduler.scheduleRepeating(every: 1) { [weak self] in
            guard let self else { return }
            self.countdownRemaining -= 1
            if self.countdownRemaining > 0 {
                self.stateMachine.transition(to: .countdown(remaining: self.countdownRemaining, prompt: prompt))
            } else {
                self.countdownToken = nil
                self.beginPlaying(prompt: prompt)
            }
        }
    }

    private func beginPlaying(prompt: DrillPrompt) {
        stateMachine.transition(to: .playing(startTime: clock.now(), prompt: prompt))
        startListening()
    }

    private func advance() {
        countdownToken = nil
        autoAdvanceToken = nil
        guard let prompt = nextPrompt() else {
            stop()
            return
        }
        stateMachine.transition(to: .playing(startTime: clock.now(), prompt: prompt))
        startListening()
    }

    private func startListening() {
        detectedNote = "—"
        do {
            if !engineStarted {
                try pitchDetector.start()
                engineStarted = true
            }
            pitchSubscription = pitchDetector.currentPitch
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pitch in self?.handle(pitch) }
        } catch {
            errorMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }

    private func stopListening() {
        pitchSubscription?.cancel()
        pitchSubscription = nil
    }

    private func handle(_ pitch: DetectedPitch) {
        detectedNote = pitch.note.displayName
        guard case .playing(let startTime, let prompt) = state else { return }
        guard validateNote.execute(detected: pitch.note, target: prompt.targetNote) else { return }
        stopListening()
        let reaction = clock.now().timeIntervalSince(startTime)
        recordCorrect(for: prompt, reactionTime: reaction)
        stateMachine.transition(to: .success(reactionTime: reaction, prompt: prompt))
        autoAdvanceToken = scheduler.scheduleAfter(1.0) { [weak self] in self?.advance() }
    }

    private func recordCorrect(for prompt: DrillPrompt, reactionTime: TimeInterval) {
        var all = progressRepository.loadAll()
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyCorrect(to: current, reactionTime: reactionTime, now: clock.now())
        progressRepository.save(all)
        let mastered = all.values.filter { $0.box >= DrillTuning.maxBox }.count
        todayCount = dailyHistoryStore.recordCorrect(now: clock.now(), reactionTime: reactionTime, masteredCount: mastered)
    }

    private func recordMiss(for prompt: DrillPrompt) {
        var all = progressRepository.loadAll()
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyMiss(to: current, now: clock.now())
        progressRepository.save(all)
    }
}
