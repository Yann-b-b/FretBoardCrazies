# Instrument-Derived String Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded, guitar-specific `StringSetPresets` enum with string-choice presets **derived from the instrument**, and persist the selection **per instrument** (keyed by `instrument.id`), eliminating the global settings key.

**Architecture:** A new `StringChoice` value type plus an `Instrument` extension that generates the choices (singles + cumulative) from the instrument's strings, ordered by pitch. `GameAllowedStringsStore` becomes instrument-aware (`load(for:)`/`save(for:)`) with a per-instrument key. `DrillView`'s picker reads the instrument's derived choices. Guitar remains the only wired instrument; the generators and store are proven instrument-general against a synthetic bass in tests.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), Xcode project `audio_listen.xcodeproj` (NOT SPM), UserDefaults persistence.

## Global Constraints

- **No comments** — code must be self-documenting (global CLAUDE.md rule). None of the code below carries comments except the one doc-comment retained on the store to state its fallback contract; do not add others.
- **Explicit over implicit; never silently fail** — preserve the store's existing validation/clamping contract exactly.
- **New/deleted `.swift` files are auto-included** via `PBXFileSystemSynchronizedRootGroup`. Creating a file = it compiles; deleting = `git rm` (never edit `project.pbxproj`).
- **Build/test command** (macOS destination avoids simulator clones; `-only-testing:audio_listenTests` skips the flaky UI-test target):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -project audio_listen.xcodeproj -scheme audio_listen \
    -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -40
  ```
  Expected success line: `** TEST SUCCEEDED **`.
- **SourceKit false positives:** cross-file "Cannot find type" errors from the editor/LSP are not authoritative — `xcodebuild` is. Only trust the `xcodebuild` result.
- **No migration:** the old global key `audio_listen_game_allowed_strings` is abandoned. A missing per-instrument key means first use.

---

## File Structure

| File | Responsibility |
|---|---|
| `audio_listen/Domain/Models/StringChoice.swift` | **new** — the `StringChoice` value type (id derived from its string set) |
| `audio_listen/Domain/Models/Instrument+StringChoices.swift` | **new** — the four generators + the Low/High/octave label rule |
| `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift` | **modified** — per-instrument `load(for:)`/`save(for:)`, instrument-clamped |
| `audio_listen/Infrastructure/Game/UserDefaultsAllowedStringsProvider.swift` | **modified** — holds the instrument, resolves `load(for:)` |
| `audio_listen/DI/AppDependencyContainer.swift` | **modified** — wire the provider with `instrument` |
| `audio_listen/Presentation/Drill/DrillView.swift` | **modified** — picker + default + save/load from the instrument |
| `audio_listen/Infrastructure/Game/StringSetPresets.swift` | **deleted** |
| `audio_listenTests/InstrumentStringChoicesTests.swift` | **new** — generator tests (guitar + synthetic bass + triple-E) |
| `audio_listenTests/audio_listenTests.swift` | **modified** — add per-instrument store tests, remove old-API store tests |
| `audio_listenTests/StringSetPresetsTests.swift` | **deleted** |

`DrillViewModel`, the drill loop, `AllowedStringsProviding` (protocol), and `MasteryView` are untouched.

---

## Task 1: Instrument-derived string choices (domain core)

Pure, additive domain code. `StringSetPresets` stays in place and compiles; nothing consumes the new code yet except its own tests.

**Files:**
- Create: `audio_listen/Domain/Models/StringChoice.swift`
- Create: `audio_listen/Domain/Models/Instrument+StringChoices.swift`
- Test: `audio_listenTests/InstrumentStringChoicesTests.swift`

**Interfaces:**
- Consumes: `Instrument` (`strings: [GuitarString]`, `stringCount`), `GuitarString.openNote: Note`, `Note.midiNumber`, `Note.displayName` (e.g. `"E2"`), `NoteName.displayName` (e.g. `"E"`) — all already defined.
- Produces (relied on by Tasks 2 & 3):
  - `struct StringChoice: Identifiable, Equatable { let id: String; let label: String; let strings: Set<Int>; init(strings: Set<Int>, label: String) }` — `id` = `strings.sorted().map(String.init).joined(separator: "-")`.
  - `Instrument.singleStringChoices: [StringChoice]` — one per string, low-pitch → high.
  - `Instrument.cumulativeStringChoices: [StringChoice]` — `first 2 … first stringCount`, low → high (empty when `stringCount < 2`).
  - `Instrument.stringChoices: [StringChoice]` — `singleStringChoices + cumulativeStringChoices`.
  - `Instrument.defaultStringChoice: StringChoice` — the single lowest-pitch string.

- [ ] **Step 1: Write the `StringChoice` value type**

Create `audio_listen/Domain/Models/StringChoice.swift`:

```swift
import Foundation

struct StringChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let strings: Set<Int>

    init(strings: Set<Int>, label: String) {
        self.strings = strings
        self.label = label
        self.id = strings.sorted().map(String.init).joined(separator: "-")
    }
}
```

- [ ] **Step 2: Write the failing generator tests**

Create `audio_listenTests/InstrumentStringChoicesTests.swift`:

```swift
import Testing
@testable import audio_listen

struct InstrumentStringChoicesTests {
    private var guitar: Instrument { Instruments.guitar }

    private var bass: Instrument {
        Instrument(
            id: "bass",
            name: "Bass",
            strings: [
                Note(.g, octave: 2), Note(.d, octave: 2),
                Note(.a, octave: 1), Note(.e, octave: 1)
            ].map { GuitarString(openNote: $0, startFret: 0) },
            fretCount: 24
        )
    }

    @Test func guitarHasSixSinglesLowToHigh() {
        #expect(guitar.singleStringChoices.map(\.strings) == [[6], [5], [4], [3], [2], [1]])
    }

    @Test func guitarSingleLabelsDisambiguateDuplicateE() {
        #expect(guitar.singleStringChoices.map(\.label) == ["Low E", "A", "D", "G", "B", "High E"])
    }

    @Test func guitarCumulativeIsFirstTwoThroughSix() {
        #expect(guitar.cumulativeStringChoices.map(\.strings) == [
            [6, 5], [6, 5, 4], [6, 5, 4, 3], [6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 1]
        ])
    }

    @Test func guitarCumulativeLabelsAreNoteNamesLowToHigh() {
        #expect(guitar.cumulativeStringChoices.map(\.label) == [
            "E · A", "E · A · D", "E · A · D · G", "E · A · D · G · B", "E · A · D · G · B · E"
        ])
    }

    @Test func guitarDefaultIsLowestSingleString() {
        #expect(guitar.defaultStringChoice.strings == Set([6]))
    }

    @Test func guitarStringChoicesAreSinglesThenCumulative() {
        let choices = guitar.stringChoices
        #expect(choices.count == 11)
        #expect(choices.prefix(6).map(\.strings) == guitar.singleStringChoices.map(\.strings))
        #expect(choices.suffix(5).map(\.strings) == guitar.cumulativeStringChoices.map(\.strings))
    }

    @Test func choiceIdsAreUnique() {
        let ids = guitar.stringChoices.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func bassHasFourSinglesAndDefaultsToLowest() {
        #expect(bass.singleStringChoices.map(\.strings) == [[4], [3], [2], [1]])
        #expect(bass.defaultStringChoice.strings == Set([4]))
    }

    @Test func bassCumulativeIsFirstTwoThroughFour() {
        #expect(bass.cumulativeStringChoices.map(\.strings) == [[4, 3], [4, 3, 2], [4, 3, 2, 1]])
    }

    @Test func bassSingleLabelsAreUniqueNoteNames() {
        #expect(bass.singleStringChoices.map(\.label) == ["E", "A", "D", "G"])
    }

    @Test func threeSameNamesUseOctaveQualifiedLabels() {
        let triple = Instrument(
            id: "triple-e",
            name: "Triple E",
            strings: [
                Note(.e, octave: 4), Note(.e, octave: 3), Note(.e, octave: 2)
            ].map { GuitarString(openNote: $0, startFret: 0) },
            fretCount: 12
        )
        #expect(triple.singleStringChoices.map(\.label) == ["E2", "E3", "E4"])
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -40
```
Expected: **build failure** — `value of type 'Instrument' has no member 'singleStringChoices'` (the extension does not exist yet).

- [ ] **Step 4: Write the generators**

Create `audio_listen/Domain/Models/Instrument+StringChoices.swift`:

```swift
import Foundation

extension Instrument {
    var singleStringChoices: [StringChoice] {
        let ordered = stringsByPitch
        return ordered.map { entry in
            StringChoice(strings: [entry.number], label: singleLabel(for: entry.note, among: ordered))
        }
    }

    var cumulativeStringChoices: [StringChoice] {
        let ordered = stringsByPitch
        guard ordered.count >= 2 else { return [] }
        return (2...ordered.count).map { count in
            let included = ordered.prefix(count)
            let numbers = Set(included.map(\.number))
            let label = included.map { $0.note.name.displayName }.joined(separator: " · ")
            return StringChoice(strings: numbers, label: label)
        }
    }

    var stringChoices: [StringChoice] {
        singleStringChoices + cumulativeStringChoices
    }

    var defaultStringChoice: StringChoice {
        singleStringChoices.first ?? StringChoice(strings: [], label: "")
    }

    private var stringsByPitch: [(number: Int, note: Note)] {
        strings.enumerated()
            .map { (number: $0.offset + 1, note: $0.element.openNote) }
            .sorted { $0.note.midiNumber < $1.note.midiNumber }
    }

    private func singleLabel(for note: Note, among ordered: [(number: Int, note: Note)]) -> String {
        let sameName = ordered.filter { $0.note.name == note.name }
        switch sameName.count {
        case 1:
            return note.name.displayName
        case 2:
            let isLowest = sameName.first?.note.midiNumber == note.midiNumber
            return (isLowest ? "Low " : "High ") + note.name.displayName
        default:
            return note.displayName
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the same command as Step 3.
Expected: `** TEST SUCCEEDED **` with all 11 `InstrumentStringChoicesTests` passing and no regressions.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Domain/Models/StringChoice.swift \
        audio_listen/Domain/Models/Instrument+StringChoices.swift \
        audio_listenTests/InstrumentStringChoicesTests.swift
git commit -m "feat: derive string-choice presets from the instrument"
```

---

## Task 2: Per-instrument store (additive)

Add `load(for:)`/`save(for:)` and the per-instrument key **alongside** the existing `load()`/`save()`/`userDefaultsKey`, so every current caller keeps compiling. New tests live in a new struct; the old `GameAllowedStringsStoreTests` is untouched here (removed in Task 3).

**Files:**
- Modify: `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift`
- Modify: `audio_listenTests/audio_listenTests.swift` (append a new test struct)

**Interfaces:**
- Consumes: `Instrument.defaultStringChoice.strings`, `Instrument.stringCount`, `Instrument.id` (from Task 1).
- Produces (relied on by Task 3):
  - `static func GameAllowedStringsStore.userDefaultsKey(for instrument: Instrument) -> String` → `"audio_listen_allowed_strings.\(instrument.id)"`.
  - `func GameAllowedStringsStore.load(for instrument: Instrument) -> Set<Int>`.
  - `func GameAllowedStringsStore.save(_ strings: Set<Int>, for instrument: Instrument)`.

- [ ] **Step 1: Write the failing per-instrument store tests**

In `audio_listenTests/audio_listenTests.swift`, add this new struct immediately after the closing brace of the existing `GameAllowedStringsStoreTests` struct (after line 141):

```swift
// MARK: - GameAllowedStringsStore (per instrument)

struct PerInstrumentAllowedStringsStoreTests {
    private let guitar = Instruments.guitar
    private let bass = Instrument(
        id: "bass",
        name: "Bass",
        strings: [
            Note(.g, octave: 2), Note(.d, octave: 2),
            Note(.a, octave: 1), Note(.e, octave: 1)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 24
    )

    @Test func roundTripPersistsSubsetForInstrument() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        let original: Set<Int> = [1, 4, 6]
        store.save(original, for: guitar)
        #expect(store.load(for: guitar) == original)
    }

    @Test func keysAreIndependentAcrossInstruments() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        store.save([6, 5], for: guitar)
        store.save([4], for: bass)
        #expect(store.load(for: guitar) == Set([6, 5]))
        #expect(store.load(for: bass) == Set([4]))
    }

    @Test func missingKeyDefaultsToInstrumentDefaultChoice() {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load(for: guitar) == guitar.defaultStringChoice.strings)
        #expect(store.load(for: bass) == bass.defaultStringChoice.strings)
    }

    @Test func outOfRangeValuesClampToInstrumentRange() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        defaults.set(try JSONEncoder().encode([3, 5, 6]), forKey: GameAllowedStringsStore.userDefaultsKey(for: bass))
        #expect(store.load(for: bass) == Set([3]))
    }

    @Test func onlyOutOfRangeValuesFallBackToDefault() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GameAllowedStringsStore(defaults: defaults)
        defaults.set(try JSONEncoder().encode([7, 8, 99]), forKey: GameAllowedStringsStore.userDefaultsKey(for: bass))
        #expect(store.load(for: bass) == bass.defaultStringChoice.strings)
    }

    @Test func storedEmptyArrayLoadsAsEmptySet() throws {
        let suite = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite"); return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(try JSONEncoder().encode([Int]()), forKey: GameAllowedStringsStore.userDefaultsKey(for: guitar))
        let store = GameAllowedStringsStore(defaults: defaults)
        #expect(store.load(for: guitar).isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -40
```
Expected: **build failure** — `extra argument 'for' in call` / `type 'GameAllowedStringsStore' has no member 'userDefaultsKey(for:)'` (the per-instrument API does not exist yet).

- [ ] **Step 3: Add the per-instrument methods to the store**

Edit `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift`. Keep everything already there; insert the three new members. The full file becomes:

```swift
//
//  GameAllowedStringsStore.swift
//  audio_listen
//
//  Persists selected practice strings per instrument in UserDefaults as JSON array.
//

import Foundation

/// Loads and saves the set of strings allowed for game targets.
struct GameAllowedStringsStore {
    static let userDefaultsKey = "audio_listen_game_allowed_strings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_allowed_strings.\(instrument.id)"
    }

    /// Missing key, decode failure, or only out-of-range values → the instrument's default choice.
    /// Successfully stored empty array → empty set (no strings selected).
    func load(for instrument: Instrument) -> Set<Int> {
        let key = Self.userDefaultsKey(for: instrument)
        guard let data = defaults.data(forKey: key) else {
            return instrument.defaultStringChoice.strings
        }
        guard let stored = try? JSONDecoder().decode([Int].self, from: data) else {
            return instrument.defaultStringChoice.strings
        }
        let inRange = stored.filter { (1...instrument.stringCount).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            return stored.isEmpty ? [] : instrument.defaultStringChoice.strings
        }
        return set
    }

    func save(_ strings: Set<Int>, for instrument: Instrument) {
        let key = Self.userDefaultsKey(for: instrument)
        let sorted = strings.filter { (1...instrument.stringCount).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: key)
    }

    /// Missing key, decode failure, or only out-of-range values → default strings (E and A).
    /// Successfully stored empty array → empty set (no strings selected).
    func load() -> Set<Int> {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return StringSetPresets.defaultStrings
        }
        guard let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return StringSetPresets.defaultStrings
        }
        let inRange = arr.filter { (1...Instruments.guitar.stringCount).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            if arr.isEmpty {
                return []
            }
            return StringSetPresets.defaultStrings
        }
        return set
    }

    func save(_ strings: Set<Int>) {
        let sorted = strings.filter { (1...Instruments.guitar.stringCount).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2.
Expected: `** TEST SUCCEEDED **` — the 6 new `PerInstrumentAllowedStringsStoreTests` pass and the existing `GameAllowedStringsStoreTests` still pass.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift \
        audio_listenTests/audio_listenTests.swift
git commit -m "feat: add per-instrument load/save to GameAllowedStringsStore"
```

---

## Task 3: Switch consumers over and delete `StringSetPresets`

Migrate the provider, container, and drill picker to the per-instrument API and the instrument-derived choices; then remove the now-dead global-key methods, `StringSetPresets`, and its tests. Everything lands together because removing the old store methods breaks their remaining callers at compile time.

**Files:**
- Modify: `audio_listen/Infrastructure/Game/UserDefaultsAllowedStringsProvider.swift`
- Modify: `audio_listen/DI/AppDependencyContainer.swift:27`
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`
- Modify: `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift` (remove old-API members)
- Modify: `audio_listenTests/audio_listenTests.swift` (remove old `GameAllowedStringsStoreTests`)
- Delete: `audio_listen/Infrastructure/Game/StringSetPresets.swift`
- Delete: `audio_listenTests/StringSetPresetsTests.swift`

**Interfaces:**
- Consumes: `GameAllowedStringsStore.load(for:)`/`save(for:)` (Task 2), `Instrument.stringChoices`/`singleStringChoices`/`cumulativeStringChoices`/`defaultStringChoice` (Task 1).
- Produces: `UserDefaultsAllowedStringsProvider.init(store:instrument:)` — the only signature change other tasks/files would notice.

- [ ] **Step 1: Make the provider instrument-aware**

Replace the body of `audio_listen/Infrastructure/Game/UserDefaultsAllowedStringsProvider.swift` with:

```swift
//
//  UserDefaultsAllowedStringsProvider.swift
//  audio_listen
//
//  Bridges `GameAllowedStringsStore` to `AllowedStringsProviding` for one instrument.
//

import Foundation

struct UserDefaultsAllowedStringsProvider: AllowedStringsProviding {
    private let store: GameAllowedStringsStore
    private let instrument: Instrument

    init(store: GameAllowedStringsStore, instrument: Instrument) {
        self.store = store
        self.instrument = instrument
    }

    var allowedStrings: Set<Int> {
        store.load(for: instrument)
    }
}
```

- [ ] **Step 2: Wire the provider with the instrument in the container**

In `audio_listen/DI/AppDependencyContainer.swift`, change line 27 from:

```swift
        allowedStringsProvider = UserDefaultsAllowedStringsProvider(store: allowedStringsStore)
```

to:

```swift
        allowedStringsProvider = UserDefaultsAllowedStringsProvider(store: allowedStringsStore, instrument: instrument)
```

(`instrument` is the container's stored `let instrument: Instrument = Instruments.guitar`, available in `init`.)

- [ ] **Step 3: Migrate `DrillView` to instrument-derived choices**

Apply four edits to `audio_listen/Presentation/Drill/DrillView.swift`.

**3a.** Change the `allowedStrings` state default (line 8) from:

```swift
    @State private var allowedStrings: Set<Int> = StringSetPresets.defaultStrings
```

to:

```swift
    @State private var allowedStrings: Set<Int> = []
```

**3b.** Replace the `stringChoiceSelection` computed binding (lines 26–35) with:

```swift
    private var stringChoiceSelection: Binding<String> {
        Binding(
            get: { instrument.stringChoices.first { $0.strings == allowedStrings }?.id ?? instrument.defaultStringChoice.id },
            set: { id in
                guard let choice = instrument.stringChoices.first(where: { $0.id == id }) else { return }
                allowedStrings = choice.strings
                allowedStringsStore.save(choice.strings, for: instrument)
            }
        )
    }
```

**3c.** Replace the initializer (lines 37–41) with one that seeds `allowedStrings` from the per-instrument store:

```swift
    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore, instrument: Instrument = Instruments.guitar) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
        self.instrument = instrument
        _allowedStrings = State(initialValue: allowedStringsStore.load(for: instrument))
    }
```

**3d.** Change the `.onAppear` load (line 63) from:

```swift
        .onAppear { allowedStrings = allowedStringsStore.load() }
```

to:

```swift
        .onAppear { allowedStrings = allowedStringsStore.load(for: instrument) }
```

**3e.** Replace the picker sections (lines 181–188) from:

```swift
            Picker("Strings", selection: stringChoiceSelection) {
                Section("Presets") {
                    ForEach(StringSetPresets.all) { Text($0.label).tag($0.id) }
                }
                Section("Single string") {
                    ForEach(StringSetPresets.singles) { Text($0.label).tag($0.id) }
                }
            }
```

to:

```swift
            Picker("Strings", selection: stringChoiceSelection) {
                Section("Single string") {
                    ForEach(instrument.singleStringChoices) { Text($0.label).tag($0.id) }
                }
                Section("Cumulative") {
                    ForEach(instrument.cumulativeStringChoices) { Text($0.label).tag($0.id) }
                }
            }
```

- [ ] **Step 4: Remove the old-API members from the store**

Replace the full contents of `audio_listen/Infrastructure/Game/GameAllowedStringsStore.swift` with (old `userDefaultsKey` constant, `load()`, and `save(_:)` gone):

```swift
//
//  GameAllowedStringsStore.swift
//  audio_listen
//
//  Persists selected practice strings per instrument in UserDefaults as JSON array.
//

import Foundation

/// Loads and saves the set of strings allowed for game targets, keyed per instrument.
struct GameAllowedStringsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_allowed_strings.\(instrument.id)"
    }

    /// Missing key, decode failure, or only out-of-range values → the instrument's default choice.
    /// Successfully stored empty array → empty set (no strings selected).
    func load(for instrument: Instrument) -> Set<Int> {
        let key = Self.userDefaultsKey(for: instrument)
        guard let data = defaults.data(forKey: key) else {
            return instrument.defaultStringChoice.strings
        }
        guard let stored = try? JSONDecoder().decode([Int].self, from: data) else {
            return instrument.defaultStringChoice.strings
        }
        let inRange = stored.filter { (1...instrument.stringCount).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            return stored.isEmpty ? [] : instrument.defaultStringChoice.strings
        }
        return set
    }

    func save(_ strings: Set<Int>, for instrument: Instrument) {
        let key = Self.userDefaultsKey(for: instrument)
        let sorted = strings.filter { (1...instrument.stringCount).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 5: Remove the old store tests**

In `audio_listenTests/audio_listenTests.swift`, delete the entire old `GameAllowedStringsStoreTests` struct — the `// MARK: - GameAllowedStringsStore` comment (line 86) through the struct's closing brace (line 141) — because it calls the removed `load()`/`save(_:)`/`userDefaultsKey` and references `StringSetPresets.defaultStrings`. Leave the `PerInstrumentAllowedStringsStoreTests` struct (added in Task 2) in place; it is the replacement.

- [ ] **Step 6: Delete `StringSetPresets` and its tests**

```bash
git rm audio_listen/Infrastructure/Game/StringSetPresets.swift \
       audio_listenTests/StringSetPresetsTests.swift
```

- [ ] **Step 7: Verify no `StringSetPresets` references remain**

Run:
```bash
grep -rn "StringSetPresets" audio_listen audio_listenTests --include="*.swift"
```
Expected: **no output** (zero matches).

- [ ] **Step 8: Build and run the full unit-test suite**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -40
```
Expected: `** TEST SUCCEEDED **` — `InstrumentStringChoicesTests` and `PerInstrumentAllowedStringsStoreTests` pass, all pre-existing suites stay green, and no reference to the deleted symbols remains.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: drive string presets from the instrument, drop StringSetPresets"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-04-instrument-string-presets-design.md`):

- `StringChoice` value type with derived `id` → Task 1, Step 1. ✓
- `singleStringChoices` / `cumulativeStringChoices` / `stringChoices` / `defaultStringChoice` generators → Task 1, Step 4. ✓
- String ordering by pitch, number = index+1, guitar `[6,5,4,3,2,1]` → `stringsByPitch` + `guitarHasSixSinglesLowToHigh`. ✓
- Cumulative `first 2 … stringCount`, guitar `{6,5}`…`all` → `cumulativeStringChoices` + `guitarCumulativeIsFirstTwoThroughSix`. ✓
- Default = single lowest, guitar `{6}` → `defaultStringChoice` + `guitarDefaultIsLowestSingleString`. ✓
- Cumulative labels note names low→high joined `" · "` → `guitarCumulativeLabelsAreNoteNamesLowToHigh`. ✓
- Single labels: unique→name, two→Low/High, 3+→note+octave → `singleLabel` + `guitarSingleLabelsDisambiguateDuplicateE`, `bassSingleLabelsAreUniqueNoteNames`, `threeSameNamesUseOctaveQualifiedLabels`. ✓
- Per-instrument key `audio_listen_allowed_strings.<id>`, no migration → Task 2, Step 3 (`userDefaultsKey(for:)`). ✓
- Fallback/validation: missing/decode-fail/empty-after-clamp → default; clamp to `1...stringCount`; stored empty array → empty set → `load(for:)` + the store tests. ✓
- Provider/protocol: provider gains instrument, `AllowedStringsProviding` unchanged → Task 3, Step 1 (protocol file not touched). ✓
- Container wires with `instrument` → Task 3, Step 2. ✓
- `DrillView` picker reads `singleStringChoices`/`cumulativeStringChoices`, default `defaultStringChoice`, save/load per instrument, loop unchanged → Task 3, Step 3. ✓
- Delete `StringSetPresets.swift` and `StringSetPresetsTests.swift` → Task 3, Step 6. ✓
- Tests: guitar + synthetic bass + 3+ duplicate edge + store independence → Tasks 1 & 2. ✓
- Out of scope (picker UI, bass wiring, `SelectedInstrumentStore`, per-instrument note/fret settings, toggle) — not planned. ✓

**2. Placeholder scan:** No TBD/TODO/"add error handling"/"similar to Task N"/"write tests for the above" — every code and test block is complete. ✓

**3. Type consistency:** `StringChoice(strings:label:)`, `.strings`, `.label`, `.id`, `singleStringChoices`, `cumulativeStringChoices`, `stringChoices`, `defaultStringChoice`, `userDefaultsKey(for:)`, `load(for:)`, `save(_:for:)`, and `UserDefaultsAllowedStringsProvider.init(store:instrument:)` are spelled identically across Tasks 1→2→3 and the tests that consume them. The synthetic bass definition (`id:"bass"`, G2/D2/A1/E1, `fretCount:24`, default `{4}`) is identical in `InstrumentStringChoicesTests` and `PerInstrumentAllowedStringsStoreTests`. ✓
