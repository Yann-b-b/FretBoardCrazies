# Instrument Abstraction — Design

**Date:** 2026-07-03
**Status:** Approved for planning
**Branch context:** `ios-drill-layout`

## Goal

Replace the hardcoded `GuitarFretboard` static god-struct with a data-driven,
injectable **`Instrument`** value type so that future sprints can add instruments
(bass, banjo) — and alternate tunings — by adding *data*, never by editing existing
code. This sprint refactors to the abstraction and keeps **guitar as the only wired
instrument** (no picker, no persistence, no new UI).

## Design principle

This is the **Type Object** pattern: one `Instrument` type whose *instances* play the
role subclasses would, with the per-instrument variation held as data rather than a
class hierarchy. It follows from:

- **Composition/data over inheritance** — no `Guitar`/`Bass`/`Banjo` subclasses.
- **Open/Closed Principle** — adding an instrument *adds* a catalog entry; it never
  modifies existing code.
- **Dependency injection** — the current instrument is injected from the container,
  so nothing hardcodes which instrument (or how many strings) is in play.

A tuning change is the same abstraction with a different open-notes list, so alternate
tunings fall out for free later — but a `Tuning` concept is explicitly **out of scope**
here (see below).

## The model

Three new value types in `Domain/Models/`:

```swift
struct GuitarString {          // per-string data; a banjo drone is just data
    let openNote: Note
    let startFret: Int         // 0 for normal strings; e.g. 5 for a banjo 5th-string drone
}

struct Instrument {
    let id: String
    let name: String
    let strings: [GuitarString]        // string 1 = index 0; stringCount = strings.count
    let fretCount: Int

    var stringCount: Int { strings.count }

    func note(at string: Int, fret: Int) -> Note?
    func positions(for note: Note, maxFretInclusive: Int) -> [FretPosition]
}
```

### Semantics

- `note(at:fret:)`:
  - `nil` when `string < 1 || string > stringCount`.
  - `nil` when `fret < startFret` (the string does not sound below its start) or
    `fret > fretCount`.
  - otherwise pitch = `openNote.midiNumber + (fret - startFret)`, mapped back via
    `Note.from(midiNumber:)`.
- `positions(for:maxFretInclusive:)`: for each string, `fret = (targetMidi - openMidi) +
  startFret`; keep it only if `startFret <= fret <= min(maxFretInclusive, fretCount)`.

Guitar has every `startFret = 0`, so both methods reproduce today's behavior exactly.
The `startFret` field is included now (even though only guitar ships) because it is the
one property that is awkward to retrofit later; bass needs only fewer strings.

## The catalog + selection

```swift
enum Instruments {                      // the single "add an instrument here" spot
    static let guitar = Instrument(
        id: "guitar",
        name: "Guitar",
        strings: [
            Note(.e, octave: 4), Note(.b, octave: 3), Note(.g, octave: 3),
            Note(.d, octave: 3), Note(.a, octave: 2), Note(.e, octave: 2)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 24
    )
    static let all = [guitar]           // bass/banjo added later as one line each
}
```

**Lifecycle.** `Instrument` is an immutable value type with no resources, so the
catalog is **constructed once as static constants and shared** — never instantiated
on demand. (Contrast the heavy, stateful audio/input objects, which are correctly
built per-drill in `makeDrillViewModel`.) The only thing with a lifecycle is the
*selection* of the current instrument.

**Selection seam (this sprint).** `AppDependencyContainer` holds a plain
`let instrument: Instrument = Instruments.guitar` and injects it into the factories,
exactly as it already injects the string/note providers. When a picker lands in a
later sprint, this single property is promoted to a stored/`@Published` selection, and
switching it re-creates the drill view model with the new instrument — the same
re-creation pattern as the existing `.id(touchMode)` in `ContentView`. Consumers never
reach into the catalog; only the container chooses the current instrument.

## Refactor map (live consumers only)

- **Delete `Domain/Models/GuitarFretboard.swift`.** Move its `Note.from(midiNumber:)`
  extension into `Note.swift` (neutral home). Drop `playableNotes` (only the dead
  strategies referenced it).
- Route the live static consumers through the injected `instrument`:
  - `Domain/UseCases/SelectNextPromptUseCase.swift` — gains an `instrument` property;
    replaces `GuitarFretboard.note(at:)`.
  - `Infrastructure/Input/TouchInputSource.swift` — takes the instrument via init;
    replaces `GuitarFretboard.note(at:)`.
  - `Infrastructure/Game/UserDefaultsMaxFretProvider.swift` — reads
    `instrument.fretCount` instead of `GuitarFretboard.fretCount`.
  - `Presentation/Drill/DrillView.swift` (line ~223) — receives the instrument and
    calls `instrument.positions(for:)` to reveal the correct dot.
- **View geometry:** `FretboardView` reads `instrument.stringCount` / `instrument.fretCount`
  instead of the hardcoded `stringCount = 6`. `FretboardGeometry` is already
  parameterized and unchanged.
- **String-count literals:** replace `1...6` in `Infrastructure/Game/StringSetPresets.swift`
  and `Infrastructure/Game/GameAllowedStringsStore.swift` with
  `1...Instruments.guitar.stringCount` — one source of truth, no magic number.

### Explicitly left alone (flagged, not touched)

- `Infrastructure/Game/RandomNoteStrategy.swift` and
  `Infrastructure/Game/RandomNoteNamePositionStrategy.swift` — **dead code** (no call
  sites). Flagged for a separate cleanup task, not deleted here to keep this refactor
  focused.
- `Domain/Models/GameSessionConfiguration.swift` — only self-referential; its `1...6`
  is not on any live path. Left as-is.

## Testing

- **New `InstrumentTests` (Swift Testing):**
  - Known notes: string 6 / fret 0 = E2, string 1 / fret 0 = E4, string 5 / fret 0 = A2.
  - `positions(for:)` round-trips a note to the expected `(string, fret)` set and
    respects `maxFretInclusive`.
  - Out-of-range: `fret > fretCount` and `string` outside `1...stringCount` → `nil`.
  - Drone: a synthetic instrument with one string at `startFret: 5` — `note(at: fret 3)`
    is `nil`, `note(at: fret 5)` equals the open pitch, and `positions(for:)` offsets
    correctly.
- **Update existing tests** that name `GuitarFretboard` to use `Instruments.guitar`.
- Whole suite stays green; guitar behavior is byte-for-byte identical, so no
  drill/combo test changes meaning.

## Out of scope

- Instrument **picker** UI, and persisting a selection.
- Wiring **bass / banjo** (the model supports them; only guitar ships).
- A `Tuning` type / tuning presets (the model already absorbs alternate tunings as a
  different open-notes list; a dedicated tuning matrix is a later refinement).
- Deleting the dead `Random*Strategy` files (separate cleanup task).
- Focus mode (its own later sprint, built on top of this abstraction).
