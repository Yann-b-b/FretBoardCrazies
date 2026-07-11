# Chord Suggestion & Explanation Engine — Design Spec (v1)

**Date:** 2026-07-10
**Status:** Approved design, ready for implementation planning.
**Builds on:** the chord domain layer (`ChordQualities`, `Voicings`, `ChordPlacement`,
`ChordNaming`, `ProgressionSession`) and the redesigned `ChordFretboardView`; the three
research surveys in `docs/research/2026-07-09-*` and `2026-07-10-*`; the existing monophonic
`PitchDetector` / note-drill input.

## Goal

An interactive, build-your-own chord engine: you're on a chord, the app suggests a few
**good next chords** (functionally justified), shows **why** each works, and you build a
progression by playing them. It teaches as you go — the vocabulary unlocks by demonstrated
speed. The chord is the vehicle; **finding the root is the measured skill.**

## Non-goals (v1)

- **No chord-quality detection.** The mic verifies only the **root note** (monophonic); the
  player owns the chord shape (it's shown on screen). Modeling chord-quality nuance is out of
  scope (proven too hard in the research).
- **No Free (roving) mode in v1** — Key mode only; Free is a fast-follow.
- **No adaptive introduction** — tiers are speed-gated, not usage-adaptive.
- **No multiple voicings per chord** — one voicing per chord (from the reference sheet).

## Prerequisite (step one) — catalog the color chords

The app currently has 6 E6-rooted qualities. This engine needs the reference sheet's full
color vocabulary as **voicings** (each chord's grip: strings / frets / fingers), digitized into
the `Voicings` catalog exactly like the existing 6, with matching `ChordQualities` entries and
formula-conformance tests. Targets: dominant 9/11/13, altered dominants (7♭9/7♯9/7♯5/7alt),
m7♭5, dim7, 6/9, m6/9, sus (7sus4/9sus4), extended maj/min (maj9, maj7♯11, m9, m11, m13,
m(maj7)). The engine can only suggest a chord it has a shape for.

## The core loop (UX)

1. A **current chord** renders on the drill neck (reuse `ChordFretboardView` — full grip,
   finger numbers, root highlighted).
2. Below it, **3–5 suggested next chords** as tappable cards: chord name, a **short "why"**,
   and a mini grip. Ordered by functional strength.
3. The player **frets the shape and plays** → the mic hears the **root** → the chord is
   confirmed. (Tapping a card selects which suggestion you're playing.)
4. On confirm, the chosen chord **glides in** as the new current chord, the previous chord
   joins a **progression breadcrumb** (the sequence you're building), and fresh suggestions
   appear.
5. Tap a suggestion's "why" for the **fuller explanation** (guide tones, chord-scale, function).
6. Controls: **Key** selector, current **tier/level** + progress toward unlock. (Key ↔ Free
   toggle is stubbed for the later Free mode.)

This evolves the **Chords tab** into the suggester; the current curated-progression player
becomes a secondary option (or folds in later).

## Input model — root-note verification (reuse the note-drill detector)

- Reuse the existing monophonic `PitchDetector` / `MicNoteSource`.
- The current chord has a known **root** (pitch class, on the root string at a placed fret).
  The engine performs **verification, not identification**: does the detected pitch match the
  **expected** root (allowing any octave)? On match → "played."
- **Timing:** time from the chord becoming current until the correct root is detected =
  *time-to-play*. This is both the "you played it" signal and the tier-unlock metric.
- The player owns the chord *shape* (unverified) — the on-screen fingering is the guide.
- **De-risk first (a spike):** verify that the monophonic detector reads the root reliably
  **while a full chord is strummed** (other strings ring). Since we only confirm the expected
  root, this is the easy case, but it must be validated before building on it. Fallback if
  flaky: "sound the root/bass note to confirm, then add the shape."

## The suggestion engine (Key mode)

A pure function `suggest(current, key, tier) → [Suggestion]`, where each `Suggestion` is a
`(chord, ruleId, shortWhy)`. Suggestions come from a **functional rule set** (from the research),
each rule **gated by tier** and carrying an explanation:

| ruleId | move | gloss/gate (tier) |
|---|---|---|
| `diatonic-step` | to a diatonic neighbor in the key | T1 |
| `ii-to-V` | ii(m7 / m7♭5) → V7 | T1 |
| `V-to-I` | V7 → Imaj7 / I6/9 (or i in minor) | T1 |
| `tonic-color` | I → I6/9; i → i·m6 / i·m(maj7) | T1 |
| `dominant-upgrade` | V7 → V9 / V13 | T2 |
| `secondary-dominant` | → V7/x (dominant of the next diatonic target); may shift key | T2 |
| `tritone-sub` | V7 → ♭II7 (shared guide tones, chromatic bass) | T2 |
| `mode-mixture-iiø` | ii7 → iiø7 (borrow ♭6) | T3 |
| `mode-mixture-V7b9` | V7 → V7♭9 | T3 |
| `altered-dominant` | V7 → V7♯9 / V7♭9 / V7alt (+ upper-structure note) | T3 |
| `dim-passing` | I → ♯i°7 → ii (chromatic passing; rootless ♭9) | T4 |
| `extended-color` | maj9 / maj7♯11 / m9 / m11 / m13 as tier-appropriate colors | T4 |

- **Ranking:** functional strength first (resolutions and ii–V motion top), then
  **tonic-stability** for resting chords (major: 6/9 or maj7♯11 > maj7; minor: m6 / m(maj7) are
  home, m7 = the ii). Show the top 3–5 whose qualities are unlocked in the current tier.
- **Key shifts:** a `secondary-dominant` or a resolving ♭II7 that tonicizes elsewhere updates
  the current key; the breadcrumb reflects the modulation.

## Explanations

A `ruleId → { short, long }` table, authored from the surveys. Examples:
- `tritone-sub` → short: *"♭II7 — tritone sub"*; long: *"D♭7 subs for G7: same 3rd & 7th, and
  the bass moves chromatically D♭→C."*
- `V-to-I` → short: *"resolves home"*; long: *"the 7th falls a half-step to the 3rd of I while
  a common tone holds."*
- `altered-dominant` → short/long include the **upper-structure** one-liner (*"13♯11 = a D triad
  over the dominant"*).

## Tiers & speed-gated unlock

- Each **Tier** defines: the chord qualities + rule ids it adds, and an app-set
  **`targetTimePerChord`** (e.g. 1.5 s) and **`sustainWindow`** (e.g. 10 min). These values are
  **dev-tunable constants**, not user settings.
- **Unlock metric:** during a timed practice run, the app tracks *time-to-play* (time until the
  correct root is heard) per chord; when the **rolling average over the sustain window clears
  the target**, the next tier unlocks. (Rolling-average vs. streak/reset is a dev-tunable detail
  to settle in playtest; the spec assumes rolling average for forgiveness.)
- Unlocking a tier surfaces a short "here's what's new" note (the added colors/moves).

## Architecture (fits existing patterns)

- **Domain (pure, tested):**
  - Catalog extension: color `ChordQualities` + `Voicings` (from the sheet).
  - `Key` (tonal center) model; `SuggestionEngine.suggest(current:key:tier:)`; a `SuggestionRule`
    set; `Explanations` table; `Tier` catalog + `TierProgress` (time-to-play accumulator + unlock).
  - `RootMatcher` — detected pitch vs expected root (octave-agnostic).
- **Input:** reuse `PitchDetector` / `MicNoteSource`; feed detected pitch to `RootMatcher`.
- **Presentation:** `ChordSuggesterView` (current chord via `ChordFretboardView` + suggestion
  cards + breadcrumb + key/tier UI). Suggestion cards render mini grips.
- **Persistence (store-as-seam):** current tier, tier progress, key, built progression.

## Testing

- **Suggestion engine:** given `(current, key, tier)`, assert the expected suggestion set +
  rule ids (per tier); key shifts on secondary dominants / tritone subs.
- **Explanations:** an entry exists for every `ruleId`.
- **RootMatcher:** detected pitch → match/no-match vs expected root, including octave handling.
- **TierProgress:** time-to-play accumulation → unlock at threshold; below-threshold does not unlock.
- **Catalog:** each color voicing's pitch classes match its quality's formula (reuse the
  conformance guard).
- **Views:** SwiftUI previews; the input/timing verified by the spike + simulator.

## Phasing

1. **Spike:** validate root detection on strummed chords (existing detector) — de-risk before building.
2. **Catalog:** digitize the sheet's color voicings + qualities (+ conformance tests).
3. **Engine:** `SuggestionEngine` + rules + explanations (Key mode), pure & tested.
4. **Tiers:** `Tier` catalog + speed-gated `TierProgress` + root-matcher timing.
5. **Screen:** `ChordSuggesterView` wiring it together on the neck; persistence; tab evolution.

## Open questions / future

- **Free (roving) mode** — voice-leading-smoothness ranking, keyless (fast-follow).
- **Adaptive** introduction; **multiple voicings** per chord; A5/D4 re-rootings.
- Exact unlock rule (rolling average vs. streak) — settle in playtest.
- If root-detection-on-strum proves unreliable, the bass-note-confirm fallback.
