# Instrument Picker + Per-Instrument Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bass instrument and a settings picker to switch instruments, with drill progress, daily history, and the belt all keyed per `instrument.id` so each instrument keeps its own correct progress.

**Architecture:** Per-instrument state lives in thin, stateless repositories keyed by `instrument.id` (the shape `GameAllowedStringsStore` already has). The container resolves a `currentInstrument` from a `SelectedInstrumentStore`; switching rebuilds the Drill and Progress views via SwiftUI `.id` identity (recreation, not mutation). Storage changes land additively first (new methods beside old), then consumers flip, then the dead old API is removed — so every task compiles.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`, `Issue.record`), Xcode project `audio_listen.xcodeproj` (NOT SPM), UserDefaults persistence.

## Global Constraints

- **No comments** — code must be self-documenting. Existing `///` doc-comments and file-header blocks are the codebase convention and may stay; do not add explanatory `//` comments.
- **New/deleted `.swift` files auto-included** via `PBXFileSystemSynchronizedRootGroup`. Creating a file = it compiles; deleting = `git rm`. Never edit `project.pbxproj`.
- **Tests use Swift Testing** (`import Testing`, `@Test`, `#expect`), never XCTest.
- **Build/test command** (macOS destination avoids simulator clones; `-only-testing:audio_listenTests` skips the flaky UI-test target). Run it in the **foreground**, one invocation, then read the tail — never background/poll:
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -project audio_listen.xcodeproj -scheme audio_listen \
    -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -40
  ```
  Success line: `** TEST SUCCEEDED **`.
- **SourceKit false positives:** cross-file "Cannot find type X in scope" / "No such module 'Testing'" editor diagnostics are NOT authoritative — `xcodebuild` is. Trust only the `xcodebuild` result.
- **No migration:** per-instrument progress/history keys start empty; the old global keys `audio_listen_drill_progress` / `audio_listen_daily_history` are abandoned (existing progress is lost by design).
- **Bass:** `id: "bass"`, `name: "Bass"`, tuning E1–A1–D2–G2 (string 4 = low E1, string 1 = G2), `fretCount: 21`.
- **Key formats (verbatim):** `audio_listen_drill_progress.<id>`, `audio_listen_daily_history.<id>`, `audio_listen_selected_instrument`.
- **Belt universe:** `DrillTuning.universeSize(for: instrument) = instrument.stringCount * 12` (guitar 72, bass 48).

---

## File Structure

| File | Responsibility |
|---|---|
| `audio_listen/Domain/Models/Instruments.swift` | **mod** — add `bass`, `all = [guitar, bass]` |
| `audio_listen/Domain/Models/DrillTuning.swift` | **mod** — `universeSize(for:)`, drop `totalItemCount` |
| `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift` | **mod** — `loadAll(for:)` / `save(_:for:)` |
| `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift` | **mod** — per-instrument key |
| `audio_listen/Infrastructure/Game/DailyHistoryStore.swift` | **mod** — `for:` on all methods, per-instrument key |
| `audio_listen/Infrastructure/Game/SelectedInstrumentStore.swift` | **new** — selected-instrument persistence |
| `audio_listen/DI/AppDependencyContainer.swift` | **mod** — `currentInstrument`; provider wiring in `makeDrillViewModel` |
| `audio_listen/Presentation/Drill/DrillViewModel.swift` | **mod** — pass `for: instrument`; `universeSize(for:)` |
| `audio_listen/Presentation/Drill/MasteryView.swift` | **mod** — inject instrument; per-instrument reads |
| `audio_listen/Presentation/Settings/InstrumentPicker.swift` | **new** — bar-of-dots selector |
| `audio_listen/Presentation/Settings/SettingsView.swift` | **mod** — Instrument section |
| `audio_listen/ContentView.swift` | **mod** — pass `currentInstrument`; `.id` includes instrument |
| `audio_listenTests/*` | **mod/new** — per task |

`DrillView` needs no change (already takes `instrument`; its string picker already derives from it). `GameAllowedStringsStore` / `AllowedStringsProviding` unchanged.

---

## Task 1: Add the bass instrument

Purely additive: extend the catalog. Everything downstream already derives from `Instrument`.

**Files:**
- Modify: `audio_listen/Domain/Models/Instruments.swift`
- Test: `audio_listenTests/InstrumentsCatalogTests.swift` (new)

**Interfaces:**
- Produces: `Instruments.bass: Instrument` (4 strings, `fretCount: 21`), `Instruments.all == [guitar, bass]`.

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/InstrumentsCatalogTests.swift`:

```swift
import Testing
@testable import audio_listen

struct InstrumentsCatalogTests {
    @Test func catalogIsGuitarThenBass() {
        #expect(Instruments.all.map(\.id) == ["guitar", "bass"])
    }

    @Test func bassIsFourStringStandardTuning() {
        let bass = Instruments.bass
        #expect(bass.stringCount == 4)
        #expect(bass.fretCount == 21)
        #expect(bass.note(at: 4, fret: 0) == Note(.e, octave: 1))
        #expect(bass.note(at: 3, fret: 0) == Note(.a, octave: 1))
        #expect(bass.note(at: 2, fret: 0) == Note(.d, octave: 2))
        #expect(bass.note(at: 1, fret: 0) == Note(.g, octave: 2))
    }

    @Test func bassDefaultStringChoiceIsLowestString() {
        #expect(Instruments.bass.defaultStringChoice.strings == Set([4]))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the build/test command from Global Constraints.
Expected: **build failure** — `type 'Instruments' has no member 'bass'`.

- [ ] **Step 3: Add bass to the catalog**

Replace the contents of `audio_listen/Domain/Models/Instruments.swift`:

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

    static let bass = Instrument(
        id: "bass",
        name: "Bass",
        strings: [
            Note(.g, octave: 2), Note(.d, octave: 2), Note(.a, octave: 1), Note(.e, octave: 1)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 21
    )

    static let all: [Instrument] = [guitar, bass]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the build/test command. Expected: `** TEST SUCCEEDED **`, the 3 new `InstrumentsCatalogTests` pass, no regressions.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/Instruments.swift audio_listenTests/InstrumentsCatalogTests.swift
git commit -m "feat: add bass to the instrument catalog"
```

---

## Task 2: Instrument-derived belt universe (additive)

Add `universeSize(for:)` **beside** `totalItemCount` (removed in Task 8). No consumer changes yet.

**Files:**
- Modify: `audio_listen/Domain/Models/DrillTuning.swift`
- Test: `audio_listenTests/DrillTuningTests.swift`

**Interfaces:**
- Produces: `DrillTuning.universeSize(for instrument: Instrument) -> Int` → `instrument.stringCount * 12`.

- [ ] **Step 1: Write the failing test**

Add this test to `audio_listenTests/DrillTuningTests.swift`, inside the existing `struct DrillTuningTests` (after the `valuesAreStable` test):

```swift
    @Test func universeSizeScalesWithStringCount() {
        #expect(DrillTuning.universeSize(for: Instruments.guitar) == 72)
        #expect(DrillTuning.universeSize(for: Instruments.bass) == 48)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run the build/test command.
Expected: **build failure** — `type 'DrillTuning' has no member 'universeSize'`.

- [ ] **Step 3: Add the helper**

Replace the contents of `audio_listen/Domain/Models/DrillTuning.swift`:

```swift
import Foundation

enum DrillTuning {
    static let maxBox = 4
    static let fastReactionSeconds: TimeInterval = 3.0
    static let totalItemCount = 6 * 12

    static func universeSize(for instrument: Instrument) -> Int {
        instrument.stringCount * 12
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run the build/test command. Expected: `** TEST SUCCEEDED **`; `universeSizeScalesWithStringCount` passes and `valuesAreStable` still passes.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/DrillTuning.swift audio_listenTests/DrillTuningTests.swift
git commit -m "feat: add instrument-derived belt universe size"
```

---

## Task 3: `SelectedInstrumentStore`

New store persisting which instrument is active. Additive; nothing consumes it yet.

**Files:**
- Create: `audio_listen/Infrastructure/Game/SelectedInstrumentStore.swift`
- Test: `audio_listenTests/SelectedInstrumentStoreTests.swift` (new)

**Interfaces:**
- Produces: `SelectedInstrumentStore.userDefaultsKey == "audio_listen_selected_instrument"`;
  `init(defaults:)`; `var selectedInstrument: Instrument` (unknown/missing id → guitar);
  `func save(_ id: String)`.

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/SelectedInstrumentStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import audio_listen

struct SelectedInstrumentStoreTests {
    private func makeStore() -> (SelectedInstrumentStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SelectedInstrumentStore(defaults: defaults), defaults, suite)
    }

    @Test func missingKeyDefaultsToGuitar() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.selectedInstrument.id == "guitar")
    }

    @Test func roundTripsSavedInstrumentId() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save("bass")
        #expect(store.selectedInstrument.id == "bass")
    }

    @Test func unknownIdFallsBackToGuitar() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save("theremin")
        #expect(store.selectedInstrument.id == "guitar")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the build/test command.
Expected: **build failure** — `cannot find 'SelectedInstrumentStore' in scope`.

- [ ] **Step 3: Create the store**

Create `audio_listen/Infrastructure/Game/SelectedInstrumentStore.swift`:

```swift
import Foundation

struct SelectedInstrumentStore {
    static let userDefaultsKey = "audio_listen_selected_instrument"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedInstrument: Instrument {
        let id = defaults.string(forKey: Self.userDefaultsKey)
        return Instruments.all.first { $0.id == id } ?? Instruments.guitar
    }

    func save(_ id: String) {
        defaults.set(id, forKey: Self.userDefaultsKey)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the build/test command. Expected: `** TEST SUCCEEDED **`, the 3 new tests pass.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Infrastructure/Game/SelectedInstrumentStore.swift audio_listenTests/SelectedInstrumentStoreTests.swift
git commit -m "feat: add SelectedInstrumentStore for the active instrument"
```

---

## Task 4: Per-instrument progress repository (additive)

Add `loadAll(for:)` / `save(_:for:)` and `userDefaultsKey(for:)` **beside** the existing global-key methods (removed in Task 8). The single conformer is `UserDefaultsDrillProgressRepository` (there is no separate mock).

**Files:**
- Modify: `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift`
- Modify: `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`
- Test: `audio_listenTests/DrillProgressRepositoryTests.swift`

**Interfaces:**
- Produces: `DrillProgressRepositoryProtocol.loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]`,
  `save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)`;
  `UserDefaultsDrillProgressRepository.userDefaultsKey(for: Instrument) -> String` → `"audio_listen_drill_progress.<id>"`.

- [ ] **Step 1: Write the failing tests**

Add these tests to `audio_listenTests/DrillProgressRepositoryTests.swift`, inside the existing `struct DrillProgressRepositoryTests` (after `corruptDataLoadsEmpty`):

```swift
    @Test func perInstrumentKeysAreIndependent() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        let key = DrillItemKey(noteName: .g, string: 3)
        let stats = ItemStats(box: 2, attempts: 3, correct: 2, lastReactionTime: 1.0, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        repo.save([key: stats], for: Instruments.guitar)
        #expect(repo.loadAll(for: Instruments.guitar) == [key: stats])
        #expect(repo.loadAll(for: Instruments.bass).isEmpty)
    }

    @Test func missingPerInstrumentKeyLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll(for: Instruments.guitar).isEmpty)
    }

    @Test func corruptPerInstrumentDataLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: UserDefaultsDrillProgressRepository.userDefaultsKey(for: Instruments.guitar))
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll(for: Instruments.guitar).isEmpty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the build/test command.
Expected: **build failure** — `extra argument 'for' in call` / no member `userDefaultsKey(for:)`.

- [ ] **Step 3: Add the protocol methods**

Replace the contents of `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift`:

```swift
protocol DrillProgressRepositoryProtocol {
    func loadAll() -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats])
    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)
}
```

- [ ] **Step 4: Add the implementation**

Replace the contents of `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`:

```swift
import Foundation

struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol {
    static let userDefaultsKey = "audio_listen_drill_progress"

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_drill_progress.\(instrument.id)"
    }

    private struct Entry: Codable {
        let key: DrillItemKey
        let stats: ItemStats
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll() -> [DrillItemKey: ItemStats] {
        decode(defaults.data(forKey: Self.userDefaultsKey))
    }

    func save(_ stats: [DrillItemKey: ItemStats]) {
        encode(stats, forKey: Self.userDefaultsKey)
    }

    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats] {
        decode(defaults.data(forKey: Self.userDefaultsKey(for: instrument)))
    }

    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument) {
        encode(stats, forKey: Self.userDefaultsKey(for: instrument))
    }

    private func decode(_ data: Data?) -> [DrillItemKey: ItemStats] {
        guard let data, let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        return Dictionary(entries.map { ($0.key, $0.stats) }, uniquingKeysWith: { _, last in last })
    }

    private func encode(_ stats: [DrillItemKey: ItemStats], forKey key: String) {
        let entries = stats.map { Entry(key: $0.key, stats: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run the build/test command. Expected: `** TEST SUCCEEDED **`; the 3 new tests pass and the existing `missingKeyLoadsEmpty`/`roundTripsStats`/`corruptDataLoadsEmpty` still pass (old methods retained).

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift \
        audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift \
        audio_listenTests/DrillProgressRepositoryTests.swift
git commit -m "feat: add per-instrument load/save to the drill progress repository"
```

---

## Task 5: Per-instrument daily history (additive)

Add `for instrument:` variants of every `DailyHistoryStore` method **beside** the existing ones (removed in Task 8). Refactor the private load/save to take a key.

**Files:**
- Modify: `audio_listen/Infrastructure/Game/DailyHistoryStore.swift`
- Test: `audio_listenTests/DailyHistoryStoreTests.swift`

**Interfaces:**
- Produces: `DailyHistoryStore.userDefaultsKey(for: Instrument) -> String` → `"audio_listen_daily_history.<id>"`;
  `history(for instrument: Instrument) -> [DailyRecord]`;
  `todayReps(for instrument: Instrument, now: Date) -> Int`;
  `recordCorrect(for instrument: Instrument, now: Date, reactionTime: TimeInterval, masteredCount: Int)` (Void).

- [ ] **Step 1: Write the failing tests**

Add these tests to `audio_listenTests/DailyHistoryStoreTests.swift`, inside `struct DailyHistoryStoreTests` (after `corruptDataIsEmpty`):

```swift
    @Test func perInstrumentHistoryIsIndependent() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.recordCorrect(for: Instruments.guitar, now: day1, reactionTime: 2.0, masteredCount: 1)
        store.recordCorrect(for: Instruments.bass, now: day1, reactionTime: 1.0, masteredCount: 0)
        store.recordCorrect(for: Instruments.bass, now: day1, reactionTime: 1.0, masteredCount: 0)
        #expect(store.todayReps(for: Instruments.guitar, now: day1) == 1)
        #expect(store.todayReps(for: Instruments.bass, now: day1) == 2)
    }

    @Test func perInstrumentMissingHistoryIsEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.history(for: Instruments.bass).isEmpty)
        #expect(store.todayReps(for: Instruments.bass, now: day1) == 0)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the build/test command.
Expected: **build failure** — `extra argument 'for' in call`.

- [ ] **Step 3: Add the per-instrument methods**

Replace the contents of `audio_listen/Infrastructure/Game/DailyHistoryStore.swift`:

```swift
import Foundation

struct DailyRecord: Codable, Equatable {
    var dayStart: Date
    var reps: Int
    var reactionSum: TimeInterval
    var reactionCount: Int
    var masteredSnapshot: Int

    var averageReaction: Double {
        reactionCount == 0 ? 0 : reactionSum / Double(reactionCount)
    }
}

struct DailyHistoryStore {
    static let userDefaultsKey = "audio_listen_daily_history"

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_daily_history.\(instrument.id)"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func history() -> [DailyRecord] {
        load(Self.userDefaultsKey).sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(now: Date) -> Int {
        load(Self.userDefaultsKey).first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    func recordCorrect(now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        record(forKey: Self.userDefaultsKey, now: now, reactionTime: reactionTime, masteredCount: masteredCount)
    }

    func history(for instrument: Instrument) -> [DailyRecord] {
        load(Self.userDefaultsKey(for: instrument)).sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(for instrument: Instrument, now: Date) -> Int {
        load(Self.userDefaultsKey(for: instrument)).first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    func recordCorrect(for instrument: Instrument, now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        record(forKey: Self.userDefaultsKey(for: instrument), now: now, reactionTime: reactionTime, masteredCount: masteredCount)
    }

    private func record(forKey key: String, now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        var records = load(key)
        if let index = records.firstIndex(where: { calendar.isDate($0.dayStart, inSameDayAs: now) }) {
            records[index].reps += 1
            records[index].reactionSum += reactionTime
            records[index].reactionCount += 1
            records[index].masteredSnapshot = masteredCount
            save(records, forKey: key)
            return
        }
        let record = DailyRecord(
            dayStart: calendar.startOfDay(for: now),
            reps: 1,
            reactionSum: reactionTime,
            reactionCount: 1,
            masteredSnapshot: masteredCount
        )
        records.append(record)
        save(records, forKey: key)
    }

    private func load(_ key: String) -> [DailyRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([DailyRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [DailyRecord], forKey key: String) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the build/test command. Expected: `** TEST SUCCEEDED **`; the 2 new tests pass and all existing `DailyHistoryStoreTests` still pass (old methods retained, now delegating to the shared `record`/`load`/`save` helpers).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Infrastructure/Game/DailyHistoryStore.swift audio_listenTests/DailyHistoryStoreTests.swift
git commit -m "feat: add per-instrument daily history"
```

---

## Task 6: Flip Drill + Progress to per-instrument reads

Behavior-preserving switch of the live consumers to the per-instrument API and `universeSize(for:)`. Guitar behavior is identical; the old global-key methods and `totalItemCount` become unused (removed in Task 8). Verified by the regression suite.

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillViewModel.swift`
- Modify: `audio_listen/Presentation/Drill/MasteryView.swift`
- Modify: `audio_listen/ContentView.swift`
- Test: `audio_listenTests/DrillViewModelTests.swift`

**Interfaces:**
- Consumes: `loadAll(for:)`/`save(_:for:)` (Task 4), `history(for:)`/`todayReps(for:)`/`recordCorrect(for:)` (Task 5), `DrillTuning.universeSize(for:)` (Task 2).
- Produces: `MasteryView.init(progressRepository:dailyHistoryStore:instrument:masteredBox:)` — new `instrument` parameter (no default).

- [ ] **Step 1: Update the affected test call sites (they will fail to compile until the code flips)**

In `audio_listenTests/DrillViewModelTests.swift`, change the five progress-repo reads and the one history read to per-instrument (the view models under test use the default `instrument: Instruments.guitar`, so they write to guitar's keys):

- Line 148: `#expect(repo.loadAll()[key]?.correct == 1)` → `#expect(repo.loadAll(for: Instruments.guitar)[key]?.correct == 1)`
- Line 169: `#expect(repo.loadAll()[key]?.attempts == 1)` → `#expect(repo.loadAll(for: Instruments.guitar)[key]?.attempts == 1)`
- Line 170: `#expect(repo.loadAll()[key]?.correct == 0)` → `#expect(repo.loadAll(for: Instruments.guitar)[key]?.correct == 0)`
- Line 193: `let beforeAttempts = repo.loadAll()[key]?.attempts ?? 0` → `let beforeAttempts = repo.loadAll(for: Instruments.guitar)[key]?.attempts ?? 0`
- Line 196: `let afterAttempts = repo.loadAll()[key]?.attempts ?? 0` → `let afterAttempts = repo.loadAll(for: Instruments.guitar)[key]?.attempts ?? 0`
- Line 242: `#expect(history.todayReps(now: clock.now()) == 1)` → `#expect(history.todayReps(for: Instruments.guitar, now: clock.now()) == 1)`

- [ ] **Step 2: Run the suite to verify it fails**

Run the build/test command.
Expected: the suite **builds** (the `for:` methods exist from Tasks 4–5) but **two tests fail**: `correctNoteTransitionsToSuccessAndRecordsReaction` and `correctAnswerRecordsDailyHistory`. The assertions now read guitar's per-instrument key while `DrillViewModel` still writes the global key, so the loaded stats are empty / `todayReps == 0`. This is the RED that Step 3 fixes.

- [ ] **Step 3: Flip `DrillViewModel` to per-instrument**

In `audio_listen/Presentation/Drill/DrillViewModel.swift`, make these edits (line numbers from the current file):

Line 71–72 (in `init`):
```swift
        self.todayCount = dailyHistoryStore.todayReps(for: instrument, now: clock.now())
        self.beltRank = BeltRank.from(stats: progressRepository.loadAll(for: instrument), maxBox: DrillTuning.maxBox, universeSize: DrillTuning.universeSize(for: instrument))
```

Line 127 (in `nextPrompt()`):
```swift
            stats: progressRepository.loadAll(for: instrument),
```

Replace the whole `recordCorrect(for:reactionTime:)` body (lines 201–210) with:
```swift
    private func recordCorrect(for prompt: DrillPrompt, reactionTime: TimeInterval) {
        var all = progressRepository.loadAll(for: instrument)
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyCorrect(to: current, reactionTime: reactionTime, now: clock.now())
        progressRepository.save(all, for: instrument)
        let mastered = all.values.filter { $0.box >= DrillTuning.maxBox }.count
        dailyHistoryStore.recordCorrect(for: instrument, now: clock.now(), reactionTime: reactionTime, masteredCount: mastered)
        todayCount = dailyHistoryStore.todayReps(for: instrument, now: clock.now())
        beltRank = BeltRank.from(stats: all, maxBox: DrillTuning.maxBox, universeSize: DrillTuning.universeSize(for: instrument))
    }
```

Replace the whole `recordMiss(for:)` body (lines 212–217) with:
```swift
    private func recordMiss(for prompt: DrillPrompt) {
        var all = progressRepository.loadAll(for: instrument)
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyMiss(to: current, now: clock.now())
        progressRepository.save(all, for: instrument)
    }
```

- [ ] **Step 4: Flip `MasteryView` to per-instrument**

In `audio_listen/Presentation/Drill/MasteryView.swift`:

Add the stored property after `private let masteredBox: Int` (line 5):
```swift
    private let instrument: Instrument
```

Change the `beltRank` state declaration (line 9) from an initialized default to an uninitialized property:
```swift
    @State private var beltRank: BeltRank
```

Replace the initializer (lines 13–17) with:
```swift
    init(progressRepository: DrillProgressRepositoryProtocol, dailyHistoryStore: DailyHistoryStore, instrument: Instrument, masteredBox: Int = DrillTuning.maxBox) {
        self.progressRepository = progressRepository
        self.dailyHistoryStore = dailyHistoryStore
        self.instrument = instrument
        self.masteredBox = masteredBox
        _beltRank = State(initialValue: BeltRank.from(stats: [:], maxBox: masteredBox, universeSize: DrillTuning.universeSize(for: instrument)))
    }
```

In `reload()` (lines 72–93), change the four reads. Replace:
```swift
        let stats = progressRepository.loadAll()
        let universe = SelectNextPromptUseCase().candidates(
            allowedStrings: Set(1...Instruments.guitar.stringCount),
            allowedNoteNames: Set(NoteName.allCases),
            maxFretInclusive: 11
        )
```
with:
```swift
        let stats = progressRepository.loadAll(for: instrument)
        let universe = SelectNextPromptUseCase().candidates(
            allowedStrings: Set(1...instrument.stringCount),
            allowedNoteNames: Set(NoteName.allCases),
            maxFretInclusive: 11
        )
```
and replace:
```swift
        beltRank = BeltRank.from(stats: stats, maxBox: masteredBox, universeSize: DrillTuning.totalItemCount)
        history = dailyHistoryStore.history()
```
with:
```swift
        beltRank = BeltRank.from(stats: stats, maxBox: masteredBox, universeSize: DrillTuning.universeSize(for: instrument))
        history = dailyHistoryStore.history(for: instrument)
```

- [ ] **Step 5: Pass the instrument to `MasteryView` in `ContentView`**

In `audio_listen/ContentView.swift`, both `MasteryView(...)` call sites (the macOS `TabView` path ~line 33 and the iOS `screen(for:)` path ~line 60) currently read:
```swift
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore
            )
```
Change **both** to add the instrument (still `container.instrument`, which stays guitar until Task 7):
```swift
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore,
                instrument: container.instrument
            )
```

- [ ] **Step 6: Run the suite to verify it passes**

Run the build/test command. Expected: `** TEST SUCCEEDED **`; `correctNoteTransitionsToSuccessAndRecordsReaction` and `correctAnswerRecordsDailyHistory` now pass (VM writes and test reads both use guitar's per-instrument keys), and the full suite is green.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillViewModel.swift \
        audio_listen/Presentation/Drill/MasteryView.swift \
        audio_listen/ContentView.swift \
        audio_listenTests/DrillViewModelTests.swift
git commit -m "refactor: drive drill + progress reads from the injected instrument"
```

---

## Task 7: Instrument switching — container seam, picker, and reactive rebuild

Wire the actual switch: the container resolves `currentInstrument`; a Settings picker writes the selected id; `ContentView` rebuilds Drill + Progress on change via `.id`. This is UI/DI wiring — verified by build + the full regression suite (the resolution logic itself is covered by `SelectedInstrumentStoreTests`).

**Files:**
- Modify: `audio_listen/DI/AppDependencyContainer.swift`
- Create: `audio_listen/Presentation/Settings/InstrumentPicker.swift`
- Modify: `audio_listen/Presentation/Settings/SettingsView.swift`
- Modify: `audio_listen/ContentView.swift`

**Interfaces:**
- Consumes: `SelectedInstrumentStore` (Task 3), `Instruments.all` (Task 1).
- Produces: `AppDependencyContainer.currentInstrument: Instrument`; `InstrumentPicker(selectedId: Binding<String>)`.

- [ ] **Step 1: Make the container instrument-switchable**

Replace the contents of `audio_listen/DI/AppDependencyContainer.swift`:

```swift
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

    private let selectedInstrumentStore = SelectedInstrumentStore()
    private let allowedNoteNamesProvider: AllowedNoteNamesProviding

    var currentInstrument: Instrument { selectedInstrumentStore.selectedInstrument }

    private init() {
        allowedStringsStore = GameAllowedStringsStore()
        allowedNoteNamesStore = GameAllowedNoteNamesStore()
        allowedNoteNamesProvider = UserDefaultsAllowedNoteNamesProvider(store: allowedNoteNamesStore)
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
        let instrument = currentInstrument
        let strings = UserDefaultsAllowedStringsProvider(store: allowedStringsStore, instrument: instrument)
        let names = allowedNoteNamesProvider
        let maxFret = UserDefaultsMaxFretProvider(instrument: instrument)
        let touchMode = UserDefaults.standard.bool(forKey: GameSettingsKeys.touchMode)

        let input: NoteInputSource
        let touchSubmit: ((FretPosition) -> Void)?
        let nameNoteProbability: Double
        if touchMode {
            let touch = TouchInputSource(instrument: instrument)
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
            selectNextPrompt: SelectNextPromptUseCase(nameNoteProbability: nameNoteProbability, instrument: instrument),
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
            randomUnit: { Double.random(in: 0..<1) },
            instrument: instrument
        )
    }

    @MainActor
    func makeRootViewModel() -> RootViewModel {
        RootViewModel()
    }
}
```

- [ ] **Step 2: Create the picker**

Create `audio_listen/Presentation/Settings/InstrumentPicker.swift`:

```swift
import SwiftUI

struct InstrumentPicker: View {
    @Binding var selectedId: String

    var body: some View {
        HStack(spacing: 28) {
            ForEach(Instruments.all, id: \.id) { instrument in
                let isSelected = instrument.id == selectedId
                Button {
                    selectedId = instrument.id
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                        Text(instrument.name)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(instrument.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
```

(Tap-to-select bar of dots. The spec's optional drag-across is deferred polish — tapping fully satisfies "switch the active instrument.")

- [ ] **Step 3: Add the Instrument section to Settings**

Replace the contents of `audio_listen/Presentation/Settings/SettingsView.swift`:

```swift
//
//  SettingsView.swift
//  audio_listen
//
//  Game settings.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(GameSettingsKeys.countdownEnabled) private var countdownEnabled = false
    @AppStorage(GameSettingsKeys.limitFretsToTwelve) private var limitFretsToTwelve = true
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false
    @AppStorage(SelectedInstrumentStore.userDefaultsKey) private var selectedInstrumentId = "guitar"

    var body: some View {
        Form {
            Section("Instrument") {
                InstrumentPicker(selectedId: $selectedInstrumentId)
            }
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–11", isOn: $limitFretsToTwelve)
                Toggle("Touch mode (tap notes instead of playing)", isOn: $touchMode)
            }
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("bg-settings")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .navigationTitle("Settings")
    }
}
```

- [ ] **Step 4: Make `ContentView` rebuild on instrument change**

In `audio_listen/ContentView.swift`:

Add an `@AppStorage` for the selected instrument, after the existing `touchMode` line (line 12):
```swift
    @AppStorage(SelectedInstrumentStore.userDefaultsKey) private var selectedInstrumentId = "guitar"
```

In the macOS `TabView` path, replace the `DrillView(...)` block (lines 25–31) with:
```swift
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                instrument: container.currentInstrument
            )
            .id("\(touchMode)-\(selectedInstrumentId)")
            .tabItem { Label("Drill", systemImage: "guitars.fill") }
```
and the `MasteryView(...)` block (now with `instrument:` from Task 6, lines 33–37) with:
```swift
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore,
                instrument: container.currentInstrument
            )
            .id(selectedInstrumentId)
            .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
```

In the iOS `screen(for:)` path, replace `case 0` (lines 52–58) with:
```swift
        case 0:
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                instrument: container.currentInstrument
            )
            .id("\(touchMode)-\(selectedInstrumentId)")
```
and `case 1` (lines 59–63) with:
```swift
        case 1:
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore,
                instrument: container.currentInstrument
            )
            .id(selectedInstrumentId)
```

- [ ] **Step 5: Build and run the full suite**

Run the build/test command. Expected: `** TEST SUCCEEDED **` — the whole suite stays green (this task is DI/UI wiring with no new unit test; the selected-instrument resolution is covered by `SelectedInstrumentStoreTests`).

- [ ] **Step 6: Commit**

```bash
git add audio_listen/DI/AppDependencyContainer.swift \
        audio_listen/Presentation/Settings/InstrumentPicker.swift \
        audio_listen/Presentation/Settings/SettingsView.swift \
        audio_listen/ContentView.swift
git commit -m "feat: instrument picker in settings switches the active instrument"
```

---

## Task 8: Remove the dead global-key API

Every consumer now uses the per-instrument API, so delete the old global-key methods, the `totalItemCount` constant, and their tests. Convert the daily-history tests that still exercised the old methods to per-instrument so their coverage survives.

**Files:**
- Modify: `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift`
- Modify: `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`
- Modify: `audio_listen/Infrastructure/Game/DailyHistoryStore.swift`
- Modify: `audio_listen/Domain/Models/DrillTuning.swift`
- Modify: `audio_listenTests/DrillTuningTests.swift`
- Modify: `audio_listenTests/DrillProgressRepositoryTests.swift`
- Modify: `audio_listenTests/DailyHistoryStoreTests.swift`

**Interfaces:**
- Produces: final `DrillProgressRepositoryProtocol` with only `loadAll(for:)`/`save(_:for:)`; `DailyHistoryStore` with only `for:` methods; `DrillTuning` without `totalItemCount`.

- [ ] **Step 1: Convert the daily-history tests that use old methods to per-instrument**

In `audio_listenTests/DailyHistoryStoreTests.swift`, update the five original tests to the `for:` API (keep the two per-instrument tests from Task 5 as-is). Apply these replacements:

In `missingIsEmpty`:
```swift
        #expect(store.history(for: Instruments.guitar).isEmpty)
        #expect(store.todayReps(for: Instruments.guitar, now: day1) == 0)
```
In `firstRecordThenIncrementSameDay`:
```swift
        store.recordCorrect(for: Instruments.guitar, now: day1, reactionTime: 2.0, masteredCount: 1)
        #expect(store.todayReps(for: Instruments.guitar, now: day1) == 1)
        store.recordCorrect(for: Instruments.guitar, now: day1.addingTimeInterval(60), reactionTime: 4.0, masteredCount: 2)
        #expect(store.todayReps(for: Instruments.guitar, now: day1) == 2)
        let today = store.history(for: Instruments.guitar).first { Calendar(identifier: .gregorian).isDate($0.dayStart, inSameDayAs: day1) }!
        #expect(today.reps == 2)
        #expect(today.averageReaction == 3.0)
        #expect(today.masteredSnapshot == 2)
```
In `newDayStartsFreshRecord`:
```swift
        store.recordCorrect(for: Instruments.guitar, now: day1, reactionTime: 2.0, masteredCount: 1)
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        #expect(store.todayReps(for: Instruments.guitar, now: day2) == 0)
        store.recordCorrect(for: Instruments.guitar, now: day2, reactionTime: 1.0, masteredCount: 3)
        #expect(store.todayReps(for: Instruments.guitar, now: day2) == 1)
        #expect(store.history(for: Instruments.guitar).count == 2)
```
In `historySortedAscending`:
```swift
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        store.recordCorrect(for: Instruments.guitar, now: day2, reactionTime: 1.0, masteredCount: 1)
        store.recordCorrect(for: Instruments.guitar, now: day1, reactionTime: 1.0, masteredCount: 1)
        let h = store.history(for: Instruments.guitar)
        #expect(h.count == 2)
        #expect(h[0].dayStart < h[1].dayStart)
```
In `corruptDataIsEmpty`:
```swift
        defaults.set(Data("nope".utf8), forKey: DailyHistoryStore.userDefaultsKey(for: Instruments.guitar))
        let store = DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
        #expect(store.history(for: Instruments.guitar).isEmpty)
```

- [ ] **Step 2: Remove the old progress-repo tests**

In `audio_listenTests/DrillProgressRepositoryTests.swift`, delete the three original tests whose coverage is now in the per-instrument versions: `missingKeyLoadsEmpty`, `roundTripsStats`, and `corruptDataLoadsEmpty`. Keep `perInstrumentKeysAreIndependent`, `missingPerInstrumentKeyLoadsEmpty`, `corruptPerInstrumentDataLoadsEmpty`, and the `makeDefaults()` helper.

- [ ] **Step 3: Remove the `totalItemCount` assertion**

In `audio_listenTests/DrillTuningTests.swift`, remove this line from `valuesAreStable`:
```swift
        #expect(DrillTuning.totalItemCount == 72)
```
(Keep the `maxBox` and `fastReactionSeconds` assertions and the `universeSizeScalesWithStringCount` test.)

- [ ] **Step 4: Remove the dead production API**

`audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift` — final form:
```swift
protocol DrillProgressRepositoryProtocol {
    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)
}
```

`audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift` — remove the old `static let userDefaultsKey`, `loadAll()`, and `save(_:)`; final form:
```swift
import Foundation

struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol {
    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_drill_progress.\(instrument.id)"
    }

    private struct Entry: Codable {
        let key: DrillItemKey
        let stats: ItemStats
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats] {
        decode(defaults.data(forKey: Self.userDefaultsKey(for: instrument)))
    }

    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument) {
        encode(stats, forKey: Self.userDefaultsKey(for: instrument))
    }

    private func decode(_ data: Data?) -> [DrillItemKey: ItemStats] {
        guard let data, let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        return Dictionary(entries.map { ($0.key, $0.stats) }, uniquingKeysWith: { _, last in last })
    }

    private func encode(_ stats: [DrillItemKey: ItemStats], forKey key: String) {
        let entries = stats.map { Entry(key: $0.key, stats: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
```

`audio_listen/Infrastructure/Game/DailyHistoryStore.swift` — remove the old `static let userDefaultsKey`, `history()`, `todayReps(now:)`, and `recordCorrect(now:reactionTime:masteredCount:)`; keep the `for:` methods and the private `record`/`load`/`save` helpers. Final form of the `DailyHistoryStore` struct body (the `DailyRecord` struct above it is unchanged):
```swift
struct DailyHistoryStore {
    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_daily_history.\(instrument.id)"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func history(for instrument: Instrument) -> [DailyRecord] {
        load(Self.userDefaultsKey(for: instrument)).sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(for instrument: Instrument, now: Date) -> Int {
        load(Self.userDefaultsKey(for: instrument)).first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    func recordCorrect(for instrument: Instrument, now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        let key = Self.userDefaultsKey(for: instrument)
        var records = load(key)
        if let index = records.firstIndex(where: { calendar.isDate($0.dayStart, inSameDayAs: now) }) {
            records[index].reps += 1
            records[index].reactionSum += reactionTime
            records[index].reactionCount += 1
            records[index].masteredSnapshot = masteredCount
            save(records, forKey: key)
            return
        }
        let record = DailyRecord(
            dayStart: calendar.startOfDay(for: now),
            reps: 1,
            reactionSum: reactionTime,
            reactionCount: 1,
            masteredSnapshot: masteredCount
        )
        records.append(record)
        save(records, forKey: key)
    }

    private func load(_ key: String) -> [DailyRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([DailyRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [DailyRecord], forKey key: String) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
```

`audio_listen/Domain/Models/DrillTuning.swift` — remove `totalItemCount`; final form:
```swift
import Foundation

enum DrillTuning {
    static let maxBox = 4
    static let fastReactionSeconds: TimeInterval = 3.0

    static func universeSize(for instrument: Instrument) -> Int {
        instrument.stringCount * 12
    }
}
```

- [ ] **Step 5: Verify no reference to the removed symbols remains**

Run:
```bash
grep -rn "totalItemCount\|loadAll()\|\.recordCorrect(now:\|\.todayReps(now:\|\.history()" audio_listen audio_listenTests --include="*.swift"
```
Expected: **no output** (all old-API call sites are gone).

- [ ] **Step 6: Build and run the full suite**

Run the build/test command. Expected: `** TEST SUCCEEDED **` — everything green with the old API removed.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift \
        audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift \
        audio_listen/Infrastructure/Game/DailyHistoryStore.swift \
        audio_listen/Domain/Models/DrillTuning.swift \
        audio_listenTests/DrillTuningTests.swift \
        audio_listenTests/DrillProgressRepositoryTests.swift \
        audio_listenTests/DailyHistoryStoreTests.swift
git commit -m "refactor: drop the dead global-key progress/history API"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-05-instrument-picker-per-instrument-progress-design.md`):

- Bass instrument (Section A) → Task 1. ✓
- `SelectedInstrumentStore` + key + fallback (B) → Task 3. ✓
- Settings picker writing `@AppStorage` (B, H) → Task 7 (`InstrumentPicker`, `SettingsView`). ✓
- Container `currentInstrument` + providers built in `makeDrillViewModel` (C) → Task 7. ✓
- Per-instrument progress repo keyed `.<id>`, missing/corrupt → `[:]` (D) → Tasks 4 (add) + 8 (finalize). ✓
- Per-instrument daily history keyed `.<id>`, `recordCorrect` stays `Void` (D) → Tasks 5 + 8. ✓
- No migration; guitar reads fresh keys (D, Global Constraints) → inherent (no copy code written). ✓
- `universeSize(for:)` replacing `totalItemCount`, guitar 72 / bass 48 (E) → Tasks 2 + 6 (call sites) + 8 (remove constant). ✓
- Recreate-on-`.id` for Drill + Progress, both platform paths (F) → Task 7. ✓
- `MasteryView` instrument-aware, universe `Set(1...stringCount)`, last hardcoded guitar removed (G) → Task 6. ✓
- Testing: `SelectedInstrumentStoreTests`, per-instrument progress + history isolation, `universeSize` 48/72, `DrillViewModelTests` updated to per-instrument (Testing section) → Tasks 3, 4, 5, 2, 6. ✓
- Out of scope (achievements, per-instrument settings, bass art, mid-drill notifications) — not planned. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". Every code and test block is complete. The one deferral (drag-across on the picker) is an explicit, justified scope note, not a placeholder — tapping fully satisfies the requirement. ✓

**3. Type consistency:** `loadAll(for:)`, `save(_:for:)`, `userDefaultsKey(for:)`, `history(for:)`, `todayReps(for:now:)`, `recordCorrect(for:now:reactionTime:masteredCount:)`, `DrillTuning.universeSize(for:)`, `SelectedInstrumentStore.userDefaultsKey`, `selectedInstrument`, `AppDependencyContainer.currentInstrument`, `MasteryView.init(...instrument:...)`, and `InstrumentPicker(selectedId:)` are spelled identically everywhere they appear across Tasks 1→8 and the tests. `Instruments.bass` / `Instruments.all` match Task 1. The `.id` strings use `selectedInstrumentId` (the `@AppStorage` value) consistently in both platform paths. ✓
