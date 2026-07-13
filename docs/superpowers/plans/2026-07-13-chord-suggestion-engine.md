# Chord Suggestion Engine (pure domain) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Encode the validated theory spec as a pure, tested Swift suggestion engine: given a current chord + key + tier, return ranked functionally-justified next chords with rule ids + explanations, plus tier progress. No voicings, no UI — grip-independent.

**Architecture:** Pure domain layer. `DiatonicModel` + `EngineQuality` catalog fuel a set of generators (§5) whose candidates a `SuggestionRanker` (§6) bands + caps; `SuggestionEngine.suggest` orchestrates them with tier filtering (§7) and tonicization context (§8). `TierProgress` handles the time-to-play unlock. `ChordSpelling` gives key-correct enharmonics (§9). `Explanations` (§10) supplies the why.

**Tech Stack:** Swift, Swift Testing (`import Testing`), Xcode project `audio_listen.xcodeproj`.

## Source of truth

The committed spec `docs/superpowers/specs/2026-07-13-chord-theory-engine-spec.md` holds the exact diatonic tables (§3), quality catalog + formulas (§4), generator algorithms (§5), ranking bands (§6), tier ladder (§7), key-shift semantics (§8), spelling (§9), explanations (§10). Each task below names its spec section — **implementers read that section for the exact values**; the plan gives the Swift interfaces and the test cases. This deliberately avoids duplicating the spec's tables inline (drift risk); it is the one allowed deviation from "inline all code," because the spec is the validated single source of truth.

## Global Constraints

- **Swift Testing** (`import Testing`, `@Test`, `#expect`) — never XCTest. Plain `struct` suites.
- Build/test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/<Suite>`.
- New `.swift` files auto-include (file-system-synchronized group) — never edit `project.pbxproj`. SourceKit standalone "cannot find type" diagnostics are cross-file indexer noise — xcodebuild is truth.
- **No comments** (self-documenting). Pure functions; value types (`struct`/`enum`) throughout; no I/O, no UI, no Combine.
- **Engine owns its quality metadata** — do NOT add shapeless qualities to `ChordQualities.all` (`ChordProgressionView` force-unwraps `Voicings.voicing(...)!`). Reference qualities by `qualityId: String`.
- Degree = semitone offset from tonic (0–11), matching `ChordNaming.rootName(tonic:degree:)`. `NoteName` is `Int` rawValue 0–11, `CaseIterable`.
- Stage files explicitly by path (never `git add -A`); never stage `Instruments.swift` (WIP) or `research/…`. Commit trailer:
  ```
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01TS94Hd87Vhi31WNLumLnKS
  ```

## File Structure (all new, under `audio_listen/Domain/`)
- `Models/Key.swift` — `Mode`, `Key`, `ChordSymbol`.
- `Models/EngineQuality.swift` — engine quality metadata + catalog.
- `Models/Tier.swift` — tier catalog (qualities + ruleIds per tier).
- `Models/ChordSuggestion.swift` — `ChordSuggestion`, `SuggestionRuleId`, `SuggestionContext`.
- `UseCases/DiatonicModel.swift` — diatonic tables + helpers.
- `UseCases/ChordSpelling.swift` — enharmonic speller.
- `UseCases/SuggestionGenerators.swift` — the §5 generators.
- `UseCases/SuggestionRanker.swift` — §6 banding + cap.
- `UseCases/SuggestionEngine.swift` — orchestration + tier filter + §8 context.
- `UseCases/TierProgress.swift` — time-to-play unlock.
- `UseCases/Explanations.swift` — ruleId → {short, long}.
- Tests mirror in `audio_listenTests/`.

---

### Task 1: Key, ChordSymbol, DiatonicModel (§2, §3)

**Files:** Create `Domain/Models/Key.swift`, `Domain/UseCases/DiatonicModel.swift`; Test `audio_listenTests/DiatonicModelTests.swift`.

**Interfaces (Produces):**
```swift
enum Mode: Hashable { case major, minor }
struct Key: Hashable { let tonic: NoteName; let mode: Mode }
struct ChordSymbol: Hashable { let degree: Int; let qualityId: String }  // degree 0..11 tonic-relative

enum DiatonicModel {
    static func diatonic(_ key: Key) -> [ChordSymbol]                    // §3.1/§3.2 tables
    static func diaQual(_ degree: Int, _ key: Key) -> String?            // diatonic quality or nil
    static func isDiatonic(_ c: ChordSymbol, _ key: Key) -> Bool         // diaQual(d)==quality
    static func isTonicHere(_ c: ChordSymbol) -> Bool                    // degree==0
    static func targets(_ key: Key) -> [Int]                            // tonicizable degrees
    static func resolutionQualityAt(_ degree: Int, _ key: Key) -> String // tonic gets its color
}
```

- [ ] **Step 1 — failing tests** (`DiatonicModelTests`), asserting the spec §3 tables exactly:
  - major C: `diatonic(C major)` degrees→qualities == `[(0,maj7),(2,m7),(4,m7),(5,maj7),(7,7),(9,m7),(11,m7b5)]`.
  - minor A: degrees→qualities == `[(0,m7),(2,m7b5),(3,maj7),(5,m7),(7,7),(8,maj7),(10,7),(11,dim7)]`.
  - `isDiatonic((2,m7), C major)==true`, `isDiatonic((2,"7"), C major)==false`.
  - `targets(C major)==[2,4,5,7,9]`; `targets(A minor as degrees)==[3,5,7,8,10]`.
  - `resolutionQualityAt(0, C major)=="maj7"`; `resolutionQualityAt(0, A minor)=="m6"`; `resolutionQualityAt(7, C major)=="7"`.
- [ ] **Step 2** — run, verify FAIL. **Step 3** — implement per spec §2/§3. **Step 4** — run, PASS. **Step 5** — commit (`feat: Key/ChordSymbol/DiatonicModel`).

**Note for implementer:** degrees are tonic-relative; `diatonic()` returns tonic-relative degrees (not absolute pitch classes). The minor table's V is `7` (borrowed), `♭VII` is `7`, `vii°` is `dim7` — copy §3.2 exactly.

---

### Task 2: EngineQuality catalog (§4)

**Files:** Create `Domain/Models/EngineQuality.swift`; Test `EngineQualityTests.swift`.

**Interfaces:**
```swift
enum ChordFunction: Hashable { case tonic, subdominant, dominant }
struct EngineQuality: Hashable {
    let id: String            // qualityId, matches ChordQuality.id where they overlap
    let formula: [Int]        // semitones from root (may exceed 12)
    let isDominant: Bool
    let isMinorSeventh: Bool  // "ii-capable": m7,m9,m11,m13,m7b5
    let function: ChordFunction
}
enum EngineQualities {
    static let all: [EngineQuality]                 // the §4 table (23 qualities)
    static func byId(_ id: String) -> EngineQuality?
    static func isDominant(_ id: String) -> Bool
    static func isMinorSeventh(_ id: String) -> Bool
}
```

- [ ] **Step 1 — failing tests:** all 23 §4 qualityIds present; spot-check formulas (`7alt==[0,4,10,13,15,18,20]`, `maj7#11==[0,4,7,11,18]`, `6/9==[0,4,7,9,14]`, `dim7==[0,3,6,9]`); `isDominant("7")&&isDominant("7alt")&&isDominant("9sus4")`, `!isDominant("m7")`; `isMinorSeventh("m7")&&isMinorSeventh("m7b5")&&isMinorSeventh("m9")`, `!isMinorSeventh("m6")`; **cross-check**: for each id also present in `ChordQualities.all`, the formula's pitch-classes (mod 12, deduped) match `ChordQualities.byId(id)!.formula` mod 12.
- [ ] Steps 2–5 as Task 1 (implement per §4; commit `feat: EngineQuality catalog`).

---

### Task 3: ChordSpelling — enharmonics (§9)

**Files:** Create `Domain/UseCases/ChordSpelling.swift`; Test `ChordSpellingTests.swift`.

**Interfaces:**
```swift
enum ChordSpelling {
    static func spell(degree: Int, key: Key, role: SpellingRole) -> String  // letter+accidental
}
enum SpellingRole: Hashable { case diatonic, secondaryDominant, flatSubstitution, ascendingPassing }
```
- [ ] **Step 1 — failing tests** (§9): in C major — diatonic degree 2 → "D"; `♭II`(1, flatSubstitution) → "D♭"; `♭VII`(10, flat) → "B♭"; `V/ii`(9, secondaryDominant) → "A"; ascending passing `♯i`(1, ascendingPassing) → "C♯". In A major — diatonic 11 → "G♯". Confirm the speller is key-signature-aware (each diatonic letter used once).
- [ ] Steps 2–5 (implement §9; commit `feat: ChordSpelling enharmonics`).

---

### Task 4: Tier catalog + suggestion types (§7, §2)

**Files:** Create `Domain/Models/Tier.swift`, `Domain/Models/ChordSuggestion.swift`; Test `TierTests.swift`.

**Interfaces:**
```swift
enum SuggestionRuleId: String, CaseIterable {
    case resolveDominant, iiToV, diatonicMotion, tonicColor, dominantUpgrade,
         secondaryDominant, tritoneSub, modeMixtureIiø, modeMixtureIv, dominantAlter,
         minorLineCliche, dimPassing, dimResolve, susDelay, extendedColor
}
struct Tier: Hashable { let level: Int; let qualityIds: Set<String>; let ruleIds: Set<SuggestionRuleId> }
enum Tiers {
    static let all: [Tier]                              // T1..T4 per §7, CUMULATIVE
    static func unlocked(atLevel: Int) -> Tier          // union of tiers 1..level
    static func isUnlocked(qualityId: String, ruleId: SuggestionRuleId, level: Int) -> Bool  // AND-gate
}
struct SuggestionContext: Hashable { let key: Key; let tierLevel: Int; let pendingTonic: Int? }
struct ChordSuggestion: Hashable { let chord: ChordSymbol; let ruleId: SuggestionRuleId; let keyShiftTonicize: Int? }
```
- [ ] **Step 1 — failing tests** (§7): T1 ruleIds == `{resolveDominant, iiToV, diatonicMotion, tonicColor}`; T1 qualities == `{maj7,m7,7,m7b5,6,m6,6/9}`; `unlocked(atLevel:2)` includes T1+T2; `isUnlocked("9", .secondaryDominant, level:2)==true`, `isUnlocked("dim7", .dimPassing, level:2)==false`, `isUnlocked("7", .tritoneSub, level:2)==false` (tritoneSub is T3). Verify every §4 quality and every ruleId appears in exactly the tier §7 assigns.
- [ ] Steps 2–5 (implement §7; commit `feat: Tier catalog + suggestion types`).

---

### Task 5: Generators (§5)

**Files:** Create `Domain/UseCases/SuggestionGenerators.swift`; Test `SuggestionGeneratorsTests.swift`.

**Interfaces:**
```swift
enum SuggestionGenerators {
    // Each generator: (current: ChordSymbol, key: Key) -> [ChordSuggestion]. Fire on ANY current chord.
    static func all(current: ChordSymbol, key: Key) -> [ChordSuggestion]   // union of every generator, pre-rank, pre-tier-filter
}
```
Implement each §5 generator (`resolve-dominant`, `ii-to-V`, `diatonic-motion`, `tonic-color`, `dominant-upgrade`, `secondary-dominant`, `tritone-sub`, `mode-mixture-iiø`, `mode-mixture-iv`, `dominant-alter`, `minor-line-cliche`, `dim-passing`, `dim-resolve`, `sus-delay`, `extended-color`) exactly per the §5 table (applies + candidates), using `DiatonicModel`/`EngineQualities` helpers.

- [ ] **Step 1 — failing tests**, one per generator, asserting the validated behaviors:
  - `resolve-dominant` on `(7,"7")` C major → contains `(0,"maj7")` (down-5th, tonic color); on `(9,"7")` (A7) → contains `(2,"m7")` (Dm7); on `(1,"7")` (D♭7) → contains `(0,"maj7")` (down-½ to tonic); on `(10,"7")` → contains `(0,"maj7")` (backdoor). Down-½ to a non-diatonic degree is NOT emitted (e.g. `(2,"7")` D7 → no D♭maj7).
  - `ii-to-V` on `(2,"m7")` → `(7,"7")`; on `(2,"m7b5")` → `(7,"7b9")`; on `(0,"m7")` (tonic) → **empty** (isTonicHere excluded).
  - `diatonic-motion` on `(0,"maj7")` C major → contains `(5,"maj7")`(IV), `(7,"7")`(V); on `(2,"7")` (chromatic on diatonic degree) → **empty** (isDiatonic gate).
  - `secondary-dominant` on `(0,…)` C major → V7 of each target incl `(9,"7")`(V/ii),`(2,"7")`(V/V); on `(9,"7")` → **empty** (not diatonic).
  - `mode-mixture-iv` on C-major tonic → `(5,"m7")`; `tritone-sub` on `(7,"7")` → `(1,"7")`; `dim-passing` on `(0,…)` (ii is a whole step up) → `(1,"dim7")`, on `(4,"m7")` (iii, IV a half step up) → **empty**; `dim-resolve` on `(1,"dim7")` → `(2,"m7")`; `minor-line-cliche` on `(0,"m6")` A minor → `(0,"m(maj7)")`, on `(0,"m(maj7)")` → `(0,"m7")`.
- [ ] Steps 2–5 (implement §5; commit `feat: suggestion generators`).

---

### Task 6: SuggestionRanker (§6)

**Files:** Create `Domain/UseCases/SuggestionRanker.swift`; Test `SuggestionRankerTests.swift`.

**Interfaces:**
```swift
enum SuggestionRanker {
    static func rank(_ candidates: [ChordSuggestion], current: ChordSymbol, key: Key) -> [ChordSuggestion]  // dedup, band, tiebreak, cap 5
}
```
- [ ] **Step 1 — failing tests** (§6 bands): given a mixed candidate pool, a band-1 resolution-to-tonic outranks a band-4 secondary dominant outranks a band-6 color; secondary dominants capped to 2; dedup keeps highest-priority ruleId; tiebreak (c): for D♭7 both down-5th (G♭maj7) and down-½ (Cmaj7) present → Cmaj7 (tonic) ranks first; output length ≤ 5.
- [ ] Steps 2–5 (implement §6; commit `feat: suggestion ranker`).

---

### Task 7: SuggestionEngine + validated scenarios (§5–§8)

**Files:** Create `Domain/UseCases/SuggestionEngine.swift`; Test `SuggestionEngineTests.swift`.

**Interfaces:**
```swift
enum SuggestionEngine {
    static func suggest(current: ChordSymbol, context: SuggestionContext) -> [ChordSuggestion]  // generators -> rank -> AND-gate tier filter -> top 3..5
    static func applyKeyShift(context: SuggestionContext, played: ChordSymbol) -> SuggestionContext // §8 tonicization/resolve
}
```
- [ ] **Step 1 — failing tests encoding the VALIDATED simulations** (`.superpowers/theory/validation-simulation-2.md`):
  - **No dead-ends (C1):** C major T2, from `(2,"7")` (D7) → suggestions contain `(7,"7")` (G7 resolution). From `(9,"7")` (A7) → contains `(2,"m7")` (Dm7).
  - **Idiom continues (C2):** from `(5,"m7")` (Fm7) → contains `(10,"7")` (B♭7); from `(10,"7")` → contains `(0,"maj7")` (backdoor). From `(1,"dim7")` → contains `(2,"m7")`.
  - **Backdoor entry:** C major T4 tonic → suggestions contain `(5,"m7")` (Fm7) via mode-mixture-iv.
  - **Minor cadence:** A minor, from `(7,"7b9")` (E7♭9) → contains `(0,"m6")` (tonic color, not m7).
  - **Tier gating:** C major T1 from tonic → no secondary dominants (secondaryDominant is T2); output length 3..5.
  - **Key-shift (§8):** `applyKeyShift` after suggesting V7/ii sets `pendingTonic=2`; playing `(2,"m7")` clears it and keeps the home key (no modulation).
- [ ] Steps 2–5 (implement §5→§6→§7 orchestration + §8; commit `feat: SuggestionEngine`).

---

### Task 8: TierProgress — time-to-play unlock (§7)

**Files:** Create `Domain/UseCases/TierProgress.swift`; Test `TierProgressTests.swift`.

**Interfaces:**
```swift
struct TierProgress: Hashable {
    private(set) var level: Int
    static let targetTimePerChord: TimeInterval  // 1.5
    static let sustainWindowSeconds: TimeInterval // 600
    mutating func record(timeToPlay: TimeInterval, at now: TimeInterval)  // rolling window
    var rollingAverage: TimeInterval? { get }
    // unlocks next level when rolling average over the window clears the target
}
```
- [ ] **Step 1 — failing tests:** a run of fast times (< target) across the window advances `level`; slow times do not; the rolling window drops samples older than `sustainWindowSeconds`; below-threshold average never unlocks. Use an injected `now` (TimeInterval) — no wall-clock (`Date()`).
- [ ] Steps 2–5 (implement §7 metric; commit `feat: TierProgress unlock`).

---

### Task 9: Explanations (§10)

**Files:** Create `Domain/UseCases/Explanations.swift`; Test `ExplanationsTests.swift`.

**Interfaces:**
```swift
enum Explanations {
    static func text(for ruleId: SuggestionRuleId) -> (short: String, long: String)
}
```
- [ ] **Step 1 — failing tests:** an entry exists for **every** `SuggestionRuleId.allCases` (no crash / non-empty short+long); spot-check `resolveDominant`/`tritoneSub`/`iiToV` long text matches §10 wording (e.g. ii-to-V "falls a half-step").
- [ ] Steps 2–5 (implement §10; commit `feat: Explanations table`).

---

## Self-Review
- **Spec coverage:** §2 (Task 1,4), §3 (1), §4 (2), §5 (5), §6 (6), §7 (4,8), §8 (7), §9 (3), §10 (9). Every section has a task.
- **Type consistency:** `ChordSymbol(degree,qualityId)`, `SuggestionRuleId` cases, `Key`/`Mode` used identically across tasks. Generators return `[ChordSuggestion]`; ranker+engine consume it.
- **No placeholders:** each task names its spec section (the validated source) + concrete Swift interfaces + concrete test assertions drawn from the validation simulations. Grip-independent throughout.
