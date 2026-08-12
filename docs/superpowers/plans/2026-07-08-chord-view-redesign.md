# Chord View Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chord mode's small camera-follow neck with a full, drill-sized, responsive guitar neck whose finger-numbered dots glide between chords, and add a timed auto-advance (1–6 s) plus manual transport.

**Architecture:** Keep the entire chord domain layer. Extend `ChordPlacement` to carry finger numbers + a root flag. Add `ChordFretboardView` built on the drill's existing `FretboardGeometry` (full 15-fret neck, `GeometryReader` + `minHeight`, gliding dots). Add a small `AutoAdvance` model (clamped pace + play state). Rework `ChordProgressionView` to use them and delete the old `ChordNeckView`/`ChordNeckGeometry`.

**Tech Stack:** Swift, SwiftUI, Swift Testing, Xcode project with `PBXFileSystemSynchronizedRootGroup`.

## Global Constraints

- **Test framework is Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.
- **Never edit `project.pbxproj`.** New/deleted `.swift` files auto-include/exclude via the synchronized file group (delete with `git rm`).
- **Run tests with Xcode's toolchain:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/<Suite>` (build cache warm; a run is ~30–90s). Full build: `xcodebuild build …`. SourceKit/IDE may show false "Cannot find type"/"No such module 'Testing'" warnings — the `xcodebuild` result is the source of truth.
- **Do not modify the note-drill** (`DrillView`, `DrillViewModel`, `FretboardView`, `FretboardGeometry`). `ChordFretboardView` *reads* `FretboardGeometry` but must not change it.
- **Keep the domain layer unchanged** except `ChordPlacement` (this plan's Task 1). `ChordQualities`, `Voicings`, `Progressions`, `ChordNaming`, `ProgressionSession`, `ProgressionSelectionStore`, and the `ContentView` Chords-tab wiring stay as-is.
- **String numbering:** 1 = high E (top), 6 = low E (bottom). The chord mode is guitar-only (`Instruments.guitar`).
- **Each task must leave the whole app building** — the ordering below preserves that (old `ChordNeckView` keeps compiling until Task 4 deletes it).

---

### Task 1: Placement carries finger numbers + root flag

**Files:**
- Modify: `audio_listen/Domain/UseCases/ChordPlacement.swift`
- Modify: `audio_listenTests/ChordPlacementTests.swift`
- Modify: `audio_listenTests/ChordFormulaConformanceTests.swift`

**Interfaces:**
- Consumes: `Voicing`/`VoicingPosition` (has `finger`), `Instrument`, `FretPosition`.
- Produces:
  - `struct PlacedNote: Hashable { let string: Int; let fret: Int; let finger: Int; let isRoot: Bool }`.
  - `struct PlacedChord: Hashable { let rootFret: Int; let notes: [PlacedNote]; let positions: [FretPosition]; let rootPosition: FretPosition }` — `notes` is new (the view uses it); `positions`/`rootPosition` are kept for now so the old `ChordNeckView` keeps compiling (removed in Task 4).
  - `ChordPlacement.place` populates `notes` (finger from the voicing, `isRoot` for the root-string offset-0 note) and still populates `positions`/`rootPosition`.

- [ ] **Step 1: Update the placement test to assert notes carry finger + isRoot**

Replace `placeAddsRootFretToEveryOffsetAndKeepsStrings` in `audio_listenTests/ChordPlacementTests.swift` with this (keep the other two tests `rootFretForDOnLowEIsTen` and `openNotePitchClassMapsToTwelveNotZero` exactly as they are):

```swift
    @Test func placeThreadsRootFretFingersAndRootFlag() {
        let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
        let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar) // G = 7 → fret 3
        #expect(placed.rootFret == 3)
        // one note per voicing position, string+fret preserved
        #expect(Set(placed.notes.map { $0.string }) == Set([6, 4, 3, 2]))
        #expect(placed.notes.allSatisfy { $0.fret == 3 })
        // exactly the low-E (string 6) note is the root
        let roots = placed.notes.filter { $0.isRoot }
        #expect(roots.count == 1)
        #expect(roots.first?.string == 6)
        // fingers come from the voicing (m7 is an all-index barre → all finger 1)
        #expect(placed.notes.allSatisfy { $0.finger == 1 })
    }
```

- [ ] **Step 2: Update the conformance test to read `notes`**

In `audio_listenTests/ChordFormulaConformanceTests.swift`, change the interval computation to iterate `placed.notes` instead of `placed.positions`:

```swift
                let intervals = Set(placed.notes.map { note -> Int in
                    let pitchClass = guitar.note(at: note.string, fret: note.fret)!.name.semitonesFromC
                    return (((pitchClass - rootPitchClass) % 12) + 12) % 12
                })
```

(The rest of that test — the `formula`/`required` sets and the two `#expect`s — is unchanged.)

- [ ] **Step 3: Run both tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordPlacementTests -only-testing:audio_listenTests/ChordFormulaConformanceTests 2>&1 | tail -30`
Expected: FAIL — `PlacedChord` has no member `notes` / `PlacedNote` undefined (compile error).

- [ ] **Step 4: Implement the placement change**

Replace the whole body of `audio_listen/Domain/UseCases/ChordPlacement.swift` with:

```swift
struct PlacedNote: Hashable {
    let string: Int
    let fret: Int
    let finger: Int
    let isRoot: Bool
}

struct PlacedChord: Hashable {
    let rootFret: Int
    let notes: [PlacedNote]
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
        let rootStringNumber = voicing.rootString.stringNumber
        let fret = rootFret(rootPitchClass: rootPitchClass, onString: rootStringNumber, instrument: instrument)
        let notes = voicing.positions.map { position in
            PlacedNote(
                string: position.string,
                fret: fret + position.fretOffset,
                finger: position.finger,
                isRoot: position.string == rootStringNumber && position.fretOffset == 0
            )
        }
        let positions = voicing.positions.map { FretPosition(string: $0.string, fret: fret + $0.fretOffset) }
        let root = FretPosition(string: rootStringNumber, fret: fret)
        return PlacedChord(rootFret: fret, notes: notes, positions: positions, rootPosition: root)
    }
}
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/ChordPlacementTests -only-testing:audio_listenTests/ChordFormulaConformanceTests 2>&1 | tail -30`
Expected: PASS (3 + 1 tests). If conformance fails, a voicing offset is wrong — do not change the test.

- [ ] **Step 6: Confirm the app still builds (old ChordNeckView still uses `positions`)**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add audio_listen/Domain/UseCases/ChordPlacement.swift audio_listenTests/ChordPlacementTests.swift audio_listenTests/ChordFormulaConformanceTests.swift
git commit -m "feat: placement carries finger numbers + root flag (PlacedNote)"
```

---

### Task 2: AutoAdvance model (clamped pace + play state)

**Files:**
- Create: `audio_listen/Presentation/Chords/AutoAdvance.swift`
- Test: `audio_listenTests/AutoAdvanceTests.swift`

**Interfaces:**
- Produces: `@MainActor final class AutoAdvance: ObservableObject` with `static let minPace: TimeInterval = 1.0`, `static let maxPace: TimeInterval = 6.0`, `@Published var isPlaying: Bool` (default `false`), `@Published var pace: TimeInterval` whose setter **clamps to 1.0…6.0**, and `init(pace: TimeInterval = 2.0)`.

- [ ] **Step 1: Write the failing test**

```swift
// audio_listenTests/AutoAdvanceTests.swift
import Testing
@testable import audio_listen

@MainActor
struct AutoAdvanceTests {
    @Test func defaultsToPausedAtTwoSeconds() {
        let a = AutoAdvance()
        #expect(a.isPlaying == false)
        #expect(a.pace == 2.0)
    }

    @Test func clampsPaceBelowMinToOne() {
        let a = AutoAdvance()
        a.pace = 0.2
        #expect(a.pace == 1.0)
    }

    @Test func clampsPaceAboveMaxToSix() {
        let a = AutoAdvance()
        a.pace = 99
        #expect(a.pace == 6.0)
    }

    @Test func keepsPaceInRange() {
        let a = AutoAdvance()
        a.pace = 3.5
        #expect(a.pace == 3.5)
    }

    @Test func initClampsOutOfRangePace() {
        #expect(AutoAdvance(pace: 100).pace == 6.0)
        #expect(AutoAdvance(pace: 0).pace == 1.0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/AutoAdvanceTests 2>&1 | tail -25`
Expected: FAIL — `AutoAdvance` undefined.

- [ ] **Step 3: Implement**

```swift
// audio_listen/Presentation/Chords/AutoAdvance.swift
import Foundation

@MainActor
final class AutoAdvance: ObservableObject {
    static let minPace: TimeInterval = 1.0
    static let maxPace: TimeInterval = 6.0

    @Published var isPlaying: Bool = false
    @Published var pace: TimeInterval {
        didSet {
            let clamped = min(max(pace, Self.minPace), Self.maxPace)
            if clamped != pace { pace = clamped }
        }
    }

    init(pace: TimeInterval = 2.0) {
        self.pace = min(max(pace, Self.minPace), Self.maxPace)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests/AutoAdvanceTests 2>&1 | tail -25`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Chords/AutoAdvance.swift audio_listenTests/AutoAdvanceTests.swift
git commit -m "feat: AutoAdvance model (pace clamped 1-6s + play state)"
```

---

### Task 3: `ChordFretboardView` — full neck with gliding dots

**Files:**
- Create: `audio_listen/Presentation/Chords/ChordFretboardView.swift`

**Interfaces:**
- Consumes: `PlacedChord`/`PlacedNote` (Task 1), `FretboardGeometry` (existing, drill), `Voicings`/`ChordPlacement`/`Instruments` (preview).
- Produces: `struct ChordFretboardView: View` with `let placedChord: PlacedChord` and `var showFingering: Bool = true`.

No unit test (a view); verified by build + `#Preview`. Both this new view and the old `ChordNeckView` exist after this task — that is fine, the build stays green.

- [ ] **Step 1: Create the view**

```swift
// audio_listen/Presentation/Chords/ChordFretboardView.swift
import SwiftUI

struct ChordFretboardView: View {
    let placedChord: PlacedChord
    var showFingering: Bool = true
    private let fretCount = 15
    private let stringCount = 6

    var body: some View {
        GeometryReader { proxy in
            let geo = FretboardGeometry(size: proxy.size, stringCount: stringCount, fretCount: fretCount)
            ZStack {
                fretLines(geo)
                strings(geo)
                inlays(geo)
                if showFingering {
                    mutedMarkers(geo)
                    dots(geo)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: placedChord)
        }
        .frame(minHeight: 220)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fretLines(_ geo: FretboardGeometry) -> some View {
        ForEach(0...fretCount, id: \.self) { fret in
            let x = geo.size.width / CGFloat(fretCount + 1) * CGFloat(fret + 1)
            Path { p in
                p.move(to: CGPoint(x: x, y: geo.stringY(1)))
                p.addLine(to: CGPoint(x: x, y: geo.stringY(stringCount)))
            }
            .stroke(Color.gray.opacity(fret == 0 ? 0.9 : 0.4), lineWidth: fret == 0 ? 3 : 1)
        }
    }

    private func strings(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1 + CGFloat(string - 1) * 0.15)
        }
    }

    private func inlays(_ geo: FretboardGeometry) -> some View {
        let inlayFrets = [3, 5, 7, 9, 12, 15]
        let centerY = geo.size.height / 2
        return ForEach(inlayFrets, id: \.self) { fret in
            Circle().fill(Color(white: 0.3)).frame(width: 8, height: 8)
                .position(x: geo.point(string: 1, fret: fret).x, y: centerY)
        }
    }

    private func dots(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            if let note = placedChord.notes.first(where: { $0.string == string }) {
                let point = geo.point(string: string, fret: note.fret)
                ZStack {
                    Circle().fill(note.isRoot ? Color.orange : Color(white: 0.93))
                    Text("\(note.finger)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(note.isRoot ? Color.black : Color(white: 0.1))
                }
                .frame(width: 24, height: 24)
                .position(point)
                .transition(.opacity)
            }
        }
    }

    private func mutedMarkers(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            if !placedChord.notes.contains(where: { $0.string == string }) {
                Text("✕")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
                    .position(x: 11, y: geo.stringY(string))
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
    let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar)
    ChordFretboardView(placedChord: placed).padding()
}
```

- [ ] **Step 2: Verify it builds and the preview renders**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`. In Xcode, open `ChordFretboardView.swift` and confirm the preview shows a full dark neck with the Gm7 grip (orange root on the low‑E string at the 3rd fret, finger "1" in each dot, muted markers on strings 5 and 1).

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Presentation/Chords/ChordFretboardView.swift
git commit -m "feat: full-neck ChordFretboardView with gliding finger-numbered dots"
```

---

### Task 4: Rework `ChordProgressionView`; delete the old camera-follow neck

**Files:**
- Modify: `audio_listen/Presentation/Chords/ChordProgressionView.swift`
- Modify: `audio_listen/Domain/UseCases/ChordPlacement.swift` (remove the now-dead `positions`/`rootPosition`)
- Delete: `audio_listen/Presentation/Chords/ChordNeckView.swift`
- Delete: `audio_listen/Presentation/Chords/ChordNeckGeometry.swift`
- Delete: `audio_listenTests/ChordNeckGeometryTests.swift`

**Interfaces:**
- Consumes: `ProgressionSession`, `AutoAdvance` (Task 2), `ChordFretboardView` (Task 3), `ChordPlacement`/`Voicings`/`ChordNaming`/`Progressions`, `Instruments`.

- [ ] **Step 1: Replace `ChordProgressionView.swift` in full**

```swift
// audio_listen/Presentation/Chords/ChordProgressionView.swift
import SwiftUI

struct ChordProgressionView: View {
    @StateObject private var session: ProgressionSession
    @StateObject private var auto = AutoAdvance()
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
        let current = placed(session.currentStep)
        VStack(spacing: 16) {
            selectors
            VStack(spacing: 4) {
                Text(name(session.currentStep))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .contentTransition(.numericText())
                HStack(spacing: 8) {
                    Text("\(current.rootFret)fr").foregroundStyle(Color.orange)
                    Text("·").foregroundStyle(.secondary)
                    Text("next: \(name(session.nextStep))").foregroundStyle(.secondary)
                }
                .font(.subheadline.monospaced())
            }
            ChordFretboardView(placedChord: current, showFingering: session.revealed)
                .padding(.horizontal)
            transport
        }
        .padding(.vertical)
        .onChange(of: session.index) { _ in persist() }
        .task(id: TimerKey(playing: auto.isPlaying, pace: auto.pace, index: session.index)) {
            guard auto.isPlaying else { return }
            try? await Task.sleep(nanoseconds: UInt64(auto.pace * 1_000_000_000))
            if !Task.isCancelled { session.advance() }
        }
    }

    private var transport: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    auto.isPlaying = false
                    session.previous()
                } label: {
                    Image(systemName: "chevron.left").font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                }
                .buttonStyle(.bordered)

                Button { auto.isPlaying.toggle() } label: {
                    Image(systemName: auto.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    auto.isPlaying = false
                    session.primaryAction()
                } label: {
                    Text(primaryLabel).font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Text("pace").font(.caption).foregroundStyle(.secondary)
                Slider(value: Binding(get: { auto.pace }, set: { auto.pace = $0 }),
                       in: AutoAdvance.minPace...AutoAdvance.maxPace)
                Text(String(format: "%.1fs", auto.pace)).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var primaryLabel: String {
        session.displayMode == .nameOnly && !session.revealed ? "Reveal" : "Next ›"
    }

    private var selectors: some View {
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

private struct TimerKey: Hashable {
    let playing: Bool
    let pace: TimeInterval
    let index: Int
}

#Preview {
    ChordProgressionView(
        session: ProgressionSession(progression: Progressions.byId("major-ii-v-i")!),
        instrument: Instruments.guitar,
        store: ProgressionSelectionStore()
    )
}
```

- [ ] **Step 2: Delete the old camera-follow neck**

```bash
git rm audio_listen/Presentation/Chords/ChordNeckView.swift audio_listen/Presentation/Chords/ChordNeckGeometry.swift audio_listenTests/ChordNeckGeometryTests.swift
```

- [ ] **Step 3: Remove the now-dead `positions`/`rootPosition` from `PlacedChord`**

Nothing references them anymore (Task 1 moved the tests to `notes`; the old view is deleted). Edit `audio_listen/Domain/UseCases/ChordPlacement.swift`: remove the `positions` and `rootPosition` stored properties from `PlacedChord`, and delete the two lines in `place` that build them, so `place` returns `PlacedChord(rootFret: fret, notes: notes)`. Final state:

```swift
struct PlacedChord: Hashable {
    let rootFret: Int
    let notes: [PlacedNote]
}

enum ChordPlacement {
    static func rootFret(rootPitchClass: Int, onString stringNumber: Int, instrument: Instrument) -> Int {
        let open = instrument.note(at: stringNumber, fret: 0)!.name.semitonesFromC
        let base = (((rootPitchClass - open) % 12) + 12) % 12
        return base == 0 ? 12 : base
    }

    static func place(voicing: Voicing, rootPitchClass: Int, instrument: Instrument) -> PlacedChord {
        let rootStringNumber = voicing.rootString.stringNumber
        let fret = rootFret(rootPitchClass: rootPitchClass, onString: rootStringNumber, instrument: instrument)
        let notes = voicing.positions.map { position in
            PlacedNote(
                string: position.string,
                fret: fret + position.fretOffset,
                finger: position.finger,
                isRoot: position.string == rootStringNumber && position.fretOffset == 0
            )
        }
        return PlacedChord(rootFret: fret, notes: notes)
    }
}
```

(`FretPosition` import is no longer needed by this file; if the file has no other `FretPosition` use, that's fine — there's no explicit import to remove since it's the same module.)

- [ ] **Step 4: Verify the whole app builds**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`. (If a stale reference to `ChordNeckView`, `ChordNeckGeometry`, `.positions`, or `.rootPosition` remains, the build names the file/line — fix that reference.)

- [ ] **Step 5: Run the full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:audio_listenTests 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. The `ChordNeckGeometryTests` are gone; `AutoAdvanceTests`, `ChordPlacementTests`, `ChordFormulaConformanceTests`, and all pre-existing suites pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: rework chord screen with full neck + auto-advance; drop camera-follow neck"
```

- [ ] **Step 7: Run the app and eyeball it (human check)**

In Xcode, run on the iPhone 17 simulator, open the **Chords** tab: the neck fills the pane and grows when you resize the window; Play auto-advances at the pace slider's setting (1–6 s); dots glide between chords along the neck; the eye toggle hides the grip (name-only recall) and the primary button reads "Reveal"; Prev/Next pause auto-advance.

---

## Deferred (unchanged from the parent roadmap)

- Metronome / click track; A5/D4 tiers; the cell-recombination generator; mastery tracking. `ChordPlacement.rootFret`'s `note(at:)!` stays guitar-safe (mode wired to `Instruments.guitar`) — harden when a non-guitar path first becomes reachable.
