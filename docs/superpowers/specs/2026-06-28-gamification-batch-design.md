# Gamification Batch — Belts, Trend, Combo Juice — Design

Date: 2026-06-28
Status: Approved (design); pending implementation plan
Builds on: 2026-06-28-adaptive-fretboard-trainer-design.md

## Goal

Add a game layer on top of the adaptive fretboard drill to reward speed and
daily consistency: an overall **belt rank**, a **trend graph** of progress over
days, and an **escalating combo** with sound + visual juice.

## Non-Goals (YAGNI)

- Daily-practice streak, XP/points, challenges/quests, leaderboards, haptics
- Backfilling historical trend data (no past data exists; trend starts at ship)
- Image/art assets (UI uses SF Symbols, SwiftUI shapes, Swift Charts)
- Per-note belt colors on the board (overall belt only; the 3-level heatmap stays)

## Shared Foundation

### DrillTuning constants
Consolidate the duplicated magic numbers into one source of truth:

```swift
enum DrillTuning {
    static let maxBox = 4
    static let fastReactionSeconds: TimeInterval = 3.0
}
```

`UpdateItemStatsUseCase`, `SelectNextPromptUseCase`, and `MasteryView` currently
hardcode `4` / `3.0`. Update their defaults to read from `DrillTuning`. Belts,
combo, and the mastered-count snapshot all reference these.

The note×string universe is the 72 items (12 note names × 6 strings, frets
0–11), enumerated via `SelectNextPromptUseCase().candidates(allowedStrings:
Set(1...6), allowedNoteNames: Set(NoteName.allCases), maxFretInclusive: 11)`.

## Feature 1 — Overall Belt Rank

### Metric
Total Leitner box-points as a fraction of the maximum:

```
fraction = sum(stats[item].box for item in universe) / (72 * DrillTuning.maxBox)
```

Items with no stored stats count as box 0. This rewards both coverage and depth
(partial credit), so progress moves smoothly rather than all-or-nothing.

### Belts (8 tiers)
White → Yellow → Orange → Green → Blue → Purple → Brown → Black, with lower
thresholds (fraction of max box-points):

| Belt | Min fraction |
|------|--------------|
| White | 0.00 |
| Yellow | 0.12 |
| Orange | 0.25 |
| Green | 0.40 |
| Blue | 0.55 |
| Purple | 0.70 |
| Brown | 0.85 |
| Black | 0.97 |

### Component
Pure value type, fully unit-tested:

```swift
enum Belt: Int, CaseIterable { case white, yellow, orange, green, blue, purple, brown, black
    var displayName: String   // "White" ... "Black"
    var color: Color          // mapped SwiftUI colors
}

struct BeltRank: Equatable {
    let belt: Belt
    let fraction: Double          // overall fraction [0, 1]
    let fractionToNext: Double    // progress within current belt toward next [0, 1]; 1.0 at Black
    static func from(stats: [DrillItemKey: ItemStats], maxBox: Int, universeSize: Int) -> BeltRank
}
```

`Belt.color` lives in a SwiftUI-importing extension if needed to keep the core
enum testable without SwiftUI; the threshold/`from` logic must be testable
without SwiftUI.

### Display
- Compact belt chip in the `DrillView` header (symbol + belt name in belt color).
- Belt card in the Progress tab (`MasteryView`): belt name, color, and a progress
  bar showing `fractionToNext` to the next belt (Black shows "max").

## Feature 2 — Trend Graph

### Persistence: DailyHistoryStore (replaces DailyGoalStore)
`DailyGoalStore` is removed; `DailyHistoryStore` subsumes its daily-count role
and adds the series the graph needs. Persists an array of per-day records in
UserDefaults (JSON), under `static let userDefaultsKey = "audio_listen_daily_history"`:

```swift
struct DailyRecord: Codable, Equatable {
    var dayStart: Date
    var reps: Int
    var reactionSum: TimeInterval
    var reactionCount: Int
    var masteredSnapshot: Int
    var averageReaction: Double   // computed: reactionCount == 0 ? 0 : reactionSum / Double(reactionCount)
}

struct DailyHistoryStore {
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current)
    static let userDefaultsKey = "audio_listen_daily_history"
    func todayReps(now: Date) -> Int
    func history() -> [DailyRecord]                                  // sorted ascending by dayStart
    @discardableResult
    func recordCorrect(now: Date, reactionTime: TimeInterval, masteredCount: Int) -> Int  // returns today's reps
}
```

`recordCorrect` finds or creates today's record (calendar-day rollover, same as
the old goal store), increments `reps`, adds `reactionTime` to the running sum,
and overwrites `masteredSnapshot` with the latest mastered count. Migration: a
missing key yields an empty history (the old `audio_listen_daily_goal` key is
abandoned; no migration needed — counts simply start fresh).

### Wiring
`DrillViewModel` replaces its `DailyGoalStore` dependency with
`DailyHistoryStore`. On a correct answer it computes the mastered count
(`stats.values.filter { $0.box >= DrillTuning.maxBox }.count` after the stats
update) and calls `recordCorrect(now:reactionTime:masteredCount:)`; the returned
value updates the published `todayCount`.

### Component
`TrendView` (Progress tab), using **Swift Charts** (`import Charts`; available at
deployment target 14.6):
- A segmented metric picker: **Reps**, **Notes mastered**, **Avg reaction time**.
- A `LineMark` series over `history()` (x = day, y = selected metric).
- Empty/one-point history renders a friendly "play to see your trend" state.

## Feature 3 — Escalating Combo + Juice

### Combo logic (DrillViewModel)
Add `@Published private(set) var comboCount: Int = 0`. Transitions:
- On success with `reaction <= DrillTuning.fastReactionSeconds`: `comboCount += 1`.
- On success slower than that: `comboCount = 0`.
- On `skip()`: `comboCount = 0`.
- On `start()`: `comboCount = 0`.

This logic is unit-tested. The VM contains NO audio/animation code.

### Visual (DrillView)
- A "🔥 N" combo badge shown when `comboCount >= 2`, scaling/flashing on each
  increment via `withAnimation`; intensity (scale, warmth) grows with the count,
  capped at a max so it stays usable.
- A brief success flash on the prompt area.
- Verified by preview + manual run (no unit test).

### Sound (ComboSoundPlayer)
A small view-level audio helper, asset-free:

```swift
final class ComboSoundPlayer {
    func play(combo: Int)   // plays a short tone whose pitch steps up the combo
}
```

Implementation: an `AVAudioEngine` + `AVAudioSourceNode` rendering a short sine
burst; pitch maps the combo to a capped pentatonic walk. It is triggered only
while the drill is in the `.success` state (mic listening already stopped via
`stopListening()`), so the tone cannot feed back into pitch detection. The view
owns and triggers it on `comboCount` increments. Verified on-device (like the
microphone path); not unit-tested.

## Architecture

- **Domain/Models:** `DrillTuning`, `Belt`, `BeltRank`
- **Infrastructure/Game:** `DailyHistoryStore` (replaces `DailyGoalStore`)
- **Presentation/Drill:** `DrillViewModel` (+`comboCount`, history wiring),
  `DrillView` (belt chip, combo badge + juice), `MasteryView` (belt card),
  `TrendView` (new), `ComboSoundPlayer` (new)
- **DI:** `AppDependencyContainer` swaps `dailyGoalStore` for `dailyHistoryStore`
  and passes it to `makeDrillViewModel()`; exposes it for `TrendView`.

Belt + trend both live in the existing **Progress** tab (no new tab). The belt
chip also appears in the Drill header for at-a-glance feedback.

## Data Flow (per correct answer)
1. `handle()` validates the note, computes reaction time from the `Clock`.
2. `recordCorrect` updates+persists `ItemStats` (existing).
3. VM computes mastered count from the updated stats, calls
   `dailyHistoryStore.recordCorrect(now:reactionTime:masteredCount:)`, updates
   `todayCount`.
4. VM updates `comboCount` (fast → +1, slow → 0).
5. VM transitions to `.success`; the view reacts: combo badge animates and
   `ComboSoundPlayer.play(combo:)` fires (success state ⇒ mic stopped).
6. Belt rank is recomputed by the views from the progress repository on demand.

## Testing (CI-verifiable, no mic/audio)
- `BeltRank.from`: threshold boundaries (each belt), `fractionToNext` within a
  belt, all-zero stats → White at 0, full stats → Black, items-to-next behavior.
- `DailyHistoryStore`: first record, increments within a day, average-reaction
  computation, mastered snapshot overwrite, calendar-day rollover starts a fresh
  record, history sorted ascending, corrupt/missing data → empty.
- `DrillViewModel` combo transitions: fast-correct increments; slow-correct
  resets; skip resets; start resets. Plus existing VM tests still green.
- Regression: existing `audio_listenTests` stay green after the
  `DailyGoalStore`→`DailyHistoryStore` swap and `DrillTuning` consolidation.

Manual/on-device: belt chip + card rendering, trend chart, combo animation, and
the escalating sound.

## Open Implementation Decisions (resolved during planning)
- Exact belt threshold tuning and combo visual intensity curve (cosmetic).
- Number of days shown in the trend chart (default: all history, or last 30).
- Pentatonic tone mapping specifics for `ComboSoundPlayer`.

These are tunable constants and do not affect the architecture.
