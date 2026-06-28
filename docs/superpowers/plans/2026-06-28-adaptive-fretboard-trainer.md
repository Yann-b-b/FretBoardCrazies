# Adaptive Fretboard Trainer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single adaptive, microphone-driven fretboard-note drill for macOS that cues note-name + string prompts (and occasional position prompts), targets weak spots via spaced repetition, and shows progress on a visual fretboard.

**Architecture:** Keep the existing layered structure (Domain / Infrastructure / Presentation / DI). Add a new `Drill` feature that reuses `Note`, `NoteName`, `GuitarFretboard`, `ValidateNoteUseCase`, and the AudioKit pitch pipeline. Selection logic and stat updates are pure, dependency-injected use cases; time and scheduling are injected behind `Clock` / `DrillScheduler` protocols so the loop and engine are unit-testable. The two old tabs (`Game`, `Find note`) are removed.

**Tech Stack:** Swift 5, SwiftUI, Combine, AudioKit + SoundpipeAudioKit, Swift `Testing` framework, Xcode project (`audio_listen.xcodeproj`, scheme `audio_listen`).

## Global Constraints

- Target platform for this work: **macOS** (`SDKROOT = auto`, `SUPPORTED_PLATFORMS` includes `macosx`, `MACOSX_DEPLOYMENT_TARGET = 14.6`). iOS-only audio-session code stays `#if os(iOS)`-guarded.
- Validation is **pitch class + octave only** (microphone cannot disambiguate unison positions). Position is a self-verified visual target.
- Mastery is keyed on **`(NoteName, string)`**, never `(string, fret)`.
- String numbering: **1 = high E … 6 = low E**.
- Default fret range is **0–11** (`GameTargetFretBounds.limitedMaxFretInclusive`); within it each note name appears exactly once per string.
- No new third-party dependencies. No pitch-detection algorithm changes.
- No comments in code (per repo style); names must be self-documenting.
- Test runner: `xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'`. Do NOT add `__init__`-style index files. New test types live in `audio_listenTests/`.
- Commit after every task with a `feat:`/`refactor:`/`chore:` prefixed message.

---

## File Structure

**Create:**
- `audio_listen/Domain/Models/DrillDirection.swift`
- `audio_listen/Domain/Models/DrillItemKey.swift`
- `audio_listen/Domain/Models/DrillPrompt.swift`
- `audio_listen/Domain/Models/ItemStats.swift`
- `audio_listen/Domain/Models/MasteryLevel.swift`
- `audio_listen/Domain/Models/DrillState.swift`
- `audio_listen/Domain/Protocols/Clock.swift`
- `audio_listen/Domain/Protocols/DrillScheduler.swift`
- `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift`
- `audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift`
- `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift`
- `audio_listen/Infrastructure/Time/SystemClock.swift`
- `audio_listen/Infrastructure/Time/TimerDrillScheduler.swift`
- `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`
- `audio_listen/Infrastructure/Game/DailyGoalStore.swift`
- `audio_listen/Infrastructure/Game/StringSetPresets.swift`
- `audio_listen/Presentation/Drill/DrillStateMachine.swift`
- `audio_listen/Presentation/Drill/DrillViewModel.swift`
- `audio_listen/Presentation/Drill/FretboardGeometry.swift`
- `audio_listen/Presentation/Drill/FretboardView.swift`
- `audio_listen/Presentation/Drill/DrillView.swift`
- `audio_listen/Presentation/Drill/MasteryView.swift`

**Modify:**
- `audio_listen/Infrastructure/Game/GameSettingsKeys.swift` (centralize keys)
- `audio_listen/Domain/Models/Note.swift` (add `Codable` to `NoteName`)
- `audio_listen/DI/AppDependencyContainer.swift` (wire drill, remove old game VMs)
- `audio_listen/ContentView.swift` (macOS layout, remove old tabs)
- `audio_listen/audio_listen.entitlements` (only if the spike requires it)

**Remove (in the final integration task, after the drill works):**
- `audio_listen/Presentation/Game/GameView.swift`
- `audio_listen/Presentation/Game/NoteNameGameView.swift`
- `audio_listen/Presentation/Game/GameViewModel.swift`
- `audio_listen/Presentation/Game/GameStateMachine.swift`
- `audio_listen/Presentation/Game/GameState.swift`
- `audio_listen/Presentation/Game/SessionStatsView.swift` (if unused after rewire — verify references first)

**Test files (Swift `Testing`), added to `audio_listenTests/`:**
- `DrillModelsTests.swift`, `ClockSchedulerTests.swift`, `DrillProgressRepositoryTests.swift`, `DailyGoalTests.swift`, `UpdateItemStatsTests.swift`, `SelectNextPromptTests.swift`, `FretboardGeometryTests.swift`, `DrillViewModelTests.swift`, `StringSetPresetsTests.swift`.

---

## Task 1: Verify-first spike — microphone on macOS

**De-risking gate. No new feature code; confirm the foundation before building on it.**

**Files:**
- Inspect: `audio_listen/audio_listen.entitlements`, `audio_listen.xcodeproj/project.pbxproj`
- Possibly modify: `audio_listen/audio_listen.entitlements`, Info.plist build settings

**Interfaces:**
- Produces: a confirmed-working macOS build with live microphone pitch detection (the existing `TunerView`).

- [ ] **Step 1: Confirm the macOS build compiles**

Run:
```bash
xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
```
Expected: `** BUILD SUCCEEDED **`. If it fails on a missing signing/team, add `CODE_SIGNING_ALLOWED=NO` to the command and retry.

- [ ] **Step 2: Check microphone configuration**

Verify an `NSMicrophoneUsageDescription` exists (search build settings / Info):
```bash
grep -rn "NSMicrophoneUsageDescription\|INFOPLIST_KEY_NSMicrophoneUsageDescription" audio_listen.xcodeproj/project.pbxproj
grep -rn "app-sandbox\|com.apple.security" audio_listen/audio_listen.entitlements
```
Expected outcomes and actions:
- If no `NSMicrophoneUsageDescription`: add `INFOPLIST_KEY_NSMicrophoneUsageDescription = "FretBoardCrazies listens to your guitar to detect notes."` to the app target build settings.
- If the entitlements show `com.apple.security.app-sandbox = true`: add `com.apple.security.device.audio-input = true` to `audio_listen.entitlements`. If not sandboxed, no entitlement change is needed.

- [ ] **Step 3: Run on macOS and confirm detection**

Launch the built app (open the `.app` from DerivedData, or run via Xcode on "My Mac"). Open the **Tuner** tab, play a note, and confirm a detected note/frequency appears and updates.

GO/NO-GO: If detection works, proceed. If it does NOT work on macOS after the above, STOP and report — the whole approach assumes mic input on the Mac, and we revisit (e.g., fall back to "Designed for iPad" runtime or reconsider input method).

- [ ] **Step 4: Commit any config changes**

```bash
git add -A
git commit -m "chore: confirm macOS mic input; add mic usage/entitlement config"
```
(If no files changed, skip the commit and note "spike passed, no config change needed.")

---

## Task 2: Centralize settings keys

**Files:**
- Modify: `audio_listen/Infrastructure/Game/GameSettingsKeys.swift`
- Modify: `audio_listen/Presentation/Settings/SettingsView.swift:11`
- Modify: `audio_listen/DI/AppDependencyContainer.swift:54,73`
- Test: `audio_listenTests/DrillModelsTests.swift` (new file; reused by later tasks)

**Interfaces:**
- Produces: `GameSettingsKeys.countdownEnabled: String` (value `"countdownEnabled"`).

- [ ] **Step 1: Write the failing test**

Create `audio_listenTests/DrillModelsTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct GameSettingsKeysTests {
    @Test func countdownKeyValueIsStable() {
        #expect(GameSettingsKeys.countdownEnabled == "countdownEnabled")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/GameSettingsKeysTests
```
Expected: FAIL — `countdownEnabled` is not a member of `GameSettingsKeys`.

- [ ] **Step 3: Add the key**

In `GameSettingsKeys.swift`, add inside the enum:
```swift
    static let countdownEnabled = "countdownEnabled"
```

- [ ] **Step 4: Replace the raw literals**

In `SettingsView.swift:11` change `@AppStorage("countdownEnabled")` to `@AppStorage(GameSettingsKeys.countdownEnabled)`.
In `AppDependencyContainer.swift:54` and `:73` change `UserDefaults.standard.bool(forKey: "countdownEnabled")` to `UserDefaults.standard.bool(forKey: GameSettingsKeys.countdownEnabled)`.

- [ ] **Step 5: Run test + build**

Run the Step 2 command. Expected: PASS. Then `xcodebuild build ... -destination 'platform=macOS'` → BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Infrastructure/Game/GameSettingsKeys.swift audio_listen/Presentation/Settings/SettingsView.swift audio_listen/DI/AppDependencyContainer.swift audio_listenTests/DrillModelsTests.swift
git commit -m "refactor: centralize countdownEnabled settings key"
```

---

## Task 3: Clock and DrillScheduler abstractions

**Files:**
- Create: `audio_listen/Domain/Protocols/Clock.swift`
- Create: `audio_listen/Domain/Protocols/DrillScheduler.swift`
- Create: `audio_listen/Infrastructure/Time/SystemClock.swift`
- Create: `audio_listen/Infrastructure/Time/TimerDrillScheduler.swift`
- Test: `audio_listenTests/ClockSchedulerTests.swift`

**Interfaces:**
- Produces:
  - `protocol Clock { func now() -> Date }`
  - `protocol DrillScheduler { func scheduleRepeating(every: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable; func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable }`
  - `struct SystemClock: Clock`, `struct TimerDrillScheduler: DrillScheduler`
  - Test doubles `FakeClock`, `FakeScheduler` (defined in the test file; later tasks reuse them — keep them in a shared test file).

- [ ] **Step 1: Write the protocols**

`Clock.swift`:
```swift
import Foundation

protocol Clock {
    func now() -> Date
}
```
`DrillScheduler.swift`:
```swift
import Combine
import Foundation

protocol DrillScheduler {
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable
    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable
}
```

- [ ] **Step 2: Write the production implementations**

`SystemClock.swift`:
```swift
import Foundation

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
```
`TimerDrillScheduler.swift`:
```swift
import Combine
import Foundation

struct TimerDrillScheduler: DrillScheduler {
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in tick() }
        RunLoop.main.add(timer, forMode: .common)
        return AnyCancellable { timer.invalidate() }
    }

    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable {
        let work = DispatchWorkItem(block: run)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return AnyCancellable { work.cancel() }
    }
}
```

- [ ] **Step 3: Write the failing test (with reusable fakes)**

`audio_listenTests/ClockSchedulerTests.swift`:
```swift
import Combine
import Foundation
import Testing
@testable import audio_listen

final class FakeClock: Clock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class FakeScheduler: DrillScheduler {
    private(set) var repeatingTicks: [() -> Void] = []
    private(set) var pendingAfter: [() -> Void] = []
    func scheduleRepeating(every interval: TimeInterval, _ tick: @escaping () -> Void) -> AnyCancellable {
        repeatingTicks.append(tick)
        return AnyCancellable { [weak self] in self?.repeatingTicks.removeAll() }
    }
    func scheduleAfter(_ delay: TimeInterval, _ run: @escaping () -> Void) -> AnyCancellable {
        pendingAfter.append(run)
        return AnyCancellable { [weak self] in self?.pendingAfter.removeAll() }
    }
    func fireRepeatingTick() { repeatingTicks.forEach { $0() } }
    func firePendingAfter() {
        let runs = pendingAfter
        pendingAfter.removeAll()
        runs.forEach { $0() }
    }
}

struct ClockSchedulerTests {
    @Test func fakeClockAdvances() {
        let c = FakeClock()
        let t0 = c.now()
        c.advance(by: 2.5)
        #expect(c.now().timeIntervalSince(t0) == 2.5)
    }

    @Test func fakeSchedulerFiresAfter() {
        let s = FakeScheduler()
        var fired = false
        _ = s.scheduleAfter(1.0) { fired = true }
        #expect(!fired)
        s.firePendingAfter()
        #expect(fired)
    }

    @Test func cancellingAfterPreventsFire() {
        let s = FakeScheduler()
        var fired = false
        let token = s.scheduleAfter(1.0) { fired = true }
        token.cancel()
        s.firePendingAfter()
        #expect(!fired)
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/ClockSchedulerTests
```
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Protocols/Clock.swift audio_listen/Domain/Protocols/DrillScheduler.swift audio_listen/Infrastructure/Time/ audio_listenTests/ClockSchedulerTests.swift
git commit -m "feat: add Clock and DrillScheduler abstractions with test fakes"
```

---

## Task 4: Drill domain models

**Files:**
- Create: `DrillDirection.swift`, `DrillItemKey.swift`, `DrillPrompt.swift`, `ItemStats.swift`, `MasteryLevel.swift` (all in `audio_listen/Domain/Models/`)
- Modify: `audio_listen/Domain/Models/Note.swift` (add `Codable` to `NoteName`)
- Test: `audio_listenTests/DrillModelsTests.swift` (append)

**Interfaces:**
- Produces:
  - `enum DrillDirection: String, Codable, CaseIterable { case findPosition, nameNote }`
  - `struct DrillItemKey: Hashable, Codable { let noteName: NoteName; let string: Int }`
  - `struct DrillPrompt: Equatable { let direction: DrillDirection; let targetNote: Note; let string: Int; var itemKey: DrillItemKey }`
  - `struct ItemStats: Codable, Equatable { var box, attempts, correct: Int; var lastReactionTime: TimeInterval?; var lastSeenAt: Date; static func unseen(at: Date) -> ItemStats }`
  - `enum MasteryLevel { case unseen, learning, mastered; static func from(box:attempts:masteredBox:) -> MasteryLevel }`
- Consumes: `Note`, `NoteName` (Task: existing).

- [ ] **Step 1: Make NoteName Codable**

In `Note.swift`, change `enum NoteName: Int, CaseIterable, Hashable {` to `enum NoteName: Int, CaseIterable, Hashable, Codable {`.

- [ ] **Step 2: Write the failing tests**

Append to `DrillModelsTests.swift`:
```swift
struct DrillModelTests {
    @Test func itemKeyRoundTripsCodable() throws {
        let key = DrillItemKey(noteName: .fSharp, string: 5)
        let data = try JSONEncoder().encode(key)
        let back = try JSONDecoder().decode(DrillItemKey.self, from: data)
        #expect(back == key)
    }

    @Test func promptDerivesItemKeyFromNoteAndString() {
        let prompt = DrillPrompt(direction: .findPosition, targetNote: Note(.c, octave: 3), string: 5)
        #expect(prompt.itemKey == DrillItemKey(noteName: .c, string: 5))
    }

    @Test func itemStatsRoundTripsCodable() throws {
        let stats = ItemStats(box: 2, attempts: 5, correct: 4, lastReactionTime: 0.9, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(stats)
        let back = try JSONDecoder().decode(ItemStats.self, from: data)
        #expect(back == stats)
    }

    @Test func masteryUnseenWhenNoAttempts() {
        #expect(MasteryLevel.from(box: 0, attempts: 0, masteredBox: 4) == .unseen)
    }

    @Test func masteryLearningBelowMasteredBox() {
        #expect(MasteryLevel.from(box: 2, attempts: 3, masteredBox: 4) == .learning)
    }

    @Test func masteryMasteredAtOrAboveBox() {
        #expect(MasteryLevel.from(box: 4, attempts: 10, masteredBox: 4) == .mastered)
    }
}
```

- [ ] **Step 3: Implement the models**

`DrillDirection.swift`:
```swift
enum DrillDirection: String, Codable, CaseIterable {
    case findPosition
    case nameNote
}
```
`DrillItemKey.swift`:
```swift
struct DrillItemKey: Hashable, Codable {
    let noteName: NoteName
    let string: Int
}
```
`DrillPrompt.swift`:
```swift
struct DrillPrompt: Equatable {
    let direction: DrillDirection
    let targetNote: Note
    let string: Int

    var itemKey: DrillItemKey {
        DrillItemKey(noteName: targetNote.name, string: string)
    }
}
```
`ItemStats.swift`:
```swift
import Foundation

struct ItemStats: Codable, Equatable {
    var box: Int
    var attempts: Int
    var correct: Int
    var lastReactionTime: TimeInterval?
    var lastSeenAt: Date

    static func unseen(at date: Date) -> ItemStats {
        ItemStats(box: 0, attempts: 0, correct: 0, lastReactionTime: nil, lastSeenAt: date)
    }
}
```
`MasteryLevel.swift`:
```swift
enum MasteryLevel {
    case unseen
    case learning
    case mastered

    static func from(box: Int, attempts: Int, masteredBox: Int) -> MasteryLevel {
        if attempts == 0 { return .unseen }
        return box >= masteredBox ? .mastered : .learning
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillModelTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/ audio_listenTests/DrillModelsTests.swift
git commit -m "feat: add drill domain models (direction, item key, prompt, stats, mastery)"
```

---

## Task 5: Drill progress repository

**Files:**
- Create: `audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift`
- Create: `audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`
- Test: `audio_listenTests/DrillProgressRepositoryTests.swift`

**Interfaces:**
- Produces:
  - `protocol DrillProgressRepositoryProtocol { func loadAll() -> [DrillItemKey: ItemStats]; func save(_ stats: [DrillItemKey: ItemStats]) }`
  - `struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol` with `static let userDefaultsKey = "audio_listen_drill_progress"` and `init(defaults: UserDefaults = .standard)`.
- Consumes: `DrillItemKey`, `ItemStats` (Task 4).

- [ ] **Step 1: Write the protocol**

`DrillProgressRepositoryProtocol.swift`:
```swift
protocol DrillProgressRepositoryProtocol {
    func loadAll() -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats])
}
```

- [ ] **Step 2: Write the failing tests**

`DrillProgressRepositoryTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct DrillProgressRepositoryTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func missingKeyLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll().isEmpty)
    }

    @Test func roundTripsStats() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        let key = DrillItemKey(noteName: .g, string: 3)
        let stats = ItemStats(box: 1, attempts: 2, correct: 1, lastReactionTime: 1.1, lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000))
        repo.save([key: stats])
        let loaded = repo.loadAll()
        #expect(loaded[key] == stats)
        #expect(loaded.count == 1)
    }

    @Test func corruptDataLoadsEmpty() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: UserDefaultsDrillProgressRepository.userDefaultsKey)
        let repo = UserDefaultsDrillProgressRepository(defaults: defaults)
        #expect(repo.loadAll().isEmpty)
    }
}
```

- [ ] **Step 3: Implement the repository**

JSON dictionaries need string keys, so persist an array of entries. `UserDefaultsDrillProgressRepository.swift`:
```swift
import Foundation

struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol {
    static let userDefaultsKey = "audio_listen_drill_progress"

    private struct Entry: Codable {
        let key: DrillItemKey
        let stats: ItemStats
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll() -> [DrillItemKey: ItemStats] {
        guard let data = defaults.data(forKey: Self.userDefaultsKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        return Dictionary(entries.map { ($0.key, $0.stats) }, uniquingKeysWith: { _, last in last })
    }

    func save(_ stats: [DrillItemKey: ItemStats]) {
        let entries = stats.map { Entry(key: $0.key, stats: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillProgressRepositoryTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Protocols/DrillProgressRepositoryProtocol.swift audio_listen/Infrastructure/Game/UserDefaultsDrillProgressRepository.swift audio_listenTests/DrillProgressRepositoryTests.swift
git commit -m "feat: add drill progress repository (UserDefaults JSON)"
```

---

## Task 6: Daily goal tracking

**Files:**
- Create: `audio_listen/Infrastructure/Game/DailyGoalStore.swift`
- Test: `audio_listenTests/DailyGoalTests.swift`

**Interfaces:**
- Produces:
  - `struct DailyGoalStore` with `init(defaults: UserDefaults = .standard, calendar: Calendar = .current)`, `static let userDefaultsKey = "audio_listen_daily_goal"`, `func todayCount(now: Date) -> Int`, `@discardableResult func recordCorrect(now: Date) -> Int`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests**

`DailyGoalTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct DailyGoalTests {
    private func makeStore() -> (DailyGoalStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DailyGoalStore(defaults: defaults, calendar: Calendar(identifier: .gregorian)), defaults, suite)
    }

    @Test func startsAtZero() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.todayCount(now: Date(timeIntervalSince1970: 1_700_000_000)) == 0)
    }

    @Test func incrementsWithinSameDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(store.recordCorrect(now: t) == 1)
        #expect(store.recordCorrect(now: t.addingTimeInterval(60)) == 2)
        #expect(store.todayCount(now: t.addingTimeInterval(120)) == 2)
    }

    @Test func resetsOnNewDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        _ = store.recordCorrect(now: day1)
        let day2 = day1.addingTimeInterval(60 * 60 * 24 + 60)
        #expect(store.todayCount(now: day2) == 0)
        #expect(store.recordCorrect(now: day2) == 1)
    }
}
```

- [ ] **Step 2: Implement the store**

`DailyGoalStore.swift`:
```swift
import Foundation

struct DailyGoalStore {
    static let userDefaultsKey = "audio_listen_daily_goal"

    private struct Record: Codable {
        var dayStart: Date
        var count: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func todayCount(now: Date) -> Int {
        guard let record = loadRecord(), calendar.isDate(record.dayStart, inSameDayAs: now) else {
            return 0
        }
        return record.count
    }

    @discardableResult
    func recordCorrect(now: Date) -> Int {
        let start = calendar.startOfDay(for: now)
        var record = loadRecord() ?? Record(dayStart: start, count: 0)
        if !calendar.isDate(record.dayStart, inSameDayAs: now) {
            record = Record(dayStart: start, count: 0)
        }
        record.count += 1
        saveRecord(record)
        return record.count
    }

    private func loadRecord() -> Record? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func saveRecord(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DailyGoalTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Infrastructure/Game/DailyGoalStore.swift audio_listenTests/DailyGoalTests.swift
git commit -m "feat: add daily goal store with day rollover"
```

---

## Task 7: Item-stats update (Leitner promote/demote)

**Files:**
- Create: `audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift`
- Test: `audio_listenTests/UpdateItemStatsTests.swift`

**Interfaces:**
- Produces:
  - `struct UpdateItemStatsUseCase { let maxBox: Int; let fastReactionSeconds: TimeInterval; init(maxBox: Int = 4, fastReactionSeconds: TimeInterval = 3.0); func applyCorrect(to: ItemStats, reactionTime: TimeInterval, now: Date) -> ItemStats; func applyMiss(to: ItemStats, now: Date) -> ItemStats }`
- Consumes: `ItemStats` (Task 4).
- Box range is `0...maxBox` (default 5 boxes: 0–4). `masteredBox` used by `MasteryLevel` == `maxBox`.

- [ ] **Step 1: Write the failing tests**

`UpdateItemStatsTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct UpdateItemStatsTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func correctAndFastPromotes() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats.unseen(at: now)
        let out = uc.applyCorrect(to: start, reactionTime: 1.0, now: now)
        #expect(out.box == 1)
        #expect(out.attempts == 1)
        #expect(out.correct == 1)
        #expect(out.lastReactionTime == 1.0)
        #expect(out.lastSeenAt == now)
    }

    @Test func correctButSlowDoesNotPromote() {
        let uc = UpdateItemStatsUseCase(maxBox: 4, fastReactionSeconds: 3.0)
        let start = ItemStats(box: 2, attempts: 3, correct: 3, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyCorrect(to: start, reactionTime: 5.0, now: now)
        #expect(out.box == 2)
        #expect(out.correct == 4)
    }

    @Test func promotionCapsAtMaxBox() {
        let uc = UpdateItemStatsUseCase(maxBox: 4, fastReactionSeconds: 3.0)
        let start = ItemStats(box: 4, attempts: 9, correct: 9, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyCorrect(to: start, reactionTime: 1.0, now: now)
        #expect(out.box == 4)
    }

    @Test func missDemotesAndCountsAttempt() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats(box: 3, attempts: 5, correct: 4, lastReactionTime: 1.0, lastSeenAt: now)
        let out = uc.applyMiss(to: start, now: now)
        #expect(out.box == 2)
        #expect(out.attempts == 6)
        #expect(out.correct == 4)
    }

    @Test func missDoesNotGoBelowZero() {
        let uc = UpdateItemStatsUseCase()
        let start = ItemStats.unseen(at: now)
        let out = uc.applyMiss(to: start, now: now)
        #expect(out.box == 0)
        #expect(out.attempts == 1)
    }
}
```

- [ ] **Step 2: Implement the use case**

`UpdateItemStatsUseCase.swift`:
```swift
import Foundation

struct UpdateItemStatsUseCase {
    let maxBox: Int
    let fastReactionSeconds: TimeInterval

    init(maxBox: Int = 4, fastReactionSeconds: TimeInterval = 3.0) {
        self.maxBox = maxBox
        self.fastReactionSeconds = fastReactionSeconds
    }

    func applyCorrect(to stats: ItemStats, reactionTime: TimeInterval, now: Date) -> ItemStats {
        var next = stats
        next.attempts += 1
        next.correct += 1
        next.lastReactionTime = reactionTime
        next.lastSeenAt = now
        if reactionTime <= fastReactionSeconds {
            next.box = min(maxBox, next.box + 1)
        }
        return next
    }

    func applyMiss(to stats: ItemStats, now: Date) -> ItemStats {
        var next = stats
        next.attempts += 1
        next.lastSeenAt = now
        next.box = max(0, next.box - 1)
        return next
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/UpdateItemStatsTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Domain/UseCases/UpdateItemStatsUseCase.swift audio_listenTests/UpdateItemStatsTests.swift
git commit -m "feat: add Leitner promote/demote item-stats update use case"
```

---

## Task 8: String-set presets

**Files:**
- Create: `audio_listen/Infrastructure/Game/StringSetPresets.swift`
- Test: `audio_listenTests/StringSetPresetsTests.swift`

**Interfaces:**
- Produces:
  - `struct StringSetPreset: Identifiable, Equatable { let id: String; let label: String; let strings: Set<Int> }`
  - `enum StringSetPresets { static let all: [StringSetPreset] }`
- Cumulative from low E (string 6) up: `E·A` = {6,5}, `E·A·D` = {6,5,4}, `E·A·D·G` = {6,5,4,3}, `E·A·D·G·B` = {6,5,4,3,2}, `All 6` = {1...6}.

- [ ] **Step 1: Write the failing tests**

`StringSetPresetsTests.swift`:
```swift
import Testing
@testable import audio_listen

struct StringSetPresetsTests {
    @Test func presetsAreCumulativeFromLowE() {
        let all = StringSetPresets.all
        #expect(all.count == 5)
        #expect(all[0].strings == Set([6, 5]))
        #expect(all[1].strings == Set([6, 5, 4]))
        #expect(all[2].strings == Set([6, 5, 4, 3]))
        #expect(all[3].strings == Set([6, 5, 4, 3, 2]))
        #expect(all[4].strings == Set(1...6))
    }

    @Test func presetIdsAreUnique() {
        let ids = StringSetPresets.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
```

- [ ] **Step 2: Implement the presets**

`StringSetPresets.swift`:
```swift
struct StringSetPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let strings: Set<Int>
}

enum StringSetPresets {
    static let all: [StringSetPreset] = [
        StringSetPreset(id: "EA", label: "E · A", strings: [6, 5]),
        StringSetPreset(id: "EAD", label: "E · A · D", strings: [6, 5, 4]),
        StringSetPreset(id: "EADG", label: "E · A · D · G", strings: [6, 5, 4, 3]),
        StringSetPreset(id: "EADGB", label: "E · A · D · G · B", strings: [6, 5, 4, 3, 2]),
        StringSetPreset(id: "ALL", label: "All 6", strings: Set(1...6))
    ]
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/StringSetPresetsTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Infrastructure/Game/StringSetPresets.swift audio_listenTests/StringSetPresetsTests.swift
git commit -m "feat: add cumulative string-set presets"
```

---

## Task 9: Next-prompt selection (candidates + weighted pick)

**Files:**
- Create: `audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift`
- Test: `audio_listenTests/SelectNextPromptTests.swift`

**Interfaces:**
- Produces:
  - `struct SelectNextPromptUseCase { init(maxBox: Int = 4, nameNoteProbability: Double = 0.25); func candidates(allowedStrings: Set<Int>, allowedNoteNames: Set<NoteName>, maxFretInclusive: Int) -> [DrillItemKey]; func next(allowedStrings: Set<Int>, allowedNoteNames: Set<NoteName>, maxFretInclusive: Int, stats: [DrillItemKey: ItemStats], now: Date, randomUnit: () -> Double) -> DrillPrompt? }`
- Consumes: `GuitarFretboard.note(at:fret:)`, `DrillItemKey`, `ItemStats`, `DrillPrompt`, `DrillDirection`, `Note`, `NoteName`.
- Selection weight per item: `weight = Double(maxBox - stats.box) + 1` (unseen/low box → higher weight); `randomUnit()` returns `[0,1)` and is used to pick within the cumulative weight and to choose direction (`< nameNoteProbability` → `.nameNote`).

- [ ] **Step 1: Write the failing tests**

`SelectNextPromptTests.swift`:
```swift
import Foundation
import Testing
@testable import audio_listen

struct SelectNextPromptTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func candidatesCoverEachAllowedNoteNameOncePerString() {
        let uc = SelectNextPromptUseCase()
        let cands = uc.candidates(
            allowedStrings: Set([6, 5]),
            allowedNoteNames: Set(NoteName.allCases),
            maxFretInclusive: 11
        )
        #expect(cands.count == 24)
        #expect(Set(cands).count == 24)
        #expect(cands.allSatisfy { [6, 5].contains($0.string) })
    }

    @Test func candidatesRespectAllowedNoteNames() {
        let uc = SelectNextPromptUseCase()
        let allowed: Set<NoteName> = [.c, .g]
        let cands = uc.candidates(allowedStrings: Set([6]), allowedNoteNames: allowed, maxFretInclusive: 11)
        #expect(cands.allSatisfy { allowed.contains($0.noteName) })
        #expect(cands.count == 2)
    }

    @Test func nextReturnsNilWhenNoCandidates() {
        let uc = SelectNextPromptUseCase()
        let prompt = uc.next(allowedStrings: [], allowedNoteNames: Set(NoteName.allCases), maxFretInclusive: 11, stats: [:], now: now, randomUnit: { 0.0 })
        #expect(prompt == nil)
    }

    @Test func nextProducesAValidPromptForTheCandidate() {
        let uc = SelectNextPromptUseCase()
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.e], maxFretInclusive: 11, stats: [:], now: now, randomUnit: { 0.99 })
        #expect(prompt != nil)
        #expect(prompt?.string == 6)
        #expect(prompt?.targetNote.name == .e)
        let board = GuitarFretboard.note(at: prompt!.string, fret: 0)
        #expect(board?.name == .e)
    }

    @Test func weightingPrefersLowerBoxItems() {
        let uc = SelectNextPromptUseCase(maxBox: 4, nameNoteProbability: 0.0)
        let weakKey = DrillItemKey(noteName: .c, string: 6)
        let strongKey = DrillItemKey(noteName: .f, string: 6)
        let stats: [DrillItemKey: ItemStats] = [
            weakKey: ItemStats(box: 0, attempts: 1, correct: 0, lastReactionTime: nil, lastSeenAt: now),
            strongKey: ItemStats(box: 4, attempts: 9, correct: 9, lastReactionTime: 1.0, lastSeenAt: now)
        ]
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.c, .f], maxFretInclusive: 11, stats: stats, now: now, randomUnit: { 0.0 })
        #expect(prompt?.itemKey == weakKey)
    }

    @Test func directionUsesNameNoteWhenRandomBelowProbability() {
        let uc = SelectNextPromptUseCase(maxBox: 4, nameNoteProbability: 0.5)
        var calls = 0
        let randoms: [Double] = [0.1, 0.0]
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.e], maxFretInclusive: 11, stats: [:], now: now, randomUnit: {
            defer { calls += 1 }
            return randoms[min(calls, randoms.count - 1)]
        })
        #expect(prompt?.direction == .nameNote)
    }
}
```

- [ ] **Step 2: Implement the use case**

`SelectNextPromptUseCase.swift`:
```swift
import Foundation

struct SelectNextPromptUseCase {
    let maxBox: Int
    let nameNoteProbability: Double

    init(maxBox: Int = 4, nameNoteProbability: Double = 0.25) {
        self.maxBox = maxBox
        self.nameNoteProbability = nameNoteProbability
    }

    func candidates(
        allowedStrings: Set<Int>,
        allowedNoteNames: Set<NoteName>,
        maxFretInclusive: Int
    ) -> [DrillItemKey] {
        var result: [DrillItemKey] = []
        for string in allowedStrings.sorted() {
            for fret in 0...maxFretInclusive {
                guard let note = GuitarFretboard.note(at: string, fret: fret) else { continue }
                guard allowedNoteNames.contains(note.name) else { continue }
                let key = DrillItemKey(noteName: note.name, string: string)
                if !result.contains(key) {
                    result.append(key)
                }
            }
        }
        return result
    }

    func next(
        allowedStrings: Set<Int>,
        allowedNoteNames: Set<NoteName>,
        maxFretInclusive: Int,
        stats: [DrillItemKey: ItemStats],
        now: Date,
        randomUnit: () -> Double
    ) -> DrillPrompt? {
        let keys = candidates(allowedStrings: allowedStrings, allowedNoteNames: allowedNoteNames, maxFretInclusive: maxFretInclusive)
        guard !keys.isEmpty else { return nil }

        let weights = keys.map { key -> Double in
            let box = stats[key]?.box ?? 0
            return Double(maxBox - box) + 1
        }
        let total = weights.reduce(0, +)
        let directionRoll = randomUnit()
        let pick = randomUnit() * total

        var cumulative = 0.0
        var chosen = keys[0]
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if pick < cumulative {
                chosen = keys[index]
                break
            }
        }

        guard let note = noteFor(key: chosen, maxFretInclusive: maxFretInclusive) else { return nil }
        let direction: DrillDirection = directionRoll < nameNoteProbability ? .nameNote : .findPosition
        return DrillPrompt(direction: direction, targetNote: note, string: chosen.string)
    }

    private func noteFor(key: DrillItemKey, maxFretInclusive: Int) -> Note? {
        for fret in 0...maxFretInclusive {
            if let note = GuitarFretboard.note(at: key.string, fret: fret), note.name == key.noteName {
                return note
            }
        }
        return nil
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/SelectNextPromptTests
```
Expected: PASS. (If `candidatesCoverEachAllowedNoteNameOncePerString` expects 24 but the fret range yields a different count, confirm `GuitarFretboard.note(at:fret:)` returns a note for frets 0–11 on strings 5–6; adjust the expected count to `allowedStrings.count * 12` only if the board model legitimately differs, and note the reason in the commit.)

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Domain/UseCases/SelectNextPromptUseCase.swift audio_listenTests/SelectNextPromptTests.swift
git commit -m "feat: add weighted next-prompt selection use case"
```

---

## Task 10: Drill state + state machine (single source of truth)

**Files:**
- Create: `audio_listen/Domain/Models/DrillState.swift`
- Create: `audio_listen/Presentation/Drill/DrillStateMachine.swift`
- Test: `audio_listenTests/DrillViewModelTests.swift` (new file; state-machine tests first)

**Interfaces:**
- Produces:
  - `enum DrillState: Equatable { case idle; case countdown(remaining: Int, prompt: DrillPrompt); case playing(startTime: Date, prompt: DrillPrompt); case success(reactionTime: TimeInterval, prompt: DrillPrompt) }`
  - `final class DrillStateMachine { private(set) var state: DrillState; var onStateChange: ((DrillState) -> Void)?; @discardableResult func transition(to: DrillState) -> Bool }`
- Consumes: `DrillPrompt` (Task 4).
- Allowed transitions: idle→countdown, idle→playing, countdown→playing, playing→success, success→playing, playing→idle, success→idle, countdown→idle. `onStateChange` fires once on every accepted transition.

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/DrillViewModelTests.swift`:
```swift
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
```

- [ ] **Step 2: Implement the state and machine**

`DrillState.swift`:
```swift
import Foundation

enum DrillState: Equatable {
    case idle
    case countdown(remaining: Int, prompt: DrillPrompt)
    case playing(startTime: Date, prompt: DrillPrompt)
    case success(reactionTime: TimeInterval, prompt: DrillPrompt)
}
```
`DrillStateMachine.swift`:
```swift
import Foundation

final class DrillStateMachine {
    private(set) var state: DrillState = .idle
    var onStateChange: ((DrillState) -> Void)?

    @discardableResult
    func transition(to newState: DrillState) -> Bool {
        switch (state, newState) {
        case (.idle, .countdown), (.idle, .playing),
             (.countdown, .playing), (.countdown, .idle),
             (.playing, .success), (.playing, .idle),
             (.success, .playing), (.success, .idle):
            break
        default:
            return false
        }
        state = newState
        onStateChange?(newState)
        return true
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillStateMachineTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Domain/Models/DrillState.swift audio_listen/Presentation/Drill/DrillStateMachine.swift audio_listenTests/DrillViewModelTests.swift
git commit -m "feat: add drill state machine with single onStateChange path"
```

---

## Task 11: DrillViewModel (loop, validation, stats, daily goal)

**Files:**
- Create: `audio_listen/Presentation/Drill/DrillViewModel.swift`
- Test: `audio_listenTests/DrillViewModelTests.swift` (append)

**Interfaces:**
- Produces: `@MainActor final class DrillViewModel: ObservableObject` with:
  - `@Published private(set) var state: DrillState`
  - `@Published private(set) var detectedNote: String`
  - `@Published private(set) var todayCount: Int`
  - `@Published var errorMessage: String?`
  - `init(pitchDetector: PitchDetectorProtocol, selectNextPrompt: SelectNextPromptUseCase, updateStats: UpdateItemStatsUseCase, validateNote: ValidateNoteUseCase, stateMachine: DrillStateMachine, progressRepository: DrillProgressRepositoryProtocol, dailyGoalStore: DailyGoalStore, clock: Clock, scheduler: DrillScheduler, allowedStrings: @escaping () -> Set<Int>, allowedNoteNames: @escaping () -> Set<NoteName>, maxFretInclusive: @escaping () -> Int, countdownEnabled: Bool, randomUnit: @escaping () -> Double)`
  - `func start()`, `func stop()`, `func skip()`
- Consumes: everything from Tasks 3–10, plus existing `PitchDetectorProtocol`, `ValidateNoteUseCase`, `DetectedPitch`.

**Behavior:** `start()` selects a prompt (error if none); if `countdownEnabled`, runs a 3-tick countdown via `scheduler.scheduleRepeating(every: 1)`, else begins playing immediately. `playing` records `clock.now()` as start, subscribes to pitch, and on a validated note computes reaction time from `clock.now()`, updates+persists stats (correct), increments daily goal, transitions to `success`, then schedules auto-advance via `scheduler.scheduleAfter(1.0)`. `skip()` applies a miss to current prompt's stats and advances. `stop()` cancels timers/subscription and returns to idle.

- [ ] **Step 1: Write the failing tests**

Append to `audio_listenTests/DrillViewModelTests.swift`:
```swift
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

    @Test @MainActor func correctNoteTransitionsToSuccessAndRecordsReaction() {
        let detector = StubPitchDetector()
        let clock = FakeClock()
        let (vm, repo) = makeViewModel(detector: detector, clock: clock, scheduler: FakeScheduler(), countdownEnabled: false)
        vm.start()
        clock.advance(by: 2.0)
        detector.subject.send(DetectedPitch(note: Note(.e, octave: 2), frequency: 82.41, amplitude: 0.1))
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
}
```

- [ ] **Step 2: Implement DrillViewModel**

`DrillViewModel.swift`:
```swift
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
    private let dailyGoalStore: DailyGoalStore
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
        dailyGoalStore: DailyGoalStore,
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
        self.dailyGoalStore = dailyGoalStore
        self.clock = clock
        self.scheduler = scheduler
        self.allowedStrings = allowedStrings
        self.allowedNoteNames = allowedNoteNames
        self.maxFretInclusive = maxFretInclusive
        self.countdownEnabled = countdownEnabled
        self.randomUnit = randomUnit
        self.todayCount = dailyGoalStore.todayCount(now: clock.now())

        stateMachine.onStateChange = { [weak self] newState in
            self?.state = newState
        }
    }

    func start() {
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
        guard let prompt = currentPrompt() else { return }
        recordMiss(for: prompt)
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

    private func currentPrompt() -> DrillPrompt? {
        switch state {
        case .countdown(_, let p), .playing(_, let p), .success(_, let p): return p
        case .idle: return nil
        }
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
        todayCount = dailyGoalStore.recordCorrect(now: clock.now())
    }

    private func recordMiss(for prompt: DrillPrompt) {
        var all = progressRepository.loadAll()
        let current = all[prompt.itemKey] ?? ItemStats.unseen(at: clock.now())
        all[prompt.itemKey] = updateStats.applyMiss(to: current, now: clock.now())
        progressRepository.save(all)
    }
}
```
Note: `handle` reads `state` (the published mirror updated by `onStateChange`), which is kept in lockstep with the machine via the single callback — no manual mirroring.

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/DrillViewModelTests
```
Expected: PASS (all five) plus `DrillStateMachineTests`.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillViewModel.swift audio_listenTests/DrillViewModelTests.swift
git commit -m "feat: add DrillViewModel game loop with injected clock/scheduler"
```

---

## Task 12: Fretboard geometry helper

**Files:**
- Create: `audio_listen/Presentation/Drill/FretboardGeometry.swift`
- Test: `audio_listenTests/FretboardGeometryTests.swift`

**Interfaces:**
- Produces: `struct FretboardGeometry { let size: CGSize; let stringCount: Int; let fretCount: Int; init(size:stringCount:fretCount:); func point(string: Int, fret: Int) -> CGPoint; func stringY(_ string: Int) -> CGFloat }`
- Layout: string 1 (high E) at top, string `stringCount` (low E) at bottom; fret 0 (open/nut) at the left edge, fret `fretCount` at the right edge. A fret dot is centered in its fret cell (between fret wires); fret 0 sits at the nut line.

- [ ] **Step 1: Write the failing tests**

`FretboardGeometryTests.swift`:
```swift
import CoreGraphics
import Testing
@testable import audio_listen

struct FretboardGeometryTests {
    let geo = FretboardGeometry(size: CGSize(width: 600, height: 250), stringCount: 6, fretCount: 12)

    @Test func string1IsAboveString6() {
        #expect(geo.stringY(1) < geo.stringY(6))
    }

    @Test func openFretIsLeftOfFret12() {
        #expect(geo.point(string: 3, fret: 0).x < geo.point(string: 3, fret: 12).x)
    }

    @Test func pointsStayWithinBounds() {
        for string in 1...6 {
            for fret in 0...12 {
                let p = geo.point(string: string, fret: fret)
                #expect(p.x >= 0 && p.x <= 600)
                #expect(p.y >= 0 && p.y <= 250)
            }
        }
    }
}
```

- [ ] **Step 2: Implement geometry**

`FretboardGeometry.swift`:
```swift
import CoreGraphics

struct FretboardGeometry {
    let size: CGSize
    let stringCount: Int
    let fretCount: Int

    init(size: CGSize, stringCount: Int = 6, fretCount: Int = 12) {
        self.size = size
        self.stringCount = stringCount
        self.fretCount = fretCount
    }

    func stringY(_ string: Int) -> CGFloat {
        let inset = size.height / CGFloat(stringCount + 1)
        return inset * CGFloat(string)
    }

    func point(string: Int, fret: Int) -> CGPoint {
        let cellWidth = size.width / CGFloat(fretCount + 1)
        let x = cellWidth * (CGFloat(fret) + 0.5)
        return CGPoint(x: x, y: stringY(string))
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/FretboardGeometryTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Drill/FretboardGeometry.swift audio_listenTests/FretboardGeometryTests.swift
git commit -m "feat: add pure fretboard geometry helper"
```

---

## Task 13: FretboardView (SwiftUI)

**Files:**
- Create: `audio_listen/Presentation/Drill/FretboardView.swift`

**Interfaces:**
- Produces: `struct FretboardView: View` with `init(highlightedString: Int?, highlightedPosition: FretPosition?, revealLabel: String?, heatmap: [DrillItemKey: MasteryLevel])` (all optional/defaulted) using `FretboardGeometry` for layout.
- Consumes: `FretboardGeometry` (Task 12), `FretPosition`, `DrillItemKey`, `MasteryLevel`.

SwiftUI rendering is verified by build + Xcode Preview + the geometry tests, not by unit tests.

- [ ] **Step 1: Implement the view**

`FretboardView.swift`:
```swift
import SwiftUI

struct FretboardView: View {
    var highlightedString: Int? = nil
    var highlightedPosition: FretPosition? = nil
    var revealLabel: String? = nil
    var heatmap: [DrillItemKey: MasteryLevel] = [:]

    private let stringCount = 6
    private let fretCount = 12

    var body: some View {
        GeometryReader { proxy in
            let geo = FretboardGeometry(size: proxy.size, stringCount: stringCount, fretCount: fretCount)
            ZStack {
                fretLines(geo)
                stringLines(geo)
                if let string = highlightedString {
                    stringGlow(geo, string: string)
                }
                if let position = highlightedPosition {
                    targetDot(geo, position: position)
                }
            }
        }
        .frame(minHeight: 220)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fretLines(_ geo: FretboardGeometry) -> some View {
        ForEach(0...fretCount, id: \.self) { fret in
            let x = geo.size.width / CGFloat(fretCount + 1) * CGFloat(fret + 1)
            Path { p in
                p.move(to: CGPoint(x: x, y: geo.stringY(1)))
                p.addLine(to: CGPoint(x: x, y: geo.stringY(stringCount)))
            }
            .stroke(Color.gray.opacity(fret == 0 ? 0.9 : 0.4), lineWidth: fret == 0 ? 3 : 1)
        }
    }

    private func stringLines(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
        }
    }

    private func stringGlow(_ geo: FretboardGeometry, string: Int) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
            p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
        }
        .stroke(Color.yellow, lineWidth: 3)
    }

    private func targetDot(_ geo: FretboardGeometry, position: FretPosition) -> some View {
        let point = geo.point(string: position.string, fret: position.fret)
        return ZStack {
            Circle().fill(Color.orange).frame(width: 22, height: 22).position(point)
            if let label = revealLabel {
                Text(label).font(.caption).bold().foregroundStyle(.white)
                    .position(x: point.x, y: point.y - 20)
            }
        }
    }
}

#Preview {
    FretboardView(highlightedPosition: FretPosition(string: 5, fret: 3), revealLabel: "C")
        .padding()
}
```

- [ ] **Step 2: Build and preview**

Run:
```bash
xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED. Open `FretboardView.swift` in Xcode and confirm the Preview renders a board with the C dot on string 5.

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Presentation/Drill/FretboardView.swift
git commit -m "feat: add SwiftUI fretboard view"
```

---

## Task 14: DrillView (cue-up UX + keyboard shortcuts)

**Files:**
- Create: `audio_listen/Presentation/Drill/DrillView.swift`

**Interfaces:**
- Produces: `struct DrillView: View` with `init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore, allowedNoteNamesStore: GameAllowedNoteNamesStore)`.
- Consumes: `DrillViewModel`, `DrillState`, `DrillPrompt`, `FretboardView`, `StringSetPresets`, `GameAllowedStringsStore`, `GameAllowedNoteNamesStore`, `GuitarFretboard`.

Keyboard: Space = start/next (`.keyboardShortcut(.space, modifiers: [])`), Esc = end (`.keyboardShortcut(.cancelAction)`), S = skip (`.keyboardShortcut("s", modifiers: [])`). For the `nameNote` direction, compute the highlighted `FretPosition` from `(prompt.targetNote, prompt.string)` via `GuitarFretboard.positions(for:)` filtered to the prompt string; hide the fret for `findPosition` and glow the string instead.

- [ ] **Step 1: Implement the view**

`DrillView.swift`:
```swift
import SwiftUI

struct DrillView: View {
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore
    private let allowedNoteNamesStore: GameAllowedNoteNamesStore

    @State private var allowedStrings: Set<Int> = Set(1...6)

    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore, allowedNoteNamesStore: GameAllowedNoteNamesStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
        self.allowedNoteNamesStore = allowedNoteNamesStore
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            content
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 480)
        .onAppear { allowedStrings = allowedStringsStore.load() }
    }

    private var header: some View {
        HStack {
            Text("Fretboard Drill").font(.title2).bold()
            Spacer()
            Text("Today: \(viewModel.todayCount)").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleSetup
        case .countdown(let remaining, let prompt):
            promptView(prompt, reveal: false)
            Text("\(remaining)").font(.system(size: 56, weight: .bold))
            controlButtons
        case .playing(_, let prompt):
            promptView(prompt, reveal: false)
            Text("Detected: \(viewModel.detectedNote)").foregroundStyle(.secondary)
            controlButtons
        case .success(let time, let prompt):
            promptView(prompt, reveal: true)
            Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            controlButtons
        }
    }

    private var idleSetup: some View {
        VStack(spacing: 16) {
            Text("Pick strings, then press Space to start").foregroundStyle(.secondary)
            HStack {
                ForEach(StringSetPresets.all) { preset in
                    Button(preset.label) {
                        allowedStrings = preset.strings
                        allowedStringsStore.save(preset.strings)
                    }
                    .buttonStyle(.bordered)
                }
            }
            FretboardView(heatmap: [:])
            Button("Start") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(allowedStrings.isEmpty)
        }
    }

    private func promptView(_ prompt: DrillPrompt, reveal: Bool) -> some View {
        VStack(spacing: 12) {
            switch prompt.direction {
            case .findPosition:
                Text("\(prompt.targetNote.name.displayName) — string \(prompt.string)")
                    .font(.system(size: 48, weight: .bold))
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil
                )
            case .nameNote:
                Text(reveal ? prompt.targetNote.name.displayName : "Name this note")
                    .font(.system(size: 40, weight: .bold))
                FretboardView(
                    highlightedPosition: position(for: prompt),
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil
                )
            }
        }
    }

    private func position(for prompt: DrillPrompt) -> FretPosition? {
        GuitarFretboard.positions(for: prompt.targetNote)
            .first { $0.string == prompt.string }
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button("Skip") { viewModel.skip() }
                .keyboardShortcut("s", modifiers: [])
            Button("End") { viewModel.stop() }
                .keyboardShortcut(.cancelAction)
                .tint(.red)
            Button("Next") { viewModel.start() }
                .keyboardShortcut(.space, modifiers: [])
        }
    }
}
```
Note: `Next`/`Start` both call `viewModel.start()`; during `success` the auto-advance also fires — pressing Space simply advances sooner. Verify `GuitarFretboard.positions(for:)` exists with this signature (it is used in existing tests); if its name differs, use the existing board API to map note→positions.

- [ ] **Step 2: Build**

```bash
xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED. (This view is not wired into the app until Task 16; build confirms it compiles.)

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: add drill view with macOS keyboard cue-up"
```

---

## Task 15: MasteryView (heatmap + summary)

**Files:**
- Create: `audio_listen/Presentation/Drill/MasteryView.swift`

**Interfaces:**
- Produces: `struct MasteryView: View` with `init(progressRepository: DrillProgressRepositoryProtocol, masteredBox: Int = 4)`.
- Consumes: `DrillProgressRepositoryProtocol`, `ItemStats`, `MasteryLevel`, `DrillItemKey`, `FretboardView`.

- [ ] **Step 1: Implement the view**

`MasteryView.swift`:
```swift
import SwiftUI

struct MasteryView: View {
    private let progressRepository: DrillProgressRepositoryProtocol
    private let masteredBox: Int

    @State private var heatmap: [DrillItemKey: MasteryLevel] = [:]
    @State private var totals: (unseen: Int, learning: Int, mastered: Int) = (0, 0, 0)

    init(progressRepository: DrillProgressRepositoryProtocol, masteredBox: Int = 4) {
        self.progressRepository = progressRepository
        self.masteredBox = masteredBox
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Progress").font(.title2).bold()
            FretboardView(heatmap: heatmap)
            HStack(spacing: 24) {
                legend(color: .gray, label: "Unseen \(totals.unseen)")
                legend(color: .orange, label: "Learning \(totals.learning)")
                legend(color: .green, label: "Mastered \(totals.mastered)")
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
        .onAppear(perform: reload)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }

    private func reload() {
        let stats = progressRepository.loadAll()
        var map: [DrillItemKey: MasteryLevel] = [:]
        var u = 0, l = 0, m = 0
        for (key, s) in stats {
            let level = MasteryLevel.from(box: s.box, attempts: s.attempts, masteredBox: masteredBox)
            map[key] = level
            switch level {
            case .unseen: u += 1
            case .learning: l += 1
            case .mastered: m += 1
            }
        }
        heatmap = map
        totals = (u, l, m)
    }
}
```
Note: rendering each heatmap cell as a colored dot on the board is a follow-up refinement; this task wires the data + legend and reuses `FretboardView`. If you extend `FretboardView` to draw heatmap dots, do it here behind the existing `heatmap` parameter (already plumbed).

- [ ] **Step 2: Build**

```bash
xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Presentation/Drill/MasteryView.swift
git commit -m "feat: add mastery progress view"
```

---

## Task 16: Wire DI + ContentView, remove old tabs, full verification

**Files:**
- Modify: `audio_listen/DI/AppDependencyContainer.swift`
- Modify: `audio_listen/ContentView.swift`
- Remove: `GameView.swift`, `NoteNameGameView.swift`, `GameViewModel.swift`, `GameStateMachine.swift`, `GameState.swift` (and `SessionStatsView.swift` if unreferenced)

**Interfaces:**
- Produces: `AppDependencyContainer.makeDrillViewModel() -> DrillViewModel`; a macOS `ContentView` exposing Drill, Progress, Tuner, Settings.

- [ ] **Step 1: Add the drill factory to the container**

In `AppDependencyContainer.swift`, add a stored `let drillProgressRepository: DrillProgressRepositoryProtocol` and `let dailyGoalStore = DailyGoalStore()` (initialize `drillProgressRepository = UserDefaultsDrillProgressRepository()` in `init`), then add:
```swift
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
```
Remove `makeGameViewModel()` and `makeNoteNameGameViewModel()`. Keep `makeTunerViewModel()`. Confirm `AllowedStringsProviding` exposes `allowedStrings` and `AllowedNoteNamesProviding` exposes `allowedNoteNames` (used in old code); if the property names differ, use the existing accessors.

- [ ] **Step 2: Restructure ContentView for macOS**

Replace `ContentView.swift` body with a Drill-first layout:
```swift
import SwiftUI

struct ContentView: View {
    private let container = AppDependencyContainer.shared

    var body: some View {
        TabView {
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                allowedNoteNamesStore: container.allowedNoteNamesStore
            )
            .tabItem { Label("Drill", systemImage: "guitars.fill") }

            MasteryView(progressRepository: container.drillProgressRepository)
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            TunerView(viewModel: container.makeTunerViewModel())
                .tabItem { Label("Tuner", systemImage: "tuningfork") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .frame(minWidth: 720, minHeight: 560)
    }
}

#Preview { ContentView() }
```

- [ ] **Step 3: Remove the old game files**

First confirm nothing else references them:
```bash
grep -rn "GameView\|NoteNameGameView\|GameViewModel\|GameStateMachine\|GameState\|SessionStatsView" audio_listen --include="*.swift" | grep -v "/Drill/" | grep -v worktrees
```
Then delete the now-unreferenced files (`GameView.swift`, `NoteNameGameView.swift`, `GameViewModel.swift`, `GameStateMachine.swift`, `GameState.swift`, and `SessionStatsView.swift` only if it shows no remaining references). Remove their `PBXFileReference`/`PBXBuildFile` entries from the Xcode project (in Xcode: delete with "Move to Trash", or edit `project.pbxproj`). Keep `GameTargetPrompt.swift` only if still referenced; otherwise remove it too.

- [ ] **Step 4: Full build + full test run**

```bash
xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED and all tests pass (new drill suites + retained domain suites). Fix any references to removed types.

- [ ] **Step 5: Manual end-to-end verification on macOS**

Launch the app. Confirm: opens to **Drill**; preset buttons set strings; **Space** starts; a `note — string` prompt appears; playing the correct note advances to "Correct!" with a reaction time; **S** skips; **Esc** ends; **Progress** tab shows updated counts; **Tuner** still works.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire adaptive drill into macOS app, remove legacy game tabs"
```

---

## Self-Review

**Spec coverage:**
- Unified mixed-direction drill → Tasks 4, 9, 11, 14 ✓
- name→position primary, nameNote occasional (probability) → Task 9 (`nameNoteProbability`), Task 14 ✓
- Validation pitch+octave via existing `ValidateNoteUseCase` → Task 11 ✓
- Mastery keyed on `(NoteName, string)` → Tasks 4, 5 ✓
- Leitner promote/demote + exploration weighting → Tasks 7, 9 ✓
- String-set presets (cumulative from low E) → Tasks 8, 14 ✓
- Visual fretboard + geometry → Tasks 12, 13 ✓
- Progress heatmap + daily goal + summary → Tasks 6, 11 (`todayCount`), 15 ✓
- macOS cue-up + keyboard shortcuts + Drill-first layout → Tasks 14, 16 ✓
- Verify-first mic spike → Task 1 ✓
- Quality bits (centralize keys, SSOT, injected Clock/Scheduler) → Tasks 2, 3, 10, 11 ✓
- Remove old tabs → Task 16 ✓

**Open follow-ups (intentionally light, not blocking):** drawing per-cell heatmap dots inside `FretboardView` (data already plumbed in Task 15); session-summary "weakest items" list (data available from the repo) can be added to `MasteryView` if desired.

**Placeholder scan:** No TBD/TODO; every code step contains complete code. View tasks (13–15) are explicitly verified by build + preview + manual run rather than fake unit tests, which is correct for SwiftUI rendering.

**Type consistency:** `DrillItemKey`, `ItemStats`, `DrillPrompt`, `DrillState`, `Clock`, `DrillScheduler`, `SelectNextPromptUseCase.next(...)`, `UpdateItemStatsUseCase.applyCorrect/applyMiss`, and `DrillProgressRepositoryProtocol.loadAll/save` signatures are used identically across Tasks 4–16. `FakeClock`/`FakeScheduler` defined once in Task 3's test file and reused.

**Assumptions to verify during execution (flagged at point of use):** `GuitarFretboard.note(at:fret:)` and `GuitarFretboard.positions(for:)` signatures (used in existing tests, so expected stable); `AllowedStringsProviding.allowedStrings` / `AllowedNoteNamesProviding.allowedNoteNames` accessor names; exact candidate count (24) for strings 5–6 over frets 0–11.
