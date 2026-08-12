# Movable Chord Shapes (root-anchored, root = 0)

**Canonical source for the `Voicings` catalog.** Each shape maps to `Voicing`/`VoicingPosition`:
- Strings low E→high e = `VoicingPosition.string` 6,5,4,3,2,1 (6 = low E).
- Each number = `VoicingPosition.fretOffset` (root-relative, root = 0; negative = toward the nut). `x` = muted (no position).
- All shapes are root-on-6th-string → `rootString: .e6`.
- Interval annotations conform to the E6 standard-tuning map used by `ChordFormulaConformanceTests` (s6:o, s5:5+o, s4:10+o, s3:3+o, s2:7+o, s1:o mod 12).
- **Fingers** are not in this sheet; the catalog auto-assigns sensible fingerings (correctable later).

**Engine-quality coverage (23 qualities in `EngineQualities.all`):** ALL 23 covered (maj9, maj7#11, 7alt added below). **Bonus shapes here without an engine quality (parked for later):** m7/6, m(add9), m6/9(add11), m7(add11), 9(♯11), 13sus4, 13(♯11), Aug.

---

Every shape is written **relative to the root, with the root = 0**. Each number is a pure distance from the root's fret: negative = toward the nut, positive = toward the bridge. Example: root at fret 5 with a "−1" → play fret 4. `x` = muted. Strings listed **low E → high e**.

To play a shape anywhere: slide the whole pattern so "0" lands on the root note you want. Shapes with negative numbers need the root high enough on the neck to fit (e.g., M6/9 needs the root at fret 4 or above).

## Major-type

| Chord | Root string | Shape (E A D G B e) | Intervals (E A D G B e) | Example (actual frets) |
|---|---|---|---|---|
| Maj7 (v1) | 6th | 0 x 1 1 0 x | R x 7 3 5 x | Fmaj7: 1 x 2 2 1 x |
| Maj7 (v2) | 6th | 0 2 1 1 x x | R 5 7 3 x x | Fmaj7: 1 3 2 2 x x |
| 6 | 6th | 0 x −1 1 0 x | R x 6 3 5 x | F♯6: 2 x 1 3 2 x |
| M6/9 | 6th | 0 x −1 −1 −3 x | R x 6 9 3 x | G6/9: 3 x 2 2 0 x |
| Maj9 | 6th | 0 x 1 1 0 2 | R x 7 3 5 9 | Gmaj9: 3 x 4 4 3 5 |
| Maj7(♯11) | 6th | 0 x 1 1 −1 −1 | R x 7 3 ♯11 7 | Gmaj7♯11: 3 x 4 4 2 2 (thumb over the low root) |

## Minor-type

| Chord | Root string | Shape (E A D G B e) | Intervals (E A D G B e) | Example (actual frets) |
|---|---|---|---|---|
| min7 | 6th | 0 x 0 0 0 x | R x b7 b3 5 x | Fm7: 1 x 1 1 1 x |
| min6 | 6th | 0 x −1 0 0 x | R x 6 b3 5 x | F♯m6: 2 x 1 2 2 x |
| m7/6 | 6th | 0 2 0 0 2 x | R 5 b7 b3 6 x | Fm7/6: 1 3 1 1 3 x |
| m(add9) | 6th | 0 −2 −3 −1 x x | R b3 5 9 x x | G♯m(add9): 4 2 1 3 x x |
| min6/9 | 6th | 0 x −1 0 0 2 | R x 6 b3 5 9 | Gm6/9: 3 x 2 3 3 5 |
| m6/9(add11) | 6th | 0 0 0 0 2 2 | R 11 b7 b3 6 9 | Fm6/9(add11): 1 1 1 1 3 3 |
| min7(♭5) | 6th | 0 x 0 0 −1 x | R x b7 b3 b5 x | F♯m7♭5: 2 x 2 2 1 x |
| m(maj7) | 6th | 0 x 1 0 0 x | R x 7 b3 5 x | Fm(maj7): 1 x 2 1 1 x |
| m9 | 6th | 0 −2 0 −1 x x | R b3 b7 9 x x | Gm9: 3 1 3 2 x x |
| m7(add11) | 6th | 0 x 0 0 −2 x | R x b7 b3 11 x | Gm7(add11): 3 x 3 3 1 x |
| m11 | 6th | 0 −2 0 −1 −2 x | R b3 b7 9 11 x | Gm11: 3 1 3 2 1 x |
| m13 | 6th | 0 −2 0 2 2 2 | R b3 b7 11 13 9 | Gm13: 3 1 3 5 5 5 |

## Dominant-type

| Chord | Root string | Shape (E A D G B e) | Intervals (E A D G B e) | Example (actual frets) |
|---|---|---|---|---|
| 7 (v1) | 6th | 0 x 0 1 0 x | R x b7 3 5 x | F7: 1 x 1 2 1 x |
| 7 (v2) | 6th | 0 −1 0 1 x x | R 3 b7 3 x x | F♯7: 2 1 2 3 x x |
| 7(♯5) | 6th | 0 x 0 1 1 x | R x b7 3 ♯5 x | F7♯5: 1 x 1 2 2 x |
| 7sus4 | 6th | 0 x 0 2 0 x | R x b7 4 5 x | F7sus4: 1 x 1 3 1 x |
| 9 | 6th | 0 −1 0 −1 x x | R 3 b7 9 x x | G9: 3 2 3 2 x x |
| 7(♭9) | 6th | 0 −1 0 −2 x x | R 3 b7 ♭9 x x | G7♭9: 3 2 3 1 x x |
| 7(♯9) | 6th | 0 −1 0 0 x x | R 3 b7 ♯9 x x | G7♯9: 3 2 3 3 x x |
| 9(♯11) | 6th | 0 −1 0 −1 −1 x | R 3 b7 9 ♯11 x | G9♯11: 3 2 3 2 2 x |
| 9sus4 | 6th | 0 x 0 −1 −2 x | R x b7 9 4 x | G9sus4: 3 x 3 2 1 x |
| 13 | 6th | 0 x 0 1 2 x | R x b7 3 13 x | F13: 1 x 1 2 3 x |
| 13sus4 | 6th | 0 x 0 2 2 x | R x b7 4 13 x | F13sus4: 1 x 1 3 3 x |
| 13(♯11) | 6th | 0 1 0 1 2 x | R ♯11 b7 3 13 x | F13♯11: 1 2 1 2 3 x |
| 7alt (♯5♯9) | 6th | 0 −1 0 0 1 x | R 3 b7 ♯9 ♯5 x | G7alt: 3 2 3 3 4 x |

## Symmetric / altered triads

| Chord | Root string | Shape (E A D G B e) | Intervals (E A D G B e) | Example (actual frets) |
|---|---|---|---|---|
| dim7 | 6th | 0 x −1 0 −1 0 | R x ♭♭7 b3 b5 R | Gdim7: 3 x 2 3 2 3 |
| Aug | 6th | 0 3 2 1 x x | R ♯5 R 3 x x | Faug: 1 4 3 2 x x |

## Notes

- On the chart, "m6/9(add11)" includes a ♭7 in the grip, so it actually sounds like a full m13 voicing.
- The second "7" voicing (0 −1 0 1 x x) has no 5th — the G-string note doubles the major 3rd an octave up.
