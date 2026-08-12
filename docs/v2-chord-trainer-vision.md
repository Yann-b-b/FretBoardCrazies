# Guitar Chord Trainer — Practice Spec (v2.0 vision)

> **Status:** Captured vision, not yet a decomposed/approved design. This is a large,
> multi-subsystem direction — it needs decomposition into sub-projects (each with its own
> brainstorm → spec → plan) plus repo-readiness groundwork before implementation. See
> `ideas.md` for the short descriptor.

## Core goal
The app is fundamentally a **fretboard note-location trainer**; chords are the vehicle.
Because a chord's shape is **invariant** for a given type + root string, the only variable
the user actually solves each rep is: *find the root note on the specified string, then
play the shape you already know.* Every drill is therefore a note-finding rep in disguise.

**Implication for the data model — track two independent mastery axes:**
- **Shape mastery** — `` `${chordId}:${rootString}` `` (do they know the grip?)
- **Note mastery** — `` `${note}:${rootString}` `` (can they *find* that note on that string, fast?)
A user can know the m7 shape cold yet be slow finding G on D4. These progress separately
and both feed drill selection.

## Architecture principle
**Mode A trains nodes (shapes). Mode B trains edges (transitions).**
Same chord objects feed both. A chord becomes eligible in Mode B once it's
mastered on **at least one** root string in Mode A.

---

## Root strings (low 3) — a first-class practice axis
```
RootString = "E6" | "A5" | "D4"
```
| Value | Root on | Role |
|-------|---------|------|
| `E6`  | low E (6th) | barre foundation |
| `A5`  | A (5th)     | barre foundation |
| `D4`  | D (4th)     | compact middle-string "grip" voicings |

- Each root string is a **distinct physical pattern** for the same chord — not the same pattern relocated.
- Shapes are **movable**: shift frets to change key *within* one root string.
- Exposed as a filter in every drill: `"E6" | "A5" | "D4" | "any"` (`"any"` = randomized = hard mode).

---

## Core entities
```ts
Chord         { id, name, family, formula, tier }
Shape         { id, chordId, rootString, fretPattern, isMovable }   // one per rootString
Transition    { fromChordId, toChordId, key, guideTones, movingNotes, travelScore }
MelodicPattern{ id, name, contour, key, randomness }               // how roots are sequenced
```
- `formula` = intervals from root (e.g. `[1, ♭3, 5, ♭7]`). Drives auto-generated "one-edit" drills and answer checking.
- **Mastery key** = `` `${chordId}:${rootString}` `` — a chord is known *per string*, tracked independently.
- `travelScore` = total fret/string distance between the two shapes; used to auto-sort easy vs. hard transitions.
- `contour` = the shape the root notes trace (see Tiers). `randomness` (0–1) = how much the generator deviates from the pure contour when picking the next root.

---

## Families (top-level category axis)
Each family = one formula skeleton; members are that skeleton + edits.

| Family | Formula | Feel |
|--------|---------|------|
| Major | 1 · 3 · 5 | resolved / home |
| Dominant | 1 · 3 · 5 · ♭7 | tense / wants to move |
| Minor | 1 · ♭3 · 5 | dark / mellow |
| Diminished / half-dim | 1 · ♭3 · ♭5 | unstable |
| Suspended / no-3rd | 3 → 2 or 4 | open / floaty |
| Augmented | 1 · 3 · #5 | dreamy / uneasy |

---

## Tiers (unlock / progression axis)
Tier defines *which chord types* are in the pool:
1. **T1** — triads + power/sus: `C, Cm, C5, Csus2, Csus4`
2. **T2** — sevenths + sixths: `Cmaj7, Cm7, C7, C6, Cm6`
3. **T3** — ninths + adds: `Cmaj9, Cm9, C9, Cadd9, C6add9`
4. **T4** — extensions + alterations: `11ths, 13ths, dim7, m7♭5, altered dominants`

### Delivery: trace the tier through a melodic pattern
Don't quiz chords in isolation — that's flashcard-boring. Instead, generate an **ordered
stream of roots** that traces a `MelodicPattern`, and hang a tier-appropriate chord on each
root. The user reads each root, locates it on the chosen string, and plays the (fixed) shape.
This makes the note-finding musical and reinforces the whole neck instead of one region.

**Contours** (the shape the roots trace):
| Contour | Root motion | Trains |
|---------|-------------|--------|
| `scale-asc/desc` | stepwise up/down a key's scale | adjacent-note fluency |
| `arpeggio` | leaps by 3rds/4ths | wider interval jumps |
| `random-walk` | small random steps within a fret window | recognition under uncertainty |
| `chromatic` | half-steps | full-neck coverage |

**Randomness** (`0–1`) dials predictability: `0` = pure contour (user can anticipate the next
root), `1` = pattern is only a loose bias and the next root is largely unpredictable (pure
recall). Use it as a difficulty ramp *within* a tier — same chords, harder finding.

---

## Mode A — Melody-agnostic (shape mastery)
No harmonic context. Pure shape recognition/formation.

| Drill | Prompt → action | Root-string effect |
|-------|-----------------|--------------------|
| Name → form | show `Cm7`, user plays it | can pin to E6/A5/D4 or leave open |
| Form → name | show shape, user names it | reverse recognition |
| Family morph | walk one family by single edits (`Cmaj7→Cmaj9→C6`) | **pin one root string** so edits stay in-position |
| Movable slide | same shape, rotate root (`Cm7→Dm7→Em7`) | **scoped to one root string** — string jumps break the slide |

Scheduling: spaced repetition keyed on `chordId:rootString`. Graduates on fast recall.

---

## Mode B — Transition-based (harmonic movement)
Chords in sequence; the *change* is the point.

| Drill | What it does |
|-------|--------------|
| Two-chord change | loop `A→B` at tempo; count clean changes (atomic unit) |
| ii–V–I loop | backbone pattern rotated through keys (`Dm7→G7→Cmaj7`, `Cm7→F7→B♭maj7`) — same 3 shapes, moved |
| Guide-tone focus | highlight the **3rd + 7th** of each chord moving by half-step (this is what makes changes sound smooth) |
| Progression library | prebuilt real sequences: 12-bar blues, `I–vi–ii–V`, `I–V–vi–IV`; tagged by key + difficulty |

**Transition generation:** derive valid `from→to` pairs from **key membership** (a chord's natural neighbors are the other diatonic chords in its key). Store the `key → chords` map once; generate edges from it rather than hand-authoring.

**Root string in transitions:**
- *Same-position* (default) — keep roots on nearby strings for minimal hand travel + tight voice leading, e.g. `Dm7 (A5) → G7 (E6) → Cmaj7 (A5)`.
- *Position-shift* (advanced) — deliberately force a jump across root strings under tempo.
- The generator picks shapes minimizing `travelScore`, then stores it as the difficulty sort key.

---

## Bite-sized session template (~7 min)
1. **Review** (2m) — spaced-repetition queue from Mode A.
2. **New item** (2m) — one new shape *or* one new transition.
3. **Timed reps** (2m) — metronome change drill on today's item.
4. **Loop-out** (1m) — play it inside a ii–V–I for musical context.

---

## Session config summary
```ts
SessionConfig {
  mode: "A" | "B",
  family?: Family,
  tier?: 1 | 2 | 3 | 4,
  rootStringFilter: "E6" | "A5" | "D4" | "any",
  contour: "scale-asc" | "scale-desc" | "arpeggio" | "random-walk" | "chromatic",
  randomness: number,                                   // 0–1
  key?: Key,                                            // tonal center for the pattern
  transitionMode?: "same-position" | "position-shift"   // Mode B only
}
```
