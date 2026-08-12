# v2.0 Chord Trainer — Roadmap

**Date:** 2026-07-06
**Companion to:** `docs/v2-chord-trainer-vision.md` (the full vision). This is the *build map* —
ordered sub-projects, what each ships, and what gates what. Each piece gets its own
brainstorm → spec → plan when its turn comes. Nothing here is a single implementable unit;
it's the decomposition.

## Reframe: the repo is already ~half the engine

The current single-note drill **is** the "note mastery" (`note:rootString`) engine. v2.0 =
**generalize the drill engine + layer chords on top**, reusing existing patterns:

| v2.0 needs | Already in the repo | Gap to close |
|---|---|---|
| Note mastery (`note:rootString`) | the whole current drill | none — reuse |
| Chord/Shape/Transition data | `Instruments` Type-Object catalog | new catalogs, same pattern |
| Shape mastery (`chordId:rootString`) | per-instrument store-as-seam | new store, same pattern |
| Prompt generation | `SelectNextPromptUseCase` | generalize to a content-agnostic `PromptSource` |
| Render a chord | `FretboardView` (single position) | render a *set* of positions (barre/mutes) |
| Hear a chord | monophonic pitch detection | **new polyphonic chord-type detector** |

## Locked cross-cutting decisions

- **Two mastery axes:** note mastery = existing store (reused); shape mastery = new
  per-instrument store. Both via store-as-seam.
- **Audio detects chord *type* only** (`root:quality`). Root string is a **prescribed
  on-screen/setting** dimension — the audio never needs to discern voicing.
- **Verification, not identification:** the drill knows the target, so detection is
  "is this consistent with the target chord?" + threshold — much easier than open ID.
- **Input model is TBD by measurement:** the audio method-sweep (P-Audio) decides audio vs
  touch vs hybrid, and which tiers audio can handle. Leaning kNN over chroma with per-user
  calibration + theory prototypes.
- **The app becomes multi-mode:** the current note drill stays as "note trainer"; chords are
  new modes alongside it.

## Layer 1 — Foundation (internal; unlocks everything)

- **P0 · `PromptSource` seam** — abstract "what to ask next"; `DrillPrompt` becomes a sum type
  (find-note | form-shape | transition). Current note drill runs through it unchanged.
  *Ships:* nothing user-facing. *Depends:* none. *Reuse:* `DrillViewModel`, state machine.
- **P-Audio · Chord-type detection** — the polyphonic detector. **First deliverable = the
  method-sweep harness** (spec: `docs/superpowers/specs/2026-07-06-chord-detection-sweep-harness-design.md`)
  → picks a method → **then** reimplement the winner in Swift as a `ChordDetector` alongside
  the existing `PitchDetector`. *Ships:* the detector + its accuracy evidence. *Depends:* none
  (parallel to P0). **Highest-uncertainty piece — do the sweep early.**
- **P1 · `Chord`/`Shape` catalog** — `Chord{id,name,family,formula,tier}`,
  `Shape{chordId,rootString,fretPattern,isMovable}`; T1 × {E6,A5,D4}. *Ships:* pure domain,
  tested, zero UI. *Depends:* none. *Reuse:* `Instruments` Type-Object pattern. **Lowest-risk.**
- **P2 · Multi-position `FretboardView`** — render a set of fretted/open/muted positions +
  barre. *Depends:* P1. *Reuse:* existing fretboard geometry.

## Layer 2 — First shippable feature 🎯

- **P3 · Mode A — shape mastery ("Chord Trainer v1")** — name→form / form→name drills, input
  per P-Audio's verdict (audio and/or touch), shape-mastery store `chordId:rootString`, spaced
  repetition, root-string filter. *Ships:* the first real chord trainer — **the v2.0-worthy
  release cut.** *Depends:* P0, P-Audio, P1, P2.

## Layer 3 — Musical depth

- **P4 · Melodic-pattern generator** — contours (scale/arpeggio/random-walk/chromatic) +
  randomness 0–1 → ordered root stream. *Depends:* P1. Pure domain, testable.
- **P5 · Mode B — transitions** — `Transition` entity, edges from key membership, `travelScore`
  sort, two-chord change / ii–V–I / guide-tone focus / progression library, same-position vs
  position-shift. *Depends:* P1, P3 (Mode-B-eligible once mastered on ≥1 string), P4.

## Layer 4 — Config & polish

- **P6 · Session config + tiers/families** — the `SessionConfig` surface, tier unlocks, family
  filters, the ~7-min session template. *Depends:* P3–P5.

## Dependency graph

```
P0 ─┐
P-Audio ─┤
P1 ─┼─► P3 (Mode A, ship) ─► P5 (Mode B) ─► P6
P2 ─┘         P4 ─────────────┘
```

## Release checkpoints

- **P0–P2 + P-Audio** — internal / can ride interim minor releases (v1.x).
- **P3 (Mode A)** — the natural **v2.0** cut (first user-facing chord trainer).
- **P5 (Mode B)** — a v2.x.

## Status

- ✅ Vision captured (`docs/v2-chord-trainer-vision.md`), this roadmap.
- ✅ **P-Audio step 1** spec'd: the sweep harness (`.../2026-07-06-chord-detection-sweep-harness-design.md`) — implementation next.
- ⬜ Everything else: brainstorm → spec → plan when its turn comes.
