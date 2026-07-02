# Welcome Screen — Design

**Date:** 2026-07-02
**Status:** Approved for planning
**Branch context:** `ios-drill-layout` (session work in progress)

## Goal

Add an on-opening welcome/landing screen. When the app launches, the user sees
the currently-unused welcome background, the app name, a one-line description,
and a single button that enters the main app (the existing tabbed/rail UI, which
opens on the Drill tab).

## Decisions (from brainstorm)

- **Shown every launch**, not first-run-only. It is a lightweight title/home
  screen (logo + one line + one button), not multi-step onboarding.
  - Rationale: simplest to build (in-memory state, no persistence), the
    background is seen each session, and it is trivially reversible later
    (`@State` → `@AppStorage`) if the daily tap becomes friction.
- **Copy stays to one short line** so returning users are not re-reading a
  paragraph every launch; the eye goes straight to the button.
- **No ViewModel** — this is a pure view plus a single boolean gate. Adding a
  ViewModel would be ceremony with no logic to hold.

## Architecture

A root coordinator chooses between the welcome screen and the existing app:

```
RootView
 ├─ @State private var started = false
 ├─ if !started → WelcomeView(onStart: { started = true })
 └─ else        → ContentView()
```

- Transition between the two is a `.transition(.opacity)` fade (wrapped in
  `withAnimation` when the flag flips).
- `RootView` holds the gate so the `@main` App file stays a one-liner.

### Components

**`WelcomeView`** (new, pure SwiftUI View)
- Purpose: present the landing screen and signal "enter the app."
- Interface: `init(onStart: @escaping () -> Void)`. Owns no persistent state.
- Body: `ZStack { Image("bg-welcome") full-bleed (.resizable().scaledToFill().ignoresSafeArea()) ; VStack { appName ; description ; startButton } }`.
- The button calls `onStart()`.
- Landscape/compact-aware (the app is landscape-locked): read
  `@Environment(\.verticalSizeClass)` and tighten spacing/fonts when `.compact`,
  consistent with `DrillView`.

**`RootView`** (new)
- Purpose: the welcome-vs-app gate. Holds `@State started`, renders `WelcomeView`
  or `ContentView`, applies the fade.
- Depends on: `WelcomeView`, `ContentView`. No other dependencies.

**`ContentView`** (unchanged)
- Already opens on the Drill tab, so "move onto drill/tuner/progress" needs no
  change here.

## Data flow

1. App launches → `RootView` renders with `started == false` → `WelcomeView`.
2. User taps "Get started" → `onStart()` sets `started = true` inside
   `withAnimation`.
3. `RootView` re-renders → `ContentView` fades in.
4. State is in-memory, so the next cold launch shows the welcome screen again.

## Files touched

| File | Change |
|---|---|
| `audio_listen/Presentation/Welcome/WelcomeView.swift` | **new** — landing screen |
| `audio_listen/RootView.swift` | **new** — welcome-vs-app gate |
| `audio_listen/audio_listenApp.swift` | **modified** — `WindowGroup { RootView() }` |
| `audio_listen/Assets.xcassets/bg-welcome.imageset/` | **new** — imageset importing the light/dark PNGs |

### Asset import detail

`art/bg-welcome-light.png` and `art/bg-welcome-dark.png` already exist but were
never added to the catalog. Create `bg-welcome.imageset/` containing both PNGs
and a `Contents.json` matching the existing `bg-drill.imageset` pattern (light =
default, dark = `luminosity/dark` appearance). This makes `Image("bg-welcome")`
resolve and gives automatic dark-mode support.

### Build integration

New `.swift` files land in the existing synchronized project group and are
picked up automatically (as prior new files this session were). The new imageset
is picked up by the asset catalog automatically. No `project.pbxproj` surgery
expected.

## Copy (draft — tweak in review)

- App name: **FretboardCrazies**
- Description (one line): **"Learn every note on the fretboard, one drill at a time."**
- Button: **"Get started"**

## Testing

This feature is UI-only: a view plus a boolean toggle. There is no meaningful
pure logic to unit-test, and asserting on SwiftUI view state requires a
view-inspection dependency this project does not use. Verification is therefore
by running on the simulator:

- App opens on the welcome screen with the `bg-welcome` background visible.
- The description reads as one short line; button is reachable in landscape.
- Tapping "Get started" fades into the Drill screen.
- Relaunching shows the welcome screen again (confirms every-launch behavior).

Existing test suites must remain green (no behavior change to `ContentView` or
the drill engine).

## Out of scope

- Persistence / first-run-only behavior (explicitly deferred; one-line change if
  wanted later).
- Multi-step onboarding, animations beyond the fade, or a settings toggle to
  re-show it.
