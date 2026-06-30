# Sticker Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the locked sticker art into the macOS app — belt badges, combo flame, success checkmark, an in-place belt-up animation, and a composited macOS app icon.

**Architecture:** Add the transparent sticker PNGs as universal imagesets in the synchronized asset catalog, extract the two pieces of testable logic (belt→asset-name, flame-for-combo, belt outranks) as pure functions with XCTest coverage, then swap the SF Symbols / emoji in `DrillView` + `MasteryView` for `Image(...)` stickers and add the celebration animations. The app icon is produced by a Pillow script that composites the locked guitar onto a warm rounded square.

**Tech Stack:** Swift / SwiftUI (macOS 14.6), XCTest, Xcode asset catalogs; one Python (Pillow) utility for the app icon.

## Global Constraints

- macOS SwiftUI app; deployment target macOS 14.6. No code comments; clear names; pure functions for logic.
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build` → expect `** BUILD SUCCEEDED **`.
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/<ClassName>` (slow — builds the app; that's expected).
- `audio_listen/Assets.xcassets` and `audio_listenTests/` are `PBXFileSystemSynchronizedRootGroup`s: new files/folders are auto-included, **no `project.pbxproj` edits**.
- Stickers are transparent PNGs in `art/`; each becomes ONE universal imageset (no light/dark variants — the white borders read on both).
- `Belt` is `enum Belt: Int, CaseIterable { case white, yellow, orange, green, blue, purple, brown, black }` (rawValue 0–7 = rank order).
- Work continues on the existing `art-backgrounds` branch (the background wiring lives there).
- Run the app to visually verify view changes: build, then `open "$(find ~/Library/Developer/Xcode/DerivedData -name audio_listen.app -path '*Debug*' -not -path '*Index*' | head -1)"`.

---

### Task 1: Add the 12 sticker imagesets

**Files:**
- Create: `audio_listen/Assets.xcassets/{belt-white,belt-yellow,belt-orange,belt-green,belt-blue,belt-purple,belt-brown,belt-black,flame-small,flame-large,combo-burst,correct-sticker}.imageset/` (each with the PNG + `Contents.json`)

**Interfaces:**
- Consumes: the committed `art/<name>.png` masters.
- Produces: catalog image names `belt-white` … `correct-sticker`, resolvable via `Image("<name>")`.

- [ ] **Step 1: Create the imagesets**

Run:
```bash
cd /Users/yannbaglinbunod/Documents/Projects/Personal/FretBoardCrazies
for name in belt-white belt-yellow belt-orange belt-green belt-blue belt-purple belt-brown belt-black flame-small flame-large combo-burst correct-sticker; do
  dir="audio_listen/Assets.xcassets/$name.imageset"
  mkdir -p "$dir"
  cp "art/$name.png" "$dir/$name.png"
  printf '{\n  "images" : [\n    {\n      "filename" : "%s.png",\n      "idiom" : "universal"\n    }\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' "$name" > "$dir/Contents.json"
done
ls -1 audio_listen/Assets.xcassets/ | grep imageset
```
Expected: 16 imagesets listed (the 4 `bg-*` from earlier + the 12 new ones).

- [ ] **Step 2: Verify the catalog still compiles**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **` (actool packs the new imagesets; no "unassigned children" errors).

- [ ] **Step 3: Commit**

```bash
git add audio_listen/Assets.xcassets/
git commit -m "feat: add belt/flame/combo/success sticker imagesets to the catalog"
```

---

### Task 2: Belt `assetName` and `outranks` (pure logic)

**Files:**
- Modify: `audio_listen/Presentation/Drill/Belt+UI.swift`
- Modify: `audio_listen/Domain/Models/Belt.swift`
- Test: `audio_listenTests/BeltStickerTests.swift`

**Interfaces:**
- Produces: `Belt.assetName: String` (e.g. `.white` → `"belt-white"`); `Belt.outranks(_ other: Belt) -> Bool`.

- [ ] **Step 1: Write the failing test**

Create `audio_listenTests/BeltStickerTests.swift`:
```swift
import XCTest
@testable import audio_listen

final class BeltStickerTests: XCTestCase {
    func testAssetNameMatchesCatalog() {
        XCTAssertEqual(Belt.white.assetName, "belt-white")
        XCTAssertEqual(Belt.yellow.assetName, "belt-yellow")
        XCTAssertEqual(Belt.purple.assetName, "belt-purple")
        XCTAssertEqual(Belt.black.assetName, "belt-black")
    }

    func testEveryBeltHasAssetName() {
        for belt in Belt.allCases {
            XCTAssertEqual(belt.assetName, "belt-\(belt.displayName.lowercased())")
        }
    }

    func testOutranksUsesRankOrder() {
        XCTAssertTrue(Belt.black.outranks(.white))
        XCTAssertTrue(Belt.yellow.outranks(.white))
        XCTAssertFalse(Belt.white.outranks(.white))
        XCTAssertFalse(Belt.white.outranks(.black))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/BeltStickerTests 2>&1 | grep -E "(error:|value of type 'Belt'|TEST FAILED|TEST SUCCEEDED)" | tail -10
```
Expected: compile failure — `value of type 'Belt' has no member 'assetName'` / `outranks`.

- [ ] **Step 3: Add `assetName`**

In `audio_listen/Presentation/Drill/Belt+UI.swift`, replace:
```swift
    var symbolName: String { "medal.fill" }
```
with:
```swift
    var symbolName: String { "medal.fill" }

    var assetName: String { "belt-\(displayName.lowercased())" }
```

- [ ] **Step 4: Add `outranks`**

In `audio_listen/Domain/Models/Belt.swift`, after the `displayName` computed property's closing `}` (before the enum's final `}`), add:
```swift

    func outranks(_ other: Belt) -> Bool { rawValue > other.rawValue }
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/BeltStickerTests 2>&1 | grep -E "(Executed|TEST FAILED|TEST SUCCEEDED|passed|failed)" | tail -10
```
Expected: `** TEST SUCCEEDED **`, all `BeltStickerTests` passing.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Presentation/Drill/Belt+UI.swift audio_listen/Domain/Models/Belt.swift audio_listenTests/BeltStickerTests.swift
git commit -m "feat: Belt.assetName and Belt.outranks with tests"
```

---

### Task 3: `flameAsset(for:)` helper (pure logic)

**Files:**
- Create: `audio_listen/Presentation/Drill/StickerHelpers.swift`
- Test: `audio_listenTests/StickerHelpersTests.swift`

**Interfaces:**
- Produces: `flameAsset(for combo: Int) -> String` — `"flame-large"` for `combo >= 5`, else `"flame-small"`.

- [ ] **Step 1: Write the failing test**

Create `audio_listenTests/StickerHelpersTests.swift`:
```swift
import XCTest
@testable import audio_listen

final class StickerHelpersTests: XCTestCase {
    func testSmallFlameForLowCombos() {
        XCTAssertEqual(flameAsset(for: 2), "flame-small")
        XCTAssertEqual(flameAsset(for: 4), "flame-small")
    }

    func testLargeFlameAtFiveAndAbove() {
        XCTAssertEqual(flameAsset(for: 5), "flame-large")
        XCTAssertEqual(flameAsset(for: 12), "flame-large")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/StickerHelpersTests 2>&1 | grep -E "(error:|cannot find 'flameAsset'|TEST FAILED|TEST SUCCEEDED)" | tail -10
```
Expected: compile failure — `cannot find 'flameAsset' in scope`.

- [ ] **Step 3: Implement the helper**

Create `audio_listen/Presentation/Drill/StickerHelpers.swift`:
```swift
func flameAsset(for combo: Int) -> String {
    combo >= 5 ? "flame-large" : "flame-small"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project audio_listen.xcodeproj -scheme audio_listen -destination 'platform=macOS' -only-testing:audio_listenTests/StickerHelpersTests 2>&1 | grep -E "(Executed|TEST FAILED|TEST SUCCEEDED)" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/StickerHelpers.swift audio_listenTests/StickerHelpersTests.swift
git commit -m "feat: flameAsset(for:) helper with tests"
```

---

### Task 4: Belt badge sticker in Drill + Progress

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift` (header)
- Modify: `audio_listen/Presentation/Drill/MasteryView.swift` (`beltCard`)

**Interfaces:**
- Consumes: `Belt.assetName` (Task 2).

- [ ] **Step 1: Swap the Drill header badge**

In `audio_listen/Presentation/Drill/DrillView.swift`, replace:
```swift
                Image(systemName: viewModel.beltRank.belt.symbolName)
                    .foregroundStyle(viewModel.beltRank.belt.color)
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
```
with:
```swift
                Image(viewModel.beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
```

- [ ] **Step 2: Swap the Progress belt card badge**

In `audio_listen/Presentation/Drill/MasteryView.swift`, replace:
```swift
                Image(systemName: beltRank.belt.symbolName).foregroundStyle(beltRank.belt.color)
                Text("\(beltRank.belt.displayName) belt").font(.headline)
```
with:
```swift
                Image(beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                Text("\(beltRank.belt.displayName) belt").font(.headline)
```

- [ ] **Step 3: Build**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and visually verify**

Run:
```bash
open "$(find ~/Library/Developer/Xcode/DerivedData -name audio_listen.app -path '*Debug*' -not -path '*Index*' | head -1)"
```
Expected: the Drill header and the Progress card show the colored belt sticker (not the `medal.fill` symbol) at ~32pt next to the belt name.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift audio_listen/Presentation/Drill/MasteryView.swift
git commit -m "feat: belt badge sticker in Drill header and Progress card"
```

---

### Task 5: Combo flame sticker

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift` (`comboBadge`)

**Interfaces:**
- Consumes: `flameAsset(for:)` (Task 3).

- [ ] **Step 1: Replace the emoji combo with the flame sticker**

In `audio_listen/Presentation/Drill/DrillView.swift`, replace:
```swift
            Text("🔥 \(viewModel.comboCount) combo")
                .font(.headline)
                .foregroundStyle(.orange)
                .scaleEffect(scale)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
```
with:
```swift
            HStack(spacing: 6) {
                Image(flameAsset(for: viewModel.comboCount))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text("\(viewModel.comboCount) combo")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            .scaleEffect(scale)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
```

- [ ] **Step 2: Build**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run and visually verify**

Run a drill, get 2+ fast correct answers in a row. Expected: the combo shows the small flame sticker + "N combo" and pulses; at 5+ it swaps to the large flame. (Build/launch as in Task 4 Step 4.)

- [ ] **Step 4: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: combo flame sticker replaces emoji"
```

---

### Task 6: Success checkmark pop

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift` (`@State` + `.success` case)

**Interfaces:**
- Consumes: catalog image `correct-sticker` (Task 1).

- [ ] **Step 1: Add the pop state**

In `audio_listen/Presentation/Drill/DrillView.swift`, replace:
```swift
    @State private var comboSound = ComboSoundPlayer()
```
with:
```swift
    @State private var comboSound = ComboSoundPlayer()
    @State private var checkPop = false
```

- [ ] **Step 2: Add the checkmark to the success state**

In the same file, replace:
```swift
        case .success(let time, let prompt):
            promptView(prompt, reveal: true)
            Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            controlButtons
```
with:
```swift
        case .success(let time, let prompt):
            promptView(prompt, reveal: true)
            HStack(spacing: 8) {
                Image("correct-sticker")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .scaleEffect(checkPop ? 1.0 : 0.5)
                    .opacity(checkPop ? 1 : 0)
                    .onAppear {
                        checkPop = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { checkPop = true }
                    }
                Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            }
            controlButtons
```

- [ ] **Step 3: Build**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and visually verify**

Get a correct answer. Expected: the checkmark sticker pops in (scale + fade) beside "Correct! X.XX s", and re-pops on each new success.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: success checkmark sticker pop"
```

---

### Task 7: Belt-up in-place celebration

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift` (`@State`, badge ZStack, `.onChange`)

**Interfaces:**
- Consumes: `Belt.outranks` (Task 2), catalog image `combo-burst` (Task 1), the Task 4 belt badge.

- [ ] **Step 1: Add celebration state**

In `audio_listen/Presentation/Drill/DrillView.swift`, replace:
```swift
    @State private var checkPop = false
```
with:
```swift
    @State private var checkPop = false
    @State private var beltBurst = false
    @State private var beltPulse = false
```

- [ ] **Step 2: Wrap the belt badge with the burst overlay**

In the same file, replace the Task 4 badge block:
```swift
                Image(viewModel.beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
```
with (the burst is a non-layout `.overlay` so the header row keeps its height):
```swift
                Image(viewModel.beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .scaleEffect(beltPulse ? 1.3 : 1.0)
                    .overlay {
                        Image("combo-burst")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 64)
                            .opacity(beltBurst ? 1 : 0)
                            .scaleEffect(beltBurst ? 1.2 : 0.6)
                            .allowsHitTesting(false)
                    }
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
```

- [ ] **Step 3: Trigger on rank-up**

In the same file, replace:
```swift
        .onChange(of: viewModel.comboCount) { oldValue, newValue in
            if newValue > oldValue {
                comboSound.play(combo: newValue)
            }
        }
```
with:
```swift
        .onChange(of: viewModel.comboCount) { oldValue, newValue in
            if newValue > oldValue {
                comboSound.play(combo: newValue)
            }
        }
        .onChange(of: viewModel.beltRank.belt) { oldBelt, newBelt in
            guard newBelt.outranks(oldBelt) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                beltBurst = true
                beltPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    beltBurst = false
                    beltPulse = false
                }
            }
        }
```

- [ ] **Step 4: Build**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run and visually verify**

To force a rank-up quickly, you can temporarily lower `Belt.thresholds` (e.g. make `yellow` 0.0) in a throwaway edit, drill one correct answer, and confirm: the `combo-burst` flashes behind the belt badge and the badge pulses ~1s, then settles. **Revert the throwaway threshold edit before committing.** Expected behavior confirmed.

- [ ] **Step 6: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: in-place belt-up burst + pulse celebration"
```

---

### Task 8: Composited macOS app icon

**Files:**
- Create: `scripts/build_app_icon.py`
- Create: `audio_listen/Assets.xcassets/AppIcon.appiconset/icon_{16,32,64,128,256,512,1024}.png`
- Modify: `audio_listen/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Interfaces:**
- Consumes: `art/app-icon.png` (locked guitar). Requires Pillow (already installed in this environment).

- [ ] **Step 1: Write the icon-build script**

Create `scripts/build_app_icon.py`:
```python
import os

from PIL import Image, ImageDraw

PROJECT = "/Users/yannbaglinbunod/Documents/Projects/Personal/FretBoardCrazies"
SRC = os.path.join(PROJECT, "art/app-icon.png")
OUT = os.path.join(PROJECT, "audio_listen/Assets.xcassets/AppIcon.appiconset")
MASTER = 1024
TOP = (255, 138, 61, 255)
BOTTOM = (255, 178, 62, 255)
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def rounded_master():
    column = Image.new("RGBA", (1, MASTER))
    for y in range(MASTER):
        t = y / (MASTER - 1)
        column.putpixel(
            (0, y),
            (
                int(TOP[0] * (1 - t) + BOTTOM[0] * t),
                int(TOP[1] * (1 - t) + BOTTOM[1] * t),
                int(TOP[2] * (1 - t) + BOTTOM[2] * t),
                255,
            ),
        )
    gradient = column.resize((MASTER, MASTER))
    mask = Image.new("L", (MASTER, MASTER), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, MASTER - 1, MASTER - 1], radius=int(MASTER * 0.2237), fill=255
    )
    canvas = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    canvas.paste(gradient, (0, 0), mask)
    guitar = Image.open(SRC).convert("RGBA")
    target = int(MASTER * 0.72)
    scale = target / max(guitar.size)
    guitar = guitar.resize(
        (int(guitar.width * scale), int(guitar.height * scale)), Image.LANCZOS
    )
    canvas.alpha_composite(
        guitar, ((MASTER - guitar.width) // 2, (MASTER - guitar.height) // 2)
    )
    return canvas


def main():
    master = rounded_master()
    for size in SIZES:
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(OUT, f"icon_{size}.png")
        )
        print(f"wrote icon_{size}.png")


main()
```

- [ ] **Step 2: Run it and verify output sizes**

Run:
```bash
cd /Users/yannbaglinbunod/Documents/Projects/Personal/FretBoardCrazies
python3 scripts/build_app_icon.py
python3 -c "
from PIL import Image
import os
OUT='audio_listen/Assets.xcassets/AppIcon.appiconset'
for s in [16,32,64,128,256,512,1024]:
    im=Image.open(f'{OUT}/icon_{s}.png')
    assert im.size==(s,s), (s, im.size)
    assert im.mode=='RGBA'
print('all icon sizes correct')
"
```
Expected: 7 `wrote icon_*.png` lines, then `all icon sizes correct`.

- [ ] **Step 3: Point the appiconset at the generated PNGs**

Overwrite `audio_listen/Assets.xcassets/AppIcon.appiconset/Contents.json` with (this replaces the stale iOS entries with the macOS icon set):
```json
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_64.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```
If a stale `fretboard_icon.png` exists in the appiconset, remove it: `git rm -f audio_listen/Assets.xcassets/AppIcon.appiconset/fretboard_icon.png 2>/dev/null || rm -f audio_listen/Assets.xcassets/AppIcon.appiconset/fretboard_icon.png`.

- [ ] **Step 4: Build and verify the icon packs**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project audio_listen.xcodeproj -scheme audio_listen -configuration Debug build 2>&1 | grep -E "(error:|warning:.*[Ii]con|BUILD SUCCEEDED|BUILD FAILED)" | tail -8
```
Expected: `** BUILD SUCCEEDED **` with no missing-icon / unassigned errors. Then launch the app (Task 4 Step 4) and confirm the dock icon shows the guitar on the warm rounded square.

- [ ] **Step 5: Commit**

```bash
git add scripts/build_app_icon.py audio_listen/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: composited macOS app icon (guitar on warm rounded square)"
```

---

## Notes for the implementer

- Swift tests run via `xcodebuild test` and are slow (each invocation builds the app) — that's expected, not a failure.
- View tasks (4–7) have no unit tests; they are verified by a clean build + the visual check described in each task's run step.
- Do all work on the `art-backgrounds` branch (it carries the background wiring these views already depend on).
- If `-destination 'platform=macOS'` errors with an ambiguous-destination message, append the arch: `-destination 'platform=macOS,arch=arm64'`.
