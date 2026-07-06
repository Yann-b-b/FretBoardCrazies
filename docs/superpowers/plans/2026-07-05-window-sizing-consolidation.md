# Window-Sizing Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the macOS `720×560` window minimum into the `Scene` (`audio_listenApp.swift`) and delete the three scattered `.frame(minWidth:…)` `#if os(macOS)` blocks from `ContentView`, `DrillView`, and `MasteryView`.

**Architecture:** Window sizing is a Scene concern. One macOS-gated `.frame` on `RootView()` plus `.windowResizability(.contentMinSize)` in the `WindowGroup` sets the window minimum window-wide (incl. the welcome screen). The redundant per-tab minimums (640) never bound under a 720-wide window, so removing them is behavior-preserving.

**Tech Stack:** Swift, SwiftUI (multiplatform macOS + iOS), Xcode project `audio_listen.xcodeproj` (NOT SPM).

## Global Constraints

- **No comments** — code self-documents (existing file-header blocks stay).
- **No `project.pbxproj` edits** — only existing `.swift` files are modified.
- **SourceKit false positives:** cross-file "Cannot find type" editor diagnostics are not authoritative — `xcodebuild` is.
- **Behavior must be identical:** macOS window minimum stays 720×560; iOS unaffected. This is a pure refactor — the unit suite must stay green (no logic changed).
- **Scope:** only the three window-sizing `#if os(macOS)` sites. Do NOT touch `ContentView`'s `#if os(iOS)` NavRail/TabView branch or `AudioKitPitchAdapter`'s `#if os(iOS)` `AVAudioSession` code.
- **Build/test commands** (run in the foreground; `DEVELOPER_DIR` required):
  ```bash
  # macOS: compiles the macOS branch + runs the unit suite (regression)
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -project audio_listen.xcodeproj -scheme audio_listen \
    -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -20
  # iOS: compiles the #if os(iOS) branches (no simulator boot, no signing)
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
    -project audio_listen.xcodeproj -scheme audio_listen \
    -destination 'generic/platform=iOS Simulator' 2>&1 | tail -20
  ```
  Success lines: `** TEST SUCCEEDED **` and `** BUILD SUCCEEDED **`.

---

## Task 1: Consolidate window sizing into the Scene

Move the window minimum to `audio_listenApp.swift` and remove the three view-body blocks. All four edits land together so the macOS window minimum is never lost mid-change.

**Files:**
- Modify: `audio_listen/audio_listenApp.swift`
- Modify: `audio_listen/ContentView.swift`
- Modify: `audio_listen/Presentation/Drill/DrillView.swift`
- Modify: `audio_listen/Presentation/Drill/MasteryView.swift`

**Interfaces:** none — internal SwiftUI layout only; no symbol signatures change.

- [ ] **Step 1: Add the window minimum to the Scene**

Replace the entire body of `audio_listen/audio_listenApp.swift` (currently the `WindowGroup { RootView() }` with no modifiers):

```swift
//
//  audio_listenApp.swift
//  audio_listen
//
//  Created by Yann Baglin-Bunod on 2/24/26.
//

import SwiftUI

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

- [ ] **Step 2: Remove the macOS minimum from `ContentView`**

In `audio_listen/ContentView.swift`, inside the macOS (`#else`) `TabView` branch, delete the `.frame(minWidth: 720, minHeight: 560)` line. Change:

```swift
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .frame(minWidth: 720, minHeight: 560)
        #endif
    }
```
to:
```swift
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        #endif
    }
```
(Leave the `#if os(iOS)` / `#else` structure and everything else untouched.)

- [ ] **Step 3: Remove the redundant macOS block from `DrillView`**

In `audio_listen/Presentation/Drill/DrillView.swift`, delete the three-line block. Change:

```swift
        .padding(compact ? 12 : 24)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .top : .center)
```
to:
```swift
        .padding(compact ? 12 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .top : .center)
```

- [ ] **Step 4: Remove the redundant macOS block from `MasteryView`**

In `audio_listen/Presentation/Drill/MasteryView.swift`, delete the three-line block. Change:

```swift
            .padding(24)
            #if os(macOS)
            .frame(minWidth: 640)
            #endif
        }
        .scrollContentBackground(.hidden)
```
to:
```swift
            .padding(24)
        }
        .scrollContentBackground(.hidden)
```

- [ ] **Step 5: Verify no window-sizing `#if os(macOS)` remains in the views**

Run:
```bash
grep -rn "os(macOS)" audio_listen --include="*.swift"
```
Expected: **exactly one** match — in `audio_listen/audio_listenApp.swift` (the Scene). No `os(macOS)` in `ContentView.swift`, `DrillView.swift`, or `MasteryView.swift`. Also confirm the removed frame minimums are gone:
```bash
grep -rn "minWidth: 720\|minWidth: 640" audio_listen --include="*.swift"
```
Expected: **no output**.

- [ ] **Step 6: Build macOS (compile + regression suite)**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=macOS' -only-testing:audio_listenTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **` — the macOS branch compiles and the full unit suite passes (no logic changed).

- [ ] **Step 7: Build iOS (compile the `#if os(iOS)` branches)**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **` — the iOS branches compile (proving no view still references a removed macOS frame and the App-file `#if` is correct on iOS).

- [ ] **Step 8: Commit**

```bash
git add audio_listen/audio_listenApp.swift audio_listen/ContentView.swift \
        audio_listen/Presentation/Drill/DrillView.swift \
        audio_listen/Presentation/Drill/MasteryView.swift
git commit -m "refactor: consolidate macOS window minimum into the Scene"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-05-window-sizing-consolidation-design.md`):

- Scene-level macOS `.frame(minWidth:720,minHeight:560)` on `RootView()` + `.windowResizability(.contentMinSize)` → Step 1. ✓
- Remove `ContentView` macOS `.frame(minWidth:720,minHeight:560)` → Step 2. ✓
- Remove `DrillView` macOS `.frame(minWidth:640,minHeight:480)` block → Step 3. ✓
- Remove `MasteryView` macOS `.frame(minWidth:640)` block → Step 4. ✓
- Result: one window-sizing `#if os(macOS)` in the App file; `DrillView`/`MasteryView` free of `#if` → Step 5 grep. ✓
- Behavior unchanged; iOS unaffected; unit suite green → Steps 6–7. ✓
- Out of scope (NavRail `#if os(iOS)`, `AVAudioSession` `#if os(iOS)`) — untouched per Global Constraints and not referenced by any step. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases". Every step shows exact before/after code and exact commands. ✓

**3. Type consistency:** No new symbols introduced; the edits only remove/relocate `.frame` modifiers. `RootView()`, `WindowGroup`, `.windowResizability(.contentMinSize)`, and the `720×560` / `640` values are used consistently and match the spec verbatim. The grep in Step 5 (`minWidth: 720`, `minWidth: 640`) matches exactly the literals removed in Steps 2–4. ✓
