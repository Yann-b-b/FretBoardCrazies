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
| `7b9` | dom 7♭9 | 0,4,7,10,13 | HW-diminished (from dom root) | — | dominant (V of minor) | NEW |
| `7#9` | dom 7♯9 | 0,4,7,10,15 | altered | — | dominant | NEW |
| `7#5` | dom 7♯5 | 0,4,8,10 | whole-tone/alt | — | dominant | NEW |
| `7alt` | altered dom | 0,4,10,13,15,18,20 | altered (7th mel-min) | — | dominant (resolving) | NEW |
| `7sus4` | dom 7 sus4 | 0,5,7,10 | Mixolydian | — | dominant (delayed) | NEW |
| `9sus4` | dom 9 sus4 | 0,5,7,10,14 | Mixolydian | — | dominant (delayed) | NEW |
| `dim7` | diminished 7 | 0,3,6,9 | WH-diminished (from dim7 root) | — | passing / rootless ♭9 dom | NEW |
| `m9` | minor 9 | 0,3,7,10,14 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m11` | minor 11 | 0,3,7,10,14,17 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m13` | minor 13 | 0,3,7,10,14,21 | Dorian | — | ii/iv (m7-family color) | NEW |
| `m(maj7)` | minor-major 7 | 0,3,7,11 | melodic minor | — | **tonic minor** | NEW |
| `m6/9` | minor 6/9 | 0,3,7,9,14 | Dorian/mel-min | — | **tonic minor** | NEW |

**R1 (folded):** minor Dorian qualities (`m7 m9 m11 m13 m6 m6/9`) have **no internal avoid-note** — do NOT port the major avoid-11 rule onto them (a source claimed the m13's 11 clashes with the ♭3; pitch arithmetic shows it's a consonant major 9th). `m9/m11/m13` are **color flags on the `m7`-family**: they inherit the underlying chord's function (ii/iv) and never reclassify it — only `m6 / m(maj7) / m6/9` are tonic-minor colors. `maj9`/`maj7#11` are **position-dependent** (tonic-color at `I`, pre-dominant at `IV`); `maj7#11` is also a valid **terminal** tonic-substitute. `6/9` is a distinct tonic branch (peer-reviewed, *MTO* 29.2) with a structurally-required 5th; `m6/9` stays pedagogical (T4). *(color survey §1 + R1: 17 CONFIRMED / 4 standard / 1 source-error corrected by arithmetic.)*

## 5. Rule set (generators)

The engine is a **candidate generator + ranker**, not a template player. Given the current chord `C = (degree d, quality q)` and key `K`, every generator whose `applies` matches contributes candidate next-chords tagged with a `ruleId`; §6 ranks them and caps to 3–5. **Generators fire on ANY current chord — diatonic or not.** This is the fix for the two defects the simulation caught: a non-tonic dominant must still resolve, and a multi-chord idiom must continue from its (non-diatonic) middle chord instead of being emitted as a monolithic template that strands the player.

Helpers (all degree math mod 12, tonic-relative):
- `diaQual(deg, K)` — the diatonic quality (§3 table for `K`) at a degree, or `nil` if chromatic.
- `isDominant(q)` = `q ∈ {7,9,13,7b9,7#9,7#5,7alt,7sus4,9sus4}`.
- `isMinorSeventh(q)` = `q ∈ {m7,m9,m11,m13,m7b5}` (a "ii-capable" chord).
- `isTonicHere(C)` = `d == 0` (a tonic-color quality at deg 0 still counts as the tonic — resolves the m6-vs-m7 recognition ambiguity).
- `targets(K)` — tonicizable diatonic degrees (stable triads; excludes the tonic and the dim/half-dim): major `{2,4,5,7,9}` (ii,iii,IV,V,vi); minor `{3,5,7,8,10}` (♭III,iv,V,♭VI,♭VII).

| ruleId | applies when current is… | candidates (each tagged with its ruleId) | tier |
|---|---|---|---|
| `resolve-dominant` | `isDominant(q)` | **down-a-5th** `((d+5)%12, diaQual‖maj7)`; **down-a-½** `((d+11)%12, diaQual‖maj7)`; **backdoor** if `d==10` also `(0, tonic-quality)`. §6 prefers whichever lands on a home-diatonic chord / the tonic. | T1 |
| `ii-to-V` | `isMinorSeventh(q)` | `((d+5)%12, "7")` — any minor chord treated as a ii offering its dominant (home ii→V, secondary ii→V, and the backdoor middle `Fm7→B♭7` all fall out of this) | T1 |
| `diatonic-motion` | `diaQual(d,K)!=nil` or `isTonicHere` | diatonic chords at **down-a-5th** `(d+5)`, **up-a-5th** `(d+7)`, and **step up/down** — filtered to `diatonic(K)`. Generates I→IV, I→V, IV→I, ii→V, V→I, and steps. | T1 |
| `tonic-color` | `isTonicHere(C)` | major `(0,6/9),(0,maj9),(0,maj7#11)`; minor `(0,m6),(0,m(maj7)),(0,m6/9)` | T1 |
| `dominant-upgrade` | `q == 7` | `(d,9),(d,13)` | T2 |
| `secondary-dominant` | `diaQual(d,K)!=nil` or `isTonicHere` | for each `x ∈ targets(K)`: `((x+7)%12, "7")` = V7/x — **tonicizes x (§8)** | T2 |
| `tritone-sub` | `isDominant(q)` | `((d+6)%12, "7")` — substitute dominant a tritone away; its own resolution then comes from `resolve-dominant` | T3 |
| `mode-mixture-iiø` | `d==2, q==m7` (major) | `(2, m7b5)` — borrow ♭6 | T3 |
| `dominant-alter` | `isDominant(q)` on the V (`d==7`) or any secondary dom | `(d,7b9),(d,7#9),(d,7#5),(d,7alt)` (+ the upper-structure triad in the explanation) | T3 |
| `minor-line-cliche` | `isTonicHere` (minor) | ordered chain `(0,m(maj7))→(0,m7)→(0,m6)`, routing to the 3rd of the next V | T3 |
| `dim-passing` | `diaQual(d,K)!=nil` **and** a diatonic chord sits a **whole step (2 semitones)** above `d` | `((d+1)%12, "dim7")` — the `♯x°7` (rootless secondary V7♭9 of the upper chord). The whole-step guard prevents the tonic/IV-root misfire the audit caught on half-step pairs. | T4 |
| `dim-resolve` | `q == dim7` | `((d+1)%12, diaQual‖m7)` — the passing dim resolves up a half-step, so chains continue | T4 |
| `sus-delay` | `isDominant(q)` on `d==7` | `(d,7sus4),(d,9sus4)` — delayed dominant; then resolves via `resolve-dominant` | T4 |
| `extended-color` | `isMinorSeventh` (ii/iv) or `isTonicHere`/IV (major) | ii/iv → `(d,m9),(d,m11),(d,m13)`; major tonic/IV → `(d,maj9),(d,maj7#11)` | T4 |

**Idioms emerge; they are not templates.** The backdoor (`iv m7 → ♭VII7 → I`), secondary ii–V (`ii/x → V7/x → x`), turnarounds (`I–vi–ii–V` and subs), and dim passing chains are **not** monolithic rules — a monolithic rule emits its whole chain and, in a single-step engine, strands the middle chords (the C2 defect). They **emerge** from the generalized generators firing chord-by-chord: from a borrowed `Fm7`, `ii-to-V` offers `B♭7`; from `B♭7` (deg 10), `resolve-dominant`'s backdoor branch offers `Cmaj7`. §6 recognizes a completed shape for the breadcrumb/explanation label.

**Every §4 quality is now emitted by some rule** (closing the audit's dangling-quality finding): `7#5` via `dominant-alter`; `7sus4`/`9sus4` via `sus-delay`; `dim7` via `dim-passing`; `m9/m11/m13` via `extended-color`; the rest via the diatonic/color/resolution rules.

**Provenance:** relationship-graph edges CONFIRMED (color survey §5.1, voice-leading survey). R2 confirmed every move here is **in-key** (§8: tonicization, not modulation). `extended-color` per R1 (§4 note). The generalized-resolution + emergent-idiom model is the redesign that resolves the simulation's C1/C2.

## 6. Ranking

Collect every generator's candidates; **dedup** by `(degree, quality)` keeping the highest-priority `ruleId`; score by **functional band** (below); tiebreak within a band; apply the **tier filter**; then **cap to the top 3–5**.

**Bands (highest → lowest):**
1. **Resolution onto the tonic / home-diatonic** — a `resolve-dominant` / `dim-resolve` / leading-tone move landing on a home-diatonic chord, **tonic first** (V→I, secondary-dom→its target, tritone→I, backdoor→I, vii°→i). Every dominant now has a strong, correctly-ranked resolution.
2. **ii→V** — a `ii-to-V` move (home ii first, then secondary ii→V).
3. **Descending-fifth diatonic motion** — `diatonic-motion` by down-a-fifth (I→IV, vi→ii, ii→V).
4. **Secondary dominant** — `secondary-dominant`, **capped to the 2 most idiomatic targets** (V/V, V/ii before V/vi, V/iii, V/IV). Sits *below* home diatonic motion, so it never crowds out the ii and colors — fixing the "5 equal secondary dominants / 20+ candidate" overload.
5. **Other diatonic motion** — up-a-fifth and steps (I→V, plagal IV→I, I→ii).
6. **Color / upgrade** — `tonic-color`, `dominant-upgrade`, `dominant-alter`, `extended-color`, `minor-line-cliche` start; ordered by **tonic-stability**: major `6/9 ≈ maj7#11 > maj9 > maj7`; minor `m6 ≈ m(maj7) > m6/9 > m9 > triad`; `m7` is never a tonic. *(deployment survey §A/B.)*
7. **Substitution / passing / idiom-entry** — `tritone-sub`, `dim-passing`, `sus-delay`, borrowed-iv / turnaround entry.

**Tiebreak within a band:** (a) prefer the tonic, then home-diatonic targets; (b) smaller root motion (voice-leading proximity); (c) for a dominant's competing resolutions, down-a-fifth over down-a-half-step **unless** the half-step lands on the tonic (so `D♭7→C` wins for a tritone sub, and the leading-tone pull home is rewarded).

**Tier filter (AND-gate):** surface a candidate only if BOTH its `ruleId` and its `quality` are unlocked in the current tier (§7). At T1 this means `tonic-color` effectively yields just `6/9`/`m6` (its `maj9`/`maj7#11`/`m(maj7)` candidates are quality-gated to later tiers) — expected, not a bug.

**Cap:** top **3–5** after banding + tiebreak.

`[V]` Exact numeric weights + tiebreak thresholds confirmed by the re-run progression simulation.

## 7. Tier ladder

Derived from the theory's own difficulty ordering (color survey §5.2: *plain 7ths → 9/13 → tritone-sub & ♭9 → altered/upper-structures → dim7 & Barry-Harris*). Each tier ADDS qualities + ruleIds to all prior tiers. A tier only introduces qualities it will have shapes for (Catalog dependency), but the ladder itself is theory-fixed.

| Tier | Adds qualities | Adds ruleIds | Musical idea |
|---|---|---|---|
| **T1 — Diatonic core** | `maj7 m7 7 m7b5 6 m6 6/9` | `resolve-dominant ii-to-V diatonic-motion tonic-color` | play changes: ii–V–I, I→IV→V, dominant resolutions, stable tonic colors |
| **T2 — Dominant color & secondary motion** | `9 13 maj9` | `dominant-upgrade secondary-dominant` | upgrade dominants; tonicize diatonic targets (backdoor & secondary ii–V emerge here) |
| **T3 — Alteration, subs & minor color** | `7b9 7#9 7#5 7alt m(maj7)` | `tritone-sub mode-mixture-iiø dominant-alter minor-line-cliche` | alter the dominant; tritone sub; minor-borrowing & the minor-line cliché |
| **T4 — Extended & passing** | `maj7#11 m9 m11 m13 m6/9 dim7 7sus4 9sus4` | `dim-passing dim-resolve sus-delay extended-color` | whole-step passing dim7, extended colors, sus delay |

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
| `ii-to-V` | "sets up the V" | "ii→V is the core jazz motion; the 7th of ii falls a half-step to the 3rd of V." |
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
