# Window-Sizing Consolidation — Design

**Date:** 2026-07-05
**Status:** Approved for planning
**Branch context:** `dev`

## Goal

Remove the scattered macOS window-minimum `#if os(macOS)` conditionals from shared view bodies
(`ContentView`, `DrillView`, `MasteryView`) and consolidate window sizing into the one place it
belongs — the `Scene` in `audio_listenApp.swift`. Behavior is unchanged; the shared views become
platform-agnostic.

## Rationale

Window sizing is a **Scene** concern, not a view concern. Today the macOS window minimum
(`720×560`) lives inside `ContentView`'s macOS branch, and two tabs (`DrillView` 640×480,
`MasteryView` 640) carry their own macOS minimums that can never bind (the window is already
≥720 wide, so a 640 tab minimum is dead). This is "scattered `#if` in shared views" — the exact
debt called out in `ideas.md`. The principle is **isolate, not eliminate**: give the one genuine
platform value a single named home.

Scope is strictly the three window-sizing `#if os(macOS)` sites. The other two platform
conditionals are intentional and stay:
- `ContentView`'s `#if os(iOS)` NavRail-vs-TabView — a deliberate structural layout difference.
- `AudioKitPitchAdapter`'s `#if os(iOS)` `AVAudioSession` — an irreducible API boundary
  (`AVAudioSession` does not exist on macOS), correctly isolated in the infrastructure layer.

## Changes

**`audio_listen/audio_listenApp.swift`** — move the window minimum to the Scene:

```swift
@main
struct audio_listenApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
```

- The `.frame` stays `#if os(macOS)`-gated because `minWidth: 720` on an iPhone (~393pt wide) would
  force horizontal overflow — it must not apply on iOS.
- `.windowResizability(.contentMinSize)` ties the macOS window's minimum size to the content's
  minimum (720×560), so the window cannot shrink below it.
- Applying this to `RootView()` (not `ContentView`) means the minimum now covers the **whole
  window incl. the welcome screen**, not just the post-welcome main screen — a small correctness
  improvement over today.

**`audio_listen/ContentView.swift`** — delete the macOS `TabView` minimum:
```swift
.frame(minWidth: 720, minHeight: 560)   // remove this line from the #else (macOS) branch
```
The `#if os(iOS)` / `#else` structural split (NavRail vs TabView) is untouched.

**`audio_listen/Presentation/Drill/DrillView.swift`** — delete the redundant block (~lines 53–55):
```swift
#if os(macOS)
.frame(minWidth: 640, minHeight: 480)
#endif
```

**`audio_listen/Presentation/Drill/MasteryView.swift`** — delete the redundant block (~lines 33–37):
```swift
#if os(macOS)
.frame(minWidth: 640)
#endif
```

After these edits, `DrillView` and `MasteryView` contain **no** `#if os()`; `ContentView` keeps
only its `#if os(iOS)` structural branch; and the sole window-sizing `#if os(macOS)` lives in the
App/Scene file.

## Behavior (unchanged)

- **macOS:** the window minimum is 720×560 (was enforced by `ContentView`'s frame; now by the
  Scene's `windowResizability(.contentMinSize)` + the `RootView` frame min). The removed 640
  tab minimums never bound (720 > 640; ~520 content height > 480), so removing them changes
  nothing. The window can still grow freely.
- **iOS/iPadOS:** unaffected — the `.frame` min is compiled out, and `windowResizability` is a
  no-op on iPhone.

## Testing

No unit tests — this is window/Scene behavior, not testable via the (XCTest-free) unit suite and
there is no ViewInspector in the project. Verification:
- **Build both platforms** — `xcodebuild build` for macOS AND an iOS Simulator destination
  (proves the consolidated `#if` compiles on each and no view still references a removed frame).
- **Existing unit suite stays green** — `-only-testing:audio_listenTests` on macOS (no logic
  changed, so this is a pure regression check).
- **Manual macOS check** — the window still refuses to shrink below 720×560, and the welcome
  screen now also respects it.

## Files touched

| File | Change |
|---|---|
| `audio_listen/audio_listenApp.swift` | **modified** — Scene-level macOS min frame + `windowResizability` |
| `audio_listen/ContentView.swift` | **modified** — remove macOS `.frame(minWidth:720,minHeight:560)` |
| `audio_listen/Presentation/Drill/DrillView.swift` | **modified** — remove macOS `.frame(minWidth:640,minHeight:480)` block |
| `audio_listen/Presentation/Drill/MasteryView.swift` | **modified** — remove macOS `.frame(minWidth:640)` block |

## Out of scope

- The `#if os(iOS)` NavRail-vs-TabView branch in `ContentView` (deliberate UX; optional future
  `RootNavigation` extraction).
- The `#if os(iOS)` `AVAudioSession` code in `AudioKitPitchAdapter` (irreducible platform API).
- The iOS-landscape layout pass and find-position string-enforcement items in `ideas.md`.
