# Chord Progression Trainer — Design Spec

**Date:** 2026-07-08
**Status:** Approved design, ready for implementation planning.
**Parent vision:** `docs/v2-chord-trainer-vision.md` (this realizes a scoped slice of Mode A + Mode B, without audio).

## Goal

A new **Chord Progressions** mode in the app: step through good-sounding jazz
progressions, seeing each chord as **name + movable fingering** on the existing
horizontal drill neck. The mode teaches the jazz-chord vocabulary the way the
user's reference chart presents it — name and fingering — sequenced into musical
progressions and anchored on a chosen root string, so every chord is also a
root-finding rep.

## Non-goals

- **No audio.** This mode has no microphone, no detection, no verification.
  Distinguishing a 13 from a 9♯11 by ear is a single-tension difference that
  chroma detection handles badly; the mode is a guided visual trainer instead.
- **No progression generator in v1.** v1 ships a curated library; the
  cell-recombination generator (designed in "Progression generator" below) is a
  later addition, and the data model must not preclude it.
- **No spaced-repetition / automatic mastery in v1.** Advancing between root
  strings is a manual choice.
- The existing single-note drill is untouched; this is a sibling mode.

## The learning path — root string is the spine

Root string is the mode's primary axis and its difficulty ramp:

| Stage | Root on | What the user practices |
|-------|---------|-------------------------|
| 1 | Low E (6th string) | Read each chord, find its root on the 6th string, play the shape there. |
| 2 | A (5th string) | Same vocabulary and progressions, re-rooted on the A string — a new grip. |
| 3 | D (4th string) | Compact middle-string voicings. |

Each stage re-roots the same chords on the next string — a genuinely different
physical grip, not the same shape relocated. The user advances when comfortable.
The mode exposes a **root-string selector**, but only strings the loaded tier
actually has voicings for are offered — so **v1 shows `E6` only**, and `A5` /
`D4` light up as the rollout adds their voicings. Because progressions are stored
in a key by scale degree, the roots spread across the neck rather than repeating
— root-finding practice, spread over different notes.

## Data model (pure domain — mirrors the `Instruments` Type-Object catalog)

```
ChordQuality { id, name, family, formula }
    // formula = intervals from the root, e.g. maj7 = [1, 3, 5, 7]

RootString = "E6" | "A5" | "D4"

Voicing {
    qualityId,
    rootString,
    // movable fret pattern relative to the root fret, per played string,
    // with finger number; unplayed strings are muted.
    positions: [ { string, fretOffset, finger } ],   // fretOffset relative to root fret
    rootStringNumber                                  // which string carries the root
}
    // exactly one Voicing per (qualityId, rootString) it supports.

Progression {
    id, name,
    key,                                              // tonal center
    steps: [ { scaleDegree, qualityId } ]             // roman-numeral form
}
    // stored in roman numerals so one entry transposes to all 12 keys.

Placement (derived, not stored):
    given (progression, key, rootString):
      for each step → root note = degree applied to key
                    → fret on rootString where that note lives
                    → render the step's Voicing at that fret
```

The **Placement** step is the seam where "find the root" happens: it converts a
roman-numeral step into a concrete fret on the selected root string, then hangs
the movable voicing there.

## Voicing sourcing

- One canonical movable voicing per `(quality, rootString)`, digitized from the
  user's reference chart plus standard movable jazz forms.
- Finger-numbered (the chart labels dots by interval; we assign a sensible
  playable fingering).
- Each voicing is validated in tests: the pitch classes it produces at an
  arbitrary root must equal the quality's `formula`.
- Not every exotic quality has a clean form on every string; a quality simply
  omits the root strings it does not support (see rollout).

## v1 tier — exact scope

**Qualities (E6-rooted only in v1):**

| id | name | formula |
|----|------|---------|
| `maj7` | Major 7 | 1 · 3 · 5 · 7 |
| `m7` | Minor 7 | 1 · ♭3 · 5 · ♭7 |
| `7` | Dominant 7 | 1 · 3 · 5 · ♭7 |
| `m7b5` | Minor 7♭5 | 1 · ♭3 · ♭5 · ♭7 |
| `dim7` | Diminished 7 | 1 · ♭3 · ♭5 · 𝄫7 |
| `6` | Major 6 | 1 · 3 · 5 · 6 |
| `m6` | Minor 6 | 1 · ♭3 · 5 · 6 |
| `aug` | Augmented | 1 · 3 · ♯5 |

**Progressions (roman-numeral form; exercise the v1 qualities):**

| name | steps |
|------|-------|
| Major ii–V–I | ii`m7` · V`7` · I`maj7` |
| I–VI–ii–V turnaround | I`maj7` · VI`7` · ii`m7` · V`7` |
| Minor ii–V–i | ii`m7b5` · V`7` · i`m7` |
| Diminished passing | I`maj7` · ♯i`dim7` · ii`m7` · V`7` |
| 6th-chord loop | I`6` · vi`m7` · ii`m7` · V`7` |
| Dominant blues (12-bar) | I`7` · IV`7` · I`7` · I`7` · IV`7` · IV`7` · I`7` · I`7` · V`7` · IV`7` · I`7` · V`7` |
| Augmented lift | I`maj7` · I`aug` · vi`m7` · ii`m7` · V`7` |
| Minor 6 tonic | i`m6` · iv`m7` · V`7` · i`m6` |

**Rollout beyond v1 (same design, more catalog rows):**
1. Add `A5` and `D4` voicings for the v1 qualities.
2. Ninths: `9`, `m9`, `maj9`, `m11`.
3. Extensions / alterations: `13`, `13sus4`, `13#11`, `7b9`, `7#9`, `7#5`,
   `7sus4`, `9sus4`, `9#11`, `m13`, `m6/9`, and the rest of the chart.

## View & interaction

- **Layout — current chord + peek at next.** One large neck shows the current
  grip; a smaller preview shows the **next** chord so the hand can prepare
  (preparing for the change is most of the skill). At the loop boundary, "next"
  wraps to the cell's first chord.
- **Transition — neck slide (camera follows the hand).** On a chord change the
  grip stays **centered**; the neck scrolls underneath it to the new position
  and settles (~0.55s ease). Because the shape never leaves center, the eye
  isn't chasing it around the fretboard. The sliding neck **carries its fret
  markers / a position number** so the actual playing position stays readable —
  essential, since finding the right fret is the point. (Chosen from an animated
  prototype over instant / crossfade / finger-glide.)
- Reuse `FretboardView` (horizontal neck, high-E on top, dark board). The current
  chord renders as its movable voicing — finger-numbered dots, the **root
  highlighted** (the drill's orange), muted strings marked. The chord **name**
  sits with each neck.
- **Display modes (a toggle):**
  - *Name + fingering* — the learning mode; the grip is shown.
  - *Name only (recall)* — both necks hide their dots; only the chord names show,
    so the user recalls and plays the grip from memory. In this mode the
    fingering **reveals on tap** (active-recall self-check) before advancing.
- The progression **loops** — it repeats until the user chooses to move on, so a
  short cell can be drilled until it's under the fingers.
- Controls: **tap to advance** (and, in recall mode, to reveal); **prev**.
  Metronome / auto-advance is a later add.
- Selectors: **key**, **root string** (only strings the loaded tier supports),
  and **display mode**.
- A **progression list** to choose what to practice (curated in v1).

## Progression generator (design; ships after v1 — curated library first)

The generator **recombines idiomatic harmonic cells** rather than building
chord-by-chord, so every result is proven-musical:

- **Cell library** — short roman-numeral fragments, each tagged with the
  qualities it uses: ii–V–I, turnarounds (I–VI–ii–V), minor ii–V–i, tritone
  subs, secondary dominants, and the like.
- **Vocabulary gate** — only cells whose every quality is in the user's
  **unlocked set** are eligible; the generator never presents a grip the user
  hasn't learned. Unlocking more qualities (via tiers or per-string progress)
  widens the pool.
- **Output = a short looping cell** (2–4 chords) that repeats until the user
  moves on.
- **Root spread ramps with comfort** — placement chooses the key and octaves so
  a new cell's roots stay **clustered in a fret region** on the pinned string,
  then widens toward full-neck spread as comfort grows. This is the difficulty
  dial (the vision's `randomness`, applied to root spacing).
- Cross-cell chaining / modulation is a later refinement; the first generator
  ships single cells.

## Architecture (fits existing app patterns)

- **Catalog** as a Type-Object enum, like `Instruments` — `ChordQualities.all`,
  `Progressions.all`, `Voicings` keyed by `(qualityId, rootString)`.
- **Placement** and transposition are pure functions / use cases, unit-tested.
- **Mode wiring**: the app becomes multi-mode; this is a new mode surface
  alongside the note drill. Reuse `DrillView`/`FretboardView` composition and the
  view-model pattern; no changes to the existing note-drill logic.
- **Neck rendering**: the neck-slide transition needs a **camera-follow** neck —
  the shape pinned to center while the neck (fret lines, inlays, fret numbers)
  translates to the active position and animates on change. This is an extension
  of `FretboardView`'s geometry, not a change to the existing note-drill neck.
- **Persistence**: v1 persists only the user's current selection (key, root
  string, last progression) via the existing store-as-seam pattern. No mastery
  store yet.

## Error handling

- A progression step whose placement would fall off the neck (root too high for
  the voicing's span on the chosen string) is resolved by choosing the octave of
  the root that keeps the whole voicing on the fretboard; if none exists, the
  step is flagged at catalog-build time (a test), never at runtime.
- Selecting a root string on which a quality has no voicing is prevented at the
  UI level (only offer supported strings for the loaded tier).

## Testing

- **Formula conformance:** each voicing rendered at several roots produces pitch
  classes equal to its quality's formula.
- **Transposition:** each progression's roman-numeral steps resolve to the
  correct root notes in every key.
- **Placement:** root → fret on each root string is correct, and every v1
  progression places fully on the neck in every key on `E6`.
- **Loop / advance / reveal state:** advancing wraps at the loop boundary, the
  next-chord peek always points at the following step (wrapping to the first),
  and recall mode hides the grip until a reveal then re-hides on advance.
- **View:** SwiftUI previews for each v1 quality's voicing and a sample
  progression step in both display modes.

## Open questions / future

- Voice-leading / mixed-string "same-position" mode (the vision's advanced
  transitions) — future; v1 pins all steps to one root string.
- Cross-cell chaining / modulation in the generator — future.
- Shape-mastery tracking and spaced repetition (auto-advancing the root-spread
  ramp and unlocking tiers from measured comfort) — future.
- Metronome / tempo / auto-advance — near-term follow-up.
