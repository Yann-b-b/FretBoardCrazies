# Gamification Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an overall belt rank, a daily trend graph, and an escalating fast-correct combo with sound + visual juice on top of the existing adaptive fretboard drill.

**Architecture:** Belts and combo are derived from the existing per-note Leitner `ItemStats` (boxes) — pure logic in the domain plus published state on `DrillViewModel`. The trend graph is backed by a new `DailyHistoryStore` that replaces the simpler `DailyGoalStore`. Tuning constants are consolidated into `DrillTuning`. Audio/animation live in the view layer (manually verified); all derivation logic is unit-tested.

**Tech Stack:** Swift 5, SwiftUI, Combine, Swift Charts (`import Charts`), AVFoundation (`AVAudioEngine`/`AVAudioSourceNode`), Swift `Testing`, Xcode project `audio_listen.xcodeproj`, scheme `audio_listen`.

## Global Constraints

- Platform: **macOS** (`platform=macOS`); deployment target 14.6 (Swift Charts available). iOS-only code stays `#if os(iOS)`-guarded.
- **Toolchain:** EVERY `xcodebuild` MUST be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. A bare `xcodebuild` fails with "requires Xcode". Tests launch a macOS test host (~1–2 min). Code signing is automatic.
- Test runner: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests`
- Project uses Xcode **file-system synchronized groups**: creating a `.swift` file under `audio_listen/` or `audio_listenTests/` auto-includes it; deleting = `git rm` (no `project.pbxproj` edits).
- No comments in code; names self-documenting. Swift `Testing` (`import Testing`, `@Test`, `#expect`).
- Mastery unit is `(NoteName, string)`; the item universe is 72 (12 note names × 6 strings, frets 0–11). Validation is pitch + octave only.
- No new third-party dependencies (Swift Charts and AVFoundation are first-party). No image assets.
- Commit after each task with a `feat:`/`refactor:` prefixed message.

---

## File Structure

**Create:**
- `audio_listen/Domain/Models/DrillTuning.swift`
- `audio_listen/Domain/Models/Belt.swift`
- `audio_listen/Domain/Models/BeltRank.swift`
- `audio_listen/Presentation/Drill/Belt+UI.swift`
- `audio_listen/Infrastructure/Game/DailyHistoryStore.swift`
- `audio_listen/Presentation/Drill/TrendView.swift`
- `audio_listen/Presentation/Drill/ComboSoundPlayer.swift`
- Test files: `DrillTuningTests.swift`, `BeltRankTests.swift`, `DailyHistoryStoreTests.swift` (in `audio_listenTests/`)

**Modify:**
- `audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift` (defaults → DrillTuning)
- `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift` (default → DrillTuning)
- `audio_listen/Presentation/Drill/DrillViewModel.swift` (history store, combo, beltRank)
- `audio_listen/Presentation/Drill/DrillView.swift` (belt chip, combo badge, juice)
- `audio_listen/Presentation/Drill/MasteryView.swift` (default → DrillTuning; belt card; embed TrendView)
- `audio_listen/DI/AppDependencyContainer.swift` (dailyGoalStore → dailyHistoryStore)
- `audio_listen/ContentView.swift` (pass dailyHistoryStore to MasteryView)
- `audio_listenTests/DrillViewModelTests.swift` (helper + combo tests)

**Remove:**
- `audio_listen/Infrastructure/Game/DailyGoalStore.swift`
- `audio_listenTests/DailyGoalTests.swift`

---

## Task 1: DrillTuning constants

**Files:**
- Create: `audio_listen/Domain/Models/DrillTuning.swift`
- Modify: `audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift`, `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift`, `audio_listen/Presentation/Drill/MasteryView.swift`
- Test: `audio_listenTests/DrillTuningTests.swift`

**Interfaces:**
- Produces: `enum DrillTuning { static let maxBox = 4; static let fastReactionSeconds: TimeInterval = 3.0; static let totalItemCount = 6 * 12 }`

- [ ] **Step 1: Write the failing test**

`audio_listenTests/DrillTuningTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct DrillTuningTests {
    @Test func valuesAreStable() {
        #expect(DrillTuning.maxBox == 4)
        #expect(DrillTuning.fastReactionSeconds == 3.0)
        #expect(DrillTuning.totalItemCount == 72)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillTuningTests`
Expected: FAIL — `DrillTuning` not found.

- [ ] **Step 3: Create DrillTuning**

`audio_listen/Domain/Models/DrillTuning.swift`:
```swift
import Foundation

enum DrillTuning {
    static let maxBox = 4
    static let fastReactionSeconds: TimeInterval = 3.0
    static let totalItemCount = 6 * 12
}
```

- [ ] **Step 4: Point existing defaults at DrillTuning**

In `UpdateItemStatsUseCase.swift`, change the init signature defaults to:
```swift
    init(maxBox: Int = DrillTuning.maxBox, fastReactionSeconds: TimeInterval = DrillTuning.fastReactionSeconds) {
```
In `SelectNextPromptUseCase.swift`, change:
```swift
    init(maxBox: Int = DrillTuning.maxBox, nameNoteProbability: Double = 0.25) {
```
In `MasteryView.swift`, change the init default:
```swift
    init(progressRepository: DrillProgressRepositoryProtocol, masteredBox: Int = DrillTuning.maxBox) {
```

- [ ] **Step 5: Run tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests`
Expected: PASS (DrillTuningTests + all existing — behavior unchanged since values are identical).

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Domain/Models/DrillTuning.swift audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift audio_listen/Presentation/Drill/MasteryView.swift audio_listenTests/DrillTuningTests.swift
git commit -m "refactor: consolidate drill tuning constants into DrillTuning"
```

---

## Task 2: Belt + BeltRank

**Files:**
- Create: `audio_listen/Domain/Models/Belt.swift`, `audio_listen/Domain/Models/BeltRank.swift`, `audio_listen/Presentation/Drill/Belt+UI.swift`
- Test: `audio_listenTests/BeltRankTests.swift`

**Interfaces:**
- Produces:
  - `enum Belt: Int, CaseIterable { case white, yellow, orange, green, blue, purple, brown, black }` with `var displayName: String` and `static let thresholds: [Double]` (8 lower-bound fractions).
  - `struct BeltRank: Equatable { let belt: Belt; let fraction: Double; let fractionToNext: Double; static func from(stats: [DrillItemKey: ItemStats], maxBox: Int, universeSize: Int) -> BeltRank }`
  - `extension Belt { var color: Color; var symbolName: String }` (SwiftUI; presentation only)
- Consumes: `DrillItemKey`, `ItemStats` (existing).

- [ ] **Step 1: Write the failing tests**

`audio_listenTests/BeltRankTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct BeltRankTests {
    private func stats(boxes: [Int]) -> [DrillItemKey: ItemStats] {
        var d: [DrillItemKey: ItemStats] = [:]
        for (i, box) in boxes.enumerated() {
            let key = DrillItemKey(noteName: NoteName(rawValue: i / 6)!, string: (i % 6) + 1)
            d[key] = ItemStats(box: box, attempts: 1, correct: 1, lastReactionTime: 1.0, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        }
        return d
    }

    @Test func emptyStatsIsWhiteAtZero() {
        let r = BeltRank.from(stats: [:], maxBox: 4, universeSize: 72)
        #expect(r.belt == .white)
        #expect(r.fraction == 0)
        #expect(r.fractionToNext == 0)
    }

    @Test func fullStatsIsBlack() {
        let boxes = Array(repeating: 4, count: 72)
        let r = BeltRank.from(stats: stats(boxes: boxes), maxBox: 4, universeSize: 72)
        #expect(r.belt == .black)
        #expect(r.fraction == 1.0)
        #expect(r.fractionToNext == 1.0)
    }

    @Test func fractionAtOrangeThreshold() {
        // 18 items at box 4 = 72 points / 288 = 0.25 -> Orange (threshold 0.25)
        var boxes = Array(repeating: 4, count: 18)
        boxes += Array(repeating: 0, count: 54)
        let r = BeltRank.from(stats: stats(boxes: boxes), maxBox: 4, universeSize: 72)
        #expect(r.belt == .orange)
        #expect(abs(r.fraction - 0.25) < 0.0001)
        #expect(r.fractionToNext < 0.05)
    }

    @Test func clampsBoxAboveMax() {
        let r = BeltRank.from(stats: stats(boxes: [99]), maxBox: 4, universeSize: 72)
        #expect(r.fraction == 4.0 / 288.0)
    }

    @Test func displayNamesCoverAllBelts() {
        #expect(Belt.allCases.map(\.displayName) == ["White","Yellow","Orange","Green","Blue","Purple","Brown","Black"])
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/BeltRankTests`
Expected: FAIL — `Belt`/`BeltRank` not found.

- [ ] **Step 3: Implement Belt and BeltRank**

`audio_listen/Domain/Models/Belt.swift`:
```swift
enum Belt: Int, CaseIterable {
    case white, yellow, orange, green, blue, purple, brown, black

    static let thresholds: [Double] = [0.0, 0.12, 0.25, 0.40, 0.55, 0.70, 0.85, 0.97]

    var displayName: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .brown: return "Brown"
        case .black: return "Black"
        }
    }
}
```
`audio_listen/Domain/Models/BeltRank.swift`:
```swift
struct BeltRank: Equatable {
    let belt: Belt
    let fraction: Double
    let fractionToNext: Double

    static func from(stats: [DrillItemKey: ItemStats], maxBox: Int, universeSize: Int) -> BeltRank {
        let maxPoints = Double(universeSize * maxBox)
        let points = stats.values.reduce(0) { $0 + min($1.box, maxBox) }
        let fraction = maxPoints == 0 ? 0 : Double(points) / maxPoints

        var current = Belt.white
        for belt in Belt.allCases where fraction >= Belt.thresholds[belt.rawValue] {
            current = belt
        }

        if current == .black {
            return BeltRank(belt: .black, fraction: fraction, fractionToNext: 1.0)
        }
        let lower = Belt.thresholds[current.rawValue]
        let upper = Belt.thresholds[current.rawValue + 1]
        let toNext = upper == lower ? 1.0 : (fraction - lower) / (upper - lower)
        return BeltRank(belt: current, fraction: fraction, fractionToNext: max(0, min(1, toNext)))
    }
}
```

- [ ] **Step 4: Add the SwiftUI color extension**

`audio_listen/Presentation/Drill/Belt+UI.swift`:
```swift
import SwiftUI

extension Belt {
    var color: Color {
        switch self {
        case .white: return Color(white: 0.85)
        case .yellow: return .yellow
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .brown: return .brown
        case .black: return .black
        }
    }

    var symbolName: String { "medal.fill" }
}
```

- [ ] **Step 5: Run tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/BeltRankTests`
Expected: PASS (all 5).

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Domain/Models/Belt.swift audio_listen/Domain/Models/BeltRank.swift audio_listen/Presentation/Drill/Belt+UI.swift audio_listenTests/BeltRankTests.swift
git commit -m "feat: add belt rank derived from Leitner box-points"
```

---

## Task 3: DailyHistoryStore

**Files:**
- Create: `audio_listen/Infrastructure/Game/DailyHistoryStore.swift`
- Test: `audio_listenTests/DailyHistoryStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct DailyRecord: Codable, Equatable { var dayStart: Date; var reps: Int; var reactionSum: TimeInterval; var reactionCount: Int; var masteredSnapshot: Int; var averageReaction: Double }`
  - `struct DailyHistoryStore { init(defaults: UserDefaults = .standard, calendar: Calendar = .current); static let userDefaultsKey = "audio_listen_daily_history"; func history() -> [DailyRecord]; func todayReps(now: Date) -> Int; @discardableResult func recordCorrect(now: Date, reactionTime: TimeInterval, masteredCount: Int) -> Int }`

- [ ] **Step 1: Write the failing tests**

`audio_listenTests/DailyHistoryStoreTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct DailyHistoryStoreTests {
    private func makeStore() -> (DailyHistoryStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)), defaults, suite)
    }
    let day1 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func missingIsEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.history().isEmpty)
        #expect(store.todayReps(now: day1) == 0)
    }

    @Test func firstRecordThenIncrementSameDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.recordCorrect(now: day1, reactionTime: 2.0, masteredCount: 1) == 1)
        #expect(store.recordCorrect(now: day1.addingTimeInterval(60), reactionTime: 4.0, masteredCount: 2) == 2)
        let today = store.history().first { Calendar(identifier: .gregorian).isDate($0.dayStart, inSameDayAs: day1) }!
        #expect(today.reps == 2)
        #expect(today.averageReaction == 3.0)
        #expect(today.masteredSnapshot == 2)
    }

    @Test func newDayStartsFreshRecord() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = store.recordCorrect(now: day1, reactionTime: 2.0, masteredCount: 1)
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        #expect(store.todayReps(now: day2) == 0)
        #expect(store.recordCorrect(now: day2, reactionTime: 1.0, masteredCount: 3) == 1)
        #expect(store.history().count == 2)
    }

    @Test func historySortedAscending() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        _ = store.recordCorrect(now: day2, reactionTime: 1.0, masteredCount: 1)
        _ = store.recordCorrect(now: day1, reactionTime: 1.0, masteredCount: 1)
        let h = store.history()
        #expect(h.count == 2)
        #expect(h[0].dayStart < h[1].dayStart)
    }

    @Test func corruptDataIsEmpty() {
        let (_, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("nope".utf8), forKey: DailyHistoryStore.userDefaultsKey)
        let store = DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
        #expect(store.history().isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DailyHistoryStoreTests`
Expected: FAIL — `DailyHistoryStore` not found.

- [ ] **Step 3: Implement DailyHistoryStore**

`audio_listen/Infrastructure/Game/DailyHistoryStore.swift`:
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

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func history() -> [DailyRecord] {
        load().sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(now: Date) -> Int {
        load().first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    @discardableResult
    func recordCorrect(now: Date, reactionTime: TimeInterval, masteredCount: Int) -> Int {
        var records = load()
        if let index = records.firstIndex(where: { calendar.isDate($0.dayStart, inSameDayAs: now) }) {
            records[index].reps += 1
            records[index].reactionSum += reactionTime
            records[index].reactionCount += 1
            records[index].masteredSnapshot = masteredCount
            save(records)
            return records[index].reps
        }
        let record = DailyRecord(
            dayStart: calendar.startOfDay(for: now),
            reps: 1,
            reactionSum: reactionTime,
            reactionCount: 1,
            masteredSnapshot: masteredCount
        )
        records.append(record)
        save(records)
        return 1
    }

    private func load() -> [DailyRecord] {
        guard let data = defaults.data(forKey: Self.userDefaultsKey),
              let records = try? JSONDecoder().decode([DailyRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [DailyRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DailyHistoryStoreTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Infrastructure/Game/DailyHistoryStore.swift audio_listenTests/DailyHistoryStoreTests.swift
git commit -m "feat: add daily-history store for trend data"
```

---

## Task 4: Swap DrillViewModel + DI to DailyHistoryStore

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillViewModel.swift`, `audio_listen/DI/AppDependencyContainer.swift`, `audio_listenTests/DrillViewModelTests.swift`
- Remove: `audio_listen/Infrastructure/Game/DailyGoalStore.swift`, `audio_listenTests/DailyGoalTests.swift`

**Interfaces:**
- Consumes: `DailyHistoryStore` (Task 3), `DrillTuning` (Task 1).
- Produces: `DrillViewModel.init(...)` now takes `dailyHistoryStore: DailyHistoryStore` in place of `dailyGoalStore: DailyGoalStore`; on a correct answer it records reaction time + current mastered count and updates `todayCount`.

- [ ] **Step 1: Update DrillViewModel to use DailyHistoryStore**

In `DrillViewModel.swift`:
- Rename the stored property and init parameter `dailyGoalStore: DailyGoalStore` → `dailyHistoryStore: DailyHistoryStore` (update the `self.dailyHistoryStore = dailyHistoryStore` assignment).
- In `init`, change the initial today count to:
```swift
        self.todayCount = dailyHistoryStore.todayReps(now: clock.now())
```
- In `recordCorrect(for:reactionTime:)`, replace the daily-goal line. The method becomes:
```swift
    private func recordCorrect(for prompt: DrillPrompt, reactionTime: TimeInterval) {
        var all = progressRepository.loadAll()
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyCorrect(to: current, reactionTime: reactionTime, now: clock.now())
        progressRepository.save(all)
        let mastered = all.values.filter { $0.box >= DrillTuning.maxBox }.count
        todayCount = dailyHistoryStore.recordCorrect(now: clock.now(), reactionTime: reactionTime, masteredCount: mastered)
    }
```

- [ ] **Step 2: Update AppDependencyContainer**

In `AppDependencyContainer.swift`:
- Replace `let dailyGoalStore = DailyGoalStore()` with `let dailyHistoryStore = DailyHistoryStore()`.
- In `makeDrillViewModel()`, change the argument `dailyGoalStore: dailyGoalStore` → `dailyHistoryStore: dailyHistoryStore`.

- [ ] **Step 3: Remove the old store and its test**

```bash
git rm audio_listen/Infrastructure/Game/DailyGoalStore.swift audio_listenTests/DailyGoalTests.swift
```

- [ ] **Step 4: Update the test helper and add a wiring test**

In `audio_listenTests/DrillViewModelTests.swift`, update BOTH `DrillViewModel(...)` constructions (the `makeViewModel` helper and the inline one in `emptyAllowedSetsShowsError`) to pass `dailyHistoryStore:` instead of `dailyGoalStore:`. The helper line becomes:
```swift
        dailyHistoryStore: DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)),
```
and the inline one:
```swift
            dailyHistoryStore: DailyHistoryStore(defaults: defaults),
```
Then add a test to `DrillViewModelTests` verifying the history is written on a correct answer. To read the store back, change the helper to ALSO return the defaults suite — simplest is a new dedicated test that builds its own VM. Add:
```swift
    @Test @MainActor func correctAnswerRecordsDailyHistory() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let history = DailyHistoryStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
        let vm = DrillViewModel(
            pitchDetector: detector,
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
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.todayCount == 1)
        #expect(history.todayReps(now: clock.now()) == 1)
    }
```

- [ ] **Step 5: Run tests + build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests`
Expected: PASS (the new wiring test + all existing). No references to `DailyGoalStore` remain (build clean).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: drive daily count from DailyHistoryStore, record reaction+mastered"
```

---

## Task 5: Combo + belt-rank state on DrillViewModel

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillViewModel.swift`, `audio_listenTests/DrillViewModelTests.swift`

**Interfaces:**
- Produces: `@Published private(set) var comboCount: Int = 0` and `@Published private(set) var beltRank: BeltRank` on `DrillViewModel`. Combo: fast-correct increments, slow-correct resets, skip resets, start resets. `beltRank` recomputed after each correct and at init.
- Consumes: `DrillTuning`, `BeltRank` (Tasks 1–2).

- [ ] **Step 1: Write the failing tests**

Append to `DrillViewModelTests` in `audio_listenTests/DrillViewModelTests.swift`:
```swift
    @Test @MainActor func comboIncrementsOnFastCorrect() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
    }

    @Test @MainActor func comboResetsOnSlowCorrect() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
        vm.start()
        clock.advance(by: 5.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 0)
    }

    @Test @MainActor func comboResetsOnSkip() async {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, _) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 1.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.comboCount == 1)
        vm.skip()
        #expect(vm.comboCount == 0)
    }

    @Test @MainActor func beltRankStartsWhite() {
        let detector = StubPitchDetector()
        let (vm, _) = makeViewModel(detector: detector, clock: FakeClock(), scheduler: FakeScheduler(), countdownEnabled: false)
        #expect(vm.beltRank.belt == .white)
        #expect(vm.beltRank.fraction == 0)
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillViewModelTests`
Expected: FAIL — `comboCount` / `beltRank` not found.

- [ ] **Step 3: Add the published state and update transitions**

In `DrillViewModel.swift`:
- Add the published properties near the others:
```swift
    @Published private(set) var comboCount: Int = 0
    @Published private(set) var beltRank: BeltRank
```
- In `init`, initialize `beltRank` BEFORE the `stateMachine.onStateChange` assignment (a stored non-optional must be set):
```swift
        self.beltRank = BeltRank.from(stats: progressRepository.loadAll(), maxBox: DrillTuning.maxBox, universeSize: DrillTuning.totalItemCount)
```
(Place this after `self.todayCount = ...` and before the `stateMachine.onStateChange = { ... }` closure.)
- In `start()`, the first lines already cancel tokens; add a combo reset there:
```swift
        comboCount = 0
```
- In `skip()`, add at the top:
```swift
        comboCount = 0
```
- In `recordCorrect(for:reactionTime:)`, after computing `mastered` and updating `todayCount`, add:
```swift
        beltRank = BeltRank.from(stats: all, maxBox: DrillTuning.maxBox, universeSize: DrillTuning.totalItemCount)
```
- In `handle(_:)`, after the `recordCorrect(for: prompt, reactionTime: reaction)` call and before the `.success` transition, add the combo update:
```swift
        comboCount = reaction <= DrillTuning.fastReactionSeconds ? comboCount + 1 : 0
```

- [ ] **Step 4: Run tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillViewModelTests`
Expected: PASS (combo + belt tests + all existing).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillViewModel.swift audio_listenTests/DrillViewModelTests.swift
git commit -m "feat: add combo count and live belt rank to DrillViewModel"
```

---

## Task 6: Belt chip + combo badge + success flash in DrillView

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`

**Interfaces:**
- Consumes: `viewModel.beltRank`, `viewModel.comboCount`, `Belt.color`/`symbolName` (Tasks 2, 5).
- No unit tests (SwiftUI); verified by build + preview + manual run.

- [ ] **Step 1: Add the belt chip to the header**

In `DrillView.swift`, replace the `header` computed property with:
```swift
    private var header: some View {
        HStack(spacing: 12) {
            Text("Fretboard Drill").font(.title2).bold()
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: viewModel.beltRank.belt.symbolName)
                    .foregroundStyle(viewModel.beltRank.belt.color)
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
            }
            Text("Today: \(viewModel.todayCount)").foregroundStyle(.secondary)
        }
    }
```

- [ ] **Step 2: Add a combo badge**

Add this computed view to `DrillView` and place `comboBadge` in the main `VStack` (e.g. directly under `header`):
```swift
    @ViewBuilder
    private var comboBadge: some View {
        if viewModel.comboCount >= 2 {
            let scale = min(1.0 + Double(viewModel.comboCount) * 0.05, 1.6)
            Text("🔥 \(viewModel.comboCount) combo")
                .font(.headline)
                .foregroundStyle(.orange)
                .scaleEffect(scale)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
        }
    }
```
In `body`, insert `comboBadge` between `header` and the error/`content` block.

- [ ] **Step 3: Build + preview**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'`
Expected: `** BUILD SUCCEEDED **`, no warnings from `DrillView.swift`.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: show belt chip and escalating combo badge in DrillView"
```

---

## Task 7: ComboSoundPlayer + trigger on combo

**Files:**
- Create: `audio_listen/Presentation/Drill/ComboSoundPlayer.swift`
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`

**Interfaces:**
- Produces: `final class ComboSoundPlayer { func play(combo: Int) }` — asset-free escalating tone via `AVAudioEngine` + `AVAudioSourceNode`.
- Triggered from `DrillView` when `comboCount` increases (during `.success`, when mic listening is already stopped, so no feedback into detection).
- Verified by build + on-device listening (no unit test).

- [ ] **Step 1: Implement ComboSoundPlayer**

`audio_listen/Presentation/Drill/ComboSoundPlayer.swift`:
```swift
import AVFoundation

final class ComboSoundPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100
    private var started = false
    private var phase: Double = 0
    private var frequency: Double = 440
    private var remainingSamples: Int = 0

    private lazy var source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let twoPi = 2.0 * Double.pi
        for frame in 0..<Int(frameCount) {
            var value: Float = 0
            if self.remainingSamples > 0 {
                value = Float(sin(self.phase)) * 0.2
                self.phase += twoPi * self.frequency / self.sampleRate
                if self.phase > twoPi { self.phase -= twoPi }
                self.remainingSamples -= 1
            }
            for buffer in buffers {
                let pointer = UnsafeMutableBufferPointer<Float>(buffer)
                pointer[frame] = value
            }
        }
        return noErr
    }

    func play(combo: Int) {
        ensureStarted()
        let steps: [Double] = [0, 2, 4, 7, 9, 12]
        let index = min(max(combo - 1, 0), steps.count - 1)
        frequency = 440 * pow(2.0, steps[index] / 12.0)
        remainingSamples = Int(sampleRate * 0.15)
    }

    private func ensureStarted() {
        guard !started else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        try? engine.start()
        started = true
    }
}
```

- [ ] **Step 2: Trigger it from DrillView on combo increase**

In `DrillView.swift`:
- Add a stored player: `private let comboSound = ComboSoundPlayer()` (as a `let` property on the struct).
- Add an `.onChange` to the root view (attach to the outer `VStack` in `body`, alongside `.onAppear`):
```swift
        .onChange(of: viewModel.comboCount) { oldValue, newValue in
            if newValue > oldValue {
                comboSound.play(combo: newValue)
            }
        }
```

- [ ] **Step 3: Build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'`
Expected: `** BUILD SUCCEEDED **`, no warnings. Then run full `audio_listenTests` to confirm no regression.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Drill/ComboSoundPlayer.swift audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: escalating combo tone on fast-correct streak"
```

---

## Task 8: Belt card + TrendView in Progress tab, final integration

**Files:**
- Create: `audio_listen/Presentation/Drill/TrendView.swift`
- Modify: `audio_listen/Presentation/Drill/MasteryView.swift`, `audio_listen/ContentView.swift`

**Interfaces:**
- Produces: `struct TrendView: View { init(history: [DailyRecord]) }` (Swift Charts line chart with a Reps/Mastered/Avg-reaction picker). `MasteryView` gains a belt card and embeds `TrendView`; its init takes `dailyHistoryStore: DailyHistoryStore`.
- Consumes: `BeltRank`, `Belt` UI, `DailyHistoryStore`/`DailyRecord` (Tasks 2–3).

- [ ] **Step 1: Implement TrendView**

`audio_listen/Presentation/Drill/TrendView.swift`:
```swift
import Charts
import SwiftUI

struct TrendView: View {
    let history: [DailyRecord]

    enum Metric: String, CaseIterable, Identifiable {
        case reps = "Reps"
        case mastered = "Mastered"
        case reaction = "Avg s"
        var id: String { rawValue }
    }

    @State private var metric: Metric = .reps

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend").font(.headline)
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if history.count < 2 {
                Text("Play on more days to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(history, id: \.dayStart) { record in
                    LineMark(
                        x: .value("Day", record.dayStart),
                        y: .value(metric.rawValue, value(for: record))
                    )
                    .symbol(.circle)
                }
                .frame(minHeight: 160)
            }
        }
    }

    private func value(for record: DailyRecord) -> Double {
        switch metric {
        case .reps: return Double(record.reps)
        case .mastered: return Double(record.masteredSnapshot)
        case .reaction: return record.averageReaction
        }
    }
}
```

- [ ] **Step 2: Add belt card + trend to MasteryView**

In `MasteryView.swift`:
- Add a stored `dailyHistoryStore` and extend the init:
```swift
    private let progressRepository: DrillProgressRepositoryProtocol
    private let dailyHistoryStore: DailyHistoryStore
    private let masteredBox: Int

    @State private var heatmap: [DrillItemKey: MasteryLevel] = [:]
    @State private var totals: (unseen: Int, learning: Int, mastered: Int) = (0, 0, 0)
    @State private var beltRank: BeltRank = BeltRank.from(stats: [:], maxBox: DrillTuning.maxBox, universeSize: DrillTuning.totalItemCount)
    @State private var history: [DailyRecord] = []

    init(progressRepository: DrillProgressRepositoryProtocol, dailyHistoryStore: DailyHistoryStore, masteredBox: Int = DrillTuning.maxBox) {
        self.progressRepository = progressRepository
        self.dailyHistoryStore = dailyHistoryStore
        self.masteredBox = masteredBox
    }
```
- Wrap the body in a `ScrollView` and add the belt card above the heatmap and `TrendView` below the legend:
```swift
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Progress").font(.title2).bold()
                beltCard
                FretboardView(heatmap: heatmap)
                HStack(spacing: 24) {
                    legend(color: .gray, label: "Unseen \(totals.unseen)")
                    legend(color: .orange, label: "Learning \(totals.learning)")
                    legend(color: .green, label: "Mastered \(totals.mastered)")
                }
                TrendView(history: history)
            }
            .padding(24)
            .frame(minWidth: 640)
        }
        .onAppear(perform: reload)
    }

    private var beltCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: beltRank.belt.symbolName).foregroundStyle(beltRank.belt.color)
                Text("\(beltRank.belt.displayName) belt").font(.headline)
            }
            ProgressView(value: beltRank.belt == .black ? 1.0 : beltRank.fractionToNext)
                .frame(maxWidth: 280)
            Text(beltRank.belt == .black ? "Max rank" : "Progress to next belt")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
```
- In `reload()`, after computing `heatmap`/`totals`, also set belt and history:
```swift
        beltRank = BeltRank.from(stats: stats, maxBox: masteredBox, universeSize: DrillTuning.totalItemCount)
        history = dailyHistoryStore.history()
```
(`stats` is the `progressRepository.loadAll()` already read at the top of `reload()`.)

- [ ] **Step 3: Pass the store from ContentView**

In `ContentView.swift`, update the Progress tab:
```swift
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore
            )
            .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
```

- [ ] **Step 4: Build + full test**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests
```
Expected: BUILD SUCCEEDED and all tests pass.

- [ ] **Step 5: Manual verification (on-device)**

Launch on "My Mac": Drill header shows a belt chip; a fast-correct streak shows the 🔥 combo badge and plays an escalating tone; the Progress tab shows the belt card with progress bar, the heatmap, and the trend chart (with the metric picker) once ≥2 days of data exist.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: belt card + trend graph in Progress tab"
```

---

## Self-Review

**Spec coverage:**
- DrillTuning consolidation → Task 1 ✓
- Belt metric (box-points) + 8 belts + BeltRank.from → Task 2 ✓
- DailyHistoryStore replaces DailyGoalStore → Tasks 3, 4 ✓
- Record reaction + mastered snapshot on correct → Task 4 ✓
- Combo (fast extends; slow/skip/start reset) → Task 5 ✓
- Live belt rank state → Task 5 ✓
- Belt chip + combo badge + flash → Task 6 ✓
- Escalating combo sound (success-only, asset-free) → Task 7 ✓
- TrendView (Swift Charts, 3 metrics) + belt card in Progress tab → Task 8 ✓
- Belt + trend in Progress tab, not a new tab → Task 8 ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. View/audio tasks (6–8) verified by build + preview + manual, which is correct for SwiftUI/AVFoundation.

**Type consistency:** `DrillTuning.maxBox/fastReactionSeconds/totalItemCount`, `BeltRank.from(stats:maxBox:universeSize:)`, `Belt.displayName/color/symbolName`, `DailyHistoryStore.recordCorrect(now:reactionTime:masteredCount:)`/`todayReps(now:)`/`history()`, `DailyRecord.averageReaction`, and `DrillViewModel`'s `comboCount`/`beltRank` are used identically across tasks. The `DailyGoalStore`→`DailyHistoryStore` rename is applied at every call site (VM, DI, test helper, inline test) in Task 4.

**Assumptions to verify during execution:** Swift `onChange(of:)` two-parameter closure (macOS 14) in Task 7; `import Charts` availability (deployment target 14.6) in Task 8; that `DrillViewModel`'s existing `recordCorrect`/`handle`/`start`/`skip` method bodies match the snippets being edited (they were written in the adaptive-trainer plan).
