# Combo Escalation — Design

**Date:** 2026-07-02
**Status:** Approved for planning
**Branch context:** `ios-drill-layout`

## Goal

Replace the flat combo feedback (a size flip at 10 + a single sine beep) with one
fluid **escalation** where the flame's size, motion, and color *and* the audio all
ramp through the same milestones as the combo climbs. Milestones: **15 / 25 / 50**.

## The escalation curve

`comboCount` maps to a tier. Thresholds are named constants (easy to tune).

| Tier | Combo | Flame | Motion (side-to-side) | Color | Audio |
|---|---|---|---|---|---|
| 0 | < 2 | — | — | — | badge hidden, silent |
| 1 | 2–14 | small | amplitude **grows** with count | normal | soft per-hit cue, rising within tier |
| 2 | 15–24 | large (pop on entry) | calm | normal | fuller per-hit cue; **tier-up stinger at 15** |
| 3 | 25–49 | large | amplitude **resumes & grows** | normal | intense per-hit; **tier-up stinger at 25** |
| 4 | 50+ | large | full | **rainbow** hue-cycle | top-tier per-hit; **tier-up stinger at 50** |

"Motion" is a horizontal wiggle (the flame jumps side to side). Amplitude is 0 at the
start of a motion tier and grows toward a max as the combo climbs within that tier;
it resets when a new tier is entered (so tier 2 feels calm before tier 3 re-energizes).

This supersedes today's `flameAsset(for:)` threshold (large at ≥10) — the size flip
now happens at 15, driven by the tier.

## Architecture

### Visual — a pure function

New file `audio_listen/Presentation/Drill/ComboEscalation.swift`:

- `enum ComboTier: Int { case none, one, two, three, four }` with `static func tier(for combo: Int) -> ComboTier` using named thresholds (`tier2 = 15`, `tier3 = 25`, `tier4 = 50`).
- `struct ComboVisual { let flameAsset: String; let wiggleAmplitude: CGFloat; let rainbow: Bool }` and `static func visual(for combo: Int) -> ComboVisual`:
  - `flameAsset` = `"flame-small"` for tier ≤ 1, else `"flame-large"`.
  - `wiggleAmplitude` grows linearly within tiers 1 and 3 (from 0 to a max), and is ~0 in tier 2 (calm); tier 4 is full.
  - `rainbow` = tier == four.

This is pure and fully unit-testable. `flameAsset(for:)` in `StickerHelpers.swift` is
retired and its uses point at `ComboEscalation` (its test moves too).

### Visual — the view

`DrillView.comboBadge` reads `ComboEscalation.visual(for: comboCount)` and applies:
- the flame image (`visual.flameAsset`),
- a horizontal wiggle: an `@State` toggled by a `repeatForever(autoreverses:)` animation, `offset(x: wiggleOn ? +amp : -amp)` with `amp = visual.wiggleAmplitude`,
- a rainbow overlay when `visual.rainbow`: an `AngularGradient` (full-spectrum) masked to the flame `Image`, with an animated `hueRotation` looping continuously; also tint the "N combo" text to match.

The badge keeps its existing constant-height slot (no fretboard resize) and the
existing scale-with-combo. Below tier 1 the badge stays hidden.

### Audio — script-generated samples

New script `scripts/generate_combo_sounds.py` (Python, numpy + `wave`, matching this
repo's "assets via script" convention) synthesizes short cues to `.wav` and writes them
into the app bundle resources:

- **Per-hit cues**, one per audible tier: `combo-hit-1.wav` … `combo-hit-4.wav`. Short
  (~0.15–0.3 s) with an ADSR envelope and a few harmonics for warmth; richer per tier
  (tier 1 single note → tier 4 bright arpeggio). Pitch may rise with position in tier.
- **Tier-up stingers**: `combo-tierup-2.wav`, `-3.wav`, `-4.wav` — short ascending
  chimes (~0.4–0.6 s), brighter each step, played when crossing 15 / 25 / 50.

The generated `.wav` files are committed (like the generated art). They live in a
bundled resources folder (e.g. `audio_listen/Sounds/`).

`ComboSoundPlayer` is rewritten to preload these files as `AVAudioPlayer`s and, in
`play(combo:)`, (a) play the current tier's per-hit cue and (b) if this increment
crossed a tier threshold, play that tier-up stinger. It tracks the previous tier
internally so the caller keeps its current `onChange(comboCount) { play(combo:new) }`
contract. If a sound file is missing, it fails silent (no crash).

## Files touched

| File | Change |
|---|---|
| `audio_listen/Presentation/Drill/ComboEscalation.swift` | **new** — `ComboTier` + `ComboVisual` pure logic |
| `audio_listen/Presentation/Drill/DrillView.swift` | **modified** — `comboBadge` uses the visual (flame, wiggle, rainbow) |
| `audio_listen/Presentation/Drill/ComboSoundPlayer.swift` | **rewritten** — sample playback + tier-up stingers |
| `audio_listen/Presentation/Drill/StickerHelpers.swift` | **modified** — retire `flameAsset`, delegate to `ComboEscalation` (or remove) |
| `scripts/generate_combo_sounds.py` | **new** — synthesize + render the `.wav` cues |
| `audio_listen/Sounds/*.wav` | **new** — generated, committed, bundled cues |
| `audio_listenTests/ComboEscalationTests.swift` | **new** — pure-function tier/visual tests |
| `audio_listenTests/StickerHelpersTests.swift` | **modified/removed** — folded into ComboEscalation tests |

### Build integration

New Swift files join the synchronized project group automatically. The `Sounds/`
`.wav` files must be members of the app target's resources so `AVAudioPlayer` /
`Bundle.main.url(forResource:)` can find them — confirm they're bundled (the plan
verifies by loading one at runtime). The Python script follows the repo's existing
`scripts/` pattern (uv/pytest available).

## Testing

- **`ComboEscalationTests`** (Swift Testing): tier boundaries (1→none, 2→one, 14→one,
  15→two, 24→two, 25→three, 49→three, 50→four); `flameAsset` per tier (small ≤ tier1,
  large ≥ tier2); `rainbow` true only at tier 4; `wiggleAmplitude` is 0 at each motion
  tier's entry, grows within tiers 1 and 3, and stays low in tier 2.
- **`scripts/test_generate_combo_sounds.py`** (pytest): running the generator produces
  every expected `.wav` with non-zero duration.
- **Audio playback + animations** are verified by ear/eye on the simulator or device
  (not unit-tested — AVAudioPlayer and SwiftUI animation aren't meaningfully unit-testable here).
- Existing suites stay green.

## Out of scope

- Achievements tied to combo (separate later feature).
- Haptics.
- Per-user sound on/off setting (could add later in Settings).
- Professional sound design — cues are script-synthesized, tunable, and a large step
  up from the single beep, not studio-produced.

## Open tuning values (decided in the plan, easy to change later)

Exact wiggle amplitude max, hue-cycle speed, per-tier cue pitches/harmonics, and cue
durations are implementation values set in the plan and tunable on-device.
