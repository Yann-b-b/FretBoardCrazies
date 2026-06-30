1. A timer + the number of notes played so far
2. A streak of some kind ?
3. Advance Feature: which frets to play (like frets 0-5 or 6-11)
4. show the next note before the first is played once you are getting too fast
5. improvisation of next notes using some machine learning setup or just some basic knowledge of the fretboard and

---

## Tech debt / refactor notes (for later)

### Platform abstraction (macOS vs iOS)

**Problem:** a few `#if os(macOS)` conditionals now live inside shared views for the
macOS window-minimum sizes — `ContentView` (720×560), `DrillView` and `MasteryView`
(640×480 / 640). They were added when locking iPhone to landscape, so the Mac
window-minimum wouldn't force the layout taller than a phone screen and push the
tab bar off-screen. Views shouldn't carry scattered `#if/else`.

**Reality:** you *isolate* the conditional, you don't *eliminate* it — give it one
well-named home instead of sprinkling it through view bodies.

**Options (light → heavy):**
- **A. Custom `ViewModifier`** — a `.windowMinSize()` `View` extension that wraps the
  `#if os(macOS)`; views just call `.windowMinSize()`. Right-sized for the ~3 sites
  today. **(Recommended starting point.)**
- **B. Platform constants type** — centralize the magic numbers (e.g. `PlatformMetrics`)
  when there are many values, not just a few.
- **C. `@Environment` injection** — a platform-config struct injected at the root and
  read via `@Environment`; gives zero `#if` in view bodies, overridable in previews/
  tests. Only worth it if iOS and macOS start diverging a lot.
- **D. Per-platform view files / `#if`-selected types** — heavy, duplication-prone;
  reserve for large divergence.

**Cleanest for this case:** the window-minimum is really a macOS **Scene** concern, so
push it to the `WindowGroup` in `audio_listenApp.swift` (e.g.
`.windowResizability(.contentMinSize)`) rather than into shared views — then the views
become fully platform-agnostic.

**Note:** SwiftUI already adapts `TabView` (top tabs on macOS vs bottom bar on iOS),
`Form`, and most controls per platform automatically — so most views need no
conditionals at all; the goal is just to keep the few genuine platform values out of
shared view bodies.

### Find-position: enforce the asked string (both modes)

Find-position validation is currently **note-only** — it never checks the string.
"Find C on string 5" is satisfied by answering C on *any* string (the mic can't tell
which string you used anyway). Consider making find-position actually require the
asked string, for guitar *and* touch — a stricter, more accurate drill.

Cost: validation grows a string check, and the input would need to carry the tapped
`FretPosition` (not just the bare `Note`), since the string can't be recovered from a
note alone. Surfaced during touch-mode design — the wrong-answer dot currently derives
its position on the *asked* string, which is consistent with the note-only judging; if
we enforce the string, the dot would instead want the literal tapped position.
