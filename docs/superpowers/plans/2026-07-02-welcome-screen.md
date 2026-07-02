# Welcome Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an every-launch welcome/landing screen with the unused welcome background, decorative belt/flame sprites, app name, one-line description, and a button that enters the main app.

**Architecture:** A `RootView` gate chooses between `WelcomeView` and the existing `ContentView`, driven by a `RootViewModel` (built via `AppDependencyContainer`) that owns an `AppRoute` enum — mirroring the app's `DrillState`/`DrillViewModel` idiom. `WelcomeView` layers the `bg-welcome` image, a decorative `FloatingBeltsView`, and the copy + button (flanked by the two flame sprites).

**Tech Stack:** SwiftUI (multiplatform, iOS landscape-locked), Combine (`ObservableObject`), Swift Testing (`import Testing`, `@Test`, `#expect`), Xcode asset catalog.

## Global Constraints

- **Build/test toolchain:** `xcodebuild` requires Xcode, but the default developer dir is CommandLineTools. Prefix every `xcodebuild` command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Simulator destination:** `-destination 'platform=iOS Simulator,name=iphone 17'` (an iPhone 17 sim exists). SourceKit "Cannot find … in scope" diagnostics across files are false positives; `xcodebuild` is authoritative.
- **No code comments** — code must be self-documenting (user global rule). None of the code below contains comments; keep it that way.
- **Every-launch behavior** — the route is in-memory (`@State`/`@Published`), never persisted.
- **DI pattern** — ViewModels are constructed by `AppDependencyContainer` factory methods, consumed by views via `@StateObject`.
- **Exact copy** — App name: `FretboardCrazies`. Description: `Learn every note on the fretboard, one drill at a time.` Button: `Get started`.
- **Assets** — `flame-small`, `flame-large`, and `belt-white`…`belt-black` are already in the catalog. Only `bg-welcome` needs importing (from `art/bg-welcome-{light,dark}.png`).
- **Bundle id** for launching on the sim: `v.audio-listen`.

---

### Task 1: `RootViewModel` + `AppRoute` (the gate's logic)

**Files:**
- Create: `audio_listen/Presentation/Root/RootViewModel.swift`
- Test: `audio_listenTests/RootViewModelTests.swift`

**Interfaces:**
- Produces: `enum AppRoute: Equatable { case welcome, main }`; `@MainActor final class RootViewModel: ObservableObject` with `@Published private(set) var route: AppRoute` (defaults to `.welcome`) and `func enterApp()` (sets `route = .main`).

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/RootViewModelTests.swift`:

```swift
import Testing
@testable import audio_listen

struct RootViewModelTests {
    @Test @MainActor func startsOnWelcome() {
        let viewModel = RootViewModel()
        #expect(viewModel.route == .welcome)
    }

    @Test @MainActor func enterAppTransitionsToMain() {
        let viewModel = RootViewModel()
        viewModel.enterApp()
        #expect(viewModel.route == .main)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' \
  -only-testing:audio_listenTests/RootViewModelTests 2>&1 | grep -E "error:|BUILD FAILED"
```
Expected: BUILD FAILED — `Cannot find 'RootViewModel' in scope`.

- [ ] **Step 3: Write the implementation**

Create `audio_listen/Presentation/Root/RootViewModel.swift`:

```swift
import Combine

enum AppRoute: Equatable {
    case welcome
    case main
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute = .welcome

    func enterApp() {
        route = .main
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' \
  -only-testing:audio_listenTests/RootViewModelTests 2>&1 | grep -E "passed|failed|BUILD (SUCCEEDED|FAILED)"
```
Expected: both tests pass; BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Root/RootViewModel.swift audio_listenTests/RootViewModelTests.swift
git commit -m "feat: add RootViewModel with AppRoute welcome/main gate"
```

---

### Task 2: `FloatingBeltsView` (decorative drifting belts)

**Files:**
- Create: `audio_listen/Presentation/Welcome/FloatingBeltsView.swift`

**Interfaces:**
- Consumes: `Belt` (existing enum, `CaseIterable`, with `var assetName: String`).
- Produces: `struct FloatingBeltsView: View` — no init parameters.

This is a decorative UI view with no pure logic, so it is verified by building and by the SwiftUI preview rather than a unit test.

- [ ] **Step 1: Write the view**

Create `audio_listen/Presentation/Welcome/FloatingBeltsView.swift`:

```swift
import SwiftUI

struct FloatingBeltsView: View {
    private struct Sprite: Identifiable {
        let id: Int
        let assetName: String
        let xFraction: CGFloat
        let yFraction: CGFloat
        let phase: Double
    }

    @State private var animate = false

    private let sprites = FloatingBeltsView.makeSprites()

    var body: some View {
        GeometryReader { proxy in
            ForEach(sprites) { sprite in
                Image(sprite.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(0.35)
                    .rotationEffect(.degrees(animate ? 8 : -8))
                    .offset(y: animate ? -10 : 10)
                    .position(
                        x: proxy.size.width * sprite.xFraction,
                        y: proxy.size.height * sprite.yFraction
                    )
                    .animation(
                        .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true)
                            .delay(sprite.phase),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    private static func makeSprites() -> [Sprite] {
        Belt.allCases.enumerated().map { index, belt in
            let isTop = index < 4
            let column = isTop ? index : index - 4
            let xFraction = CGFloat(column) / 3.0 * 0.8 + 0.1
            return Sprite(
                id: index,
                assetName: belt.assetName,
                xFraction: xFraction,
                yFraction: isTop ? 0.12 : 0.88,
                phase: Double(index) * 0.25
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FloatingBeltsView()
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: BUILD SUCCEEDED. (If it fails with `assetName` unresolved, confirm `Belt` exposes `var assetName: String` — it is used in `DrillView.swift` header.)

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Presentation/Welcome/FloatingBeltsView.swift
git commit -m "feat: add FloatingBeltsView decorative belt sprites"
```

---

### Task 3: Import `bg-welcome` asset + build `WelcomeView`

**Files:**
- Create: `audio_listen/Assets.xcassets/bg-welcome.imageset/Contents.json`
- Create (copy): `audio_listen/Assets.xcassets/bg-welcome.imageset/bg-welcome-light.png`, `…/bg-welcome-dark.png`
- Create: `audio_listen/Presentation/Welcome/WelcomeView.swift`

**Interfaces:**
- Consumes: `FloatingBeltsView` (Task 2); assets `bg-welcome`, `flame-small`, `flame-large`.
- Produces: `struct WelcomeView: View` with `let onStart: () -> Void`.

- [ ] **Step 1: Create the imageset directory and copy the PNGs**

```bash
mkdir -p audio_listen/Assets.xcassets/bg-welcome.imageset
cp art/bg-welcome-light.png audio_listen/Assets.xcassets/bg-welcome.imageset/bg-welcome-light.png
cp art/bg-welcome-dark.png audio_listen/Assets.xcassets/bg-welcome.imageset/bg-welcome-dark.png
```

- [ ] **Step 2: Write the imageset `Contents.json`**

Create `audio_listen/Assets.xcassets/bg-welcome.imageset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "bg-welcome-light.png",
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "bg-welcome-dark.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Write `WelcomeView`**

Create `audio_listen/Presentation/Welcome/WelcomeView.swift`:

```swift
import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            Image("bg-welcome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            FloatingBeltsView()

            VStack(spacing: compact ? 12 : 20) {
                Text("FretboardCrazies")
                    .font(.system(size: compact ? 34 : 48, weight: .bold))
                Text("Learn every note on the fretboard, one drill at a time.")
                    .font(compact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Image("flame-small")
                        .resizable()
                        .scaledToFit()
                        .frame(height: compact ? 36 : 48)
                    Button("Get started", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Image("flame-large")
                        .resizable()
                        .scaledToFit()
                        .frame(height: compact ? 44 : 60)
                }
            }
            .padding(compact ? 20 : 40)
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
```

- [ ] **Step 4: Verify it builds and the asset resolves**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' build 2>&1 | grep -E "error:|warning: .*bg-welcome|BUILD (SUCCEEDED|FAILED)"
```
Expected: BUILD SUCCEEDED, with no "unassigned children" / missing-asset warning for `bg-welcome`.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Assets.xcassets/bg-welcome.imageset audio_listen/Presentation/Welcome/WelcomeView.swift
git commit -m "feat: add WelcomeView and import bg-welcome asset"
```

---

### Task 4: `RootView` + DI factory

**Files:**
- Create: `audio_listen/Presentation/Root/RootView.swift`
- Modify: `audio_listen/DI/AppDependencyContainer.swift` (add `makeRootViewModel()` after `makeDrillViewModel()`, before the closing brace ~line 79)

**Interfaces:**
- Consumes: `RootViewModel` / `AppRoute` (Task 1), `WelcomeView` (Task 3), `ContentView` (existing).
- Produces: `struct RootView: View`; `AppDependencyContainer.makeRootViewModel() -> RootViewModel`.

- [ ] **Step 1: Add the DI factory**

In `audio_listen/DI/AppDependencyContainer.swift`, add this method inside the class, immediately after the closing brace of `makeDrillViewModel()`:

```swift
    @MainActor
    func makeRootViewModel() -> RootViewModel {
        RootViewModel()
    }
```

- [ ] **Step 2: Write `RootView`**

Create `audio_listen/Presentation/Root/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppDependencyContainer.shared.makeRootViewModel()

    var body: some View {
        switch viewModel.route {
        case .welcome:
            WelcomeView(onStart: { withAnimation(.easeInOut) { viewModel.enterApp() } })
                .transition(.opacity)
        case .main:
            ContentView()
                .transition(.opacity)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 3: Verify it builds**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Root/RootView.swift audio_listen/DI/AppDependencyContainer.swift
git commit -m "feat: add RootView gate and makeRootViewModel DI factory"
```

---

### Task 5: Wire the app entry point + end-to-end verification

**Files:**
- Modify: `audio_listen/audio_listenApp.swift:14` (`ContentView()` → `RootView()`)

**Interfaces:**
- Consumes: `RootView` (Task 4).

- [ ] **Step 1: Point the WindowGroup at `RootView`**

In `audio_listen/audio_listenApp.swift`, replace `ContentView()` with `RootView()`:

```swift
@main
struct audio_listenApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 2: Build, install, and launch on the simulator**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DD=$(mktemp -d)
xcodebuild -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
SIM=$(xcrun simctl list devices available | grep -m1 "iPhone 17 (" | grep -oE "[0-9A-F-]{36}")
xcrun simctl bootstatus "$SIM" -b
open -a Simulator
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/audio_listen.app"
xcrun simctl launch "$SIM" v.audio-listen
```

- [ ] **Step 3: Manually verify on the simulator**

Confirm all of:
- App opens on the welcome screen; `bg-welcome` background is visible.
- Two flames flank the "Get started" button; belts drift along the top and bottom.
- The description is one line; the button is reachable in landscape.
- Tapping "Get started" fades into the Drill screen (the main app).
- Cold-relaunch (`xcrun simctl terminate "$SIM" v.audio-listen && xcrun simctl launch "$SIM" v.audio-listen`) shows the welcome screen again.

- [ ] **Step 4: Run the full test suite to confirm nothing regressed**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=iOS Simulator,name=iphone 17' 2>&1 | grep -E "Test Suite .* (passed|failed)|BUILD (SUCCEEDED|FAILED)"
```
Expected: all suites pass; BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/audio_listenApp.swift
git commit -m "feat: show welcome screen on launch via RootView"
```

---

## Self-Review

**Spec coverage:**
- Every-launch welcome screen → Tasks 1, 4, 5 (in-memory `AppRoute`, gate, app entry). ✓
- Unused `bg-welcome` background imported + shown → Task 3. ✓
- One-line description + app name + `Get started` button → Task 3 (exact copy). ✓
- Enum-in-ViewModel gate built via `AppDependencyContainer` → Tasks 1 & 4. ✓
- Two flames flank the button → Task 3. ✓
- Eight belts drift top & bottom → Task 2. ✓
- `RootViewModel` unit test → Task 1. ✓
- Existing suites stay green → Task 5 Step 4. ✓
- Files-touched table matches the created/modified files across Tasks 1–5. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; no "similar to Task N". ✓

**Type consistency:** `AppRoute { .welcome, .main }`, `RootViewModel.route`, `RootViewModel.enterApp()`, `makeRootViewModel() -> RootViewModel`, `WelcomeView(onStart:)`, `FloatingBeltsView()` are used identically wherever they appear across tasks. ✓
