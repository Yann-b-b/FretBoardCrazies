# Welcome Screen — Design

**Date:** 2026-07-02
**Status:** Approved for planning
**Branch context:** `ios-drill-layout` (session work in progress)

## Goal

Add an on-opening welcome/landing screen. When the app launches, the user sees
the currently-unused welcome background, decorative belt/flame sprites, the app
name, a one-line description, and a single button that enters the main app (the
existing tabbed/rail UI, which opens on the Drill tab).

## Decisions (from brainstorm)

- **Shown every launch**, not first-run-only. It is a lightweight title/home
  screen, not multi-step onboarding.
  - Rationale: the background is seen each session, and the every-launch vs
    first-run choice is trivially reversible later (in-memory route vs a
    persisted flag).
- **Copy stays to one short line** so returning users are not re-reading a
  paragraph every launch; the eye goes straight to the button.
- **Top-level flow is modeled as a state enum in a ViewModel, not a `Bool`** —
  mirroring the app's existing `DrillState` + `DrillViewModel` idiom, and built
  through `AppDependencyContainer` like the other ViewModels.
- **Decorative sprites**: the 2 flame assets flank the button; the 8 belt assets
  drift across the top and bottom edges.

## Architecture

A root coordinator chooses between the welcome screen and the existing app,
driven by a ViewModel that owns a route enum:

```swift
enum AppRoute { case welcome, main }

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute = .welcome
    func enterApp() { route = .main }
}
```

- `RootViewModel` is constructed via `AppDependencyContainer.makeRootViewModel()`,
  consistent with how `ContentView` obtains its ViewModels.
- `RootView` holds it as `@StateObject`, switches on `route`, and fades between
  screens (`.transition(.opacity)` inside `withAnimation`).
- `WelcomeView` calls `viewModel.enterApp()` — passed in as an `onStart` closure
  so `WelcomeView` stays dependency-free and previewable.

Why the enum + ViewModel over a `Bool`:
- Named states (`.welcome` / `.main`) and `enterApp()` read as intent.
- Extensible — future phases (`.onboarding`, `.paused`) drop in without
  reshaping the type or touching indifferent call sites.
- Matches the codebase idiom, so it reads like it belongs.
- Testable — `enterApp()` flipping the route is a real unit test.

### Components

**`RootViewModel`** (new, `ObservableObject`)
- Purpose: own the top-level `AppRoute` and the `enterApp()` transition.
- Built by `AppDependencyContainer.makeRootViewModel()`. No dependencies today;
  going through the container keeps the construction pattern uniform and leaves
  room to inject later (e.g., a persisted flag if this becomes first-run-only).

**`RootView`** (new)
- Purpose: the welcome-vs-app gate. `@StateObject var viewModel` from the
  container; renders `WelcomeView(onStart: viewModel.enterApp)` or
  `ContentView()` based on `viewModel.route`, with the fade.

**`WelcomeView`** (new, pure SwiftUI View)
- Interface: `init(onStart: @escaping () -> Void)`. Owns no persistent state.
- Layout:
  ```
  ZStack {
      Image("bg-welcome").resizable().scaledToFill().ignoresSafeArea()   // back
      FloatingBeltsView()                                                // belts, top & bottom
      VStack {                                                           // front
          appName
          description
          HStack { Image("flame-small") ; startButton ; Image("flame-large") }
      }
  }
  ```
- The two flames flank the "Get started" button (small on one side, large on the
  other), sized modestly and optionally given a subtle pulse.
- Landscape/compact-aware (app is landscape-locked): read
  `@Environment(\.verticalSizeClass)` and tighten spacing/fonts when `.compact`,
  consistent with `DrillView`.

**`FloatingBeltsView`** (new, decorative SwiftUI View)
- Purpose: drift the 8 belt sprites across the top and bottom edges.
- Split the belts into a top group and a bottom group (e.g., 4 + 4), each placed
  at deterministic seeded positions (a fixed layout array — no runtime
  randomness, so it composes the same each launch and is easy to tune).
- Gentle continuous motion: slow vertical bob + slight rotation + soft opacity
  pulse, each sprite phase-offset so they don't move in lockstep. Kept
  low-opacity and edge-anchored so they never fight the text/button.

**`ContentView`** (unchanged) — already opens on the Drill tab.

## Data flow

1. Launch → `RootView` builds `RootViewModel` (route `.welcome`) → `WelcomeView`.
2. User taps "Get started" → `onStart()` → `viewModel.enterApp()` sets route
   `.main` (inside `withAnimation`).
3. `RootView` re-renders → `ContentView` fades in.
4. Route is in-memory, so the next cold launch shows the welcome screen again.

## Files touched

| File | Change |
|---|---|
| `audio_listen/Presentation/Welcome/WelcomeView.swift` | **new** — landing screen (bg + flames + copy + button) |
| `audio_listen/Presentation/Welcome/FloatingBeltsView.swift` | **new** — drifting belt sprites, top & bottom |
| `audio_listen/Presentation/Root/RootView.swift` | **new** — welcome-vs-app gate |
| `audio_listen/Presentation/Root/RootViewModel.swift` | **new** — `AppRoute` enum + `RootViewModel` |
| `audio_listen/DI/AppDependencyContainer.swift` | **modified** — add `makeRootViewModel()` |
| `audio_listen/audio_listenApp.swift` | **modified** — `WindowGroup { RootView() }` |
| `audio_listen/Assets.xcassets/bg-welcome.imageset/` | **new** — imageset importing the light/dark PNGs |

### Asset import detail

`art/bg-welcome-light.png` and `art/bg-welcome-dark.png` exist but were never
added to the catalog. Create `bg-welcome.imageset/` containing both PNGs and a
`Contents.json` matching the existing `bg-drill.imageset` pattern (light =
default, dark = `luminosity/dark`). Makes `Image("bg-welcome")` resolve with
automatic dark-mode support. The flame and belt sprites are already in the
catalog and need no import.

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

- **`RootViewModelTests`** (new): route starts at `.welcome`; `enterApp()`
  transitions it to `.main`. This is the real logic worth covering.
- The views (`WelcomeView`, `FloatingBeltsView`) are decorative/UI-only with no
  pure logic; verify them on the simulator rather than with brittle UI tests:
  - App opens on the welcome screen; `bg-welcome` visible; flames flank the
    button; belts drift along top and bottom.
  - Copy reads as one short line; button reachable in landscape.
  - Tapping "Get started" fades into the Drill screen.
  - Relaunch shows the welcome screen again (confirms every-launch behavior).
- Existing suites remain green (no behavior change to `ContentView` or the drill
  engine).

## Out of scope

- Persistence / first-run-only behavior (deferred; swap the in-memory route for
  an injected persisted flag if wanted later).
- Multi-step onboarding, elaborate particle systems, or a settings toggle to
  re-show the welcome screen.
