import Combine
import Foundation
import Testing
@testable import audio_listen

struct DrillStateMachineTests {
    let prompt = DrillPrompt(direction: .findPosition, targetNote: Note(.c, octave: 3), string: 5)

    @Test func acceptsValidTransitionAndFiresCallback() {
        let sm = DrillStateMachine()
        var observed: [DrillState] = []
        sm.onStateChange = { observed.append($0) }
        let ok = sm.transition(to: .countdown(remaining: 3, prompt: prompt))
        #expect(ok)
        #expect(sm.state == .countdown(remaining: 3, prompt: prompt))
        #expect(observed.count == 1)
    }

    @Test func rejectsInvalidTransition() {
        let sm = DrillStateMachine()
        let ok = sm.transition(to: .success(reactionTime: 1, prompt: prompt))
        #expect(!ok)
        #expect(sm.state == .idle)
    }
}

private final class StubPitchDetector: PitchDetectorProtocol {
    let subject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> { subject.eraseToAnyPublisher() }
    private(set) var startCalled = false
    func start() throws { startCalled = true }
    func stop() {}
}

@MainActor
private func makeViewModel(
    detector: StubPitchDetector,
    clock: FakeClock,
    scheduler: FakeScheduler,
    countdownEnabled: Bool
) -> (DrillViewModel, DrillProgressRepositoryProtocol) {
    let suite = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
    let vm = DrillViewModel(
        pitchDetector: detector,
        selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: 0.0),
        updateStats: UpdateItemStatsUseCase(),
        validateNote: ValidateNoteUseCase(),
        stateMachine: DrillStateMachine(),
        progressRepository: repo,
        dailyGoalStore: DailyGoalStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)),
        clock: clock,
        scheduler: scheduler,
        allowedStrings: { Set([6]) },
        allowedNoteNames: { [.e] },
        maxFretInclusive: { 11 },
        countdownEnabled: countdownEnabled,
        randomUnit: { 0.0 }
    )
    return (vm, repo)
}

struct DrillViewModelTests {
    @Test @MainActor func startWithoutCountdownEntersPlaying() {
        let detector = StubPitchDetector()
        let (vm, _) = makeViewModel(detector: detector, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        if case .playing(_, let prompt) = vm.state {
            #expect(prompt.string == 6)
            #expect(prompt.targetNote.name == .e)
        } else {
            Issue.record("Expected playing state, got \(vm.state)")
        }
        #expect(detector.startCalled)
    }

    @Test @MainActor func emptyAllowedSetsShowsError() {
        let detector = StubPitchDetector()
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let vm = DrillViewModel(
            pitchDetector: detector,
            selectNextPrompt: SelectNextPromptUseCase(),
            updateStats: UpdateItemStatsUseCase(),
            validateNote: ValidateNoteUseCase(),
            stateMachine: DrillStateMachine(),
            progressRepository: UserDefaultsDrillProgressRepository(defaults: defaults),
            dailyGoalStore: DailyGoalStore(defaults: defaults),
            clock: FakeClock(),
            scheduler: FakeScheduler(),
            allowedStrings: { [] },
            allowedNoteNames: { [.e] },
            maxFretInclusive: { 11 },
            countdownEnabled: false,
            randomUnit: { 0.0 }
        )
        vm.start()
        #expect(vm.errorMessage != nil)
        #expect(vm.state == .idle)
    }

    @Test @MainActor func correctNoteTransitionsToSuccessAndRecordsReaction() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, repo) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 2.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        if case .success(let reaction, _) = vm.state {
            #expect(reaction == 2.0)
        } else {
            Issue.record("Expected success state, got \(vm.state)")
        }
        #expect(vm.todayCount == 1)
        let key = DrillItemKey(noteName: .e, string: 6)
        #expect(repo.loadAll()[key]?.correct == 1)
    }

    @Test @MainActor func countdownTicksThenPlays() {
        let detector = StubPitchDetector()
        let scheduler = FakeScheduler()
        let (vm, _) = makeViewModel(detector: detector, clock: FakeClock(), scheduler: scheduler, countdownEnabled: true)
        vm.start()
        if case .countdown(let r, _) = vm.state { #expect(r == 3) } else { Issue.record("expected countdown") }
        scheduler.fireRepeatingTick()
        scheduler.fireRepeatingTick()
        scheduler.fireRepeatingTick()
        if case .playing = vm.state {} else { Issue.record("expected playing after 3 ticks, got \(vm.state)") }
    }

    @Test @MainActor func skipAppliesMiss() {
        let detector = StubPitchDetector()
        let (vm, repo) = makeViewModel(detector: detector, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        vm.skip()
        let key = DrillItemKey(noteName: .e, string: 6)
        #expect(repo.loadAll()[key]?.attempts == 1)
        #expect(repo.loadAll()[key]?.correct == 0)
    }

    @Test @MainActor func skipDuringCountdownCancelsCountdown() {
        let detector = StubPitchDetector()
        let scheduler = FakeScheduler()
        let (vm, _) = makeViewModel(detector: detector, clock: FakeClock(), scheduler: scheduler, countdownEnabled: true)
        vm.start()
        vm.skip()
        guard case .playing = vm.state else { Issue.record("expected playing after skip from countdown, got \(vm.state)"); return }
        scheduler.fireRepeatingTick()
        guard case .playing = vm.state else { Issue.record("stale countdown tick mutated state after skip"); return }
    }

    @Test @MainActor func skipDuringSuccessDoesNotRecordMiss() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, repo) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        let key = DrillItemKey(noteName: .e, string: 6)
        let beforeAttempts = repo.loadAll()[key]?.attempts ?? 0
        #expect(beforeAttempts == 1)
        vm.skip()
        let afterAttempts = repo.loadAll()[key]?.attempts ?? 0
        #expect(afterAttempts == beforeAttempts)
    }
}
