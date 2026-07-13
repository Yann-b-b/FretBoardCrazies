# Chord Theory Engine — Implementation-Ready Spec

**Date:** 2026-07-13
**Status:** Research folded (R1 + R2 complete, 2026-07-13); pending Phase V validation. `[V]` marks claims the validation phase confirms.
**Purpose:** The single source of truth that fuels the chord-suggestion engine's **progression generation** and **tier ladder**. Distilled from the three jazz surveys (`docs/research/2026-07-09-*`, `2026-07-10-*`) + the two 2026-07-13 rounds, de-conflicted against what those surveys **refuted** and flagged **unverified**, and pinned to algorithms an engineer can implement + TDD without making theory decisions.
**Builds on:** the engine design `2026-07-10-chord-suggestion-engine-design.md` (this spec is that design's theory, made concrete) and the existing chord domain (`ChordQualities`, `Voicings`, `ChordNaming`, `ProgressionSession`).

---

## 1. Goal & scope

Given the **current chord** and the **current key**, produce a ranked list of **functionally-justified next chords**, each with a `ruleId` and an explanation, gated by the player's **tier**. Key mode only (v1); no Free/roving mode. The engine reasons over **abstract chords** — `(degree, quality)` — not voicings; grips are a separate concern (the Catalog), so this spec and the engine it defines are **buildable and testable without any voicing data**.

**Non-goal (inherited):** no chord-*quality* detection — the mic verifies only the root. This spec is about *which* chords to suggest and why, not how they're detected or fingered.

## 2. Core representation

- **Pitch class**: `NoteName`, `0..11` (`C=0`), matching the code.
- **Degree**: an `Int` **semitone offset from the key's tonic**, `0..11` — matching the existing `ChordNaming.rootName(tonic:degree:) -> NoteName` (`root = (tonic + degree) mod 12`). NOT a scale-degree ordinal. So in C: `ii`'s degree = 2, `V`'s = 7, `♭II`'s = 1, `♭VII`'s = 10.
- **Quality**: a `qualityId: String` (matches `ChordQuality.id`).
- **ChordSymbol**: `(degree: Int, qualityId: String)` — key-relative. Absolute root = `rootName(tonic, degree)`.
- **Key**: `(tonic: NoteName, mode: Mode)` where `Mode ∈ {major, minor}`. (Minor = the jazz "functional minor" of §3.2, a melodic/harmonic blend, not strict natural minor.)
- **Function**: `enum HarmonicFunction { tonic, subdominant, dominant }` — used for ranking and rule applicability.

## 3. The diatonic model (the backbone)

`diatonic(key) -> [(degree, qualityId, function, roman)]`. Every rule that says "diatonic neighbor" / "the ii" / "the V" / "the next diatonic target" resolves against these tables.

### 3.1 Major key
| degree | roman | qualityId | function |
|---|---|---|---|
| 0 | I | `maj7` | tonic |
| 2 | ii | `m7` | subdominant |
| 4 | iii | `m7` | tonic (mediant) |
| 5 | IV | `maj7` | subdominant |
| 7 | V | `7` | dominant |
| 9 | vi | `m7` | tonic (submediant) |
| 11 | vii | `m7b5` | dominant |

**Tonic colors (major):** `I` may be colored as `6/9`, `maj9`, or `maj7#11`. The natural **11 is the avoid note** on a major tonic — a stable tonic wants `6/9` or `maj7(#11)`, never plain 11. `6/9` / `6` are the most stable **ending** chords (no leading-tone bite). *(color survey §A — CONFIRMED 3-0.)*

### 3.2 Minor key (functional jazz minor)
The tonic is minor; the **dominant is borrowed from harmonic minor (V7, not v m7)**; the tonic color is `m6`/`m(maj7)`, NOT `m7` (m7 on the tonic degree is heard as *the ii*, not as home). *(deployment survey §B — CONFIRMED for tonic-color hierarchy; v→V7 borrowing is standard.)*

| degree | roman | qualityId | function | notes |
|---|---|---|---|---|
| 0 | i | `m7` (diatonic) | tonic | **tonic color = `m6` / `m(maj7)` / `m6/9` / `m9`**; bare `m7` here reads as "a ii", not home |
| 2 | iiø | `m7b5` | subdominant | the ii of the minor ii–V–i |
| 3 | ♭III | `maj7` | tonic (relative major) | |
| 5 | iv | `m7` | subdominant | |
| 7 | V | `7` | dominant | borrowed (harmonic minor); usually `7b9`. Replaces the natural-minor v `m7` for dominant function |
| 8 | ♭VI | `maj7` | subdominant | |
| 10 | ♭VII | `7` | subtonic / **backdoor dominant** | dom7; resolves to I via backdoor (§5) |
| 11 | vii° | `dim7` | dominant | leading-tone dim7 (harmonic minor) |

**Minor tonic-color rule:** palette `{m6, m(maj7), m6/9, m9, m triad}`; the signature move is the **minor-line cliché** `i → i(maj7) → i7 → i6` (§5). `m7` ⇒ "this is a ii," not "home." *(deployment survey §B.)*

## 4. Quality catalog

Each quality: `formula` = semitone intervals from the root (may exceed 12 for extensions; conformance reduces mod 12), `scale` = parent chord-scale, `avoid` = avoid note (semitones) or none, `function` typing, and the `introducedInTier` (see §7). **EXISTS** = already in `ChordQualities.all` (has an E6 voicing); **NEW** = needs a grip before it can be *shown* (but the engine can reason about it now).

| qualityId | name | formula (semitones) | chord-scale | avoid | typical function | status |
|---|---|---|---|---|---|---|
| `maj7` | major 7 | 0,4,7,11 | Ionian/Lydian | 11 (Ionian) | tonic / IV | EXISTS |
| `m7` | minor 7 | 0,3,7,10 | Dorian | — | ii / iv | EXISTS |
| `7` | dominant 7 | 0,4,7,10 | Mixolydian | 11 | dominant | EXISTS |
| `m7b5` | half-dim | 0,3,6,10 | Locrian ♮2 | — | iiø / vii | EXISTS |
| `6` | major 6 | 0,4,7,9 | Ionian/Lydian | 11 | tonic (stable) | EXISTS |
| `m6` | minor 6 | 0,3,7,9 | Dorian/mel-min | — | **tonic minor** | EXISTS |
| `6/9` | six-nine | 0,4,7,9,14 | Ionian/Lydian | 11 | **tonic (most stable)** | NEW |
| `maj9` | major 9 | 0,4,7,11,14 | Ionian | 11 | tonic (I) / pre-dom (IV) | NEW |
| `maj7#11` | Lydian maj7 | 0,4,7,11,18 | Lydian | — (none) | tonic-sub (terminal) / IV | NEW |
| `9` | dominant 9 | 0,4,7,10,14 | Mixolydian | 11 | dominant | NEW |
| `13` | dominant 13 | 0,4,7,10,14,21 | Lydian-dom (♯11) | 11 (nat) | dominant | NEW |
| `7b9` | dom 7♭9 | 0,4,7,10,13 | HW-diminished | — | dominant (V of minor) | NEW |
| `7#9` | dom 7♯9 | 0,4,7,10,15 | altered | — | dominant | NEW |
| `7#5` | dom 7♯5 | 0,4,8,10 | whole-tone/alt | — | dominant | NEW |
| `7alt` | altered dom | 0,4,10,13,15,18,20 | altered (7th mel-min) | — | dominant (resolving) | NEW |
| `7sus4` | dom 7 sus4 | 0,5,7,10 | Mixolydian | — | dominant (delayed) | NEW |
| `9sus4` | dom 9 sus4 | 0,5,7,10,14 | Mixolydian | — | dominant (delayed) | NEW |
| `dim7` | diminished 7 | 0,3,6,9 | HW-diminished | — | passing / rootless ♭9 dom | NEW |
| `m9` | minor 9 | 0,3,7,10,14 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m11` | minor 11 | 0,3,7,10,14,17 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m13` | minor 13 | 0,3,7,10,14,21 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m(maj7)` | minor-major 7 | 0,3,7,11 | melodic minor | — | **tonic minor** | NEW |
| `m6/9` | minor 6/9 | 0,3,7,9,14 | Dorian/mel-min | — | **tonic minor** | NEW |

**R1 (folded):** minor Dorian qualities (`m7 m9 m11 m13 m6 m6/9`) have **no internal avoid-note** — do NOT port the major avoid-11 rule onto them (a source claimed the m13's 11 clashes with the ♭3; pitch arithmetic shows it's a consonant major 9th). `m9/m11/m13` are **color flags on the `m7`-family**: they inherit the underlying chord's function (ii/iv) and never reclassify it — only `m6 / m(maj7) / m6/9` are tonic-minor colors. `maj9`/`maj7#11` are **position-dependent** (tonic-color at `I`, pre-dominant at `IV`); `maj7#11` is also a valid **terminal** tonic-substitute. `6/9` is a distinct tonic branch (peer-reviewed, *MTO* 29.2) with a structurally-required 5th; `m6/9` stays pedagogical (T4). *(color survey §1 + R1: 17 CONFIRMED / 4 standard / 1 source-error corrected by arithmetic.)*

## 5. Rule set (each rule = an algorithm)

Each rule: `id`, an `applies(current, key) -> Bool`, a `candidates(current, key) -> [ChordSymbol]`, a `keyShift` effect (§8), and the tier that unlocks it (§7). All degree math is mod 12. `V7ofDegree(d) = (degree: (d+7) mod 12, "7")` — the dominant a fifth above `d`. `tritoneOf(d) = (d+6) mod 12`.

| ruleId | applies when current is… | candidates | keyShift | tier |
|---|---|---|---|---|
| `diatonic-step` | any diatonic chord | the diatonic chords one scale-step above and below current's degree (from §3 table for the key) | none | T1 |
| `ii-to-V` | the `ii` (deg 2, `m7`\|`m7b5`) | `V7` = (deg 7, `7`) [minor: `7b9`] | none | T1 |
| `V-to-I` | the `V` (deg 7, dominant) | tonic: major → (0,`maj7`\|`6/9`\|`maj9`); minor → (0,`m6`\|`m(maj7)`) | none | T1 |
| `tonic-color` | the `I`/`i` (deg 0) | major → (0,`6/9`),(0,`maj9`),(0,`maj7#11`); minor → (0,`m6`),(0,`m(maj7)`),(0,`m6/9`) | none | T1 |
| `dominant-upgrade` | any dominant (`7`) | same degree as `9`, then `13` | none | T2 |
| `secondary-dominant` | any diatonic chord T | for each diatonic target x (ii, iii, IV, V, vi), `V7ofDegree(x.degree)` = (x.degree+7, `7`\|`7b9`) | **tonicize(x)** | T2 |
| `tritone-sub` | any dominant resolving to target t | `(tritoneOf(dominant.degree), "7")` — resolves to t by ♭II7, chromatic bass | inherits dominant's | T2 |
| `mode-mixture-iiø` | the `ii` (deg 2, `m7`) | (2, `m7b5`) — borrow ♭6 | none | T3 |
| `mode-mixture-V7b9` | the `V` (deg 7, `7`) | (7, `7b9`) | none | T3 |
| `altered-dominant` | the `V` (deg 7, dominant) | (7,`7#9`),(7,`7b9`),(7,`7alt`) + US triad note (explanation) | none | T3 |
| `dim-passing` | a diatonic chord followed by a step-up diatonic chord | passing `(current.degree+1 mod 12, "dim7")` between current and the diatonic chord a step above (rootless ♭9 dom pulling up) | none | T4 |
| `backdoor-ii-V` `[R2]` | the `I`/`IV` in major | `(5,"m7")` then `(10,"7")` → resolves to I (♭VII7 backdoor) | none | T4 |
| `minor-line-cliche` `[R2]` | the `i` (minor, deg 0) | ordered `(0,"m(maj7)") → (0,"m7") → (0,"m6")` chromatic top-voice descent | none | T3 |
| `extended-color` `[R1]` | tonic or `ii`/`iv` | tier-appropriate colors: `maj9`,`maj7#11` (major tonic/IV); `m9`,`m11`,`m13` (ii/iv); `m6/9`,`m(maj7)` (minor tonic) | none | T4 |
| `turnaround` `[R2]` | the `I`/`i` at a phrase end | `I–vi–ii–V` and subs `I–VI7–ii–V`, `iii–VI7–ii–V`, tritone-sub turnaround `I–♭III7–♭VI7–♭II7`, Ladybird `Imaj7–♭IIImaj7–♭VImaj7–♭IImaj7` | in-key (≤ tonicization) | T4 |

**Rationale provenance (research folded 2026-07-13):** the relationship-graph edges (`secondary-dominant`, `tritone-sub`, `mode-mixture-*`, `dim7≈rootless♭9`, `tonic-color`, minor ii–V–i) are CONFIRMED (color survey §5.1, voice-leading survey). **R2 confirmed** (closing the round-3 gap, by 2–3 sources + pitch arithmetic): `minor-line-cliche` — the **forced ordered chain** `i→i(maj7)→i7→i6` then routing to the **3rd of the next V7**, static tonic, **no key change** (`i6 ≡ rootless V9 of the relative major`); `backdoor-ii-V` (`ivm7→♭VII7→I`, both borrowed from parallel minor, **no modulation**); `dim-passing` (each `♯x°7` is a **rootless secondary V7♭9** of the next diatonic chord, connector only); the **secondary ii–V** 5-row table (over ii/iii/IV/V/vi — **tonicization, NOT modulation**); and the turnaround subs (all **in-key**). `extended-color` movement per **R1** (see §4 note).

## 6. Ranking

`rank(candidate) =` sort by, in order:
1. **Functional strength** (highest first): a resolving dominant→tonic (`V-to-I`, `tritone-sub` into tonic) > `ii-to-V` motion > `secondary-dominant` (tonicizing) > diatonic step > color swaps (`tonic-color`, `dominant-upgrade`, `extended-color`) > passing (`dim-passing`).
2. **Tonic-stability** (for resting/target chords): major tonic `6/9` ≈ `maj7#11` > `maj9` > `maj7`; minor tonic `m6` ≈ `m(maj7)` > `m6/9` > `m9` > `m triad`; `m7` is NOT a tonic. *(deployment survey §A/B — CONFIRMED.)*
3. **Tier** — only surface candidates whose quality AND ruleId are unlocked in the current tier (§7). Show the top **3–5**.

`[V]` The exact numeric scoring + tie-breaks are validated by the progression-simulation pass.

## 7. Tier ladder

Derived from the theory's own difficulty ordering (color survey §5.2: *plain 7ths → 9/13 → tritone-sub & ♭9 → altered/upper-structures → dim7 & Barry-Harris*). Each tier ADDS qualities + ruleIds to all prior tiers. A tier only introduces qualities it will have shapes for (Catalog dependency), but the ladder itself is theory-fixed.

| Tier | Adds qualities | Adds ruleIds | Musical idea |
|---|---|---|---|
| **T1 — Diatonic core** | `maj7 m7 7 m7b5 6 m6 6/9` | `diatonic-step ii-to-V V-to-I tonic-color` | play changes: ii–V–I, diatonic motion, stable tonic colors |
| **T2 — Dominant color & secondary motion** | `9 13 maj9` | `dominant-upgrade secondary-dominant tritone-sub` | upgrade dominants; tonicize; chromatic bass |
| **T3 — Alteration & minor color** | `7b9 7#9 7#5 7alt m9 m(maj7)` | `mode-mixture-iiø mode-mixture-V7b9 altered-dominant minor-line-cliche` | alter the dominant; minor-borrowing; minor-line cliché |
| **T4 — Extended & passing** | `maj7#11 m11 m13 m6/9 dim7 7sus4 9sus4` | `dim-passing extended-color backdoor-ii-V turnaround` | passing dim7, extended colors, backdoor & turnaround subs |

**Unlock metric (dev-tunable constants, seeded here):** during a timed run the engine tracks **time-to-play** (chord-becomes-current → correct root heard) per chord; when the **rolling average over `sustainWindow` clears `targetTimePerChord`**, the next tier unlocks. Seed: `targetTimePerChord = 1.5s`, `sustainWindow = 10 min` rolling. Rolling-average (not streak) for forgiveness. These are constants, not user settings. `[V]`

## 8. Key-shift / modulation semantics

The home key is stable. A `secondary-dominant` or a tonicizing `tritone-sub`/`turnaround` sub creates a **pending tonicization** of a target degree `x`, not a permanent modulation:
- Playing `V7/x` sets `pendingTonic = x` (relative to home). The breadcrumb annotates the chord as `V7/x`.
- If the next chord played **is** `x` (its diatonic quality in home key), the tonicization **resolves** and the key stays home (`x` is reinterpreted as its home-key diatonic role). This is a brief tonicization, the common case.
- Only a **completed ii–V–I in the new key** (a secondary ii, then `V7/x`, then `x` as a *tonic* quality) promotes `pendingTonic` to an actual `key` change (modulation); the breadcrumb shows the modulation.
- Any diatonic chord of the home key clears a stale `pendingTonic`.

**R2 confirmed:** secondary dominants / secondary ii–V's, backdoor ii–V, dim7 passing chains, and turnaround subs are all **tonicization at most — the home key does not change.** So the default `keyShift` for these is a *pending tonicization annotation*, never a `key` reassignment; only a fully-completed ii–V–I in a new key promotes to modulation.

`[V]` The promotion-to-modulation threshold is validated by simulating secondary-dominant chains and confirming the paths stay coherent and the key annotations read correctly.

## 9. Enharmonic spelling

Theory reads in flats where function demands (`♭II7` = D♭7 in C, not C#7); the code's `NoteName.displayName` is sharps-only. The engine needs a **key-relative speller**: `spell(degree, key, role) -> String` (letter + accidental).
- Diatonic degrees use the key's key-signature spelling (each of the 7 letters once).
- Chromatic degrees spell by **function**: secondary dominants and their targets spell toward resolution (`V7/ii` in C = A7, its root A♮); `♭II7`/`♭VI`/`♭III`/`♭VII` spell **flat**; `♯iv°7`/`♯i°7` passing dims spell **sharp** (ascending). 
- Implementation: a per-key letter-cycle table (circle of fifths) + a function-driven accidental choice. This is a small pure module (`ChordSpelling`) with unit tests; it does not change `NoteName` (which stays the pitch-class truth).

## 10. Explanations table

`ruleId -> {short, long}`, authored from the surveys. Draft (long forms cite the mechanism):
| ruleId | short | long |
|---|---|---|
| `V-to-I` | "resolves home" | "the 7th of V falls a half-step to the 3rd of I while a common tone holds." |
| `ii-to-V` | "sets up the V" | "ii→V is the core jazz motion; the 7th of ii becomes the 3rd of V." |
| `tonic-color` | "colors the tonic" | "6/9 and maj7♯11 rest without the maj7 leading-tone bite (the 11 is the avoid note)." |
| `secondary-dominant` | "V7 of the next chord" | "a dominant borrowed to tonicize the next target — e.g. A7 pulls to Dm (ii)." |
| `tritone-sub` | "♭II7 — tritone sub" | "D♭7 subs for G7: same 3rd & 7th, and the bass moves chromatically D♭→C." |
| `mode-mixture-iiø` | "borrow the ♭6" | "ii7 → iiø7 borrows ♭6 from the parallel minor; signals a minor ii–V." |
| `altered-dominant` | "alter the dominant" | "♭9/♯9/♯11/♭13 are tendency tones pulling into the tonic; e.g. 13♯11 = a D triad over the dominant." |
| `dim-passing` | "passing dim7" | "this dim7 is a rootless ♭9 dominant pulling up to the next chord." |
| `minor-line-cliche` | "minor-line cliché" | "the inner voice walks down root→7→♭7→6 over the minor tonic (My Funny Valentine)." |
| `backdoor-ii-V` `[R2]` | "backdoor to I" | "iv m7 → ♭VII7 resolves to I from below (borrowed from parallel minor)." |
| `extended-color` `[R1]` | "extended color" | authored from R1 per quality. |
| `turnaround` `[R2]` | "turnaround" | "I–vi–ii–V (and subs) recycles back to the top of the form." |

## 11. Provenance & open items

- **Refuted claims explicitly NOT used:** the CAGED per-shape root-string mapping (voice-leading survey — refuted 1-2); the "canonical 5 majors + 2 minors" upper-structure count (deployment survey — refuted 1-2); the root/5th/7th upper-structure enumeration (color survey — refuted 0-3). The engine uses only the *confirmed* per-triad US spellings as explanation flavor, never as a ranked list.
- **Research folded (2026-07-13):** R1 (`docs/research/2026-07-13-extended-color-movement-survey.md`) and R2 (`docs/research/2026-07-13-deployment-patterns-survey.md`) complete. Net: the minor-line cliché, backdoor ii–V, dim7 passing chains, secondary ii–V table, and turnaround subs — previously round-3 **unverified** — are now CONFIRMED (2–3 sources + pitch arithmetic), and all are **in-key (no modulation)**.
- **Pending validation `[V]`:** ranking numerics, key-shift semantics, tier boundaries — confirmed by the theory-correctness review + progression simulation.
- **Dev-tunable (not theory):** `targetTimePerChord`, `sustainWindow`, exact ranking weights.
