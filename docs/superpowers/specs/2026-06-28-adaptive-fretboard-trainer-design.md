# Adaptive Fretboard Trainer (macOS) — Design

Date: 2026-06-28
Status: Approved (design); pending implementation plan

## Goal

Learn the notes on the guitar fretboard within one week, using a low-friction
macOS interface that can be cued up instantly. The driver is **learning
effectiveness** (adaptive practice + a visual map of the fretboard) plus a
**fast macOS UX**, not internal code polish.

The user practices with a real guitar; answers are played into the microphone.

## Non-Goals (YAGNI)

- Curriculum auto-ladder (string-by-string automatic progression)
- Octave-shape drills, streaks, speed tiers/levels
- Pitch-detection algorithm changes (smoothing, octave-error correction)
- Additional settings UI beyond selecting strings and note names for the drill
- Click/keyboard answering (input is microphone only)

## Key Constraint: Microphone Cannot Verify Exact Position

A note+octave is a *unison* across multiple board positions (e.g. C4 is string 2
fret 1, string 3 fret 5, and string 4 fret 10 — identical frequency). Pitch
detection hears the note, not the location. Therefore validation confirms the
**note (pitch class + octave)**, and the **position** is a visual target the user
self-verifies. The learning gains come from structure and feedback, not from
stricter machine validation.

## Core Concept: One Unified, Mixed-Direction Drill

Replace the two near-duplicate tabs (`Game`, `Find note`) with a single
**Drill**. Keep `Tuner`. Each round is a prompt:

```swift
enum DrillDirection { case findPosition, nameNote }
struct DrillPrompt {
    let direction: DrillDirection
    let targetNote: Note
    let string: Int
}
```

- **name → position (primary, majority of rounds):** cue shows the note name +
  string (e.g. `C — string 5`); the user plays it as fast as possible; the round
  is timed.
- **position → name (occasional):** cue highlights a fret dot on a string; the
  user names and plays it; the note name is revealed on success.

Both directions validate identically through the existing `ValidateNoteUseCase`
(pitch class + octave) and both exercise the same `(note name, string)` items.

## Mastery Unit: `(NoteName, string)`

Stats are keyed on `(NoteName, string)` — **not** `(string, fret)`. The note is
what matters; within the default 0–11 fret range each note name appears exactly
once per string, so `C on string 5` maps to a single fret. The reveal shows the
fret.

```swift
struct ItemStats {
    var box: Int            // Leitner box, higher = more mastered
    var attempts: Int
    var correct: Int
    var lastReactionTime: TimeInterval?
    var lastSeenAt: Date
}
```

Keyed by an item identity such as `DrillItemKey { noteName: NoteName, string: Int }`.

## Adaptive Weak-Spot Engine (Leitner Spaced Repetition)

The single biggest learning lever for a one-week push.

- Correct + fast → **promote** (shown less often). Wrong or slow → **demote**
  (shown more often). Unseen items get **exploration** weight so the full set is
  covered.
- `SelectNextPromptUseCase` is a **pure function**: given selected strings,
  allowed note names, max fret, and current `ItemStats`, it returns the next
  `DrillPrompt` (direction + note + string), weighted by box / overdue-ness.
  Direction is biased toward `findPosition` (primary) with occasional `nameNote`.
- Persistence via a new `UserDefaultsDrillProgressRepository`. Existing
  `GameRound` history (`audio_listen_game_rounds`) is left untouched.

"Slow" vs "fast" threshold for promotion/demotion is a configurable constant in
the use case (single named definition); default chosen during implementation and
tuned by feel.

## String-Set Progression (Presets)

Cumulative presets, built from the low (thick) strings up, are the manual
progression dial:

- **E · A** (strings 6, 5)
- **E · A · D** (6, 5, 4)
- **E · A · D · G** (6, 5, 4, 3)
- **E · A · D · G · B** (6, 5, 4, 3, 2)
- **All 6**

One tap loads a preset into the allowed-strings set; the existing per-string
toggles remain for custom selection. Allowed note names remain selectable
(reuse `GameAllowedNoteNamesStore`). The adaptive engine targets weak spots
*within* the selected strings.

String numbering convention (existing): 1 = high E … 6 = low E.

## Visual Fretboard (`FretboardView`)

The centerpiece component.

- Draws 6 strings × frets 0–11 (respecting the configured max fret), the nut,
  and inlay dots at frets 3, 5, 7, 9, 12.
- **position → name:** renders a filled **target dot** at the prompted spot.
- **name → position:** glows the **target string** with the fret hidden; reveals
  the correct dot + label on success.
- Reused to render the mastery **heatmap** (a note × string grid mapped onto the
  board).
- Geometry (mapping `(string, fret)` → view coordinate) lives in a **pure
  helper** that is unit-tested independently of SwiftUI.

## Progress / Mastery View (`MasteryView`)

- **Heatmap** over `FretboardView`: unseen = grey, learning = amber,
  mastered = green, derived from `ItemStats` boxes.
- **Daily goal:** a simple count (e.g. N correct today) with date-rollover
  logic and a progress bar. Daily counter resets when the calendar day changes
  (compared via the injected `Clock`).
- **Session summary** on End: count, accuracy, average reaction time, and the
  weakest items.

## macOS Cue-Up & UX

- The app opens **straight into the Drill**.
- Keyboard shortcuts: **Space = start / next**, **Esc = end**, **S = skip**.
- Large, high-contrast prompt sized for a Mac window.
- `ContentView` restructured for macOS: a primary Drill view plus a toolbar to
  reach Progress / Tuner / Settings, rather than a phone-style tab bar.
- **Verify-first risk:** the first implementation step is a tiny spike that
  confirms AudioKit microphone input runs on macOS and that the sandbox
  **audio-input entitlement** (`com.apple.security.device.audio-input`) is set.
  This is the one thing that could block the whole approach, so it is checked
  before any UI is built on top of it. The project already targets macOS
  (`SDKROOT = auto`, `SUPPORTED_PLATFORMS` includes `macosx`, deployment target
  14.6) and the iOS-only audio-session code is already `#if os(iOS)`-guarded.

## Quality Bits Riding Along

Because the game loop is being rewritten anyway, fold in the low-risk
improvements that make the new code testable and consistent:

- Centralize all `UserDefaults` keys into `GameSettingsKeys` (currently
  `"countdownEnabled"` is a raw literal duplicated in `SettingsView` and
  `AppDependencyContainer`).
- Make the state machine the **single source of truth**: it fires an
  `onStateChange` callback; the view model updates its single published `state`
  in exactly one place, removing the scattered `state = stateMachine.state`
  mirroring.
- Inject `Clock` (`now() -> Date`) and `DrillScheduler` (repeating + delayed
  callbacks) so the loop (countdown, auto-advance) and the selection engine are
  deterministically unit-testable. Production implementations wrap `Timer` /
  `Task`; test fakes advance time manually.

## Architecture (respects existing layered structure)

- **Domain/Models:** `DrillDirection`, `DrillPrompt`, `DrillItemKey`,
  `ItemStats`, `MasteryLevel`
- **Domain/UseCases:** `SelectNextPromptUseCase` (adaptive selection); keep
  `ValidateNoteUseCase`
- **Domain/Protocols:** `DrillProgressRepositoryProtocol`, `Clock`,
  `DrillScheduler`
- **Infrastructure/Game:** `LeitnerPromptSelector` (selection impl),
  `UserDefaultsDrillProgressRepository`, production `Clock` / `DrillScheduler`
- **Presentation/Drill:** `DrillViewModel`, `DrillView`, `FretboardView`,
  `MasteryView`
- **DI / ContentView:** rewire `AppDependencyContainer`; restructure
  `ContentView`; remove the `Game` and `Find note` tabs.

Existing reused types: `Note`, `NoteName`, `FretPosition`, `GuitarFretboard`,
`GameTargetFretBounds`, `GameRound`, `ValidateNoteUseCase`,
`DebouncedPitchDetector`, `AudioKitPitchAdapter`, `GameAllowedStringsStore`,
`GameAllowedNoteNamesStore`.

## Validation Flow (per round)

1. `SelectNextPromptUseCase` produces a `DrillPrompt` from current stats +
   filters.
2. The drill enters `playing`; the `Clock` records the start time.
3. `DebouncedPitchDetector` emits detected notes; `ValidateNoteUseCase` compares
   pitch class + octave against `targetNote`.
4. On match: compute reaction time from the `Clock`, update `ItemStats`
   (promote/demote by correctness + speed), persist, show success + reveal the
   exact fret, then auto-advance after a short delay (via `DrillScheduler`).
5. `Skip` records an attempt without a correct result (demotes / keeps low box)
   and advances.

## Testing (all CI-verifiable, no microphone)

- **Fretboard geometry:** pure `(string, fret)` → coordinate helper.
- **Leitner selection:** weak/overdue items surface more often; promotion and
  demotion transitions; unseen-item exploration; respects selected strings,
  allowed note names, and max fret; direction bias toward `findPosition`.
- **Drill loop:** with injected `Clock` + `DrillScheduler` — countdown ticks,
  success reaction timing, auto-advance, and `stop`/`skip` cancellation.
- **Daily-goal rollover:** counter resets across a simulated date change.
- **Regression:** existing domain tests (`NoteConverter`, `GuitarFretboard`,
  `ValidateNoteUseCase`, stores, `DebouncedPitchDetector`, etc.) stay green.

## Open Implementation Decisions (resolved during planning)

- Exact promotion/demotion thresholds and Leitner box count (start ~5 boxes).
- Reaction-time "fast" threshold default.
- Whether `nameNote` direction frequency is a fixed ratio or adapts.

These are tunable constants and do not affect the architecture.
