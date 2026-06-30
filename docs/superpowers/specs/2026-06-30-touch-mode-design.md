# Touch Mode — Design

Date: 2026-06-30
Topic: Add a "touch mode" so the fretboard drill can be played by tapping the
note on screen, alongside the existing "guitar mode" (play it, detected via mic),
so the game can be trained anywhere without an instrument.

## Goal

Let the user answer find-position prompts by tapping the fret on screen instead
of playing it on a guitar. The choice is a setting; everything downstream of
"which note did the user answer" is reused unchanged.

## Guiding principle

Vary the **input**, not the ViewModel (Strategy + Dependency Inversion). There
is one `DrillViewModel`; guitar vs touch is a swapped input source behind a
protocol. The whole answer pipeline — validate → record → spaced-repetition →
belts → combo → advance — is identical for both modes.

## Decisions (locked)

- **Input abstraction:** a new `NoteInputSource` protocol that emits bare `Note`
  values. Both the mic and touch conform; the ViewModel depends on the protocol.
- **Touch scope (first cut):** find-position prompts only (name-this-note is set
  to probability 0 in touch mode). Validation is the existing note-equality check,
  untouched. Name-note on touch is out of scope (a later, richer addition).
- **Mode switch:** a "Touch mode" toggle in Settings (`@AppStorage` via
  `GameSettingsKeys`), read at ViewModel construction; takes effect when the drill
  (re)starts. A live in-Drill switch is out of scope.
- **Wrong-answer dot:** on a non-matching answer, the position is **derived** from
  the answered note + the prompt's string (not carried through the abstraction):
  `GuitarFretboard.positions(for: note).first { $0.string == prompt.string }`.
  This is published as `lastWrongPosition` and drawn by `FretboardView` as a coral
  dot, cleared on the next prompt. Because it is derived from the note, the **same
  `handle()` path produces it for both modes** (guitar gets it too, alongside the
  existing live "Detected: X" text).
- **Correct-answer dot:** none added — the existing `.success` reveal already draws
  the correct position dot.

## Architecture

### New files

- `audio_listen/Domain/Protocols/NoteInputSource.swift` — protocol:
  ```swift
  protocol NoteInputSource {
      var notes: AnyPublisher<Note, Never> { get }
      func start()
      func stop()
  }
  ```
- `audio_listen/Infrastructure/Input/MicNoteSource.swift` —
  `NoteInputSource` that wraps the existing `PitchDetectorProtocol` chain, maps
  `currentPitch` → `pitch.note`; `start()/stop()` drive the mic.
- `audio_listen/Infrastructure/Input/TouchInputSource.swift` —
  `NoteInputSource` whose `notes` is a `PassthroughSubject<Note, Never>`;
  `start()/stop()` are no-ops; adds
  `func submit(_ position: FretPosition)` that does
  `GuitarFretboard.note(at: position.string, fret: position.fret)` and, if
  non-nil, sends it on the subject.

### Modified files

- `audio_listen/Presentation/Drill/FretboardGeometry.swift` — add the inverse of
  `point(string:fret:)`:
  `func hitTest(point: CGPoint) -> FretPosition?` (clamps to `1...stringCount`,
  `0...fretCount`; returns nil outside the board). Pure + unit-tested.
- `audio_listen/Presentation/Drill/DrillViewModel.swift`:
  - dependency `pitchDetector: PitchDetectorProtocol` → `input: NoteInputSource`.
  - `handle(_ pitch:)` → `handle(_ note:)`; subscribe to `input.notes`;
    `startListening()/stopListening()` call `input.start()/stop()`.
  - add `@Published private(set) var lastWrongPosition: FretPosition?`; set it in
    the wrong branch of `handle()` (derived as above); clear it on a new prompt
    (`start`/`advance`) and on success.
  - add `func submitTouch(_ position: FretPosition)` that forwards to a
    `touchSubmit: ((FretPosition) -> Void)?` closure injected by the container
    (nil in guitar mode). This keeps the View's single collaborator the ViewModel.
- `audio_listen/Presentation/Drill/FretboardView.swift` — add two optional params:
  `onTap: ((FretPosition) -> Void)? = nil` (attaches a tap gesture using the
  `GeometryReader` size + `hitTest`) and `wrongPosition: FretPosition? = nil`
  (drawn as a coral dot). Both default nil, so the Progress heatmap is unaffected.
- `audio_listen/Presentation/Drill/DrillView.swift` — in touch mode, pass
  `onTap: { viewModel.submitTouch($0) }` and
  `wrongPosition: viewModel.lastWrongPosition` to the `.playing`-state
  `FretboardView`. Read the mode from `@AppStorage`.
- `audio_listen/DI/AppDependencyContainer.swift` — in `makeDrillViewModel()`,
  read `GameSettingsKeys.touchMode`. If touch: build a `TouchInputSource`, inject
  it as `input`, pass `touchSubmit: touchSource.submit`, and use
  `SelectNextPromptUseCase(nameNoteProbability: 0)`. Else: `MicNoteSource` wrapping
  the existing chain, `touchSubmit: nil`, default `SelectNextPromptUseCase()`.
- `audio_listen/Infrastructure/Game/GameSettingsKeys.swift` — add a `touchMode`
  key.
- `audio_listen/Presentation/Settings/SettingsView.swift` — add a "Touch mode"
  `Toggle` bound to `@AppStorage(GameSettingsKeys.touchMode)`.

## Data flow (touch)

1. `FretboardView` tap → `hitTest` → `FretPosition`.
2. `onTap` → `viewModel.submitTouch(position)` → `touchSubmit` →
   `TouchInputSource.submit` → `note(at:)` → emits on `notes`.
3. `DrillViewModel.handle(note)` (the single, shared answer path):
   - correct → `.success` (existing reveal draws the correct dot);
   - wrong → `lastWrongPosition = positions(for: note).first { string == prompt.string }`
     → `FretboardView` draws the coral dot until the next prompt.
4. No mic is touched in touch mode (`start/stop` are no-ops; no permission prompt).

## Testing

- `FretboardGeometry.hitTest` — taps map to the expected `(string, fret)`;
  boundary/clamping cases (added to `FretboardGeometryTests`).
- `TouchInputSource.submit` — a position emits the correct note; out-of-range
  emits nothing.
- `MicNoteSource` — emits `pitch.note` for a fed pitch.
- `DrillViewModelTests` — replace `StubPitchDetector` with a `NoteInputSource`
  stub (drop-in); add: a wrong note sets `lastWrongPosition` to the wrong note's
  position on the prompt's string; a correct answer clears it and reaches
  `.success`.
- Touch wiring — with `touchMode` on, prompts are find-position only
  (`nameNoteProbability` 0).

## Known caveat (to revisit)

The wrong-dot shows the answered note's position **on the asked string**, not the
literal string the user touched. For "find C on string 5" this is coherent
feedback, and it is exactly what lets guitar and touch share one code path. If
literal tapped-string feedback turns out to matter, the abstraction would need to
carry the tapped `FretPosition` (a small change to `NoteInputSource`).

## Out of scope

- Name-this-note on touch (note-name buttons + a richer answer type).
- A live guitar/touch switch on the Drill screen.
- Haptics / wrong-tap animation beyond the coral dot.
