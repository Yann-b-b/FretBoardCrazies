# Touch-Mode Ambient Audio Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Touch-mode combo dings mix over background music (Spotify etc.) instead of pausing it.

**Architecture:** Fill in the empty `TouchInputSource.start()` body so touch mode declares its `AVAudioSession` category (`.ambient`) before the first ding implicitly activates the session — the same declare-in-`start()` pattern `AudioKitPitchAdapter` already uses for `.playAndRecord`. No other file changes.

**Tech Stack:** Swift, AVFoundation (`AVAudioSession`), existing `NoteInputSource` protocol wiring.

**Spec:** `docs/superpowers/specs/2026-09-20-touch-mode-ambient-audio-design.md`

## Global Constraints

- `AVAudioSession` exists only on iOS — the call MUST be wrapped in `#if os(iOS)` (the macOS build has no such API and must keep compiling).
- Category is exactly `.ambient` (silent-switch-respecting, mixable) — NOT `.playback` + `.mixWithOthers` (rejected in the decision log).
- No changes to `AppDependencyContainer`, `DrillViewModel`, `ComboSoundPlayer`, or any mic-path file.
- `AVAudioSession` behavior is not unit-testable; automated verification is "existing tests stay green on macOS + project builds for iOS". Behavioral verification is manual on the physical test device (steps in Task 1).

---

### Task 1: Set `.ambient` in `TouchInputSource.start()`

**Files:**
- Modify: `audio_listen/Infrastructure/Input/TouchInputSource.swift` (imports at line 1, `start()` at line 13)

**Interfaces:**
- Consumes: `NoteInputSource.start() throws` — already called polymorphically by `DrillViewModel.startListening()` (`DrillViewModel.swift:189`), once per view-model lifetime behind the `engineStarted` guard.
- Produces: no signature changes; `start()` may now throw (`setCategory` failure), which `DrillViewModel` already surfaces as `errorMessage`.

- [ ] **Step 1: Make the edit**

Replace the import block and `start()` in `audio_listen/Infrastructure/Input/TouchInputSource.swift`:

```swift
import AVFoundation
import Combine
```

```swift
    func start() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.ambient)
        #endif
    }
```

(`import AVFoundation` is safe on macOS — the framework exists there; only the `AVAudioSession` type does not, hence the `#if os(iOS)` around the call, mirroring `AudioKitPitchAdapter.swift:41-43`.)

- [ ] **Step 2: Run the existing test suite on macOS**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -only-testing:audio_listenTests -destination platform=macOS
```
Expected: `** TEST SUCCEEDED **` — proves the `#if os(iOS)` guard compiles out cleanly and no existing behavior changed (DrillViewModelTests exercise `TouchInputSource` via the input protocol).

- [ ] **Step 3: Build for iOS Simulator**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project audio_listen.xcodeproj -scheme audio_listen -destination 'generic/platform=iOS Simulator'
```
Expected: `** BUILD SUCCEEDED **` — proves the iOS branch (the `AVAudioSession` call) compiles.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Infrastructure/Input/TouchInputSource.swift
git commit -m "feat: mix touch-mode dings over background music via .ambient session"
```

- [ ] **Step 5: Manual verification on the physical test device (user-run)**

1. Play music (Spotify/Apple Music), enter a touch-mode drill, answer correctly — music continues through the dings.
2. Visit the tuner (music pauses — expected; mic owns the session), return to the drill, start a round — dings mix over music again.
3. Flip the ring/silent switch — dings go quiet, music unaffected.
4. Guitar (mic) drill and tuner behave exactly as before.
