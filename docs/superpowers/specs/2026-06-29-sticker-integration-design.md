# Sticker Integration — Design

Date: 2026-06-29
Topic: Wire the generated transparent stickers into the FretBoardCrazies macOS
app — belt badges, combo flame, success checkmark, an in-place belt-up moment,
and a proper macOS app icon.

## Goal

Replace the placeholder SF Symbols / emoji in the app with the locked sticker
art so the UI matches the new visual identity, and add a small belt-up
celebration. Screen backgrounds are already wired (separate work on the
`art-backgrounds` branch); this spec covers the foreground stickers only.

## Scope (locked)

In scope: belt badge swap, combo flame swap, success checkmark, in-place
belt-up animation, composited macOS app icon, and adding the sticker assets to
the catalog.

Out of scope: the welcome screen (deferred to a later run), Tuner/Settings
sticker accents, and any animation beyond what is specified here.

## Appearance decisions (locked)

- **Belt badge:** the colored belt sticker (~32pt) next to the `<X> belt` text
  label; the sticker is already colored, so no tint.
- **Combo flame:** a flame sticker inline to the left of `<N> combo`;
  `flame-small` for combos 2–4, `flame-large` for ≥5; keeps the existing
  spring-scale pulse on increment.
- **Success checkmark:** `correct-sticker` scales + fades in beside the
  `Correct!  X.XX s` line on the success state, and clears on the next prompt.
- **Belt-up:** when the belt rank increases, the belt badge springs up in scale
  once while `combo-burst` flashes behind it, then settles (~1s). In-place, no
  overlay.
- **App icon:** the locked transparent guitar (`art/app-icon.png`) composited
  (centered, padded) onto a warm orange→amber rounded-square master, exported as
  the macOS iconset.

## Architecture

### A. Assets into the catalog

Add transparent imagesets to `audio_listen/Assets.xcassets` (one folder +
`Contents.json` each; the catalog is a synchronized group, so dropping folders
in auto-includes them — same as the background imagesets):

- `belt-white`, `belt-yellow`, `belt-orange`, `belt-green`, `belt-blue`,
  `belt-purple`, `belt-brown`, `belt-black`
- `flame-small`, `flame-large`, `combo-burst`, `correct-sticker`

These are transparent PNGs with white sticker borders that read on both light
and dark, so **no light/dark appearance variants** are needed (single universal
image per set).

### B. Belt badge

`audio_listen/Presentation/Drill/Belt+UI.swift` currently maps each belt to a
`color` and a `symbolName` (always `"medal.fill"`, line 17). Add a computed
`assetName` returning the catalog name, e.g. `"belt-white"` for `.white`.

Replace the badge at:
- `audio_listen/Presentation/Drill/DrillView.swift:39` —
  `Image(systemName: viewModel.beltRank.belt.symbolName)` →
  `Image(viewModel.beltRank.belt.assetName).resizable().scaledToFit().frame(height: 32)`
- `audio_listen/Presentation/Drill/MasteryView.swift:41` — the same swap.

Drop the `.foregroundStyle(belt.color)` tint (the sticker is already colored).
Keep the `<X> belt` text label.

### C. Combo flame

`audio_listen/Presentation/Drill/DrillView.swift:48-58` (`comboBadge`): replace
`Text("🔥 \(viewModel.comboCount) combo")` with an `HStack` of
`Image(flameAsset(for: viewModel.comboCount)).resizable().scaledToFit().frame(height: 24)`
and `Text("\(viewModel.comboCount) combo")`. Keep the existing `scaleEffect` +
spring animation on the HStack.

`flameAsset(for:)` — a pure helper: returns `"flame-small"` for 2–4,
`"flame-large"` for ≥5.

### D. Success checkmark

`audio_listen/Presentation/Drill/DrillView.swift:73-76` (the `.success` case):
place `correct-sticker` beside the `Correct!  X.XX s` text in an `HStack`, with
a `.scaleEffect`/`.opacity` transition that pops it in (e.g. `.transition(.scale
.combined(with: .opacity))` driven by the success state). It is naturally
cleared when the state leaves `.success`.

### E. Belt-up (in-place)

In `DrillView`, add `@State private var beltBurst = false` and a `.onChange(of:
viewModel.beltRank.belt)` that, when the new belt **outranks** the old one,
toggles a brief `combo-burst` overlay behind the belt badge plus a one-shot
scale pulse on the badge, then resets after ~1s.

"Outranks" is a pure comparison on the belt's order (`Belt` is an ordered
ladder white→black); add an `Int` rank/order on `Belt` (or use its
`CaseIterable` index) for the comparison.

**Assumption to verify during implementation:** `viewModel.beltRank` updates
live mid-session (after answers) so `onChange` fires. If it does not, the
implementer hooks the celebration to whatever point recomputes the rank, rather
than forcing a fake update.

### F. App icon

A small Python script (stdlib + the already-present Pillow) composites
`art/app-icon.png` (the locked transparent guitar) centered with ~12% padding
onto a warm orange→amber rounded-square 1024×1024 master, then exports the macOS
icon sizes (16, 32, 128, 256, 512 at @1x and @2x) into
`audio_listen/Assets.xcassets/AppIcon.appiconset/` with the matching
`Contents.json`. macOS app icons are opaque, so the composite is flattened (no
alpha) onto the rounded-square background.

## Testable units

Pure functions, unit-tested (Swift test target `audio_listenTests`):
- `Belt.assetName` — every belt maps to its catalog name.
- `flameAsset(for:)` — threshold boundaries (1→none/handled by ≥2 gate, 2, 4,
  5).
- Belt "outranks" comparison — higher rank detected, equal/lower not.

The app-icon compositing is verified by its output (correct sizes written,
opaque). The view changes are verified by building and running the app.

## Out of scope

- Welcome screen (deferred).
- Tuner / Settings sticker accents.
- Replacing the in-fretboard target dot or heatmap dots with stickers.
