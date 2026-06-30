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

private final class StubNoteInputSource: NoteInputSource {
    let subject = PassthroughSubject<Note, Never>()
    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }
    private(set) var startCalled = false
    func start() throws { startCalled = true }
    func stop() {}
}

@MainActor
private func makeViewModel(
    source: StubNoteInputSource,
    clock: FakeClock,
    scheduler: FakeScheduler,
    countdownEnabled: Bool
) -> (DrillViewModel, DrillProgressRepositoryProtocol) {
    let suite = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
    let vm = DrillViewModel(
        input: source,
        selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: 0.0),
        updateStats: UpdateItemStatsUseCase(),
        validateNote: ValidateNoteUseCase(),
        stateMachine: DrillStateMachine(),
        progressRepository: repo,
        dailyHistoryStore: DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)),
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
        let source = StubNoteInputSource()
        let (vm, _) = makeViewModel(source: source, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        if case .playing(_, let prompt) = vm.state {
            #expect(prompt.string == 6)
            #expect(prompt.targetNote.name == .e)
        } else {
            Issue.record("Expected playing state, got \(vm.state)")
        }
        #expect(source.startCalled)
    }

    @Test @MainActor func emptyAllowedSetsShowsError() {
        let source = StubNoteInputSource()
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let vm = DrillViewModel(
            input: source,
            selectNextPrompt: SelectNextPromptUseCase(),
            updateStats: UpdateItemStatsUseCase(),
            validateNote: ValidateNoteUseCase(),
            stateMachine: DrillStateMachine(),
            progressRepository: UserDefaultsDrillProgressRepository(defaults: defaults),
            dailyHistoryStore: DailyHistoryStore(defaults: defaults),
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
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, repo) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 2.0)
        source.subject.send(Note(.e, octave: 2))
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
        let source = StubNoteInputSource()
        let scheduler = FakeScheduler()
        let (vm, _) = makeViewModel(source: source, clock: FakeClock(), scheduler: scheduler, countdownEnabled: true)
        vm.start()
        if case .countdown(let r, _) = vm.state { #expect(r == 3) } else { Issue.record("expected countdown") }
        scheduler.fireRepeatingTick()
        scheduler.fireRepeatingTick()
        scheduler.fireRepeatingTick()
        if case .playing = vm.state {} else { Issue.record("expected playing after 3 ticks, got \(vm.state)") }
    }

    @Test @MainActor func skipAppliesMiss() {
        let source = StubNoteInputSource()
        let (vm, repo) = makeViewModel(source: source, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        vm.skip()
        let key = DrillItemKey(noteName: .e, string: 6)
        #expect(repo.loadAll()[key]?.attempts == 1)
        #expect(repo.loadAll()[key]?.correct == 0)
    }

    @Test @MainActor func skipDuringCountdownCancelsCountdown() {
        let source = StubNoteInputSource()
        let scheduler = FakeScheduler()
        let (vm, _) = makeViewModel(source: source, clock: FakeClock(), scheduler: scheduler, countdownEnabled: true)
        vm.start()
        vm.skip()
        guard case .playing = vm.state else { Issue.record("expected playing after skip from countdown, got \(vm.state)"); return }
        scheduler.fireRepeatingTick()
        guard case .playing = vm.state else { Issue.record("stale countdown tick mutated state after skip"); return }
    }

    @Test @MainActor func skipDuringSuccessDoesNotRecordMiss() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, repo) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        let key = DrillItemKey(noteName: .e, string: 6)
        let beforeAttempts = repo.loadAll()[key]?.attempts ?? 0
        #expect(beforeAttempts == 1)
        vm.skip()
        let afterAttempts = repo.loadAll()[key]?.attempts ?? 0
        #expect(afterAttempts == beforeAttempts)
    }

    @Test @MainActor func manualStartDuringSuccessCancelsStaleAutoAdvance() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let scheduler = FakeScheduler()
        let (vm, _) = makeViewModel(source: source, clock: clock, scheduler: scheduler, countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        vm.start()
        guard case .playing = vm.state else { Issue.record("expected playing after manual start, got \(vm.state)"); return }
        scheduler.firePendingAfter()
        guard case .playing = vm.state else { Issue.record("stale auto-advance fired after manual start"); return }
    }

    @Test @MainActor func correctAnswerRecordsDailyHistory() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let history = DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
        let vm = DrillViewModel(
            input: source,
            selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: 0.0),
            updateStats: UpdateItemStatsUseCase(),
            validateNote: ValidateNoteUseCase(),
            stateMachine: DrillStateMachine(),
            progressRepository: UserDefaultsDrillProgressRepository(defaults: defaults),
            dailyHistoryStore: history,
            clock: clock,
            scheduler: FakeScheduler(),
            allowedStrings: { Set([6]) },
            allowedNoteNames: { [.e] },
            maxFretInclusive: { 11 },
            countdownEnabled: false,
            randomUnit: { 0.0 }
        )
        vm.start()
        clock.advance(by: 1.5)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.todayCount == 1)
        #expect(history.todayReps(now: clock.now()) == 1)
    }

    @Test @MainActor func comboIncrementsOnFastCorrect() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
    }

    @Test @MainActor func comboResetsOnSlowCorrect() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
        vm.start()
        clock.advance(by: 5.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 0)
    }

    @Test @MainActor func comboResetsOnSkip() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
        vm.skip()
        #expect(vm.comboCount == 0)
    }

    @Test @MainActor func beltRankStartsWhite() {
        let source = StubNoteInputSource()
        let (vm, _) = makeViewModel(source: source, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        #expect(vm.beltRank.belt == .white)
        #expect(vm.beltRank.fraction == 0)
    }

    @Test @MainActor func wrongNoteSetsLastWrongPositionOnPromptString() async {
        let source = StubNoteInputSource()
        let (vm, _) = makeViewModel(source: source, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        source.subject.send(Note(.f, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.lastWrongPosition == FretPosition(string: 6, fret: 1))
        if case .playing = vm.state {} else { Issue.record("should stay playing after a wrong answer") }
    }

    @Test @MainActor func correctNoteClearsLastWrongPosition() async {
        let source = StubNoteInputSource()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(source: source, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        source.subject.send(Note(.f, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.lastWrongPosition != nil)
        clock.advance(by: 1.0)
        source.subject.send(Note(.e, octave: 2))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.lastWrongPosition == nil)
    }
}
