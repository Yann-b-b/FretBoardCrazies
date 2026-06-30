# Touch Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "touch mode" so find-position drills can be answered by tapping the fret on screen (no guitar/mic), switchable from Settings.

**Architecture:** Vary the input, not the ViewModel. Introduce a `NoteInputSource` protocol emitting `Note`; the existing mic becomes `MicNoteSource`, a new `TouchInputSource` emits a note when a fret is tapped. `DrillViewModel` depends on `NoteInputSource` (instead of `PitchDetectorProtocol`); the whole validate/score/belt/combo/advance loop is reused. A wrong answer publishes `lastWrongPosition` (derived from the answered note + the prompt's string) which the fretboard draws as a coral dot — works for both modes via one code path.

**Tech Stack:** Swift / SwiftUI, Combine, Swift Testing (`import Testing`, `@Test`, `#expect`). Multiplatform target (macOS 14.6, iOS 18.2).

## Global Constraints

- No code comments; clear names; pure functions for logic.
- Unit tests use **Swift Testing** (`import Testing`), matching the existing test suite — NOT XCTest.
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build` → `** BUILD SUCCEEDED **`.
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests` → `** TEST SUCCEEDED **` (macOS is fastest; the logic is platform-agnostic).
- `audio_listen/` and `audio_listenTests/` are `PBXFileSystemSynchronizedRootGroup`s — new files auto-include, no `project.pbxproj` edits.
- Standard tuning: string 1 = high E4, string 6 = low E2. `GuitarFretboard.note(at: 6, fret: 0)` = `Note(.e, octave: 2)`; `note(at: 6, fret: 1)` = `Note(.f, octave: 2)`.
- Touch mode: find-position only (`SelectNextPromptUseCase(nameNoteProbability: 0)`); validation stays the existing note-equality check.
- Work on a feature branch off `main` (e.g. `touch-mode`); do not work on `main` directly.

---

### Task 1: Input source layer (`NoteInputSource`, `MicNoteSource`, `TouchInputSource`)

**Files:**
- Create: `audio_listen/Domain/Protocols/NoteInputSource.swift`
- Create: `audio_listen/Infrastructure/Input/MicNoteSource.swift`
- Create: `audio_listen/Infrastructure/Input/TouchInputSource.swift`
- Test: `audio_listenTests/InputSourceTests.swift`

**Interfaces:**
- Produces:
  - `protocol NoteInputSource: AnyObject { var notes: AnyPublisher<Note, Never> { get }; func start() throws; func stop() }`
  - `MicNoteSource(detector: PitchDetectorProtocol)` — maps `detector.currentPitch` → `pitch.note`.
  - `TouchInputSource()` with `func submit(_ position: FretPosition)`.

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/InputSourceTests.swift`:
```swift
import Combine
import Testing
@testable import audio_listen

private final class StubDetector: PitchDetectorProtocol {
    let subject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> { subject.eraseToAnyPublisher() }
    func start() throws {}
    func stop() {}
}

struct InputSourceTests {
    @Test func micSourceEmitsTheDetectedNote() {
        let detector = StubDetector()
        let source = MicNoteSource(detector: detector)
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        detector.subject.send(DetectedPitch(note: Note(.g, octave: 3), frequency: 196, amplitude: 0.2))
        c.cancel()
        #expect(received == [Note(.g, octave: 3)])
    }

    @Test func touchSourceEmitsNoteAtTappedPosition() {
        let source = TouchInputSource()
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        source.submit(FretPosition(string: 6, fret: 1))   // low E string, fret 1 = F2
        c.cancel()
        #expect(received == [Note(.f, octave: 2)])
    }

    @Test func touchSourceIgnoresOutOfRangePosition() {
        let source = TouchInputSource()
        var received: [Note] = []
        let c = source.notes.sink { received.append($0) }
        source.submit(FretPosition(string: 9, fret: 0))   // no such string
        c.cancel()
        #expect(received.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the Test command (scoped is fine):
`… xcodebuild test … -only-testing:audio_listenTests/InputSourceTests`
Expected: compile failure — `cannot find 'MicNoteSource' / 'TouchInputSource' / 'NoteInputSource'`.

- [ ] **Step 3: Create the protocol**

Create `audio_listen/Domain/Protocols/NoteInputSource.swift`:
```swift
import Combine

protocol NoteInputSource: AnyObject {
    var notes: AnyPublisher<Note, Never> { get }
    func start() throws
    func stop()
}
```

- [ ] **Step 4: Create `MicNoteSource`**

Create `audio_listen/Infrastructure/Input/MicNoteSource.swift`:
```swift
import Combine

final class MicNoteSource: NoteInputSource {
    private let detector: PitchDetectorProtocol

    init(detector: PitchDetectorProtocol) {
        self.detector = detector
    }

    var notes: AnyPublisher<Note, Never> {
        detector.currentPitch.map { $0.note }.eraseToAnyPublisher()
    }

    func start() throws { try detector.start() }
    func stop() { detector.stop() }
}
```

- [ ] **Step 5: Create `TouchInputSource`**

Create `audio_listen/Infrastructure/Input/TouchInputSource.swift`:
```swift
import Combine

final class TouchInputSource: NoteInputSource {
    private let subject = PassthroughSubject<Note, Never>()

    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }

    func start() throws {}
    func stop() {}

    func submit(_ position: FretPosition) {
        if let note = GuitarFretboard.note(at: position.string, fret: position.fret) {
            subject.send(note)
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run the Test command for `InputSourceTests`. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Domain/Protocols/NoteInputSource.swift audio_listen/Infrastructure/Input/ audio_listenTests/InputSourceTests.swift
git commit -m "feat: NoteInputSource protocol with mic and touch implementations"
```

---

### Task 2: `FretboardGeometry.hitTest` (tap point → fret position)

**Files:**
- Modify: `audio_listen/Presentation/Drill/FretboardGeometry.swift`
- Modify: `audio_listen/Domain/Models/FretPosition.swift` (only if not already `Equatable`)
- Test: `audio_listenTests/FretboardGeometryTests.swift`

**Interfaces:**
- Produces: `FretboardGeometry.hitTest(point: CGPoint) -> FretPosition?` — inverse of `point(string:fret:)`; clamps to `1...stringCount` / `0...fretCount`, nil outside.

- [ ] **Step 1: Write the failing tests**

Append to `audio_listenTests/FretboardGeometryTests.swift` (inside the `FretboardGeometryTests` struct):
```swift
    @Test func hitTestRoundTripsPointForEveryPosition() {
        for string in 1...6 {
            for fret in 0...12 {
                let p = geo.point(string: string, fret: fret)
                #expect(geo.hitTest(point: p) == FretPosition(string: string, fret: fret))
            }
        }
    }

    @Test func hitTestReturnsNilOutsideTheBoard() {
        #expect(geo.hitTest(point: CGPoint(x: -10, y: 125)) == nil)
        #expect(geo.hitTest(point: CGPoint(x: 300, y: 1000)) == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run `-only-testing:audio_listenTests/FretboardGeometryTests`.
Expected: compile failure — `value of type 'FretboardGeometry' has no member 'hitTest'` (and, if `FretPosition` isn't `Equatable`, an `==` error — fix in Step 3).

- [ ] **Step 3: Implement `hitTest` (and ensure `FretPosition: Equatable`)**

In `audio_listen/Presentation/Drill/FretboardGeometry.swift`, add inside the struct (after `point(string:fret:)`):
```swift
    func hitTest(point: CGPoint) -> FretPosition? {
        let inset = size.height / CGFloat(stringCount + 1)
        let cellWidth = size.width / CGFloat(fretCount + 1)
        guard inset > 0, cellWidth > 0 else { return nil }
        let string = Int((point.y / inset).rounded())
        let fret = Int((point.x / cellWidth).rounded(.down))
        guard string >= 1, string <= stringCount, fret >= 0, fret <= fretCount else { return nil }
        return FretPosition(string: string, fret: fret)
    }
```
Then open `audio_listen/Domain/Models/FretPosition.swift`; if its declaration is not already `Equatable` (e.g. `struct FretPosition {`), add the conformance so the test's `==` compiles: `struct FretPosition: Equatable {`. (It is a plain value type of `let string: Int; let fret: Int`; adding `Equatable` is safe.)

- [ ] **Step 4: Run tests to verify they pass**

Run `-only-testing:audio_listenTests/FretboardGeometryTests`. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/FretboardGeometry.swift audio_listen/Domain/Models/FretPosition.swift audio_listenTests/FretboardGeometryTests.swift
git commit -m "feat: FretboardGeometry.hitTest inverse mapping"
```

---

### Task 3: Settings key + "Touch mode" toggle

**Files:**
- Modify: `audio_listen/Infrastructure/Game/GameSettingsKeys.swift`
- Modify: `audio_listen/Presentation/Settings/SettingsView.swift`

**Interfaces:**
- Produces: `GameSettingsKeys.touchMode` (String key) consumed by Task 4's container and Task 5's DrillView.

- [ ] **Step 1: Add the key**

In `audio_listen/Infrastructure/Game/GameSettingsKeys.swift`, replace:
```swift
    static let countdownEnabled = "countdownEnabled"
}
```
with:
```swift
    static let countdownEnabled = "countdownEnabled"
    static let touchMode = "touchMode"
}
```

- [ ] **Step 2: Add the toggle**

In `audio_listen/Presentation/Settings/SettingsView.swift`, add the `@AppStorage` and the `Toggle`. Replace:
```swift
    @AppStorage(GameSettingsKeys.limitFretsToTwelve) private var limitFretsToTwelve = true

    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–11", isOn: $limitFretsToTwelve)
            }
        }
```
with:
```swift
    @AppStorage(GameSettingsKeys.limitFretsToTwelve) private var limitFretsToTwelve = true
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false

    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–11", isOn: $limitFretsToTwelve)
                Toggle("Touch mode (tap notes instead of playing)", isOn: $touchMode)
            }
        }
```

- [ ] **Step 3: Build**

Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Infrastructure/Game/GameSettingsKeys.swift audio_listen/Presentation/Settings/SettingsView.swift
git commit -m "feat: touchMode settings key and toggle"
```

---

### Task 4: Migrate `DrillViewModel` to `NoteInputSource` + wire the container

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillViewModel.swift`
- Modify: `audio_listen/DI/AppDependencyContainer.swift`
- Modify: `audio_listenTests/DrillViewModelTests.swift`

**Interfaces:**
- Consumes: `NoteInputSource`, `MicNoteSource`, `TouchInputSource` (Task 1); `GameSettingsKeys.touchMode` (Task 3).
- Produces: `DrillViewModel(input: NoteInputSource, touchSubmit: ((FretPosition) -> Void)? = nil, selectNextPrompt:…, … )`; `@Published private(set) var lastWrongPosition: FretPosition?`; `func submitTouch(_ position: FretPosition)`.

- [ ] **Step 1: Update the tests first (they pin the new shape)**

In `audio_listenTests/DrillViewModelTests.swift`:

(a) Replace the `StubPitchDetector` class:
```swift
private final class StubPitchDetector: PitchDetectorProtocol {
    let subject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> { subject.eraseToAnyPublisher() }
    private(set) var startCalled = false
    func start() throws { startCalled = true }
    func stop() {}
}
```
with:
```swift
private final class StubNoteInputSource: NoteInputSource {
    let subject = PassthroughSubject<Note, Never>()
    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }
    private(set) var startCalled = false
    func start() throws { startCalled = true }
    func stop() {}
}
```

(b) In the `makeViewModel` helper, change the parameter `detector: StubPitchDetector` to `source: StubNoteInputSource`, and the VM argument `pitchDetector: detector` to `input: source`.

(c) Global mechanical replacements across the file:
- every `StubPitchDetector()` → `StubNoteInputSource()`
- every local named `detector` → `source` (including `detector: detector` call-site labels → `source: source`, and `detector.startCalled` → `source.startCalled`)
- every `detector.subject.send(DetectedPitch(note: N, frequency: _, amplitude: _))` → `source.subject.send(N)` (drop the frequency/amplitude; keep the `Note(...)`). There are several (the correct-answer, daily-history, combo, skip-during-success, manual-start tests).
- the two **inline** `DrillViewModel(` constructions (`emptyAllowedSetsShowsError`, `correctAnswerRecordsDailyHistory`): `pitchDetector: detector` → `input: source`.

(d) Add a new test (uses the find-position prompt: allowed string 6, note E; a wrong F2 maps to fret 1 on string 6):
```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run `-only-testing:audio_listenTests/DrillViewModelTests`.
Expected: compile failure — `DrillViewModel` has no `input:` parameter / no `lastWrongPosition` / `StubNoteInputSource` doesn't conform yet won't arise (it's defined), but the VM init mismatch fails to compile.

- [ ] **Step 3: Migrate `DrillViewModel`**

In `audio_listen/Presentation/Drill/DrillViewModel.swift`:

(a) Add the published property near the other `@Published`s (after `@Published var errorMessage: String?`):
```swift
    @Published private(set) var lastWrongPosition: FretPosition?
```

(b) Replace the stored dependency line:
```swift
    private let pitchDetector: PitchDetectorProtocol
```
with:
```swift
    private let input: NoteInputSource
    private let touchSubmit: ((FretPosition) -> Void)?
```

(c) Rename the subscription field:
```swift
    private var pitchSubscription: AnyCancellable?
```
→
```swift
    private var inputSubscription: AnyCancellable?
```

(d) In `init`, replace the first parameter `pitchDetector: PitchDetectorProtocol,` with:
```swift
        input: NoteInputSource,
        touchSubmit: ((FretPosition) -> Void)? = nil,
```
and in the body replace `self.pitchDetector = pitchDetector` with:
```swift
        self.input = input
        self.touchSubmit = touchSubmit
```

(e) In `start()`, add `lastWrongPosition = nil` next to the other resets (with `comboCount = 0`).

(f) In `advance()`, add `lastWrongPosition = nil` at the top (next to `countdownToken = nil`).

(g) Replace `startListening()`:
```swift
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
```
with:
```swift
    private func startListening() {
        detectedNote = "—"
        do {
            if !engineStarted {
                try input.start()
                engineStarted = true
            }
            inputSubscription = input.notes
                .receive(on: DispatchQueue.main)
                .sink { [weak self] note in self?.handle(note) }
        } catch {
            errorMessage = "Could not start input: \(error.localizedDescription)"
        }
    }
```

(h) Replace `stopListening()`:
```swift
    private func stopListening() {
        pitchSubscription?.cancel()
        pitchSubscription = nil
    }
```
with:
```swift
    private func stopListening() {
        inputSubscription?.cancel()
        inputSubscription = nil
    }
```

(i) Replace `handle(_ pitch:)`:
```swift
    private func handle(_ pitch: DetectedPitch) {
        detectedNote = pitch.note.displayName
        guard case .playing(let startTime, let prompt) = state else { return }
        guard validateNote.execute(detected: pitch.note, target: prompt.targetNote) else { return }
        stopListening()
        let reaction = clock.now().timeIntervalSince(startTime)
        recordCorrect(for: prompt, reactionTime: reaction)
        comboCount = reaction <= DrillTuning.fastReactionSeconds ? comboCount + 1 : 0
        stateMachine.transition(to: .success(reactionTime: reaction, prompt: prompt))
        autoAdvanceToken = scheduler.scheduleAfter(1.0) { [weak self] in self?.advance() }
    }
```
with:
```swift
    private func handle(_ note: Note) {
        detectedNote = note.displayName
        guard case .playing(let startTime, let prompt) = state else { return }
        guard validateNote.execute(detected: note, target: prompt.targetNote) else {
            lastWrongPosition = GuitarFretboard.positions(for: note).first { $0.string == prompt.string }
            return
        }
        lastWrongPosition = nil
        stopListening()
        let reaction = clock.now().timeIntervalSince(startTime)
        recordCorrect(for: prompt, reactionTime: reaction)
        comboCount = reaction <= DrillTuning.fastReactionSeconds ? comboCount + 1 : 0
        stateMachine.transition(to: .success(reactionTime: reaction, prompt: prompt))
        autoAdvanceToken = scheduler.scheduleAfter(1.0) { [weak self] in self?.advance() }
    }
```

(j) Add the touch entry point (anywhere among the public methods, e.g. after `skip()`):
```swift
    func submitTouch(_ position: FretPosition) {
        touchSubmit?(position)
    }
```

- [ ] **Step 4: Wire the container**

In `audio_listen/DI/AppDependencyContainer.swift`, replace the body of `makeDrillViewModel()` (lines from `let adapter = …` through the `return DrillViewModel(...)`) with:
```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run `-only-testing:audio_listenTests/DrillViewModelTests`. Expected: `** TEST SUCCEEDED **` (all existing tests + the two new `lastWrongPosition` tests).

- [ ] **Step 6: Build the whole app**

Run the Build command. Expected: `** BUILD SUCCEEDED **` (the container + VM compile; `TunerViewModel` still uses `PitchDetectorProtocol`, unaffected).

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillViewModel.swift audio_listen/DI/AppDependencyContainer.swift audio_listenTests/DrillViewModelTests.swift
git commit -m "feat: DrillViewModel consumes NoteInputSource; container selects mic/touch; wrong-answer dot state"
```

---

### Task 5: Tappable fretboard + coral wrong-dot + DrillView wiring

**Files:**
- Modify: `audio_listen/Presentation/Drill/FretboardView.swift`
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`

**Interfaces:**
- Consumes: `FretboardGeometry.hitTest` (Task 2); `DrillViewModel.submitTouch` + `lastWrongPosition` (Task 4); `GameSettingsKeys.touchMode` (Task 3).

- [ ] **Step 1: Add tap + wrong-dot to `FretboardView`**

In `audio_listen/Presentation/Drill/FretboardView.swift`, add two params after `heatmap`:
```swift
    var heatmap: [DrillItemKey: MasteryLevel] = [:]
    var onTap: ((FretPosition) -> Void)? = nil
    var wrongPosition: FretPosition? = nil
```
In the `ZStack` (after the `highlightedPosition` block), add the wrong dot and the conditional tap gesture:
```swift
                if let position = highlightedPosition {
                    targetDot(geo, position: position)
                }
                if let position = wrongPosition {
                    wrongDot(geo, position: position)
                }
            }
            .modifier(TapToFret(geo: geo, onTap: onTap))
```
Add the `wrongDot` function (next to `targetDot`):
```swift
    private func wrongDot(_ geo: FretboardGeometry, position: FretPosition) -> some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.42, blue: 0.42))
            .frame(width: 22, height: 22)
            .position(geo.point(string: position.string, fret: position.fret))
    }
```
Add the conditional-gesture modifier at file scope (below the `FretboardView` struct, above `#Preview`):
```swift
private struct TapToFret: ViewModifier {
    let geo: FretboardGeometry
    let onTap: ((FretPosition) -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            content
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        if let position = geo.hitTest(point: value.location) {
                            onTap(position)
                        }
                    }
                )
        } else {
            content
        }
    }
}
```
(`onTap` defaults nil, so `MasteryView`'s heatmap fretboard attaches no gesture and the Progress `ScrollView` is unaffected.)

- [ ] **Step 2: Wire `DrillView`**

In `audio_listen/Presentation/Drill/DrillView.swift`, add the setting near the other `@State`s:
```swift
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false
```
In `promptView(_:reveal:)`, pass the two params to the **find-position** `FretboardView` (the one with `highlightedString:`). Replace:
```swift
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil
                )
```
with:
```swift
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    onTap: (touchMode && !reveal) ? { viewModel.submitTouch($0) } : nil,
                    wrongPosition: reveal ? nil : viewModel.lastWrongPosition
                )
```

- [ ] **Step 3: Build**

Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and verify (macOS, fastest to launch)**

Build + launch the macOS app:
```bash
open "$(find ~/Library/Developer/Xcode/DerivedData -name audio_listen.app -path '*Debug*' -not -path '*Index*' | head -1)"
```
Then: Settings → turn on **Touch mode**, return to Drill, press Start. Expected: a find-position prompt ("X — string N"); tapping the correct fret on that string → "Correct!"; tapping a wrong fret → a coral dot at the tapped fret, prompt stays; no mic-permission prompt appears. (Visual confirmation; the implementer reports build + clean launch, the human confirms the interaction.)

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/FretboardView.swift audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: tappable fretboard with coral wrong-dot for touch mode"
```

---

## Notes for the implementer

- Swift tests run via `xcodebuild test` (slow — each builds the app). Use the `-only-testing:audio_listenTests/<Suite>` scoping shown per task; run the full `-only-testing:audio_listenTests` once before the final commit of Task 4.
- View tasks (5) have no unit test; verified by a clean build + the manual run-through in the step.
- Do not touch `TunerViewModel` / `PitchDetectorProtocol` — the mic protocol stays for the tuner; only the drill moved to `NoteInputSource`.
- The wrong-dot shows the answered note's position on the **asked string** by design (see the spec's "Known caveat"); this is intended, not a bug.
