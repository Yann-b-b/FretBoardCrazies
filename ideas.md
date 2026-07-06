## Done ✅

1. Combo escalation (streak feedback) — **shipped**
   - [x] fix fretboard shrinking when the flame icon appears (constant-height slots)
   - [x] replace the beep with script-generated tiered cues + tier-up stingers
   - [x] rainbow flame at 50+
   - [x] full escalation curve: wiggle grows → calm at 15 → re-energize at 25 → rainbow at 50
   - [x] welcome screen with floating belt/flame sprites
   - [x] string-selection dropdown (singles + presets, default Low E + A)
   - [x] touch mode: ignore taps on the non-asked string
   - [x] fretboard inlay dots (frets 3/5/7/9, double at 12)
   - [x] floating bubble nav rail + compact landscape layout (iOS)

## Next up 🔜

2. **Focus mode** — single-note drill on one string, play it as fast as possible.
   New view + new nav entry (working name "Focus"). Random string with anti-repeat.
3. **Achievements page** — per mode: reach 100, and hit a 50 streak. Start with just these two.

## 🎸 v2.0 — Chord Trainer (big)

The next major direction. Reframes the app: it's fundamentally a **fretboard
note-location trainer**, and chords are the vehicle — every chord rep reduces to "find the
root on the given string, then play the shape you already know." Tracks **two independent
mastery axes** (shape `chordId:rootString`, note `note:rootString`), two modes (**A** =
shape mastery / nodes, **B** = transitions / edges), and practice axes for root string
(E6/A5/D4), chord family, tier, and melodic-pattern contour. Full vision:
`docs/v2-chord-trainer-vision.md`. Big enough to be **v2.0** — needs decomposition into
sub-projects + repo-readiness groundwork before building. The current single-note drill is
already the "note mastery" engine, so much of the foundation is reusable.

## Backlog 💭

4. Advanced: choose which frets to drill (e.g. frets 0–5 or 6–11).
5. Show the next note before the first is played once you're getting too fast.
6. Improvisation of next notes — ML setup or basic fretboard heuristics.
7. Chord page — how would it look? Start small.

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

**Partly addressed:** touch mode now ignores taps on the non-asked string
(`DrillViewModel.submitTouch` guard). Guitar/mic mode is still note-only (below).

Find-position validation is currently **note-only** — it never checks the string.
"Find C on string 5" is satisfied by answering C on *any* string (the mic can't tell
which string you used anyway). Consider making find-position actually require the
asked string, for guitar *and* touch — a stricter, more accurate drill.

Cost: validation grows a string check, and the input would need to carry the tapped
`FretPosition` (not just the bare `Note`), since the string can't be recovered from a
note alone. Surfaced during touch-mode design — the wrong-answer dot currently derives
its position on the *asked* string, which is consistent with the note-only judging; if
we enforce the string, the dot would instead want the literal tapped position.

### iOS landscape layout pass

**Largely done for Drill:** compact-aware heights/fonts + floating bubble nav rail
via `safeAreaInset` mean the Drill screen now fits landscape without the tab bar
overlapping the controls. Remaining: give the other tabs (esp. Tuner's Start/Stop)
the same compact pass, and isolate the `#if os(macOS)` window-minimums per the note
above.

The screens were designed for a roomy Mac window; on a landscape iPhone (~393pt tall)
some content overflows. Concretely: on the **Drill** screen the content (header +
fretboard `minHeight 220` + the large prompt + the control row) is taller than the
screen, so the bottom Start/End/Next row spills into the bottom safe area and ends up
**behind the tab bar** (unreachable). Likely affects other tabs with bottom content
(Tuner's Start/Stop) too.

Not a touch-mode bug — it's a macOS→iOS adaptation gap. Fix direction: make the
background a `ZStack` (only the background `.ignoresSafeArea()`, content stays above the
tab bar) AND compact the landscape layout so it fits (smaller fretboard / fonts /
spacing on iOS). Avoid a `ScrollView` on Drill — it fights the fretboard tap gesture in
touch mode. Needs iteration on the simulator; worth its own focused pass.
