# Jazz Deployment Patterns — Minor-Line Cliché, Backdoor, dim7 Chains, Secondary ii–V's, Turnaround Subs (Round 4)

**Date:** 2026-07-13
**Method:** targeted WebSearch/WebFetch verification (not the full deep-research harness) —
each of the 5 patterns cross-checked against **2–3 independent sources**, plus **direct
pitch/interval arithmetic** performed by hand for every chord spelling and every claimed
enharmonic/rootless identity. This closes the verification gap explicitly left open by
`2026-07-10-jazz-color-chords-deployment-survey.md` §D, which named these five patterns but
had its adversarial vote pass cut off by a spend limit.
**Anchor sources:** Wikipedia (*Backdoor progression*, *Rhythm changes*, *Secondary chord*),
learnjazzstandards.com, jazzguitar.be, jazz-library.com, iujazztheory (Indiana University
jazz-theory course notes), thejazzpianosite.com, antonjazz.com (Anton Schwartz), djangobooks.com.
**Fourth in the series** — see `2026-07-09-jazz-guitar-voice-leading-survey.md` (foundations),
`2026-07-09-jazz-color-chords-survey.md` (color-chord theory), and
`2026-07-10-jazz-color-chords-deployment-survey.md` (extended colors + the open gap this
round closes).

---

## 1. Minor-line cliché: `i → i(maj7) → i7 → i6`

**Chords (key of D minor, i = Dm):** Dm → Dm(maj7) → Dm7 → Dm6, i.e. **root → maj7 → ♭7 → 6**
held over a static tonic-minor root while the 5th (A) and ♭3rd (F) stay fixed.
*(djangobooks.com, thejazzpianosite.com/line-cliches — confirmed 2-0.)*

- **The line, verified by arithmetic:** the moving voice descends **D → C♯ → C → B** —
  root, major 7th, minor 7th, major 6th of D minor — a fully chromatic descending tetrachord
  (each step a half-step: C♯→C, C→B). This matches djangobooks.com's own worked example in D
  minor verbatim. *(CONFIRMED — 2 sources + arithmetic.)*
- **Terminology:** this is a specific case of a **line cliché**, also called **CESH**
  (chromatic embellishment of a static harmony) — a contrapuntal decoration that doesn't
  change the underlying function, only the color, while the chord stays "home." *(djangobooks.com
  — CONFIRMED.)*
- **Where it applies:** on a **static tonic-minor chord** (i, not ii) — famous as the
  recurring **"My Funny Valentine" progression** (Cm–Cm(maj7)–Cm7–Cm6 in that tune's actual
  key of C minor; the user-facing D-minor spelling above is the generic textbook illustration,
  not literally the MFV key). *(learnjazzstandards/jazzguitar.be forum threads, multiple
  chord-chart sources for "My Funny Valentine" — CONFIRMED the song uses this exact
  Cm-Cm(maj7)-Cm7-Cm6 cell; STANDARD-UNVERIFIED that "the My Funny Valentine progression" is
  a universally-used name for the *general* pattern outside that tune.)*
- **Routing into the following V — the rootless identity (verified by arithmetic):**
  **i6 is enharmonically a rootless V9 of the relative-major dominant.** Take Dm6 (D-F-A-B).
  G9 = G-B-D-F-A; remove the root G → B-D-F-A = **exactly Dm6, respelled**. So the last chord
  of the cliché already *contains* the upcoming dominant as an upper structure — resolving to
  "G9/B" (bass moves D-then-implicit → B, or simply the root G drops in under the held
  upper notes) is the smallest possible move, not a leap. This is explicitly corroborated by
  thejazzpianosite.com's line-cliché page, which lists the same cliché voiced as **"Dmin6 or
  G9"** and notes it "can also function as a ii–V against some flavor of C chord."
  *(CONFIRMED — 1 direct source stating the identity, matches independent arithmetic.)*
- **Key effect:** **no key change** — it is a color/voice-leading decoration of a single
  static tonic-minor chord; the "routing" is a pivot into the **V7 of the relative major** (or
  of wherever the tonic minor functions as vi/ii in the surrounding tune), not a modulation of
  the cliché itself.

## 2. Backdoor ii–V: `ivm7 → ♭VII7 → Imaj7`

**Chords (key of C):** Fm7 → B♭7 → Cmaj7 — **iv (minor iv, borrowed) → ♭VII7 (borrowed
dominant) → I**. *(Wikipedia "Backdoor progression," learnjazzstandards.com, antonjazz.com —
confirmed 3-0; named for jazz theorist Jerry Coker per Wikipedia.)*

- **Derivation — borrowed from the parallel minor:** both Fm7 and B♭7 are diatonic to **C
  minor** (Fm7 = iv7 of Cm, B♭7 = ♭VII7 of Cm — literally V7/♭III of the major key, i.e. the
  dominant of C minor's relative major E♭, reinterpreted). *(Wikipedia, learnjazzstandards —
  CONFIRMED.)*
- **Why ♭VII7 resolves convincingly to I (three corroborating explanations, all present
  across sources):**
  1. **Shared diminished-scale material:** B♭7, G7, and D7 all voice against the same
     B-diminished (whole-half) scale when extended with 9/13 — i.e. B♭7 sits in the same
     octatonic collection as the "expected" V7 (G7). *(antonjazz.com — CONFIRMED.)*
  2. **Relative-minor substitution:** Fm7 functions like **Dø7** (the real minor-key ii),
     because Fm7 is Dø7's relative-minor-flavored stand-in — both precede a dominant that
     targets C. *(antonjazz.com — STANDARD-UNVERIFIED, a looser analogy than #1/#3.)*
  3. **Tritone-sub-of-the-relative-minor:** Fm7-B♭7 is the *normal* resolution into **Am**
     (Fm7-B♭7-Am reads as iv-♭VII-i in A minor's relative context); since that cadence already
     works into C minor's relative major (A minor → C major share signature), the same
     Fm7-B♭7 duo resolves equally well directly to **C major**. *(antonjazz.com — CONFIRMED
     by the source's own worked reasoning; independently checkable: B♭7 is the tritone sub of
     E7 (V7/Am), and Fm7/B♭7 do function as a minor-key iv-♭VII cadence into Am.)*
- **Voice leading (verified by arithmetic):** B♭7 (B♭-D-F-A♭) → Cmaj7 (C-E-G-B) — the ♭7
  (A♭) resolves down a half-step to the 5th of C (G is NOT a half-step from A♭... the
  standard cited motion is **♭7th of ♭VII7 (A♭) → 5th of I (G)**, a half-step down, and the
  **5th of ♭VII7 (F) → 3rd of I (E)**, also a half-step down) — both guide-tone-adjacent
  voices resolve chromatically downward into I. *(learnjazzstandards.com — CONFIRMED, matches
  arithmetic.)*
- **Key effect:** **no permanent key change** — ♭VII7 is a borrowed (modal-mixture) dominant
  substituting for V7 in the same key; it's an alternate cadential route to the *same* I,
  not a tonicization of a different chord.

## 3. dim7 passing chains

**Chords (key of C, generalized template):** `I → ♯i°7 → ii`, `ii → ♯ii°7 → iii`,
`IV → ♯IV°7 → V` — a chromatic passing diminished 7th inserted between two diatonic chords a
whole step apart, filling the gap with a half-step-half-step bass motion.
*(iujazztheory.weebly.com, jazzguitar.be — confirmed 2-0; worked examples: "Have You Met Miss
Jones" uses F-F♯°7-Gm (I-♯i°7-ii in F); "Once I Loved" uses Gm-G♯°7-Am (ii-♯ii°7-iii in F).)*

- **The identity that justifies every one of these (verified by arithmetic): a dim7 chord is
  a rootless dominant-7♭9 built a major 3rd below the dim7's stated root.** Removing the root
  from any dom7♭9 leaves a dim7:
  - **C♯°7** (C♯-E-G-B♭) = **A7♭9** (A-C♯-E-G-B♭) with the A removed → in key C, ♯I°7 is a
    rootless **V7/ii** (A7, the dominant of ii = Dm). *(Verified: A7♭9 minus root A = C♯-E-G-B♭
    = C♯°7. Matches iujazztheory's parallel example in F: F♯°7 = D7♭9 minus root, and D7 is
    V7/ii of F (ii = Gm).)*
  - **G♯°7** (G♯-B-D-F) = **E7♭9** (E-G♯-B-D-F) minus root → in key C, ♯ii°7 is a rootless
    **V7/iii** (E7, dominant of iii = Em). *(Verified by same subtraction; matches
    iujazztheory's F-key example: G♯°7 = E7♭9 minus root, E7 = V7/iii of F (iii = Am).)*
  - **F♯°7** (F♯-A-C-E♭) = **D7♭9** (D-F♯-A-C-E♭) minus root → in key C, ♯IV°7 is a rootless
    **V7/V** (D7, dominant of V = G). *(Verified directly.)*
  *(jazzguitar.be states the general identity explicitly for the ♯I°7 case ["a Bdim7 chord has
  the same notes as the 3rd, 5th, ♭7th, and ♭9th of a G7♭9 chord"]; the ii/iii/V extensions
  above are this survey's own arithmetic extrapolation of the identical pattern — CONFIRMED by
  arithmetic, STANDARD-UNVERIFIED as an explicitly-stated triple in any single source.)*
- **Net effect:** every passing dim7 in this family is functionally **a secondary dominant
  with its root omitted**, which is *why* it works as a smooth chromatic connector — it's not
  an ad hoc chromatic chord, it's an elided V7/x resolving normally to x.
- **Key effect:** **no key change** — purely a passing/embellishing chord between two
  diatonic degrees in the same key; it borrows a secondary-dominant *function* momentarily
  but does not tonicize.

## 4. Secondary-dominant ii's / secondary ii–V

**General mechanism (key of C major, confirmed 3+ sources — Wikipedia "Secondary chord,"
learnjazzstandards.com, thejazzpianosite.com, medium.com/Jared-Forth):** any diatonic chord
other than V can be preceded by **its own ii–V**, i.e. a secondary dominant plus that
dominant's related ii-7, borrowed from the *target's* own key. This is **tonicization, not
modulation** — "brief[ly making] a chord that is not the tonic... sound like the tonic,"
explicitly distinguished from a real, extended key change. *(CONFIRMED — 3 sources agree
verbatim on this distinction.)*

**Exact secondary ii–V pairs in C major (derived and verified by interval arithmetic — the
secondary V7/x is the dominant 7th a 5th above x; the secondary ii-7/x is a minor(/half-dim)
7th a 5th above that):**

| Target (x) | Secondary ii of x | Secondary V7/x | Resolves to |
|---|---|---|---|
| **ii** (Dm) | Em7(♭5) or Em7 | **A7** (V7/ii) | Dm7 |
| **iii** (Em) | F♯m7(♭5) | **B7** (V7/iii) | Em7 |
| **IV** (Fmaj) | Gm7 | **C7** (V7/IV) | Fmaj7 |
| **V** (G) | Am7 | **D7** (V7/V) | G7 |
| **vi** (Am) | Bm7(♭5) | **E7** (V7/vi) | Am7 |

*(CONFIRMED by arithmetic: each V7/x root is a perfect 5th above x's root — A above D, B above
E, C above F, D above G, E above A. The secondary-ii-of-a-minor-target is conventionally
half-diminished, matching the minor-ii–V convention from the color-chords survey (§2,
half-diminished = ii of a minor ii–V–i); the secondary-ii-of-IV, being a major-quality target,
is a plain m7.)* **CONFIRMED as concept + individual chord spellings** (Wikipedia/
learnjazzstandards/thejazzpianosite state the general rule and at least the V7/ii=A7,
V7/V=D7, V7/vi=E7 spellings explicitly); **STANDARD-UNVERIFIED** that any single source lays
out the complete 5-row table above as one unit — it is assembled here from the general rule
plus arithmetic, matching the "Rhythm changes" ii-V-chain variant below.

- **A concrete, independently-sourced instance of the same mechanism:** the **Rhythm-changes
  bridge** (III7-VI7-II7-V7, i.e. **D7-G7-C7-F7** in B♭, each chord the V7 of the next) is
  commonly played with **a ii-7 inserted before each dominant** — **Am7-D7 / Dm7-G7 / Gm7-C7 /
  Cm7-F7** — turning a pure dominant chain into a chain of secondary ii-V's.
  *(peterspitzer.blogspot.com "chain of dominants," Wikipedia "Rhythm changes" — CONFIRMED 2-0;
  matches the ii-of-V and ii-of-IV rows in the table above exactly: Am7-D7 = ii-V/V-ish chain
  member, Gm7-C7 = secondary ii-V/IV.)*
- **Key effect:** **no true modulation** — every source explicitly frames this as
  tonicization. The tune's key signature and overall tonal center do not change; only the
  *local* pull toward the target chord is strengthened for 1-2 bars.

## 5. Turnaround substitutions

**Base form (key of C, fully diatonic — confirmed, jazz-library.com, learnjazzstandards.com):**
**I – vi – ii – V** = Cmaj7 – Am7 – Dm7 – G7. "No borrowed chords or substitutions" in the
plain form. *(CONFIRMED.)*

- **`I → I–VI7–ii–V`** (secondary dominant on vi): Cmaj7 – **A7** – Dm7 – G7. A7 is **V7/ii**
  (see §4 table) substituting for the diatonic Am7; the added leading tone **C♯** in A7 pulls
  by half-step into **D**, the root of the following ii, strengthening the resolution.
  *(learnjazzstandards.com — CONFIRMED; matches §4's V7/ii = A7 exactly.)*
- **`iii–VI7–ii–V`**: Em7 – A7 – Dm7 – G7. Diatonic **iii substitutes for I** (both share
  {E,G,B}, both tonic-function), while **vi becomes its secondary dominant A7** as above.
  Common in "countless tunes, including Rhythm changes," and cited as a favorite move of
  Wes Montgomery/Joe Pass/Barney Kessel-lineage turnarounds. *(learnjazzstandards.com,
  guitarworld.com — confirmed 2-0.)*
- **`I–♭III7–♭VI7–♭II7`** (tritone-sub turnaround): Cmaj7 – **E♭7** – **A♭7** – **D♭7**.
  Verified by arithmetic as the **tritone substitute of each dominant in the all-dominant
  turnaround I-VI7-II7-V7** (Cmaj7-A7-D7-G7): E♭7 is a tritone from A7 (E♭ and A are 6
  semitones apart) substituting for A7 (=V7/ii); A♭7 is a tritone from D7 substituting for D7
  (=V7/V); D♭7 is a tritone from G7 substituting for G7 (=V). Each substitute keeps the same
  guide tones (3rd/7th swap roles) as the chord it replaces, and the roots now fall
  chromatically: C-E♭-A♭-D♭-(C). *(jazz-library.com explicitly lists "I ♭III7 ♭VI7 ♭II7 I" as
  a named turnaround alongside "I VI7 II7 ♭II7 I" and "I ♭III7 II7 ♭II7 I" — CONFIRMED, and
  the tritone-sub derivation is independently verifiable by pitch-class arithmetic.)*
- **The "Ladybird" / Montgomery-style variant (all-major-7th, no dominants):**
  Cmaj7 – E♭maj7 – A♭maj7 – D♭maj7 — the **same ♭III/♭VI/♭II root skeleton as above, but every
  chord voiced as maj7 instead of dominant 7**, from Tadd Dameron's "Lady Bird" (1939), a
  favorite Wes Montgomery turnaround. Explained as **iii substituting for I** (Em7-ish reading
  shifted a third down) **combined with parallel tritone-substitute roots** — Eb subs for Am
  (vi), Ab subs for Dm (ii), Db subs for G7 (V) — but voiced with major-7th quality throughout
  for a smoother, non-dominant color. *(guitarworld.com, jazzguitar.be Wes Montgomery article —
  confirmed 2-0.)*
- **Key effect on all of the above:** every substitution is a **turnaround inside the same
  key** — none of them modulate; they only vary *how* the ii–V–I (or vi–ii–V–I) cadential
  motion back to I is colored and voice-led. The tritone subs specifically trade "resolve by
  falling 5th" for "resolve by falling half-step," which is the whole appeal.

---

## What this gives the engine

Each pattern is a **suggestion-graph edge or rule**, explicitly tagged with its key-shift
behavior so the engine never over- or under-claims a modulation:

1. **Minor-line cliché** — `i → i(maj7) → i7 → i6` is a **static-tonic decoration edge** (no
   key change) with a built-in **pivot rule**: `i6 ≡ rootless V9(relative)` — when the engine
   sees a held tonic-minor chord, it can offer the cliché as a "make this more interesting"
   suggestion, then auto-suggest the relative-major V7 as the natural exit because it's
   already implied by the last cliché voicing.
2. **Backdoor ii–V** — `ivm7 → ♭VII7 → I` is a **modal-mixture cadence edge**, an alternate
   route to the *same* I as the plain V7-I edge — offer it as a "smoother bass line to the
   same destination" swap, not a new destination.
3. **dim7 passing chains** — `X → ♯x°7 → Y` (Y a step above X) is a **connector edge**
   generated mechanically from the `dim7 ≡ rootless secondary-V7♭9` identity: for *any*
   diatonic X→Y a whole step apart, the engine can compute the passing dim7 as "the secondary
   dominant of Y with its root removed," rather than hand-storing each case.
4. **Secondary ii–V** — a **parameterized tonicization edge**: `ii(x)–V(x) → x` for
   `x ∈ {ii,iii,IV,V,vi}`, each pair computable directly from x's root (5th-above for V7/x,
   another 5th-above for the secondary ii) — explicitly flagged as **non-modulating** so the
   engine's key-tracking state doesn't flip.
5. **Turnaround substitutions** — a **substitution family on one skeleton** (I–vi–ii–V):
   swap vi→VI7 (secondary dom.), swap I→iii (tonic-function swap), swap any/all dominants for
   their tritone subs (♭III7/♭VI7/♭II7), or flatten the whole thing to parallel maj7's
   (Ladybird). All stay in-key — a great "give me 5 ways to play the same 2 bars" feature.

## Caveats

- This round used **targeted search+arithmetic verification**, not the full multi-agent deep-
  research harness with independent voting — treat corroboration counts (2-3 sources) as
  solid but lighter-weight than the "3-0 adversarial vote" standard in the round-1/2 surveys.
- **No claim here rests on arithmetic alone without at least one textual source**, except the
  §3 extension of the ♯i°7 identity to ♯ii°7/♯IV°7 and the §4 full 5-row secondary-ii table,
  both flagged **STANDARD-UNVERIFIED** inline — they follow the *identical, source-confirmed*
  pattern applied to adjacent scale degrees, verified independently by this survey's own pitch
  arithmetic, but no single source spells out the complete set.
- **Mark Levine's *Jazz Theory Book*** (the anchor for rounds 1-2) was searched for direct
  chapter coverage of backdoor/dim7-chain material and **not found in accessible excerpts** —
  this round's anchors are Wikipedia + reputable teaching sites + one university course-notes
  page (iujazztheory), not the primary text. Flagged as a sourcing gap, matching round 1's own
  admission that named pedagogies are often only secondhand-referenced.
- The "My Funny Valentine progression" naming convention for the *generic* minor-line cliché
  (vs. its specific use inside that one tune) is **STANDARD-UNVERIFIED** as a term of art —
  the cliché itself and its use in that song are both confirmed independently.
- Theory is stable — no staleness risk.

## Sources
- Wikipedia — *Backdoor progression*: en.wikipedia.org/wiki/Backdoor_progression
- Wikipedia — *Rhythm changes*: en.wikipedia.org/wiki/Rhythm_changes
- Wikipedia — *Secondary chord*: en.wikipedia.org/wiki/Secondary_chord
- learnjazzstandards.com — /blog/learning-jazz/jazz-theory/backdoor-progression/,
  /blog/jazz-turnarounds/, /blog/secondary-dominants/
- jazzguitar.be — /blog/diminished-chords/, Wes Montgomery licks/chord-solo articles, forum
  threads on the minor cliché and backdoor bVII7
- jazz-library.com — /articles/chord-progressions/ (turnaround + tritone-sub enumerations)
- iujazztheory.weebly.com — /passing-diminished-chords.html, /back-door-progression.html
- thejazzpianosite.com — /jazz-piano-lessons/jazz-chord-progressions/line-cliches/,
  /jazz-piano-lessons/jazz-chords/secondary-chords/
- antonjazz.com — Anton Schwartz, "The Backdoor ii-V Progression" (2012)
- djangobooks.com — "Lesson #6: Minor Line Cliché"
- medium.com — Jared Forth, "Secondary Dominant Chords, Tonicization, and Related II-7"
- guitarworld.com — "The chord secrets of Joe Pass, Barney Kessel and Wes Montgomery"
  (Ladybird turnaround)
- peterspitzer.blogspot.com — "The Chain of Dominants Progression" (Rhythm changes bridge)
- All chord spellings independently verified by this survey via pitch/interval arithmetic.
