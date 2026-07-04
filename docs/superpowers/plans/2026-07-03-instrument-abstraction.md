# Instrument Abstraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded `GuitarFretboard` static struct with a data-driven, injectable `Instrument` value type so future sprints add instruments/tunings by adding data, not code.

**Architecture:** Introduce an `Instrument` value type (Type Object pattern) whose per-string data (`GuitarString { openNote, startFret }`) describes any fretted, tuned instrument. A static `Instruments` catalog holds the one shipped instrument (`guitar`). The `AppDependencyContainer` picks the current instrument and injects it into the domain use case, the touch input source, the max-fret provider, and the drill view. `GuitarFretboard` is collapsed into a thin shim over `Instruments.guitar` (single source of truth) rather than deleted, because the not-yet-removed dead `Random*Strategy` files and their tests still reference it; it is removed later with them.

**Tech Stack:** Swift, SwiftUI (multiplatform macOS + iOS), Swift Testing (`import Testing`), Xcode project `audio_listen.xcodeproj` built via `xcodebuild`.

## Global Constraints

- Guitar is the ONLY wired instrument this sprint — no picker, no persistence, no new user-facing UI.
- Guitar behavior must stay byte-for-byte identical; no existing drill/combo/prompt test may change meaning. All existing tests stay green **without edits**.
- Swift files auto-join the target via the synchronized project group — no `.pbxproj` edits needed to add files.
- Tests run via: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16'`. If that simulator is absent, run `xcrun simctl list devices available` and substitute an installed iPhone, or use `-destination 'platform=macOS'` for a faster run. Append `-only-testing:audio_listenTests/<Suite>` to scope, and `2>&1 | tail -30` to trim output.
- Do NOT delete the dead `RandomNoteStrategy.swift` / `RandomNoteNamePositionStrategy.swift` or their tests (separate cleanup). Do NOT touch `GameSessionConfiguration.swift`.
- Every commit message ends with the repo's trailer:
  ```
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS
  ```

---

## File Structure

- **Create** `audio_listen/Domain/Models/Instrument.swift` — `GuitarString` + `Instrument` value types (note/positions logic).
- **Create** `audio_listen/Domain/Models/Instruments.swift` — static catalog (`guitar`, `all`).
- **Create** `audio_listenTests/InstrumentTests.swift` — pure-function tests incl. a synthetic drone instrument.
- **Modify** `audio_listen/Domain/Models/Note.swift` — receive the `Note.from(midiNumber:)` extension.
- **Modify** `audio_listen/Domain/Models/GuitarFretboard.swift` — lose the `Note.from` extension (Task 1), then become a shim (Task 3).
- **Modify** `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift` — inject `instrument`.
- **Modify** `audio_listen/Infrastructure/Input/TouchInputSource.swift` — inject `instrument`.
- **Modify** `audio_listen/Infrastructure/Game/UserDefaultsMaxFretProvider.swift` — inject `instrument`, use `instrument.fretCount`.
- **Modify** `audio_listen/DI/AppDependencyContainer.swift` — hold `let instrument`, thread it into factories.
- **Modify** `audio_listen/Presentation/Drill/FretboardView.swift` — derive `stringCount` from the instrument.
- **Modify** `audio_listen/Presentation/Drill/DrillView.swift` — take `instrument`, use `instrument.positions(for:)`.
- **Modify** `audio_listen/ContentView.swift` — pass `container.instrument` into `DrillView`.
- **Modify** `audio_listen/Infrastructure/Game/StringSetPresets.swift` — kill `1...6` literal.
- **Modify** `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift` — kill `1...6` literals.

---

## Task 1: Instrument model + catalog + `Note.from` relocation

**Files:**
- Create: `audio_listen/Domain/Models/Instrument.swift`
- Create: `audio_listen/Domain/Models/Instruments.swift`
- Modify: `audio_listen/Domain/Models/Note.swift`
- Modify: `audio_listen/Domain/Models/GuitarFretboard.swift` (remove only the `Note.from` extension)
- Test: `audio_listenTests/InstrumentTests.swift`

**Interfaces:**
- Consumes: `Note`, `NoteName`, `FretPosition` (existing domain models).
- Produces:
  - `struct GuitarString { let openNote: Note; let startFret: Int }`
  - `struct Instrument { let id: String; let name: String; let strings: [GuitarString]; let fretCount: Int; var stringCount: Int; func note(at: Int, fret: Int) -> Note?; func positions(for: Note, maxFretInclusive: Int) -> [FretPosition] }`
  - `enum Instruments { static let guitar: Instrument; static let all: [Instrument] }`
  - `extension Note { static func from(midiNumber: Int) -> Note? }` (now lives in `Note.swift`)

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/InstrumentTests.swift`:

```swift
import Testing
@testable import audio_listen

struct InstrumentTests {
    let guitar = Instruments.guitar

    @Test func openLowEIsE2() {
        #expect(guitar.note(at: 6, fret: 0) == Note(.e, octave: 2))
    }

    @Test func openHighEIsE4() {
        #expect(guitar.note(at: 1, fret: 0) == Note(.e, octave: 4))
    }

    @Test func openAStringIsA2() {
        #expect(guitar.note(at: 5, fret: 0) == Note(.a, octave: 2))
    }

    @Test func stringCountIsSix() {
        #expect(guitar.stringCount == 6)
    }

    @Test func positionsRoundTrip() {
        let target = Note(.g, octave: 3)
        let positions = guitar.positions(for: target, maxFretInclusive: 24)
        #expect(!positions.isEmpty)
        for pos in positions {
            #expect(guitar.note(at: pos.string, fret: pos.fret) == target)
        }
    }

    @Test func positionsRespectMaxFret() {
        let target = Note(.e, octave: 3)
        let at12 = guitar.positions(for: target, maxFretInclusive: 12)
        let at11 = guitar.positions(for: target, maxFretInclusive: 11)
        #expect(at12.contains { $0.fret == 12 })
        #expect(!at11.contains { $0.fret == 12 })
    }

    @Test func outOfRangeYieldsNil() {
        #expect(guitar.note(at: 6, fret: 25) == nil)
        #expect(guitar.note(at: 0, fret: 0) == nil)
        #expect(guitar.note(at: 7, fret: 0) == nil)
    }

    @Test func droneStringStartsAtItsStartFret() {
        let drone = GuitarString(openNote: Note(.g, octave: 4), startFret: 5)
        let banjoish = Instrument(id: "test", name: "Test", strings: [drone], fretCount: 22)
        #expect(banjoish.note(at: 1, fret: 3) == nil)
        #expect(banjoish.note(at: 1, fret: 5) == Note(.g, octave: 4))
        #expect(banjoish.note(at: 1, fret: 6) == Note(.gSharp, octave: 4))
    }

    @Test func dronePositionsOffsetByStartFret() {
        let drone = GuitarString(openNote: Note(.g, octave: 4), startFret: 5)
        let banjoish = Instrument(id: "test", name: "Test", strings: [drone], fretCount: 22)
        #expect(banjoish.positions(for: Note(.g, octave: 4), maxFretInclusive: 22) == [FretPosition(string: 1, fret: 5)])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:audio_listenTests/InstrumentTests 2>&1 | tail -30`
Expected: Compile failure — `cannot find 'Instruments' in scope` / `cannot find type 'Instrument'` / `GuitarString`.

- [ ] **Step 3: Create the `Instrument` model**

Create `audio_listen/Domain/Models/Instrument.swift`:

```swift
struct GuitarString: Equatable {
    let openNote: Note
    let startFret: Int
}

struct Instrument: Equatable {
    let id: String
    let name: String
    let strings: [GuitarString]
    let fretCount: Int

    var stringCount: Int { strings.count }

    func note(at string: Int, fret: Int) -> Note? {
        guard string >= 1, string <= strings.count else { return nil }
        let guitarString = strings[string - 1]
        guard fret >= guitarString.startFret, fret <= fretCount else { return nil }
        return Note.from(midiNumber: guitarString.openNote.midiNumber + (fret - guitarString.startFret))
    }

    func positions(for note: Note, maxFretInclusive: Int) -> [FretPosition] {
        let targetMidi = note.midiNumber
        let cap = min(maxFretInclusive, fretCount)
        var result: [FretPosition] = []
        for index in strings.indices {
            let guitarString = strings[index]
            let fret = (targetMidi - guitarString.openNote.midiNumber) + guitarString.startFret
            if fret >= guitarString.startFret, fret <= cap {
                result.append(FretPosition(string: index + 1, fret: fret))
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Create the catalog**

Create `audio_listen/Domain/Models/Instruments.swift`:

```swift
enum Instruments {
    static let guitar = Instrument(
        id: "guitar",
        name: "Guitar",
        strings: [
            Note(.e, octave: 4), Note(.b, octave: 3), Note(.g, octave: 3),
            Note(.d, octave: 3), Note(.a, octave: 2), Note(.e, octave: 2)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 24
    )

    static let all: [Instrument] = [guitar]
}
```

- [ ] **Step 5: Move `Note.from(midiNumber:)` into `Note.swift`**

Append to `audio_listen/Domain/Models/Note.swift` (after the `NoteName` enum, at end of file):

```swift
// MARK: - Note MIDI conversion

extension Note {
    /// Create a Note from MIDI note number.
    static func from(midiNumber: Int) -> Note? {
        guard midiNumber >= 0, midiNumber <= 127 else { return nil }
        let semitones = ((midiNumber % 12) + 12) % 12
        guard let name = NoteName(rawValue: semitones) else { return nil }
        let octave = (midiNumber / 12) - 1
        return Note(name, octave: octave)
    }
}
```

- [ ] **Step 6: Remove the duplicate `Note.from` extension from `GuitarFretboard.swift`**

In `audio_listen/Domain/Models/GuitarFretboard.swift`, delete this trailing block (leave the rest of the file — the `GuitarFretboard` struct — untouched for now):

```swift
// MARK: - Note MIDI conversion

extension Note {
    /// Create a Note from MIDI note number.
    static func from(midiNumber: Int) -> Note? {
        guard midiNumber >= 0, midiNumber <= 127 else { return nil }
        let semitones = ((midiNumber % 12) + 12) % 12
        guard let name = NoteName(rawValue: semitones) else { return nil }
        let octave = (midiNumber / 12) - 1
        return Note(name, octave: octave)
    }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:audio_listenTests/InstrumentTests 2>&1 | tail -30`
Expected: `Test Suite 'InstrumentTests' passed` — all 9 tests pass.

- [ ] **Step 8: Run the full suite to confirm nothing regressed**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **` — existing suites (incl. `GuitarFretboardTests`) still green; `Note.from` resolves from its new home.

- [ ] **Step 9: Commit**

```bash
git add audio_listen/Domain/Models/Instrument.swift audio_listen/Domain/Models/Instruments.swift audio_listen/Domain/Models/Note.swift audio_listen/Domain/Models/GuitarFretboard.swift audio_listenTests/InstrumentTests.swift
git commit -m "feat: add data-driven Instrument model and catalog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS"
```

---

## Task 2: Inject the instrument into the domain/infrastructure consumers

**Files:**
- Modify: `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift`
- Modify: `audio_listen/Infrastructure/Input/TouchInputSource.swift`
- Modify: `audio_listen/Infrastructure/Game/UserDefaultsMaxFretProvider.swift`
- Modify: `audio_listen/DI/AppDependencyContainer.swift`
- Test: existing `audio_listenTests/SelectNextPromptTests.swift` and the `UserDefaultsMaxFretProvider` tests (no edits — must stay green)

**Interfaces:**
- Consumes: `Instrument`, `Instruments.guitar` (Task 1).
- Produces:
  - `SelectNextPromptUseCase.init(maxBox:nameNoteProbability:instrument:)` with `instrument` defaulted to `Instruments.guitar`.
  - `TouchInputSource.init(instrument:)` defaulted to `Instruments.guitar`.
  - `UserDefaultsMaxFretProvider.init(defaults:instrument:)` defaulted to `Instruments.guitar`.
  - `AppDependencyContainer.instrument: Instrument` (stored `let`, module-visible).

- [ ] **Step 1: Migrate `SelectNextPromptUseCase` to the injected instrument**

In `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift`, replace the stored properties + init:

```swift
struct SelectNextPromptUseCase {
    let maxBox: Int
    let nameNoteProbability: Double

    init(maxBox: Int = DrillTuning.maxBox, nameNoteProbability: Double = 0.25) {
        self.maxBox = maxBox
        self.nameNoteProbability = nameNoteProbability
    }
```

with:

```swift
struct SelectNextPromptUseCase {
    let maxBox: Int
    let nameNoteProbability: Double
    let instrument: Instrument

    init(maxBox: Int = DrillTuning.maxBox, nameNoteProbability: Double = 0.25, instrument: Instrument = Instruments.guitar) {
        self.maxBox = maxBox
        self.nameNoteProbability = nameNoteProbability
        self.instrument = instrument
    }
```

In the same file, replace the two `GuitarFretboard.note(at:` call sites with `instrument.note(at:`:
- In `candidates(...)`: `guard let note = GuitarFretboard.note(at: string, fret: fret) else { continue }` → `guard let note = instrument.note(at: string, fret: fret) else { continue }`
- In `noteFor(key:maxFretInclusive:)`: `if let note = GuitarFretboard.note(at: key.string, fret: fret), note.name == key.noteName {` → `if let note = instrument.note(at: key.string, fret: fret), note.name == key.noteName {`

- [ ] **Step 2: Migrate `TouchInputSource`**

Replace the whole body of `audio_listen/Infrastructure/Input/TouchInputSource.swift`:

```swift
import Combine

final class TouchInputSource: NoteInputSource {
    private let subject = PassthroughSubject<Note, Never>()
    private let instrument: Instrument

    init(instrument: Instrument = Instruments.guitar) {
        self.instrument = instrument
    }

    var notes: AnyPublisher<Note, Never> { subject.eraseToAnyPublisher() }

    func start() throws {}
    func stop() {}

    func submit(_ position: FretPosition) {
        if let note = instrument.note(at: position.string, fret: position.fret) {
            subject.send(note)
        }
    }
}
```

- [ ] **Step 3: Migrate `UserDefaultsMaxFretProvider`**

In `audio_listen/Infrastructure/Game/UserDefaultsMaxFretProvider.swift`, replace the stored property + init + the return line:

```swift
struct UserDefaultsMaxFretProvider: MaxFretProviding {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
```

with:

```swift
struct UserDefaultsMaxFretProvider: MaxFretProviding {
    private let defaults: UserDefaults
    private let instrument: Instrument

    init(defaults: UserDefaults = .standard, instrument: Instrument = Instruments.guitar) {
        self.defaults = defaults
        self.instrument = instrument
    }
```

and change the final return:

```swift
        return limitToTwelve ? GameTargetFretBounds.limitedMaxFretInclusive : GuitarFretboard.fretCount
```

to:

```swift
        return limitToTwelve ? GameTargetFretBounds.limitedMaxFretInclusive : instrument.fretCount
```

- [ ] **Step 4: Hold + thread the instrument in the container**

In `audio_listen/DI/AppDependencyContainer.swift`, add the stored property just below `let dailyHistoryStore = DailyHistoryStore()`:

```swift
    let instrument: Instrument = Instruments.guitar
```

In `private init()`, change:

```swift
        maxFretProvider = UserDefaultsMaxFretProvider()
```

to:

```swift
        maxFretProvider = UserDefaultsMaxFretProvider(instrument: instrument)
```

In `makeDrillViewModel()`, change:

```swift
            selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: nameNoteProbability),
```

to:

```swift
            selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: nameNoteProbability, instrument: instrument),
```

and change the touch-mode input construction:

```swift
            let touch = TouchInputSource()
```

to:

```swift
            let touch = TouchInputSource(instrument: instrument)
```

- [ ] **Step 5: Run the full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. `SelectNextPromptTests` (constructs `SelectNextPromptUseCase()` — instrument defaults to guitar) and the `UserDefaultsMaxFretProvider` tests (`provider.maxFretInclusive == GuitarFretboard.fretCount` — both 24) still pass unchanged.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift audio_listen/Infrastructure/Input/TouchInputSource.swift audio_listen/Infrastructure/Game/UserDefaultsMaxFretProvider.swift audio_listen/DI/AppDependencyContainer.swift
git commit -m "refactor: inject Instrument into prompt/touch/maxfret consumers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS"
```

---

## Task 3: Collapse `GuitarFretboard` into a shim over `Instruments.guitar`

**Files:**
- Modify: `audio_listen/Domain/Models/GuitarFretboard.swift`
- Test: existing `audio_listenTests/audio_listenTests.swift` `GuitarFretboardTests` (no edits — must stay green)

**Interfaces:**
- Consumes: `Instruments.guitar` (Task 1).
- Produces: `GuitarFretboard` with the SAME static surface it has today — `static var fretCount: Int`, `static func note(at:fret:) -> Note?`, `static func positions(for:maxFretInclusive:) -> [FretPosition]`, `static var playableNotes: [Note]` — now delegating to `Instruments.guitar`. This keeps the dead `Random*Strategy` files and all existing `GuitarFretboard`-named tests compiling and passing.

- [ ] **Step 1: Replace the file with a shim**

Replace the entire contents of `audio_listen/Domain/Models/GuitarFretboard.swift`:

```swift
//
//  GuitarFretboard.swift
//  audio_listen
//
//  Deprecated shim over `Instruments.guitar` (the single source of truth).
//  Retained only so the not-yet-removed Random*Strategy files and their tests
//  compile; delete this together with them in the dead-code cleanup task.
//

import Foundation

struct GuitarFretboard {
    static var fretCount: Int { Instruments.guitar.fretCount }

    static func note(at string: Int, fret: Int) -> Note? {
        Instruments.guitar.note(at: string, fret: fret)
    }

    static func positions(for note: Note, maxFretInclusive: Int = Instruments.guitar.fretCount) -> [FretPosition] {
        Instruments.guitar.positions(for: note, maxFretInclusive: maxFretInclusive)
    }

    static var playableNotes: [Note] {
        let minMidi = Note(.e, octave: 2).midiNumber
        let maxMidi = Note(.e, octave: 5).midiNumber
        return (minMidi...maxMidi).compactMap { Note.from(midiNumber: $0) }
    }
}
```

- [ ] **Step 2: Run the full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. `GuitarFretboardTests` (open low E = E2, positions round-trip, maxFret caps) now exercise the shim and still pass because it delegates to `Instruments.guitar`, which is byte-for-byte identical to the old tuning.

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Domain/Models/GuitarFretboard.swift
git commit -m "refactor: reduce GuitarFretboard to a shim over Instruments.guitar

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS"
```

---

## Task 4: Wire the view layer to the instrument

**Files:**
- Modify: `audio_listen/Presentation/Drill/FretboardView.swift`
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`
- Modify: `audio_listen/ContentView.swift`
- Test: full suite (no view unit tests; guitar rendering unchanged)

**Interfaces:**
- Consumes: `Instrument`, `Instruments.guitar`, `AppDependencyContainer.instrument`.
- Produces:
  - `FretboardView.instrument: Instrument` property (default `Instruments.guitar`); `stringCount` derived from it.
  - `DrillView.init(viewModel:allowedStringsStore:instrument:)` with `instrument` defaulted to `Instruments.guitar`.

Note: `FretboardView`'s displayed `fretCount = 12` is the first-position practice window (a display choice), NOT the instrument's full 24-fret span — leave it a constant. Only `stringCount` comes from the instrument.

- [ ] **Step 1: Derive `stringCount` from the instrument in `FretboardView`**

In `audio_listen/Presentation/Drill/FretboardView.swift`, add an `instrument` property and replace the hardcoded `stringCount`. Change:

```swift
    var minHeight: CGFloat = 220

    private let stringCount = 6
    private let fretCount = 12
```

to:

```swift
    var minHeight: CGFloat = 220
    var instrument: Instrument = Instruments.guitar

    private var stringCount: Int { instrument.stringCount }
    private let fretCount = 12
```

In the same file, change the heatmap helper `fret(for:)` to use the instrument. Replace:

```swift
    private func fret(for key: DrillItemKey) -> Int? {
        for fret in 0...fretCount where GuitarFretboard.note(at: key.string, fret: fret)?.name == key.noteName {
            return fret
        }
        return nil
    }
```

with:

```swift
    private func fret(for key: DrillItemKey) -> Int? {
        for fret in 0...fretCount where instrument.note(at: key.string, fret: fret)?.name == key.noteName {
            return fret
        }
        return nil
    }
```

- [ ] **Step 2: Take + use the instrument in `DrillView`**

In `audio_listen/Presentation/Drill/DrillView.swift`, add the stored property next to `allowedStringsStore`. Change:

```swift
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore
```

to:

```swift
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore
    private let instrument: Instrument
```

Change the initializer:

```swift
    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
    }
```

to:

```swift
    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore, instrument: Instrument = Instruments.guitar) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
        self.instrument = instrument
    }
```

Change `position(for:)`:

```swift
    private func position(for prompt: DrillPrompt) -> FretPosition? {
        GuitarFretboard.positions(for: prompt.targetNote)
            .first { $0.string == prompt.string }
    }
```

to:

```swift
    private func position(for prompt: DrillPrompt) -> FretPosition? {
        instrument.positions(for: prompt.targetNote, maxFretInclusive: instrument.fretCount)
            .first { $0.string == prompt.string }
    }
```

- [ ] **Step 3: Pass the instrument into each `FretboardView` in `DrillView`**

In `audio_listen/Presentation/Drill/DrillView.swift`, add `instrument: instrument` to the three `FretboardView(...)` constructions:

In `idleSetup`, change `FretboardView(heatmap: [:], minHeight: fretboardHeight)` to:

```swift
            FretboardView(heatmap: [:], minHeight: fretboardHeight, instrument: instrument)
```

In `promptView`'s `.findPosition` branch, change the `FretboardView(...)` call by adding `instrument: instrument` after `minHeight: fretboardHeight`:

```swift
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    onTap: (touchMode && !reveal) ? { viewModel.submitTouch($0) } : nil,
                    wrongPosition: reveal ? nil : viewModel.lastWrongPosition,
                    minHeight: fretboardHeight,
                    instrument: instrument
                )
```

In `promptView`'s `.nameNote` branch, change to:

```swift
                FretboardView(
                    highlightedPosition: position(for: prompt),
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    minHeight: fretboardHeight,
                    instrument: instrument
                )
```

- [ ] **Step 4: Pass `container.instrument` into `DrillView` from `ContentView`**

In `audio_listen/ContentView.swift`, both `DrillView(...)` constructions (the iOS `screen(for:)` `case 0` and the macOS `TabView` branch) currently read:

```swift
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore
            )
```

Change BOTH to:

```swift
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                instrument: container.instrument
            )
```

- [ ] **Step 5: Build + run the full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. Guitar renders 6 strings / 12-fret window exactly as before; no test changes meaning.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Presentation/Drill/FretboardView.swift audio_listen/Presentation/Drill/DrillView.swift audio_listen/ContentView.swift
git commit -m "refactor: wire the drill view layer to the injected Instrument

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS"
```

---

## Task 5: Remove the `1...6` magic numbers

**Files:**
- Modify: `audio_listen/Infrastructure/Game/StringSetPresets.swift`
- Modify: `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift`
- Test: existing `GameAllowedStringsStoreTests` (no edits — must stay green)

**Interfaces:**
- Consumes: `Instruments.guitar.stringCount` (Task 1).
- Produces: no new API; the string-range literals now derive from the instrument's string count (single source of truth).

- [ ] **Step 1: Kill `1...6` in `StringSetPresets`**

In `audio_listen/Infrastructure/Game/StringSetPresets.swift`, change:

```swift
        StringSetPreset(id: "ALL", label: "All 6", strings: Set(1...6))
```

to:

```swift
        StringSetPreset(id: "ALL", label: "All 6", strings: Set(1...Instruments.guitar.stringCount))
```

- [ ] **Step 2: Kill `1...6` in `GameAllowedStringsStore`**

In `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift`, change the filter in `load()`:

```swift
        let inRange = arr.filter { (1...6).contains($0) }
```

to:

```swift
        let inRange = arr.filter { (1...Instruments.guitar.stringCount).contains($0) }
```

and the filter in `save(_:)`:

```swift
        let sorted = strings.filter { (1...6).contains($0) }.sorted()
```

to:

```swift
        let sorted = strings.filter { (1...Instruments.guitar.stringCount).contains($0) }.sorted()
```

- [ ] **Step 3: Run the full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. `1...Instruments.guitar.stringCount` is `1...6` for guitar, so `GameAllowedStringsStoreTests` behavior is identical.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Infrastructure/Game/StringSetPresets.swift audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift
git commit -m "refactor: derive string range from the instrument, drop 1...6 literals

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS"
```

---

## Done-when

- `Instrument` + `Instruments` exist; `Instruments.guitar` is the single source of truth for the guitar tuning.
- Every live consumer (prompt selection, touch input, max-fret, drill view, fretboard view, string presets/store) reads the instrument through injection — no production code calls `GuitarFretboard` directly except the shim's own delegation.
- `GuitarFretboard` is a thin shim (deleted later with the dead `Random*Strategy` files).
- All existing tests pass unedited; new `InstrumentTests` (incl. drone) pass.
- Guitar behavior is unchanged end-to-end.

## Deviation from spec (flag for reviewer)

The spec said "Delete `GuitarFretboard.swift`." During planning we found the dead `RandomNoteStrategy` / `RandomNoteNamePositionStrategy` files **and their tests** reference `GuitarFretboard`, so deleting it would break code the spec also said to leave for a later cleanup. Resolution: collapse `GuitarFretboard` into a shim over `Instruments.guitar` (single source of truth) and delete it later together with the dead strategies. Net effect matches the spec's intent — production is fully instrument-driven — with less churn and all existing tests green.
