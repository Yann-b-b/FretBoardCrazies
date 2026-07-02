# Combo Escalation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat combo feedback (size flip at 10 + a single sine beep) with a tiered escalation — flame size, side-to-side wiggle, and a rainbow at 50 — plus script-generated per-tier audio cues and tier-up stingers, all keyed on combo milestones 15/25/50.

**Architecture:** A pure `ComboEscalation` function maps `comboCount` → `ComboVisual` (flame asset, wiggle amplitude, rainbow flag). `DrillView.comboBadge` renders it (image + animated offset + hue cycle). A Python script synthesizes `.wav` cues committed under `audio_listen/Sounds/`; `ComboSoundPlayer` is rewritten to play the per-tier cue and a tier-up stinger via `AVAudioPlayer`.

**Tech Stack:** SwiftUI, AVFoundation (`AVAudioPlayer`), Swift Testing, Python (numpy + `wave`) for asset generation.

## Global Constraints

- **Build/test toolchain:** prefix every `xcodebuild` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Simulator: iPhone 17, `-destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A'`. SourceKit cross-file "Cannot find … in scope" diagnostics are false positives; `xcodebuild` is authoritative.
- **No code comments** (self-documenting code — user global rule). Applies to Swift and Python.
- **Combo thresholds (named constants):** tier2 = 15, tier3 = 25, tier4 = 50; tier1 starts at combo 2.
- **Flame assets:** `flame-small` for tiers 0–1, `flame-large` for tiers 2–4 (large now begins at 15, superseding the old ≥10 flip).
- **Rainbow** only at tier 4 (combo ≥ 50).
- **Audio files** live in `audio_listen/Sounds/` and must be members of the app target's resources (loadable via `Bundle.main.url(forResource:withExtension:)`); `.wav`, mono, 44100 Hz, 16-bit PCM. Filenames: `combo-hit-1..4`, `combo-tierup-2..4`.
- **Deleting files** in this project is `git rm` (it uses a synchronized file-system group; no `.pbxproj` edits).
- **Python:** run via `uv run` and match the conventions in the existing `scripts/` (see `scripts/test_generate_art.py` for the test/import style); ruff-clean, imports at top of file.
- Existing test suites must stay green.

---

### Task 1: `ComboEscalation` pure logic (tiers + visual)

**Files:**
- Create: `audio_listen/Presentation/Drill/ComboEscalation.swift`
- Test: `audio_listenTests/ComboEscalationTests.swift`

**Interfaces:**
- Produces:
  - `enum ComboTier: Int { case none, one, two, three, four }` with `static func tier(for combo: Int) -> ComboTier` and `static let tier2Threshold = 15`, `tier3Threshold = 25`, `tier4Threshold = 50`.
  - `struct ComboVisual { let flameAsset: String; let wiggleAmplitude: CGFloat; let rainbow: Bool }`.
  - `enum ComboEscalation { static let maxWiggle: CGFloat; static func visual(for combo: Int) -> ComboVisual }`.

- [ ] **Step 1: Write the failing tests**

Create `audio_listenTests/ComboEscalationTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import audio_listen

struct ComboEscalationTests {
    @Test func tierBoundaries() {
        #expect(ComboTier.tier(for: 1) == .none)
        #expect(ComboTier.tier(for: 2) == .one)
        #expect(ComboTier.tier(for: 14) == .one)
        #expect(ComboTier.tier(for: 15) == .two)
        #expect(ComboTier.tier(for: 24) == .two)
        #expect(ComboTier.tier(for: 25) == .three)
        #expect(ComboTier.tier(for: 49) == .three)
        #expect(ComboTier.tier(for: 50) == .four)
    }

    @Test func flameAssetByTier() {
        #expect(ComboEscalation.visual(for: 2).flameAsset == "flame-small")
        #expect(ComboEscalation.visual(for: 14).flameAsset == "flame-small")
        #expect(ComboEscalation.visual(for: 15).flameAsset == "flame-large")
        #expect(ComboEscalation.visual(for: 50).flameAsset == "flame-large")
    }

    @Test func rainbowOnlyAtTierFour() {
        #expect(ComboEscalation.visual(for: 49).rainbow == false)
        #expect(ComboEscalation.visual(for: 50).rainbow == true)
    }

    @Test func wiggleResetsAtMotionTierEntryAndGrows() {
        #expect(ComboEscalation.visual(for: 2).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 14).wiggleAmplitude > ComboEscalation.visual(for: 2).wiggleAmplitude)
        #expect(ComboEscalation.visual(for: 15).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 25).wiggleAmplitude == 0)
        #expect(ComboEscalation.visual(for: 49).wiggleAmplitude > ComboEscalation.visual(for: 25).wiggleAmplitude)
        #expect(ComboEscalation.visual(for: 50).wiggleAmplitude == ComboEscalation.maxWiggle)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A' \
  -only-testing:audio_listenTests/ComboEscalationTests 2>&1 | grep -E "error:|BUILD FAILED"
```
Expected: BUILD FAILED — `Cannot find 'ComboTier' in scope`.

- [ ] **Step 3: Write the implementation**

Create `audio_listen/Presentation/Drill/ComboEscalation.swift`:

```swift
import CoreGraphics

enum ComboTier: Int {
    case none, one, two, three, four

    static let tier2Threshold = 15
    static let tier3Threshold = 25
    static let tier4Threshold = 50

    static func tier(for combo: Int) -> ComboTier {
        if combo >= tier4Threshold { return .four }
        if combo >= tier3Threshold { return .three }
        if combo >= tier2Threshold { return .two }
        if combo >= 2 { return .one }
        return .none
    }
}

struct ComboVisual {
    let flameAsset: String
    let wiggleAmplitude: CGFloat
    let rainbow: Bool
}

enum ComboEscalation {
    static let maxWiggle: CGFloat = 10

    static func visual(for combo: Int) -> ComboVisual {
        let tier = ComboTier.tier(for: combo)
        let flame = (tier == .none || tier == .one) ? "flame-small" : "flame-large"
        return ComboVisual(
            flameAsset: flame,
            wiggleAmplitude: wiggle(for: combo, tier: tier),
            rainbow: tier == .four
        )
    }

    private static func wiggle(for combo: Int, tier: ComboTier) -> CGFloat {
        switch tier {
        case .none, .two:
            return 0
        case .one:
            return ramp(combo, start: 2, end: ComboTier.tier2Threshold - 1)
        case .three:
            return ramp(combo, start: ComboTier.tier3Threshold, end: ComboTier.tier4Threshold - 1)
        case .four:
            return maxWiggle
        }
    }

    private static func ramp(_ combo: Int, start: Int, end: Int) -> CGFloat {
        guard end > start else { return maxWiggle }
        let fraction = CGFloat(combo - start) / CGFloat(end - start)
        return maxWiggle * min(max(fraction, 0), 1)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A' \
  -only-testing:audio_listenTests/ComboEscalationTests 2>&1 | grep -E "passed|failed|\*\* TEST (SUCCEEDED|FAILED)"
```
Expected: all 4 tests pass; TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/ComboEscalation.swift audio_listenTests/ComboEscalationTests.swift
git commit -m "feat: add ComboEscalation tier/visual pure logic"
```

---

### Task 2: Wire `comboBadge` to the escalation visual; retire `flameAsset`

**Files:**
- Modify: `audio_listen/Presentation/Drill/DrillView.swift` (the `comboBadge` computed property, and add two `@State` fields)
- Delete: `audio_listen/Presentation/Drill/StickerHelpers.swift`, `audio_listenTests/StickerHelpersTests.swift`

**Interfaces:**
- Consumes: `ComboEscalation.visual(for:)`, `ComboVisual` (Task 1).

This is a UI change verified by build (the tier/visual logic is already tested in Task 1). `flameAsset(for:)` was only used by `comboBadge`; after this task it is gone.

- [ ] **Step 1: Add the two animation-state fields**

In `audio_listen/Presentation/Drill/DrillView.swift`, add these after the existing `@State private var beltPulse = false` line:

```swift
    @State private var wigglePhase = false
    @State private var rainbowPhase = 0.0
```

- [ ] **Step 2: Replace `comboBadge`**

Replace the entire existing `comboBadge` computed property with:

```swift
    private var comboBadge: some View {
        let showing = viewModel.comboCount >= 2
        let visual = ComboEscalation.visual(for: viewModel.comboCount)
        let scale = min(1.0 + Double(viewModel.comboCount) * 0.05, 1.6)
        return HStack(spacing: 6) {
            Image(visual.flameAsset)
                .resizable()
                .scaledToFit()
                .frame(height: flameHeight)
                .hueRotation(.degrees(visual.rainbow ? rainbowPhase : 0))
                .offset(x: wigglePhase ? visual.wiggleAmplitude : -visual.wiggleAmplitude)
                .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: wigglePhase)
            Text("\(viewModel.comboCount) combo")
                .font(.headline)
                .foregroundStyle(visual.rainbow ? AnyShapeStyle(rainbowGradient) : AnyShapeStyle(Color.orange))
                .hueRotation(.degrees(visual.rainbow ? rainbowPhase : 0))
        }
        .scaleEffect(scale)
        .opacity(showing ? 1 : 0)
        .frame(height: flameHeight)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
        .onAppear {
            wigglePhase = true
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rainbowPhase = 360
            }
        }
    }

    private var rainbowGradient: AngularGradient {
        AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center)
    }
```

- [ ] **Step 3: Delete the retired helper and its test**

```bash
git rm audio_listen/Presentation/Drill/StickerHelpers.swift audio_listenTests/StickerHelpersTests.swift
```

- [ ] **Step 4: Verify it builds**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: BUILD SUCCEEDED. (If `flameAsset` is still referenced anywhere, the build fails — grep `flameAsset` should return nothing under `audio_listen/`.)

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/DrillView.swift
git commit -m "feat: drive combo badge from ComboEscalation (flame, wiggle, rainbow)"
```

---

### Task 3: Generate the combo sound cues (Python script + `.wav` files)

**Files:**
- Create: `scripts/generate_combo_sounds.py`
- Create: `scripts/test_generate_combo_sounds.py`
- Create (generated, committed): `audio_listen/Sounds/combo-hit-1.wav` … `combo-hit-4.wav`, `combo-tierup-2.wav` … `combo-tierup-4.wav`

**Interfaces:**
- Produces: `generate(output_dir: str) -> None` and `CUE_NAMES: list[str]` in `scripts/generate_combo_sounds.py`.

- [ ] **Step 1: Write the failing test**

First check the existing convention: `cat scripts/test_generate_art.py | head -20` and `cat scripts/README.md` to see how tests import the script and how pytest is invoked. Mirror that import style. Then create `scripts/test_generate_combo_sounds.py`:

```python
import wave

from generate_combo_sounds import CUE_NAMES, generate


def test_generates_all_cues_nonempty(tmp_path):
    generate(str(tmp_path))
    for name in CUE_NAMES:
        path = tmp_path / f"{name}.wav"
        assert path.exists()
        with wave.open(str(path)) as reader:
            assert reader.getnframes() > 0
            assert reader.getframerate() == 44100
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd scripts && uv run pytest test_generate_combo_sounds.py -q
```
Expected: FAIL — `ModuleNotFoundError: No module named 'generate_combo_sounds'` (or collection error). If `uv run pytest` is not how this repo runs script tests, use the exact command from `scripts/README.md`.

- [ ] **Step 3: Write the generator**

Create `scripts/generate_combo_sounds.py`:

```python
import os
import wave

import numpy as np

SAMPLE_RATE = 44100


def _note_hz(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))


def _envelope(length):
    t = np.linspace(0.0, 1.0, length, dtype=np.float32)
    attack = np.clip(t / 0.05, 0.0, 1.0)
    decay = np.exp(-3.5 * t)
    return (attack * decay).astype(np.float32)


def _render(semitone_sequence, note_seconds, harmonics):
    chunks = []
    for semitone in semitone_sequence:
        length = int(SAMPLE_RATE * note_seconds)
        t = np.arange(length, dtype=np.float32) / SAMPLE_RATE
        freq = _note_hz(semitone)
        tone = np.zeros(length, dtype=np.float32)
        for multiple, amplitude in harmonics:
            tone += amplitude * np.sin(2.0 * np.pi * freq * multiple * t)
        chunks.append(tone * _envelope(length))
    samples = np.concatenate(chunks)
    peak = float(np.max(np.abs(samples))) or 1.0
    return (samples / peak * 0.9).astype(np.float32)


WARM = [(1.0, 1.0), (2.0, 0.4), (3.0, 0.15)]
BRIGHT = [(1.0, 1.0), (2.0, 0.6), (3.0, 0.35), (4.0, 0.2)]

C5, E5, G5, C6, E6 = 3, 7, 10, 15, 19

CUES = {
    "combo-hit-1": ([C5], 0.16, WARM),
    "combo-hit-2": ([C5, E5], 0.13, WARM),
    "combo-hit-3": ([C5, E5, G5], 0.12, WARM),
    "combo-hit-4": ([C5, E5, G5, C6], 0.11, BRIGHT),
    "combo-tierup-2": ([C5, E5, G5], 0.16, WARM),
    "combo-tierup-3": ([C5, E5, G5, C6], 0.15, BRIGHT),
    "combo-tierup-4": ([C5, E5, G5, C6, E6], 0.14, BRIGHT),
}

CUE_NAMES = list(CUES.keys())


def _write_wav(path, samples):
    data = (samples * 32767.0).astype(np.int16)
    with wave.open(path, "w") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(SAMPLE_RATE)
        writer.writeframes(data.tobytes())


def generate(output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for name, (sequence, note_seconds, harmonics) in CUES.items():
        samples = _render(sequence, note_seconds, harmonics)
        _write_wav(os.path.join(output_dir, f"{name}.wav"), samples)


def main():
    output_dir = os.path.join(os.path.dirname(__file__), "..", "audio_listen", "Sounds")
    generate(output_dir)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd scripts && uv run pytest test_generate_combo_sounds.py -q
```
Expected: 1 passed.

- [ ] **Step 5: Generate the committed audio files**

```bash
cd scripts && uv run python generate_combo_sounds.py
ls -la ../audio_listen/Sounds/
```
Expected: 7 `.wav` files listed, each non-zero size.

- [ ] **Step 6: Lint and commit**

```bash
cd scripts && uv run ruff check generate_combo_sounds.py test_generate_combo_sounds.py && uv run ruff format generate_combo_sounds.py test_generate_combo_sounds.py
cd .. && git add scripts/generate_combo_sounds.py scripts/test_generate_combo_sounds.py audio_listen/Sounds
git commit -m "feat: script-generate combo sound cues"
```

---

### Task 4: Rewrite `ComboSoundPlayer` to play the tiered samples

**Files:**
- Rewrite: `audio_listen/Presentation/Drill/ComboSoundPlayer.swift`

**Interfaces:**
- Consumes: `ComboTier` (Task 1); the bundled `.wav` cues (Task 3).
- Produces: `final class ComboSoundPlayer { func play(combo: Int) }` (same call site as today: `DrillView` calls `comboSound.play(combo: newValue)` on combo increment).

- [ ] **Step 1: Rewrite the player**

Replace the entire contents of `audio_listen/Presentation/Drill/ComboSoundPlayer.swift` with:

```swift
import AVFoundation

final class ComboSoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]
    private var lastTier: ComboTier = .none

    private let hitFiles: [ComboTier: String] = [
        .one: "combo-hit-1",
        .two: "combo-hit-2",
        .three: "combo-hit-3",
        .four: "combo-hit-4"
    ]

    private let tierUpFiles: [ComboTier: String] = [
        .two: "combo-tierup-2",
        .three: "combo-tierup-3",
        .four: "combo-tierup-4"
    ]

    func play(combo: Int) {
        let tier = ComboTier.tier(for: combo)
        guard tier != .none else {
            lastTier = tier
            return
        }
        if tier.rawValue > lastTier.rawValue, let stinger = tierUpFiles[tier] {
            play(named: stinger)
        }
        if let hit = hitFiles[tier] {
            play(named: hit)
        }
        lastTier = tier
    }

    private func play(named name: String) {
        guard let player = player(named: name) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(named name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A' \
  -derivedDataPath /private/tmp/combo-dd build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify the cues are bundled into the app**

```bash
ls /private/tmp/combo-dd/Build/Products/Debug-iphonesimulator/audio_listen.app/ | grep combo
```
Expected: the 7 `combo-*.wav` files are listed (they were copied into the app bundle). If they are absent, the `Sounds/` files are not app-target resources — STOP and report `DONE_WITH_CONCERNS`, because playback will silently no-op.

- [ ] **Step 4: Run the full unit suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'id=7C763FCE-958D-4249-BF6A-B54DE02FA35A' \
  -only-testing:audio_listenTests 2>&1 | grep -E "\*\* TEST (SUCCEEDED|FAILED)"
```
Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add audio_listen/Presentation/Drill/ComboSoundPlayer.swift
git commit -m "feat: play tiered combo sample cues and tier-up stingers"
```

---

## Self-Review

**Spec coverage:**
- Tiered flame size / motion / rainbow keyed on 15/25/50 → Task 1 (`ComboEscalation`) + Task 2 (view). ✓
- `flameAsset` retired / superseded → Task 2 (deleted, uses `ComboEscalation`). ✓
- Side-to-side wiggle growing within tiers 1 & 3, calm in tier 2, full in tier 4 → Task 1 `wiggle(for:tier:)` + Task 2 `offset`/animation. ✓
- Rainbow at 50+ → Task 1 `rainbow` flag + Task 2 `hueRotation`/gradient. ✓
- Script-generated per-tier cues + tier-up stingers → Task 3 (`generate_combo_sounds.py`, 7 wavs). ✓
- Sample-based `ComboSoundPlayer` with tier-up detection, fail-silent on missing file → Task 4. ✓
- Bundling verified → Task 4 Step 3. ✓
- Pure-function tests → Task 1; script test → Task 3; existing suites green → Task 4 Step 4. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; no "similar to Task N". ✓

**Type consistency:** `ComboTier` (`.none/.one/.two/.three/.four`, `rawValue`, `tier(for:)`, `tier2/3/4Threshold`), `ComboVisual` (`flameAsset`/`wiggleAmplitude`/`rainbow`), `ComboEscalation.visual(for:)`/`maxWiggle`, `generate`/`CUE_NAMES`, `ComboSoundPlayer.play(combo:)` are used identically across Tasks 1–4. ✓
