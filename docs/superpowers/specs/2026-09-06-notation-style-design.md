# Switchable note notation: letters / solfège

**Status:** design approved in conversation 2026-09-06; awaiting spec review before planning.
**Decision-log entries:** see `docs/decisions.md` 2026-09-06 (locale default + Settings override;
solfège spelling; observed-state delivery).

## Problem

Note names appear throughout the app as English letters (C, C#, D…). Players who learned music
in fixed-do countries (France, Italy, Spain, Portugal, Romania, Latin America) read notes as
solfège (do, ré, mi…) and letters are friction on every screen. The app must be able to display
either system.

This is a display concern only. `NoteName` (Int-raw enum, C=0…B=11 in
`audio_listen/Domain/Models/Note.swift`) is the single identity for the twelve pitches; every
store persists raw values, game logic and answer checking compare enum values, and the string
"C#" exists only in `displayName`. Nothing but rendering changes.

## Decisions already made

1. **Trigger:** locale default + Settings override. When no value is stored, the preference
   derives from the device's preferred language at read time (fr/it/es/pt/ro → solfège,
   otherwise letters). An explicit pick in Settings writes the key and wins forever. Absence of
   the key means "no explicit choice" — the same convention `GameAllowedNoteNamesStore` uses
   (missing key → all twelve notes). Nothing is written at install or launch.
2. **Spelling:** do, do#, ré, ré#, mi, fa, fa#, sol, sol#, la, la#, si. Accented ré, `#` for
   sharps, octave suffix unchanged (`la4`), chord quality suffixes unchanged (`do#m`).
   Long-form accidentals ("do dièse") rejected: labels across fret markers, answer buttons, and
   the tuner assume ~2-character strings; "sol#" at four characters is the widest and gets a
   simulator eyeball during implementation.
3. **Delivery:** parameterized display + observed state (Approach B). A hidden global read
   inside `displayName` was rejected because SwiftUI cannot see it — screens flip only when
   they happen to re-render, so a live tuner shows "la4" while a static drill screen still says
   "C#". The call-site edits are the dependency registration that makes every screen flip
   instantly. A DI-injected formatter protocol was rejected as more files and churn for the
   same behavior.

## Design

### Domain

- `Domain/Models/NotationStyle.swift` — `enum NotationStyle: String, CaseIterable, Codable`
  with cases `letters`, `solfege`.
- `NoteName.displayName(style:)` — returns the existing strings for `.letters`, the solfège
  strings above for `.solfege`. The no-argument `displayName` remains and delegates to
  `.letters`, so unmigrated/debug uses keep compiling and behaving as today.
- `Note.displayName(style:)` — name plus octave (`la4`).
- `ChordNaming.displayName(step:tonic:style:)` and `rootName` call sites — root name follows
  the style; quality symbol untouched.

### Infrastructure

- `Infrastructure/Game/NotationStyleStore.swift`, sibling of `GameAllowedNoteNamesStore`:
  - `load() -> NotationStyle`: stored raw value if present and valid; otherwise derived from an
    injected locale (default `Locale.current`): preferred language in {fr, it, es, pt, ro} →
    `.solfege`, else `.letters`. Garbage data falls back to the locale derivation.
  - `save(_:)` writes the raw value. Only SettingsView calls save.
  - Locale is a constructor parameter so tests force French/English without touching the
    simulator.

### Presentation

- `Presentation/Settings/NotationSettings.swift` — `final class NotationSettings:
  ObservableObject` with `@Published var style: NotationStyle`; initialized from the store by
  `AppDependencyContainer`; a `didSet`/binding path persists changes through the store.
- Root (`ContentView.swift`) injects it with `.environmentObject`.
- `SettingsView` adds a two-option picker (Letters / Solfège) bound to `NotationSettings`.
- View call sites read `notation.style` and pass it to `displayName(style:)`:
  - `DrillView.swift` — 4 sites (prompt line, reveal labels, name-this-note text).
  - `ChordSuggesterView.swift` — 2 sites; `ChordProgressionView.swift` — 2 sites. These
    screens are behind `AppTab.shippingTabs` and unreachable in the shipping build; they are
    converted anyway because revealing them is a one-line change and letters-only labels there
    would be a delayed-detonation bug.
- View-model call sites (`TunerViewModel.currentNote`, `DrillViewModel.detectedNote`) receive
  `NotationSettings` via the DI container and read `style` at format time. Both strings refresh
  continuously with pitch detection, so a toggle flip becomes visible at the next update
  without extra subscription machinery.

### Testing

- `NotationStyleTests`: all twelve solfège strings, letters unchanged, octave formatting,
  chord names in both styles.
- `NotationStyleStoreTests`: French locale → solfège; English → letters; stored value beats
  locale; invalid stored data falls back to locale derivation; save round-trips.
- Existing tests pass untouched — `.letters` remains the no-argument behavior.

### Out of scope (deliberately unchanged)

Game logic, answer checking, all persisted formats and keys, drill progress, `NoteName` cases
and raw values, layout. No flats/enharmonic spelling, no German H notation, no movable-do —
the `style` parameter is the seam any of those would slot into later.

## App Store note

The submitted v1.1.0 build is unaffected; this lands in a future version. The Settings picker
will appear in screenshots/review notes for whichever release ships it.
