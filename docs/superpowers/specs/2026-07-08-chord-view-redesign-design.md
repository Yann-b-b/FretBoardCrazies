# Chord View Redesign — Design Spec

**Date:** 2026-07-08
**Status:** Approved design, ready for implementation planning.
**Supersedes:** the "View & interaction" + neck-rendering portions of
`docs/superpowers/specs/2026-07-08-chord-progression-trainer-design.md`. The domain
layer of that spec (and its implementation) is unchanged and reused.

## Goal

Replace the chord-mode neck view after real-device testing revealed three problems:
the neck was too small and did not grow with the window; the camera-follow "neck
slide" hid *where* on the fretboard each chord sat; and there was no timed pacing.
The redesign shows the **full guitar neck** (drill-sized, responsive), transitions
chords by **gliding the fingered dots** to their new frets, and adds a **timed
auto-advance**.

## Non-goals

- **No change to the domain layer.** Chord qualities, voicings, progressions,
  naming/transposition, the `ProgressionSession` loop/recall/reveal logic, and the
  `ProgressionSelectionStore` are all kept and reused as-is (one small additive
  change to placement — see below).
- **No metronome / click audio.** Auto-advance is silent (timed), not a click track.
- **No root-string selector** (still E6-only in v1).
- The existing note-drill and its `FretboardView` remain untouched.

## What changes

1. **Discard** `ChordNeckView.swift`, `ChordNeckGeometry.swift`, and
   `ChordNeckGeometryTests.swift` (the camera-follow windowed neck).
2. **Add** `ChordFretboardView` — a full-neck view built on the drill's existing
   `FretboardGeometry`, with gliding dots.
3. **Extend placement** so a placed chord carries **finger numbers + root flag**
   (the old view never rendered finger numbers; the redesign does).
4. **Add** timed auto-advance (play/pause + adjustable pace) to the mode.
5. **Rework** `ChordProgressionView`'s layout so the neck fills the pane.

## Component — `ChordFretboardView`

- **Reuses `FretboardGeometry`** (`Presentation/Drill/FretboardGeometry.swift`,
  `init(size:stringCount:fretCount:)`, `stringY(_:)`, `point(string:fret:)`). The
  drill's `FretboardView` is NOT modified; this is a parallel view that shares the
  geometry. Some neck-drawing (fret lines, string lines, inlays) is intentionally
  re-expressed here rather than extracted from `FretboardView`, to keep the drill
  view untouched.
- **Full neck, `fretCount = 15`.** Root frets land in 1…12 and voicings add up to
  +2, so 15 frets guarantees every v1 chord sits fully on-board with its position
  context. Nut drawn thick at fret 0; inlays at 3, 5, 7, 9, 12, 15; string 1
  (high E) on top, string 6 (low E) on the bottom; dark board (`Color(white: 0.12)`)
  matching the drill.
- **Sizing:** wrapped in a `GeometryReader` with `.frame(minHeight: 220)`, filling
  available width and height — it grows with the window/pane exactly like the drill,
  fixing the fixed-height bug.
- **Dots (gliding):** one persistent dot per string (`ForEach(1...6, id: \.self)`).
  Each dot reads the current chord's note for that string and renders a circle at
  `geometry.point(string:fret:)` with the **finger number** centered, the **root**
  dot in orange (the drill's target color), others light. A string with no note in
  the current chord shows a **✕ muted marker** at the neck's left edge and its dot
  at `opacity 0`. An `.animation(.easeInOut, value: placedChord)` on the dot layer
  makes each dot **glide** along its string to the next chord's fret (and fade
  in/out when a string switches played↔muted).

## Domain change — placement carries fingers

`ChordPlacement` currently returns `PlacedChord { rootFret, positions: [FretPosition],
rootPosition }`. Replace with:

```
PlacedNote { string: Int, fret: Int, finger: Int, isRoot: Bool }
PlacedChord { rootFret: Int, notes: [PlacedNote] }
```

`place(voicing:rootPitchClass:instrument:)` maps each `VoicingPosition` (which already
carries `finger`) to a `PlacedNote`, flagging the note on the root string at
`fretOffset 0` as `isRoot`. This is additive information (finger + root flag) the view
needs; the `ChordPlacementTests` and `ChordFormulaConformanceTests` are updated to read
`notes` (the conformance check still computes intervals from `note.string`/`note.fret`,
unchanged in substance).

## Timed auto-advance

- **State:** a small, testable `AutoAdvance` model holding `pace: TimeInterval`
  (its setter **clamps to 1.0…6.0** seconds) and `isPlaying: Bool`, kept separate
  from `ProgressionSession` so the session stays pure. The view owns the actual
  timer scheduling and drives `session.advance()`; `AutoAdvance` just holds the
  clamped pace + play state.
- **Behavior:** while `isPlaying`, a repeating timer calls `session.advance()` every
  `pace` seconds. **Play/Pause** toggles it. Manual **Prev/Next** work at any time and
  **pause** auto-advance (matching the prototype). In name-only recall mode,
  auto-advance simply advances (reveal-on-tap stays a manual affordance).
- **Controls:** Play/Pause button, Prev/Next buttons, and a **pace slider (1–6 s)**
  with a live readout.

## Layout — `ChordProgressionView`

Top: current chord **name** + a small **position** readout (e.g. "8th fret") and the
**next**-chord name (name-only peek, unchanged). Center: `ChordFretboardView` filling
the pane. Bottom: the transport controls (Play/Pause, Prev/Next, pace slider) and the
existing **key**, **progression**, and **name-only** selectors. Persistence
(`persist()` on selection changes) is unchanged.

## Discarded vs kept

- **Discarded:** `ChordNeckView.swift`, `ChordNeckGeometry.swift`,
  `ChordNeckGeometryTests.swift`.
- **Kept unchanged:** `ChordQuality/ChordQualities`, `RootString/Voicing/Voicings`,
  `Progression/Progressions`, `ChordNaming`, `ProgressionSession`,
  `ProgressionSelectionStore`, the Chords-tab wiring in `ContentView`
  (`Instruments.guitar`).
- **Modified:** `ChordPlacement` (+ its two test files), `ChordProgressionView`.

## Testing

- **Placement:** updated `ChordPlacementTests` (root fret math, finger + `isRoot`
  threading) and `ChordFormulaConformanceTests` (intervals from `notes`) stay green.
- **Auto-advance state:** unit-test pace clamping to `1.0…6.0` and the `isPlaying`
  toggle. The wall-clock scheduling is verified by build + the sim.
- **View:** `ChordFretboardView` and `ChordProgressionView` verify by build + SwiftUI
  preview + your eyeball in the simulator (dark board, dot sizing, glide feel,
  resize-with-window).

## Open / future

- Metronome / click track (deferred, as before).
- A5/D4 tiers, generator, mastery — unchanged from the parent spec's roadmap.
- Possible later extraction of shared neck-drawing between `FretboardView` and
  `ChordFretboardView` once both are stable (kept separate now to protect the drill).
