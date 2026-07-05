# Instrument-Derived String Presets — Design

**Date:** 2026-07-04
**Status:** Approved for planning
**Branch context:** `main`

## Goal

Move the string-choice presets out of the hardcoded, guitar-specific `StringSetPresets`
enum and make them a **property of the instrument**, derived from its strings. Persist
the selection **per instrument** (keyed by `instrument.id`) so each instrument keeps its
own last selection, eliminating the global settings key. Guitar remains the only wired
instrument; the generators and store are instrument-general and unit-tested against a
synthetic bass.

## Scope

- **In:** instrument-derived string-choice generators; a `StringChoice` value type;
  per-instrument persistence keyed by `instrument.id`; wiring the drill picker + default
  to the instrument; deleting `StringSetPresets`.
- **Out (designed-for, built later in the picker sprint):** an instrument **picker**,
  wiring **bass/banjo**, and persisting the **last-selected instrument**. These require a
  UI to select an instrument, which does not exist yet; see *Future* below for the exact
  seam they drop into.

## The generators (on `Instrument`)

New value type `Domain/Models/StringChoice.swift`:

```swift
struct StringChoice: Identifiable, Equatable {
    let id: String            // stable: sorted string numbers joined, e.g. "5-6"
    let label: String
    let strings: Set<Int>
}
```

New extension `Domain/Models/Instrument+StringChoices.swift`:

```swift
extension Instrument {
    var singleStringChoices: [StringChoice]      // one per string, low-pitch → high
    var cumulativeStringChoices: [StringChoice]  // "first 2" … "first stringCount", low → high
    var stringChoices: [StringChoice]            // singles + cumulative (picker order)
    var defaultStringChoice: StringChoice        // the single lowest-pitch string
}
```

### Derivation rules

- **String ordering** is by pitch: the lowest-pitch string first. For each string, its
  number is `index + 1` (string 1 = `strings[0]`). Sort by `openNote.midiNumber` ascending.
  For guitar that yields string order `[6, 5, 4, 3, 2, 1]` (low E → high e), matching
  today's presets exactly.
- **Singles:** one `StringChoice` per string, `strings = {stringNumber}`, in ascending-pitch
  order.
- **Cumulative:** for `N` in `2...stringCount`, `strings =` the `N` lowest-pitch strings'
  numbers. `first 2` on guitar = `{6, 5}` (E·A); `first 3` = `{6, 5, 4}` (E·A·D); …;
  `first 6` = all.
- **Default:** `defaultStringChoice` = the single lowest-pitch string. Guitar → `{6}` (low E).
- **`id`:** `strings.sorted().map(String.init).joined(separator: "-")` — stable and unique
  per set, used as the `Picker` tag.

### Labels

- **Cumulative:** the included strings' open-note names, low → high, joined by `" · "`
  (e.g., `"E · A · D"`). Duplicate names in the full set (guitar's two E's) read acceptably
  in low→high order.
- **Single (Low/High qualifier):**
  - A note name that appears on **one** string → just the name (`"A"`, `"D"`, `"G"`, `"B"`).
  - A name on **two** strings → the lower-pitch one is `"Low E"`, the higher `"High E"`.
  - A name on **3+** strings (rare tunings) → fall back to note + octave (`"E2"`, `"E3"`,
    `"E4"`) so labels are always unambiguous.

## Per-instrument storage

`Infrastructure/Game/GameAllowedStringsStore.swift` becomes instrument-aware:

```swift
func load(for instrument: Instrument) -> Set<Int>
func save(_ strings: Set<Int>, for instrument: Instrument)
```

- **Key:** `"audio_listen_allowed_strings.\(instrument.id)"` (e.g.
  `audio_listen_allowed_strings.guitar`). The old global key
  `audio_listen_game_allowed_strings` is abandoned — **no migration**; a missing key means
  first use.
- **Fallback / validation:** missing key, decode failure, or a stored set that clamps to
  empty → `instrument.defaultStringChoice.strings` (single lowest string). On load and
  save, clamp to `1...instrument.stringCount` (the *current* instrument, not hardcoded
  guitar), so a stored set never contains strings the instrument lacks. A successfully
  stored **empty** array still means "no strings selected" (empty set), preserving today's
  distinction.

The read path stays through the existing injected seam: `AllowedStringsProviding` /
`UserDefaultsAllowedStringsProvider` gain the instrument at construction so
`allowedStrings` resolves `store.load(for: instrument)`. No new protocol ceremony is
added — the per-instrument key is the future-proofing.

## Drill / picker consumption

`Presentation/Drill/DrillView.swift`:

- The idle-screen `Picker` reads `instrument.stringChoices`, sectioned into **Singles** and
  **Cumulative** (derived from `singleStringChoices` / `cumulativeStringChoices`).
- The derived selection `Binding` maps the current `allowedStrings` set ↔ a `StringChoice.id`;
  the fallback is `instrument.defaultStringChoice`.
- On change, `store.save(choice.strings, for: instrument)`; on appear,
  `allowedStrings = store.load(for: instrument)`.
- The drill loop is **unchanged** — it already receives `allowedStrings` as a closure; the
  container now backs that closure with the per-instrument, instrument-aware read.

`AppDependencyContainer` wires the store/provider with the current `instrument` (the existing
`let instrument = Instruments.guitar` seam).

## Files touched

| File | Change |
|---|---|
| `Domain/Models/StringChoice.swift` | **new** — `StringChoice` value type |
| `Domain/Models/Instrument+StringChoices.swift` | **new** — the four generators + Low/High label helper |
| `Infrastructure/Game/StringSetPresets.swift` | **deleted** — replaced by instrument-derived choices |
| `Infrastructure/Game/GameAllowedStringsStore.swift` | **modified** — `load(for:)`/`save(for:)`, per-instrument key, instrument-clamped |
| `Infrastructure/Game/UserDefaultsAllowedStringsProvider.swift` | **modified** — holds the instrument, resolves `load(for:)` |
| `Domain/Protocols/AllowedStringsProviding.swift` | unchanged (still `var allowedStrings: Set<Int>`) |
| `Presentation/Drill/DrillView.swift` | **modified** — picker + default + save/load from the instrument |
| `DI/AppDependencyContainer.swift` | **modified** — wire store/provider with `instrument` |
| `audio_listenTests/StringSetPresetsTests.swift` | **deleted/replaced** by the generator tests |
| `audio_listenTests/InstrumentStringChoicesTests.swift` | **new** — generator tests (guitar + synthetic bass) |
| `audio_listenTests/audio_listenTests.swift` | **modified** — `GameAllowedStringsStoreTests` use `load(for:)`/`save(for:)` and `instrument.defaultStringChoice` |

`DrillViewModel` and the drill loop are untouched.

## Testing

- **`InstrumentStringChoicesTests`** (Swift Testing):
  - **Guitar:** `singleStringChoices` = 6 choices, low→high, with `"Low E"` / `"High E"`
    disambiguation and plain `"A"/"D"/"G"/"B"`; `cumulativeStringChoices` = `first 2…6` with
    the exact sets (`{6,5}`, `{6,5,4}`, …) and `"E · A · D…"` labels; `defaultStringChoice`
    = `{6}`.
  - **Synthetic 4-string bass** (`Instrument(id:"bass", strings:[G2,D2,A1,E1], fretCount:24)`
    or similar): 4 singles, `cumulative = first 2…4`, `default = {4}` (its lowest) — proves
    the generators are instrument-general with no bass wired into the app.
  - **3+ duplicate names** edge: a synthetic instrument with a note name on three strings →
    octave-qualified labels.
- **`GameAllowedStringsStoreTests`** (updated): save under a `guitar` instrument and a
  synthetic `bass` instrument, assert the two keys are **independent**; missing key →
  `instrument.defaultStringChoice.strings`; a stored set with out-of-range strings clamps to
  the instrument's range; stored empty array → empty set.
- Existing suites stay green; guitar behavior (its preset sets) is identical to today.

## Future (picker sprint — designed-for, not built now)

Persisting the **last-selected instrument** and switching instruments drop into the single
existing seam:

```swift
// AppDependencyContainer, later:
var currentInstrument: Instrument {
    Instruments.all.first { $0.id == selectedInstrumentStore.load() } ?? .guitar
}
```

A tiny `SelectedInstrumentStore` (one key → `instrument.id`, default `"guitar"`) written by
the picker drives it. Because the string store is already keyed by `instrument.id`, switching
instruments automatically restores that instrument's own last string selection — "remember
last instrument" and "remember its strings" compose with no rework.

## Out of scope

- Instrument picker UI; wiring bass/banjo into the app; `SelectedInstrumentStore` (all above).
- Per-instrument note-name or fret-range settings (note names and frets are instrument-agnostic;
  their current global stores are fine).
- A user-facing "remember last selection" toggle (persistence is always-on; default is
  cold-start only).
