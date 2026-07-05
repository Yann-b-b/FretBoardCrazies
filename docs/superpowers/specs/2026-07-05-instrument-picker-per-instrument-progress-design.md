# Instrument Picker + Per-Instrument Progress — Design

**Date:** 2026-07-05
**Status:** Approved for planning
**Branch context:** `main`

## Goal

Add a **bass** instrument alongside guitar, a **settings picker** to switch the active
instrument, and make all per-instrument state — string presets (already done), drill
progress, daily history, and the belt — **keyed by `instrument.id`** so each instrument
keeps its own correct progress. Switching instruments reconfigures the drill, fretboard,
and progress views automatically. The design leaves a clean, no-new-machinery seam for a
future **achievements** feature.

## Guiding decisions (locked)

- **The store is the seam.** Per-instrument state lives in thin, stateless repositories
  keyed by `instrument.id` (the same shape `GameAllowedStringsStore` already has). No
  progress service, event bus, snapshot type, or reactive machinery. A future achievements
  feature reads the same per-instrument stores and adds its own `*.<id>` key — nothing else.
- **Switch by SwiftUI identity, not mutation.** Flipping the instrument rebuilds the Drill
  and Progress views (via `.id`), which build fresh view models bound to the new instrument.
  Recreation *is* the update — no live view-model mutation.
- **No migration; start fresh.** Progress and daily history move to per-instrument keys with
  no copy from the old global keys. Existing progress (belt/boxes/history) is abandoned on
  update. Accepted knowingly (single early user).
- **`fretCount` is neck length, not drill range.** Bass uses `fretCount: 21` (authentic
  4-string neck). The drill's 0–11 target cap is the independent `limitFretsToTwelve`
  toggle (default on); `fretCount` only affects targets when that toggle is off.

## A. Bass instrument

`Domain/Models/Instruments.swift`:

```swift
static let bass = Instrument(
    id: "bass", name: "Bass",
    strings: [Note(.g, octave: 2), Note(.d, octave: 2), Note(.a, octave: 1), Note(.e, octave: 1)]
        .map { GuitarString(openNote: $0, startFret: 0) },
    fretCount: 21)

static let all: [Instrument] = [guitar, bass]
```

Standard 4-string tuning E1–A1–D2–G2 (string 4 = low E1, string 1 = G2). Everything
downstream already derives from the instrument: fretboard rendering, `positions(for:)`,
and the string-choice generators (bass → 4 singles, cumulative `first 2…4`, default `{4}`).

## B. Selecting & persisting the instrument

New `Infrastructure/Game/SelectedInstrumentStore.swift`:

```swift
struct SelectedInstrumentStore {
    static let userDefaultsKey = "audio_listen_selected_instrument"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard)

    var selectedInstrument: Instrument {
        let id = defaults.string(forKey: Self.userDefaultsKey)
        return Instruments.all.first { $0.id == id } ?? Instruments.guitar
    }
    func save(_ id: String) { defaults.set(id, forKey: Self.userDefaultsKey) }
}
```

- **Default / fallback:** missing key or an unknown id → `Instruments.guitar`.
- Persists across launches for free (same pull-based `UserDefaults` pattern as `touchMode`).
- The Settings picker writes via `@AppStorage(SelectedInstrumentStore.userDefaultsKey)`
  (a `String`, default `"guitar"`); the container reads through the store. Both hit the same
  key, so they stay in sync exactly like `touchMode` does today.

## C. Container seam: `currentInstrument`

`DI/AppDependencyContainer.swift` — replace the fixed `let instrument = Instruments.guitar`:

```swift
private let selectedInstrumentStore = SelectedInstrumentStore()
var currentInstrument: Instrument { selectedInstrumentStore.selectedInstrument }
```

- `makeDrillViewModel()` reads `currentInstrument` and builds the VM + string/max-fret
  providers bound to it. The `UserDefaultsAllowedStringsProvider` and
  `UserDefaultsMaxFretProvider` construction moves **out of `init` into
  `makeDrillViewModel()`**, since they are now instrument-dependent (they were guitar-fixed
  before). `allowedStringsStore`, `drillProgressRepository`, and `dailyHistoryStore` stay
  single shared **instances** — they are stateless and take the instrument per call.

## D. Per-instrument storage (no migration)

Two stores gain a `for instrument:` parameter on every method and a per-instrument key.

`Domain/Protocols/DrillProgressRepositoryProtocol.swift`:

```swift
protocol DrillProgressRepositoryProtocol {
    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)
}
```

`Infrastructure/Game/UserDefaultsDrillProgressRepository.swift`:
- `static func userDefaultsKey(for instrument: Instrument) -> String` →
  `"audio_listen_drill_progress.\(instrument.id)"`. Missing/corrupt → `[:]` (unchanged
  fallback, per instrument).

`Infrastructure/Game/DailyHistoryStore.swift` — add `for instrument:` to each method:
- `history(for instrument: Instrument) -> [DailyRecord]`
- `todayReps(for instrument: Instrument, now: Date) -> Int`
- `recordCorrect(for instrument: Instrument, now: Date, reactionTime: TimeInterval, masteredCount: Int)`
  (stays a pure command / `Void`, per the CQS fix already shipped)
- `static func userDefaultsKey(for instrument: Instrument) -> String` →
  `"audio_listen_daily_history.\(instrument.id)"`.

**Consumers pass their injected `instrument` through.** `DrillViewModel` already receives an
`instrument`; `MasteryView` gains one (Section G). No migration: guitar reads its new empty
`*.guitar` keys; the old global keys are left untouched and unused.

**Achievements seam (future, not built now):** an `AchievementStore.load(for:)/save(_:for:)`
keyed `audio_listen_achievements.<id>` plus pure rules over `loadAll(for:)`/`history(for:)`,
evaluated where `DrillViewModel` already re-derives after each answer. Drops in with no
change to the shape defined here.

## E. Instrument-derived belt universe

`Domain/Models/DrillTuning.swift` — replace the hardcoded constant:

```swift
// remove: static let totalItemCount = 6 * 12
static func universeSize(for instrument: Instrument) -> Int { instrument.stringCount * 12 }
```

12 note-names per string; the 0–11 fret cap covers a full octave, so every note name is
reachable on every string → `stringCount * 12` (guitar 72, bass 48). All `BeltRank.from(...)`
call sites pass `universeSize: DrillTuning.universeSize(for: instrument)`:
- `DrillViewModel.swift:72` (init) and `:209` (after correct)
- `MasteryView.swift:92` (reload); the `:10` `@State` default moves into `init` so it can use
  `universeSize(for: instrument)` (belt from empty stats is white regardless of universe, so
  correctness is unaffected — this just removes the last `totalItemCount` reference).

`BeltRank.from(stats:maxBox:universeSize:)` itself is unchanged (already pure).

## F. Reactive switch (recreate, not mutate)

`ContentView.swift` — extend the existing `.id(touchMode)` identity to include the instrument,
on both the Drill and Progress screens (macOS `TabView` and iOS `screen(for:)` paths):

```swift
DrillView(viewModel: container.makeDrillViewModel(),
          allowedStringsStore: container.allowedStringsStore,
          instrument: container.currentInstrument)
    .id("\(touchMode)-\(container.currentInstrument.id)")

MasteryView(progressRepository: container.drillProgressRepository,
            dailyHistoryStore: container.dailyHistoryStore,
            instrument: container.currentInstrument)
    .id(container.currentInstrument.id)
```

Flip the picker → `@AppStorage` changes → `ContentView` re-renders → `currentInstrument.id`
changes → Drill + Progress are torn down and rebuilt fresh against the new instrument, each
loading that instrument's own stats. The Tuner is instrument-agnostic (raw pitch detection)
and is left untouched.

## G. `MasteryView` instrument-aware

`Presentation/Drill/MasteryView.swift`:
- `init(progressRepository:dailyHistoryStore:instrument:masteredBox:)` — add `instrument`.
- `reload()` uses `progressRepository.loadAll(for: instrument)`,
  `dailyHistoryStore.history(for: instrument)`, the universe
  `Set(1...instrument.stringCount)`, and `DrillTuning.universeSize(for: instrument)`.
- This removes the last hardcoded `Instruments.guitar` reference in the app.

## H. The settings picker (light UI)

`Presentation/Settings/SettingsView.swift` — new section:

```swift
Section("Instrument") {
    InstrumentPicker(selectedId: $selectedInstrumentId)   // @AppStorage(SelectedInstrumentStore.userDefaultsKey)
}
```

`InstrumentPicker` is a small horizontal "bar with dots": one labeled dot per
`Instruments.all`, the selected one filled/highlighted; tapping a dot (or dragging across the
bar to the nearest dot) sets `selectedId`. Writing `selectedId` persists via `@AppStorage`
and drives the whole switch through Section F. Kept intentionally light — the backend above
is what makes the control a thin binding.

## Files touched

| File | Change |
|---|---|
| `Domain/Models/Instruments.swift` | **modified** — add `bass`, `all = [guitar, bass]` |
| `Domain/Models/DrillTuning.swift` | **modified** — replace `totalItemCount` with `universeSize(for:)` |
| `Domain/Protocols/DrillProgressRepositoryProtocol.swift` | **modified** — `loadAll(for:)` / `save(_:for:)` |
| `Infrastructure/Game/UserDefaultsDrillProgressRepository.swift` | **modified** — per-instrument key |
| `Infrastructure/Game/DailyHistoryStore.swift` | **modified** — `for:` on all methods, per-instrument key |
| `Infrastructure/Game/SelectedInstrumentStore.swift` | **new** — selected-instrument persistence |
| `DI/AppDependencyContainer.swift` | **modified** — `currentInstrument`, store wiring in `makeDrillViewModel` |
| `Presentation/Drill/DrillViewModel.swift` | **modified** — pass `for: instrument`; `universeSize(for:)` |
| `Presentation/Drill/MasteryView.swift` | **modified** — inject instrument; per-instrument reads |
| `Presentation/Settings/SettingsView.swift` | **modified** — Instrument section + `InstrumentPicker` |
| `Presentation/Settings/InstrumentPicker.swift` | **new** — bar-with-dots selector (may live inline in SettingsView) |
| `ContentView.swift` | **modified** — pass `currentInstrument`; `.id` includes instrument |
| `audio_listenTests/*` | **modified/new** — see Testing |

`DrillView` needs no change (it already takes `instrument`, and its string picker already
derives from it). `AllowedStringsProviding` / `GameAllowedStringsStore` are unchanged (already
per-instrument).

## Testing

- **`SelectedInstrumentStoreTests`** (new): round-trip a saved id; missing key → guitar;
  unknown/garbage id → guitar.
- **Per-instrument progress isolation** (`DrillProgressRepositoryTests`): save under guitar and
  under bass, assert independent keys and no cross-read; missing key → `[:]`.
- **Per-instrument daily history isolation** (`DailyHistoryStoreTests`): `recordCorrect(for:)`
  under guitar vs bass are independent; `todayReps(for:)` / `history(for:)` read the right key.
- **`DrillTuningTests`**: replace `totalItemCount == 72` with
  `universeSize(for: guitar) == 72` and `universeSize(for: bass) == 48`.
- **`DrillViewModelTests`**: update the mock `DrillProgressRepositoryProtocol` to the `for:`
  signatures and the `repo.loadAll()` assertions to `loadAll(for:)`; existing behavior
  (correct/miss/belt) stays green with an injected instrument.
- Existing suites stay green. Guitar behavior is identical to today except that its progress
  now lives under `audio_listen_drill_progress.guitar` (fresh, per the no-migration decision).

## Future: achievements (next spec — designed-for, not built now)

Confirmed direction so the next sprint starts from it:

- **Data-driven catalog.** `Achievements.all: [Achievement]` where each `Achievement` is a
  declarative rule `{ id, title, detail, isUnlocked: (stats, history) -> Bool }` — same
  catalog/Type-Object pattern as `Instruments.all`. The board is a `ForEach(Achievements.all)`,
  so **adding a rule auto-populates the board** with zero UI changes.
- **Pure evaluation, per instrument.** Evaluate `Achievements.all` over
  `loadAll(for:)` / `history(for:)` where `DrillViewModel` already re-derives after each answer;
  diff against a per-instrument unlocked set persisted to `audio_listen_achievements.<id>`.
- **Schema evolution rule.** Today's logs (`ItemStats`, `DailyRecord`) already support
  mastery-, streak-, and speed-based achievements. Richer ones (lifetime totals, fastest single
  answer) need new logged attributes — which **must be added as optional/defaulted Codable
  fields** so old stored JSON still decodes (the no-migration decision means a non-optional new
  field would silently wipe history).

## Out of scope

- The achievements feature itself (only its storage seam is reserved; see Future above).
- Per-instrument `limitFretsToTwelve` / countdown / touch-mode settings (these stay global —
  they are instrument-agnostic preferences).
- Bass-specific fretboard art or inlay differences; the shared fretboard renders any instrument.
- Reactive "unlocked mid-drill" notifications (would need the stateful service we deliberately
  rejected).
