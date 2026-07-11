# Chord Progression Trainer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native, no-audio "Chords" mode that steps through curated jazz progressions, each chord shown as name + movable fingering on a camera-following neck, rooted on the low-E string.

**Architecture:** Pure-domain catalogs (`ChordQualities`, `Voicings`, `Progressions`) mirror the existing `Instruments` Type-Object pattern. A placement function turns a `(quality, rootString, root pitch class)` into absolute `FretPosition`s. A `@MainActor` `ProgressionSession` view model holds loop/reveal state. A new `ChordNeckView` renders a chord with a camera-follow neck (shape centered, neck slides). The existing note-drill code is untouched; a new tab wires the mode in.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), Xcode project with `PBXFileSystemSynchronizedRootGroup` (new `.swift` files auto-include).

## Global Constraints

- **Test framework is Swift Testing**, not XCTest — `import Testing`, `struct XTests { @Test func … { #expect(…) } }`.
- **Never edit `project.pbxproj`.** New `.swift` files under `audio_listen/` and `audio_listenTests/` are auto-included by the synchronized file group.
- **Run tests with Xcode's toolchain** (command-line tools alone can't):
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/<Suite>/<test>`
  The **first** build resolves SwiftPM (AudioKit) and is slow (minutes); later runs are fast.
- **Do not modify the existing note-drill** (`DrillView`, `DrillViewModel`, `FretboardView`, `FretboardGeometry`). The chord mode adds its own view; it may *read* `FretboardGeometry` but must not change it.
- **String numbering:** 1 = high E, 6 = low E (per `FretPosition`). Low-E root string is string **6**.
- **Pitch classes** are semitones from C (C=0 … B=11), via `NoteName.semitonesFromC` and `Note.name`.
- **v1 scope:** exactly these 6 qualities — `maj7, m7, 7, m7b5, 6, m6` — and the 6 progressions below. `dim7`/`aug` (root-5 forms) and their progressions are deferred; do not add them.
- **Neutral naming:** dominant-7 quality id is the string `"7"`; minor-7-flat-5 symbol is `"m7♭5"` (Unicode flat U+266D).

---

### Task 1: Chord quality catalog

**Files:**
- Create: `audio_listen/Domain/Models/ChordQuality.swift`
- Create: `audio_listen/Domain/Models/ChordQualities.swift`
- Test: `audio_listenTests/ChordQualitiesTests.swift`

**Interfaces:**
- Produces: `ChordQuality { id: String, name: String, symbol: String, formula: [Int] }` (formula = semitone intervals from root, always includes `0`); `ChordQualities.all: [ChordQuality]`; `ChordQualities.byId(_ id: String) -> ChordQuality?`.

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/ChordQualitiesTests.swift
import Testing
@testable import audio_listen

struct ChordQualitiesTests {
    @Test func catalogHasTheSixV1Qualities() {
        #expect(ChordQualities.all.map(\.id) == ["maj7", "m7", "7", "m7b5", "6", "m6"])
    }

    @Test func formulasAreCorrectIntervalSets() {
        #expect(Set(ChordQualities.byId("maj7")!.formula) == [0, 4, 7, 11])
        #expect(Set(ChordQualities.byId("m7")!.formula) == [0, 3, 7, 10])
        #expect(Set(ChordQualities.byId("7")!.formula) == [0, 4, 7, 10])
        #expect(Set(ChordQualities.byId("m7b5")!.formula) == [0, 3, 6, 10])
        #expect(Set(ChordQualities.byId("6")!.formula) == [0, 4, 7, 9])
        #expect(Set(ChordQualities.byId("m6")!.formula) == [0, 3, 7, 9])
    }

    @Test func symbolsRenderChordNames() {
        #expect(ChordQualities.byId("7")!.symbol == "7")
        #expect(ChordQualities.byId("m7b5")!.symbol == "m7♭5")
    }

    @Test func byIdReturnsNilForUnknown() {
        #expect(ChordQualities.byId("13#11") == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordQualitiesTests`
Expected: FAIL — `ChordQuality` / `ChordQualities` undefined (compile error).

- [ ] **Step 3: Write minimal implementation**

```swift
// audio_listen/Domain/Models/ChordQuality.swift
struct ChordQuality: Hashable {
    let id: String
    let name: String
    let symbol: String
    let formula: [Int]
}
```

```swift
// audio_listen/Domain/Models/ChordQualities.swift
enum ChordQualities {
    static let maj7 = ChordQuality(id: "maj7", name: "Major 7", symbol: "maj7", formula: [0, 4, 7, 11])
    static let m7 = ChordQuality(id: "m7", name: "Minor 7", symbol: "m7", formula: [0, 3, 7, 10])
    static let dom7 = ChordQuality(id: "7", name: "Dominant 7", symbol: "7", formula: [0, 4, 7, 10])
    static let m7b5 = ChordQuality(id: "m7b5", name: "Minor 7♭5", symbol: "m7♭5", formula: [0, 3, 6, 10])
    static let six = ChordQuality(id: "6", name: "Major 6", symbol: "6", formula: [0, 4, 7, 9])
    static let m6 = ChordQuality(id: "m6", name: "Minor 6", symbol: "m6", formula: [0, 3, 7, 9])

    static let all: [ChordQuality] = [maj7, m7, dom7, m7b5, six, m6]

    static func byId(_ id: String) -> ChordQuality? {
        all.first { $0.id == id }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordQualitiesTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/ChordQuality.swift audio_listen/Domain/Models/ChordQualities.swift audio_listenTests/ChordQualitiesTests.swift
git commit -m "feat: chord quality catalog (v1 six qualities)"
```

---

### Task 2: Root string + voicing catalog

**Files:**
- Create: `audio_listen/Domain/Models/RootString.swift`
- Create: `audio_listen/Domain/Models/Voicing.swift`
- Create: `audio_listen/Domain/Models/Voicings.swift`
- Test: `audio_listenTests/VoicingsCatalogTests.swift`

**Interfaces:**
- Consumes: `ChordQualities` (Task 1).
- Produces:
  - `enum RootString: String, CaseIterable { case e6, a5, d4 }` with `var stringNumber: Int` (6/5/4) and `var label: String` ("Low E"/"A"/"D").
  - `struct VoicingPosition: Hashable { let string: Int; let fretOffset: Int; let finger: Int }`.
  - `struct Voicing: Hashable { let qualityId: String; let rootString: RootString; let positions: [VoicingPosition] }`.
  - `Voicings.all: [Voicing]`; `Voicings.voicing(qualityId: String, rootString: RootString) -> Voicing?`.
  - Convention: exactly one position has `string == rootString.stringNumber && fretOffset == 0` (the root).

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/VoicingsCatalogTests.swift
import Testing
@testable import audio_listen

struct VoicingsCatalogTests {
    @Test func everyV1QualityHasAnE6Voicing() {
        for quality in ChordQualities.all {
            #expect(Voicings.voicing(qualityId: quality.id, rootString: .e6) != nil)
        }
    }

    @Test func everyVoicingHasExactlyOneRootAtOffsetZeroOnItsRootString() {
        for voicing in Voicings.all {
            let roots = voicing.positions.filter {
                $0.string == voicing.rootString.stringNumber && $0.fretOffset == 0
            }
            #expect(roots.count == 1)
        }
    }

    @Test func rootStringMapsToStringNumber() {
        #expect(RootString.e6.stringNumber == 6)
        #expect(RootString.a5.stringNumber == 5)
        #expect(RootString.d4.stringNumber == 4)
    }

    @Test func fretOffsetsAreNonNegativeAndFingersAreOneToFour() {
        for voicing in Voicings.all {
            for position in voicing.positions {
                #expect(position.fretOffset >= 0)
                #expect((1...4).contains(position.finger))
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/VoicingsCatalogTests`
Expected: FAIL — `RootString`/`Voicing`/`Voicings` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// audio_listen/Domain/Models/RootString.swift
enum RootString: String, CaseIterable {
    case e6
    case a5
    case d4

    var stringNumber: Int {
        switch self {
        case .e6: return 6
        case .a5: return 5
        case .d4: return 4
        }
    }

    var label: String {
        switch self {
        case .e6: return "Low E"
        case .a5: return "A"
        case .d4: return "D"
        }
    }
}
```

```swift
// audio_listen/Domain/Models/Voicing.swift
struct VoicingPosition: Hashable {
    let string: Int
    let fretOffset: Int
    let finger: Int
}

struct Voicing: Hashable {
    let qualityId: String
    let rootString: RootString
    let positions: [VoicingPosition]
}
```

```swift
// audio_listen/Domain/Models/Voicings.swift
// E6-rooted movable forms. Each string's interval from the root
// (verified against its quality's formula in ChordFormulaConformanceTests):
//   s6:o  s5:(5+o)  s4:(10+o)  s3:(3+o)  s2:(7+o)   (mod 12, o = fretOffset)
enum Voicings {
    static let all: [Voicing] = [
        Voicing(qualityId: "maj7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 3),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m7b5", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: 1, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 2, finger: 3),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 2, finger: 4),
        ]),
        Voicing(qualityId: "m6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 2, finger: 3),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 2, finger: 4),
        ]),
    ]

    static func voicing(qualityId: String, rootString: RootString) -> Voicing? {
        all.first { $0.qualityId == qualityId && $0.rootString == rootString }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/VoicingsCatalogTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/RootString.swift audio_listen/Domain/Models/Voicing.swift audio_listen/Domain/Models/Voicings.swift audio_listenTests/VoicingsCatalogTests.swift
git commit -m "feat: root string + E6 voicing catalog (v1 six qualities)"
```

---

### Task 3: Chord placement + formula conformance

**Files:**
- Create: `audio_listen/Domain/UseCases/ChordPlacement.swift`
- Test: `audio_listenTests/ChordPlacementTests.swift`
- Test: `audio_listenTests/ChordFormulaConformanceTests.swift`

**Interfaces:**
- Consumes: `Voicing`, `RootString`, `Instrument`/`Instruments` (existing), `FretPosition` (existing), `Note`/`NoteName` (existing).
- Produces:
  - `struct PlacedChord: Hashable { let rootFret: Int; let positions: [FretPosition]; let rootPosition: FretPosition }`.
  - `enum ChordPlacement`:
    - `static func rootFret(rootPitchClass: Int, onString stringNumber: Int, instrument: Instrument) -> Int` — the fret (1…12) on that string carrying the pitch class (fret 0 mapped up to 12 so movable shapes never sit on the nut).
    - `static func place(voicing: Voicing, rootPitchClass: Int, instrument: Instrument) -> PlacedChord`.

- [ ] **Step 1: Write the failing placement test**

```swift
// audio_listenTests/ChordPlacementTests.swift
import Testing
@testable import audio_listen

struct ChordPlacementTests {
    // Low E open = E (pitch class 4). D = pitch class 2 → fret 10 on the low E string.
    @Test func rootFretForDOnLowEIsTen() {
        let fret = ChordPlacement.rootFret(rootPitchClass: 2, onString: 6, instrument: Instruments.guitar)
        #expect(fret == 10)
    }

    // E itself would be fret 0; movable shapes map it up to fret 12.
    @Test func openNotePitchClassMapsToTwelveNotZero() {
        let fret = ChordPlacement.rootFret(rootPitchClass: 4, onString: 6, instrument: Instruments.guitar)
        #expect(fret == 12)
    }

    @Test func placeAddsRootFretToEveryOffsetAndKeepsStrings() {
        let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
        let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar) // G = 7 → fret 3
        #expect(placed.rootFret == 3)
        #expect(placed.rootPosition == FretPosition(string: 6, fret: 3))
        #expect(Set(placed.positions) == Set([
            FretPosition(string: 6, fret: 3),
            FretPosition(string: 4, fret: 3),
            FretPosition(string: 3, fret: 3),
            FretPosition(string: 2, fret: 3),
        ]))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordPlacementTests`
Expected: FAIL — `ChordPlacement`/`PlacedChord` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// audio_listen/Domain/UseCases/ChordPlacement.swift
struct PlacedChord: Hashable {
    let rootFret: Int
    let positions: [FretPosition]
    let rootPosition: FretPosition
}

enum ChordPlacement {
    static func rootFret(rootPitchClass: Int, onString stringNumber: Int, instrument: Instrument) -> Int {
        let open = instrument.note(at: stringNumber, fret: 0)!.name.semitonesFromC
        let base = (((rootPitchClass - open) % 12) + 12) % 12
        return base == 0 ? 12 : base
    }

    static func place(voicing: Voicing, rootPitchClass: Int, instrument: Instrument) -> PlacedChord {
        let fret = rootFret(rootPitchClass: rootPitchClass, onString: voicing.rootString.stringNumber, instrument: instrument)
        let positions = voicing.positions.map { FretPosition(string: $0.string, fret: fret + $0.fretOffset) }
        let root = FretPosition(string: voicing.rootString.stringNumber, fret: fret)
        return PlacedChord(rootFret: fret, positions: positions, rootPosition: root)
    }
}
```

- [ ] **Step 4: Run to verify placement passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordPlacementTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the formula-conformance test**

This is the guard that every catalog voicing actually spells its chord. A movable
grip may **omit the perfect 5th** (interval 7) — that's standard, since the full
barre is often unplayable — but it must contain **no non-chord tones** and all
other formula tones. So the check is: every interval is in the formula (subset),
and every required tone (the formula minus the optional perfect 5th) is present.

```swift
// audio_listenTests/ChordFormulaConformanceTests.swift
import Testing
@testable import audio_listen

struct ChordFormulaConformanceTests {
    @Test func everyVoicingSpellsItsQualityAtSeveralRoots() {
        let guitar = Instruments.guitar
        for voicing in Voicings.all {
            let formula = Set(ChordQualities.byId(voicing.qualityId)!.formula)
            let required = formula.filter { $0 != 7 } // the perfect 5th may be dropped
            for rootPitchClass in [0, 2, 5, 7, 10] { // C, D, F, G, A#
                let placed = ChordPlacement.place(voicing: voicing, rootPitchClass: rootPitchClass, instrument: guitar)
                let intervals = Set(placed.positions.map { position -> Int in
                    let pitchClass = guitar.note(at: position.string, fret: position.fret)!.name.semitonesFromC
                    return (((pitchClass - rootPitchClass) % 12) + 12) % 12
                })
                #expect(intervals.isSubset(of: formula), "\(voicing.qualityId) at root \(rootPitchClass) has non-chord tone: \(intervals.sorted()) ⊄ \(formula.sorted())")
                #expect(required.isSubset(of: intervals), "\(voicing.qualityId) at root \(rootPitchClass) missing required tone: \(required.sorted()) ⊄ \(intervals.sorted())")
            }
        }
    }
}
```

- [ ] **Step 6: Run to verify conformance passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordFormulaConformanceTests`
Expected: PASS. If any voicing fails, its fret offsets in `Voicings.swift` are wrong — fix the offsets, not the test.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Domain/UseCases/ChordPlacement.swift audio_listenTests/ChordPlacementTests.swift audio_listenTests/ChordFormulaConformanceTests.swift
git commit -m "feat: chord placement + formula-conformance guard"
```

---

### Task 4: Progression catalog + chord naming

**Files:**
- Create: `audio_listen/Domain/Models/Progression.swift`
- Create: `audio_listen/Domain/Models/Progressions.swift`
- Create: `audio_listen/Domain/UseCases/ChordNaming.swift`
- Test: `audio_listenTests/ProgressionsTests.swift`

**Interfaces:**
- Consumes: `ChordQualities`, `NoteName` (existing).
- Produces:
  - `struct ProgressionStep: Hashable { let degree: Int; let qualityId: String }` — `degree` = semitones above the tonic (0…11).
  - `struct Progression: Hashable { let id: String; let name: String; let steps: [ProgressionStep] }`.
  - `Progressions.all: [Progression]`; `Progressions.byId(_ id: String) -> Progression?`.
  - `enum ChordNaming`:
    - `static func rootName(tonic: NoteName, degree: Int) -> NoteName`.
    - `static func displayName(step: ProgressionStep, tonic: NoteName) -> String` — e.g. `Dm7`.

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/ProgressionsTests.swift
import Testing
@testable import audio_listen

struct ProgressionsTests {
    @Test func majorTwoFiveOneUsesM7Then7ThenMaj7() {
        let steps = Progressions.byId("major-ii-v-i")!.steps
        #expect(steps.map(\.qualityId) == ["m7", "7", "maj7"])
        #expect(steps.map(\.degree) == [2, 7, 0])
    }

    @Test func chordNamesResolveInCMajor() {
        let ii251 = Progressions.byId("major-ii-v-i")!
        let names = ii251.steps.map { ChordNaming.displayName(step: $0, tonic: .c) }
        #expect(names == ["Dm7", "G7", "Cmaj7"])
    }

    @Test func chordNamesTransposeToEveryKey() {
        let ii251 = Progressions.byId("major-ii-v-i")!
        // In G: ii=Am7, V=D7, I=Gmaj7
        let names = ii251.steps.map { ChordNaming.displayName(step: $0, tonic: .g) }
        #expect(names == ["Am7", "D7", "Gmaj7"])
    }

    @Test func everyProgressionStepQualityIsInTheV1Catalog() {
        let allowed = Set(ChordQualities.all.map(\.id))
        for progression in Progressions.all {
            for step in progression.steps {
                #expect(allowed.contains(step.qualityId))
            }
        }
    }

    @Test func catalogHasTheSixV1Progressions() {
        #expect(Progressions.all.map(\.id) == [
            "major-ii-v-i", "turnaround", "minor-ii-v-i", "sixth-loop", "dominant-blues", "minor-six-tonic",
        ])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionsTests`
Expected: FAIL — undefined types.

- [ ] **Step 3: Write the implementation**

```swift
// audio_listen/Domain/Models/Progression.swift
struct ProgressionStep: Hashable {
    let degree: Int
    let qualityId: String
}

struct Progression: Hashable {
    let id: String
    let name: String
    let steps: [ProgressionStep]
}
```

```swift
// audio_listen/Domain/Models/Progressions.swift
enum Progressions {
    private static func step(_ degree: Int, _ qualityId: String) -> ProgressionStep {
        ProgressionStep(degree: degree, qualityId: qualityId)
    }

    static let all: [Progression] = [
        Progression(id: "major-ii-v-i", name: "Major ii–V–I", steps: [
            step(2, "m7"), step(7, "7"), step(0, "maj7"),
        ]),
        Progression(id: "turnaround", name: "I–VI–ii–V turnaround", steps: [
            step(0, "maj7"), step(9, "7"), step(2, "m7"), step(7, "7"),
        ]),
        Progression(id: "minor-ii-v-i", name: "Minor ii–V–i", steps: [
            step(2, "m7b5"), step(7, "7"), step(0, "m7"),
        ]),
        Progression(id: "sixth-loop", name: "6th-chord loop", steps: [
            step(0, "6"), step(9, "m7"), step(2, "m7"), step(7, "7"),
        ]),
        Progression(id: "dominant-blues", name: "Dominant blues", steps: [
            step(0, "7"), step(5, "7"), step(0, "7"), step(0, "7"),
            step(5, "7"), step(5, "7"), step(0, "7"), step(0, "7"),
            step(7, "7"), step(5, "7"), step(0, "7"), step(7, "7"),
        ]),
        Progression(id: "minor-six-tonic", name: "Minor-6 tonic", steps: [
            step(0, "m6"), step(5, "m7"), step(7, "7"), step(0, "m6"),
        ]),
    ]

    static func byId(_ id: String) -> Progression? {
        all.first { $0.id == id }
    }
}
```

```swift
// audio_listen/Domain/UseCases/ChordNaming.swift
enum ChordNaming {
    static func rootName(tonic: NoteName, degree: Int) -> NoteName {
        NoteName(rawValue: (((tonic.semitonesFromC + degree) % 12) + 12) % 12)!
    }

    static func displayName(step: ProgressionStep, tonic: NoteName) -> String {
        let root = rootName(tonic: tonic, degree: step.degree)
        let quality = ChordQualities.byId(step.qualityId)!
        return root.displayName + quality.symbol
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionsTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Domain/Models/Progression.swift audio_listen/Domain/Models/Progressions.swift audio_listen/Domain/UseCases/ChordNaming.swift audio_listenTests/ProgressionsTests.swift
git commit -m "feat: progression catalog + chord naming/transposition"
```

---

### Task 5: Progression session (loop + reveal state)

**Files:**
- Create: `audio_listen/Presentation/Chords/ProgressionSession.swift`
- Test: `audio_listenTests/ProgressionSessionTests.swift`

**Interfaces:**
- Consumes: `Progression`, `RootString`, `NoteName` (existing), `Progressions`.
- Produces: `@MainActor final class ProgressionSession: ObservableObject` with:
  - `enum DisplayMode { case nameAndFingering, nameOnly }`
  - `@Published var progression: Progression`, `@Published var tonic: NoteName`, `@Published var rootString: RootString`, `@Published var displayMode: DisplayMode`.
  - `@Published private(set) var index: Int`, `@Published private(set) var revealed: Bool`.
  - `var currentStep: ProgressionStep`, `var nextStep: ProgressionStep` (wraps to first).
  - `func primaryAction()` — in `nameOnly` with `revealed == false`, reveal; otherwise advance.
  - `func advance()`, `func previous()` — wrap; reset `revealed` to `displayMode == .nameAndFingering`.
  - Setting `displayMode` resets `revealed` accordingly.
  - `init(progression:tonic:rootString:displayMode:)` with defaults `tonic: .c`, `rootString: .e6`, `displayMode: .nameAndFingering`.

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/ProgressionSessionTests.swift
import Testing
@testable import audio_listen

@MainActor
struct ProgressionSessionTests {
    private func session(_ mode: ProgressionSession.DisplayMode) -> ProgressionSession {
        ProgressionSession(progression: Progressions.byId("major-ii-v-i")!, tonic: .c, rootString: .e6, displayMode: mode)
    }

    @Test func advanceWrapsAtLoopBoundary() {
        let s = session(.nameAndFingering)
        #expect(s.index == 0)
        s.advance(); s.advance()
        #expect(s.index == 2)
        s.advance()
        #expect(s.index == 0)
    }

    @Test func nextStepWrapsToFirst() {
        let s = session(.nameAndFingering)
        s.advance(); s.advance() // index 2 (last)
        #expect(s.nextStep == s.progression.steps[0])
    }

    @Test func fingeringModeIsAlwaysRevealed() {
        let s = session(.nameAndFingering)
        #expect(s.revealed == true)
        s.primaryAction() // advances
        #expect(s.index == 1)
        #expect(s.revealed == true)
    }

    @Test func recallModeRevealsThenAdvances() {
        let s = session(.nameOnly)
        #expect(s.revealed == false)
        s.primaryAction() // reveals, does not advance
        #expect(s.index == 0)
        #expect(s.revealed == true)
        s.primaryAction() // advances, re-hides
        #expect(s.index == 1)
        #expect(s.revealed == false)
    }

    @Test func switchingToRecallModeHidesTheGrip() {
        let s = session(.nameAndFingering)
        s.displayMode = .nameOnly
        #expect(s.revealed == false)
    }

    @Test func previousWraps() {
        let s = session(.nameAndFingering)
        s.previous()
        #expect(s.index == 2)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionSessionTests`
Expected: FAIL — `ProgressionSession` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// audio_listen/Presentation/Chords/ProgressionSession.swift
import Foundation

@MainActor
final class ProgressionSession: ObservableObject {
    enum DisplayMode {
        case nameAndFingering
        case nameOnly
    }

    @Published var progression: Progression { didSet { reset() } }
    @Published var tonic: NoteName
    @Published var rootString: RootString
    @Published var displayMode: DisplayMode { didSet { revealed = fullyRevealed } }

    @Published private(set) var index: Int = 0
    @Published private(set) var revealed: Bool

    init(progression: Progression,
         tonic: NoteName = .c,
         rootString: RootString = .e6,
         displayMode: DisplayMode = .nameAndFingering) {
        self.progression = progression
        self.tonic = tonic
        self.rootString = rootString
        self.displayMode = displayMode
        self.revealed = displayMode == .nameAndFingering
    }

    var currentStep: ProgressionStep { progression.steps[index] }
    var nextStep: ProgressionStep { progression.steps[(index + 1) % progression.steps.count] }

    private var fullyRevealed: Bool { displayMode == .nameAndFingering }

    func primaryAction() {
        if displayMode == .nameOnly && !revealed {
            revealed = true
        } else {
            advance()
        }
    }

    func advance() {
        index = (index + 1) % progression.steps.count
        revealed = fullyRevealed
    }

    func previous() {
        index = (index - 1 + progression.steps.count) % progression.steps.count
        revealed = fullyRevealed
    }

    private func reset() {
        index = 0
        revealed = fullyRevealed
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionSessionTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Chords/ProgressionSession.swift audio_listenTests/ProgressionSessionTests.swift
git commit -m "feat: progression session loop + reveal state"
```

---

### Task 6: Selection persistence (store-as-seam)

**Files:**
- Create: `audio_listen/Infrastructure/Game/ProgressionSelectionStore.swift`
- Test: `audio_listenTests/ProgressionSelectionStoreTests.swift`

**Interfaces:**
- Consumes: `Progressions`, `RootString`, `NoteName` (existing), `ProgressionSession.DisplayMode`.
- Produces: `struct ProgressionSelectionStore` with injectable `UserDefaults`, persisting last `progressionId`, `tonic` (NoteName rawValue), `rootString`, `displayMode`. Getters fall back to sane defaults (`major-ii-v-i`, `.c`, `.e6`, `.nameAndFingering`). Mirrors `SelectedInstrumentStore`.

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/ProgressionSelectionStoreTests.swift
import Foundation
import Testing
@testable import audio_listen

struct ProgressionSelectionStoreTests {
    private func makeStore() -> (ProgressionSelectionStore, UserDefaults, String) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (ProgressionSelectionStore(defaults: defaults), defaults, suite)
    }

    @Test func defaultsWhenEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.progression.id == "major-ii-v-i")
        #expect(store.tonic == .c)
        #expect(store.rootString == .e6)
        #expect(store.displayMode == .nameAndFingering)
    }

    @Test func roundTripsSelection() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(progressionId: "turnaround", tonic: .g, rootString: .e6, displayMode: .nameOnly)
        #expect(store.progression.id == "turnaround")
        #expect(store.tonic == .g)
        #expect(store.displayMode == .nameOnly)
    }

    @Test func unknownProgressionFallsBackToDefault() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(progressionId: "nope", tonic: .c, rootString: .e6, displayMode: .nameAndFingering)
        #expect(store.progression.id == "major-ii-v-i")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionSelectionStoreTests`
Expected: FAIL — `ProgressionSelectionStore` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// audio_listen/Infrastructure/Game/ProgressionSelectionStore.swift
import Foundation

struct ProgressionSelectionStore {
    private enum Key {
        static let progression = "audio_listen_chord_progression_id"
        static let tonic = "audio_listen_chord_tonic"
        static let rootString = "audio_listen_chord_root_string"
        static let displayMode = "audio_listen_chord_display_mode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var progression: Progression {
        let id = defaults.string(forKey: Key.progression)
        return Progressions.all.first { $0.id == id } ?? Progressions.byId("major-ii-v-i")!
    }

    var tonic: NoteName {
        guard defaults.object(forKey: Key.tonic) != nil,
              let name = NoteName(rawValue: defaults.integer(forKey: Key.tonic)) else { return .c }
        return name
    }

    var rootString: RootString {
        guard let raw = defaults.string(forKey: Key.rootString),
              let value = RootString(rawValue: raw) else { return .e6 }
        return value
    }

    var displayMode: ProgressionSession.DisplayMode {
        defaults.bool(forKey: Key.displayMode) ? .nameOnly : .nameAndFingering
    }

    func save(progressionId: String, tonic: NoteName, rootString: RootString, displayMode: ProgressionSession.DisplayMode) {
        defaults.set(progressionId, forKey: Key.progression)
        defaults.set(tonic.rawValue, forKey: Key.tonic)
        defaults.set(rootString.rawValue, forKey: Key.rootString)
        defaults.set(displayMode == .nameOnly, forKey: Key.displayMode)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ProgressionSelectionStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Infrastructure/Game/ProgressionSelectionStore.swift audio_listenTests/ProgressionSelectionStoreTests.swift
git commit -m "feat: progression selection persistence store"
```

---

### Task 7: Camera-follow chord neck view

**Files:**
- Create: `audio_listen/Presentation/Chords/ChordNeckGeometry.swift`
- Create: `audio_listen/Presentation/Chords/ChordNeckView.swift`
- Test: `audio_listenTests/ChordNeckGeometryTests.swift`

**Interfaces:**
- Consumes: `PlacedChord`, `FretPosition`, `CoreGraphics`.
- Produces:
  - `struct ChordNeckGeometry` — pure layout math for a fixed-width fret window centered on the chord. Init `ChordNeckGeometry(size: CGSize, windowFrets: Int, centerFret: Double)`. Provides `func stringY(_ string: Int) -> CGFloat` (string 1 top … 6 bottom), `func x(forFret fret: Double) -> CGFloat` (absolute fret → x, so sliding the window changes x), and `let windowFrets: Int`.
  - `struct ChordNeckView: View` — takes `placedChord: PlacedChord`, `showFingering: Bool`, renders a dark board, strings, the sliding fret lines/inlays/fret-number, and finger dots (root highlighted) centered on `placedChord.rootFret`; animates the slide when `placedChord` changes.

The geometry is the only unit-tested part; the view is verified by a SwiftUI preview.

- [ ] **Step 1: Write the failing geometry test**

```swift
// audio_listenTests/ChordNeckGeometryTests.swift
import CoreGraphics
import Testing
@testable import audio_listen

struct ChordNeckGeometryTests {
    private let size = CGSize(width: 300, height: 140)

    @Test func stringOneIsAboveStringSix() {
        let geo = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 5)
        #expect(geo.stringY(1) < geo.stringY(6))
    }

    @Test func centerFretSitsAtHorizontalCenter() {
        let geo = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 5)
        #expect(abs(geo.x(forFret: 5) - size.width / 2) < 0.5)
    }

    @Test func slidingTheCenterMovesFretsLeft() {
        let low = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 3)
        let high = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 8)
        // Fret 5 is right of center when centered on 3, left of center when centered on 8.
        #expect(low.x(forFret: 5) > size.width / 2)
        #expect(high.x(forFret: 5) < size.width / 2)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordNeckGeometryTests`
Expected: FAIL — `ChordNeckGeometry` undefined.

- [ ] **Step 3: Write the geometry**

```swift
// audio_listen/Presentation/Chords/ChordNeckGeometry.swift
import CoreGraphics

struct ChordNeckGeometry {
    let size: CGSize
    let windowFrets: Int
    let centerFret: Double

    init(size: CGSize, windowFrets: Int, centerFret: Double) {
        self.size = size
        self.windowFrets = windowFrets
        self.centerFret = centerFret
    }

    private var cellWidth: CGFloat { size.width / CGFloat(windowFrets) }

    func x(forFret fret: Double) -> CGFloat {
        size.width / 2 + CGFloat(fret - centerFret) * cellWidth
    }

    func stringY(_ string: Int) -> CGFloat {
        let inset = size.height / CGFloat(7)
        return inset * CGFloat(string)
    }
}
```

- [ ] **Step 4: Run to verify geometry passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordNeckGeometryTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the view**

```swift
// audio_listen/Presentation/Chords/ChordNeckView.swift
import SwiftUI

struct ChordNeckView: View {
    let placedChord: PlacedChord
    var showFingering: Bool = true
    private let windowFrets = 6
    private let dotRadius: CGFloat = 11

    private var centerFret: Double { Double(placedChord.rootFret) + 1.0 }

    var body: some View {
        GeometryReader { proxy in
            let geo = ChordNeckGeometry(size: proxy.size, windowFrets: windowFrets, centerFret: centerFret)
            ZStack {
                fretLines(geo)
                strings(geo)
                positionLabel(geo)
                if showFingering {
                    dots(geo)
                }
            }
            .animation(.timingCurve(0.4, 0.1, 0.2, 1, duration: 0.55), value: placedChord)
        }
        .frame(height: 150)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fretLines(_ geo: ChordNeckGeometry) -> some View {
        let lo = placedChord.rootFret - windowFrets
        let hi = placedChord.rootFret + windowFrets
        return ZStack {
            ForEach(lo...hi, id: \.self) { fret in
                let x = geo.x(forFret: Double(fret))
                Path { p in
                    p.move(to: CGPoint(x: x, y: geo.stringY(1)))
                    p.addLine(to: CGPoint(x: x, y: geo.stringY(6)))
                }
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                if [3, 5, 7, 9, 12, 15, 17, 19, 21].contains(fret) {
                    Circle().fill(Color(white: 0.3)).frame(width: 6, height: 6)
                        .position(x: geo.x(forFret: Double(fret) - 0.5), y: geo.stringY(3) + (geo.stringY(4) - geo.stringY(3)) / 2)
                }
            }
        }
    }

    private func strings(_ geo: ChordNeckGeometry) -> some View {
        ForEach(1...6, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1 + CGFloat(string - 1) * 0.15)
        }
    }

    private func positionLabel(_ geo: ChordNeckGeometry) -> some View {
        Text("\(placedChord.rootFret)fr")
            .font(.caption2.monospaced())
            .foregroundStyle(Color.gray)
            .position(x: geo.x(forFret: Double(placedChord.rootFret) - 0.5), y: geo.stringY(1) - 8)
    }

    private func dots(_ geo: ChordNeckGeometry) -> some View {
        ForEach(placedChord.positions, id: \.self) { position in
            let isRoot = position == placedChord.rootPosition
            Circle()
                .fill(isRoot ? Color.orange : Color(white: 0.93))
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .position(x: geo.x(forFret: Double(position.fret) - 0.5), y: geo.stringY(position.string))
        }
    }
}

#Preview {
    let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
    let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar)
    ChordNeckView(placedChord: placed).padding()
}
```

- [ ] **Step 6: Verify it builds and preview renders**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `BUILD SUCCEEDED`. Then open `ChordNeckView.swift` in Xcode and confirm the preview shows a dark neck with the Gm7 grip, orange root on the low‑E string, and a "3fr" position label.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Presentation/Chords/ChordNeckGeometry.swift audio_listen/Presentation/Chords/ChordNeckView.swift audio_listenTests/ChordNeckGeometryTests.swift
git commit -m "feat: camera-follow chord neck view"
```

---

### Task 8: Progression screen + DI wiring

**Files:**
- Create: `audio_listen/Presentation/Chords/ChordProgressionView.swift`
- Modify: `audio_listen/DI/AppDependencyContainer.swift` (add a factory)

**Interfaces:**
- Consumes: `ProgressionSession`, `ChordNeckView`, `ChordPlacement`, `ChordNaming`, `Progressions`, `ProgressionSelectionStore`, `Instruments`.
- Produces:
  - `struct ChordProgressionView: View` — the mode screen.
  - `AppDependencyContainer.makeProgressionSession() -> ProgressionSession` (seeded from `ProgressionSelectionStore`), and a `progressionSelectionStore` property.

- [ ] **Step 1: Add the DI factory (no test — wiring)**

In `audio_listen/DI/AppDependencyContainer.swift`, add a stored store and a factory. Insert after the `dailyHistoryStore` property:

```swift
    let progressionSelectionStore = ProgressionSelectionStore()
```

And add this method alongside the other `make…` methods:

```swift
    @MainActor
    func makeProgressionSession() -> ProgressionSession {
        ProgressionSession(
            progression: progressionSelectionStore.progression,
            tonic: progressionSelectionStore.tonic,
            rootString: progressionSelectionStore.rootString,
            displayMode: progressionSelectionStore.displayMode
        )
    }
```

- [ ] **Step 2: Write the screen**

```swift
// audio_listen/Presentation/Chords/ChordProgressionView.swift
import SwiftUI

struct ChordProgressionView: View {
    @StateObject private var session: ProgressionSession
    private let instrument: Instrument
    private let store: ProgressionSelectionStore

    init(session: ProgressionSession, instrument: Instrument, store: ProgressionSelectionStore) {
        _session = StateObject(wrappedValue: session)
        self.instrument = instrument
        self.store = store
    }

    private func placed(_ step: ProgressionStep) -> PlacedChord {
        let voicing = Voicings.voicing(qualityId: step.qualityId, rootString: session.rootString)!
        let pitchClass = ChordNaming.rootName(tonic: session.tonic, degree: step.degree).semitonesFromC
        return ChordPlacement.place(voicing: voicing, rootPitchClass: pitchClass, instrument: instrument)
    }

    private func name(_ step: ProgressionStep) -> String {
        ChordNaming.displayName(step: step, tonic: session.tonic)
    }

    var body: some View {
        VStack(spacing: 20) {
            controls

            Text(name(session.currentStep))
                .font(.system(size: 40, weight: .bold, design: .serif))
                .contentTransition(.numericText())

            ChordNeckView(placedChord: placed(session.currentStep), showFingering: session.revealed)
                .padding(.horizontal)

            HStack(spacing: 6) {
                Text("next:").foregroundStyle(.secondary)
                Text(name(session.nextStep)).fontWeight(.semibold)
            }
            .font(.subheadline)

            Spacer()

            Button(action: { session.primaryAction() }) {
                Text(primaryLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding(.top)
        .onChange(of: session.index) { _ in persist() }
    }

    private var primaryLabel: String {
        session.displayMode == .nameOnly && !session.revealed ? "Reveal" : "Next ›"
    }

    private var controls: some View {
        HStack {
            Menu {
                ForEach(Progressions.all, id: \.id) { progression in
                    Button(progression.name) { session.progression = progression; persist() }
                }
            } label: { Label(session.progression.name, systemImage: "music.note.list") }

            Spacer()

            Picker("Key", selection: Binding(get: { session.tonic }, set: { session.tonic = $0; persist() })) {
                ForEach(NoteName.allCases, id: \.self) { note in Text(note.displayName).tag(note) }
            }
            .pickerStyle(.menu)

            Button {
                session.displayMode = session.displayMode == .nameAndFingering ? .nameOnly : .nameAndFingering
                persist()
            } label: {
                Image(systemName: session.displayMode == .nameOnly ? "eye.slash" : "eye")
            }
        }
        .padding(.horizontal)
    }

    private func persist() {
        store.save(progressionId: session.progression.id, tonic: session.tonic,
                   rootString: session.rootString, displayMode: session.displayMode)
    }
}

#Preview {
    ChordProgressionView(
        session: ProgressionSession(progression: Progressions.byId("major-ii-v-i")!),
        instrument: Instruments.guitar,
        store: ProgressionSelectionStore()
    )
}
```

- [ ] **Step 3: Verify it builds and preview works**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `BUILD SUCCEEDED`. In Xcode, open `ChordProgressionView.swift`, run the preview, tap **Next ›** and watch the neck slide between Dm7 → G7 → Cmaj7; toggle the eye to hide the grip and confirm **Reveal** appears.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Chords/ChordProgressionView.swift audio_listen/DI/AppDependencyContainer.swift
git commit -m "feat: chord progression screen + DI wiring"
```

---

### Task 9: Wire the Chords mode into the app

**Files:**
- Modify: `audio_listen/ContentView.swift`

**Interfaces:**
- Consumes: `ChordProgressionView`, `AppDependencyContainer`.
- Produces: a new "Chords" tab in both the iOS `NavRail`/`screen(for:)` and the macOS `TabView`.

- [ ] **Step 1: Add the Chords screen to the iOS `screen(for:)` switch**

In `audio_listen/ContentView.swift`, the iOS path uses `screen(for: selection)` with a `NavRail`. Renumber so Chords is index 1, pushing the rest down. Replace the `screen(for:)` body:

```swift
    @ViewBuilder
    private func screen(for index: Int) -> some View {
        switch index {
        case 0:
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                instrument: container.currentInstrument
            )
            .id("\(touchMode)-\(selectedInstrumentId)")
        case 1:
            ChordProgressionView(
                session: container.makeProgressionSession(),
                instrument: container.currentInstrument,
                store: container.progressionSelectionStore
            )
        case 2:
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore,
                instrument: container.currentInstrument
            )
            .id(selectedInstrumentId)
        case 3:
            TunerView(viewModel: container.makeTunerViewModel())
        default:
            SettingsView()
        }
    }
```

- [ ] **Step 2: Add the Chords item to the iOS `NavRail`**

Replace the `NavRail` `items` array:

```swift
    private let items: [(label: String, icon: String)] = [
        ("Drill", "guitars.fill"),
        ("Chords", "pianokeys"),
        ("Progress", "chart.bar.fill"),
        ("Tuner", "tuningfork"),
        ("Settings", "gearshape.fill")
    ]
```

- [ ] **Step 3: Add the Chords tab to the macOS `TabView`**

In the `#else` (macOS) branch, add this tab immediately after the `DrillView` tab and before `MasteryView`:

```swift
            ChordProgressionView(
                session: container.makeProgressionSession(),
                instrument: container.currentInstrument,
                store: container.progressionSelectionStore
            )
            .id(selectedInstrumentId)
            .tabItem { Label("Chords", systemImage: "pianokeys") }
```

- [ ] **Step 4: Verify the whole app builds**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `BUILD SUCCEEDED`. In Xcode, run the app (iOS simulator): a **Chords** item appears in the nav rail; selecting it shows the progression trainer; the existing Drill/Progress/Tuner/Settings still work.

- [ ] **Step 5: Run the full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests`
Expected: all tests pass, including the new chord suites and the pre-existing ones.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/ContentView.swift
git commit -m "feat: add Chords mode tab to the app"
```

---

## Deferred (not in this plan)

- `A5` and `D4` voicings; `dim7`/`aug` and the "Diminished passing" / "Augmented lift" progressions (root-5 forms — deferred to the A5 tier).
- The cell-recombination generator; metronome / auto-advance; mastery tracking; voice-leading mixed-string mode.
