# Anchored Art Generation — Design

Date: 2026-06-29
Topic: A repeatable, consistent, cost-aware pipeline for generating
FretBoardCrazies art assets via the OpenAI Images API (`gpt-image-1`).

## Goal

Generate a cohesive set of UI art assets (app icon, belt badges, combo flames,
success sticker, and later fretboard/preset art) that share one visual identity,
while keeping spend low and the human review loop tight.

Two problems this design solves:

1. **Consistency** — independent `gpt-image-1` calls drift in palette, line
   weight, and lighting even with a shared prompt prefix.
2. **Cost & iteration** — you rarely nail an image on the first roll; the loop
   must make cheap iteration and single-asset re-rolls easy without re-spending
   on the whole set.

## Decisions (locked)

- **No mascot.** The earlier "Fret" character concept is dropped. Consistency
  comes from a coherent *visual style* across objects, not an on-model character.
- **Theme: flat playful** (the existing doc direction) — Duolingo-style flat
  vector, chunky rounded shapes, thick clean outlines, soft drop shadow, warm
  orange/amber + teal accents.
- **Consistency via style-anchor reference image** — one approved anchor tile is
  passed as a reference into every other generation.
- **Variants are flag-controlled, off by default** — single-shot is the norm;
  `--variants N` is reached for only while a prompt is still unsettled.
- **Master PNGs are committed to git.**

## Architecture

### Theme as a structured style spec

A single block at the top of `scripts/generate_art.py` holds the theme:
palette hex values, shape language, line weight, lighting, and texture. It is
the single source that (a) builds the anchor and (b) prefixes every asset
prompt. Editing the theme means editing one block — nothing else.

### Two-endpoint flow

- **Anchor** (`anchor` pseudo-group) → `POST /v1/images/generations`, no
  reference image, generated from the style spec → written to `art/_anchor.png`.
- **All other assets** → `POST /v1/images/edits`, passing `art/_anchor.png` as
  the reference image alongside the asset's own prompt body. The edits endpoint's
  image input is what carries the anchor's palette/line-weight/lighting into
  each new asset.
- **Fallback** — if `art/_anchor.png` is missing, warn and fall back to the
  generations endpoint (prompt-only). The run still works; it is just less
  cohesive.

### Asset set

Configured as data in an `ASSETS` dict, group → list of asset entries
(filename, prompt body, size, transparent, quality):

- `anchor` — 1 style tile (pseudo-group; no reference).
- `icon` — `app-icon` (opaque, high).
- `belts` — 8 belts (white→black), transparent.
- `combo` — `flame-small`, `flame-large`, `combo-burst`, transparent.
- `success` — `correct-sticker`, transparent.

Adding `presets` or `fretboard` later is purely a new `ASSETS` entry — no code
changes.

**Dropped / deferred:**
- Mascot poses — removed (no mascot).
- Fret-based empty-state and "how it works" art — need a non-mascot redesign;
  out of scope for this spec.
- Background — stays a SwiftUI gradient (no generation needed).

## Iteration & review loop

### Phase A — lock the theme (once)

1. Edit the style spec; run the `anchor` group at low quality.
2. **User reviews the anchor.** If rejected, tweak spec/prompt and re-roll
   (cheap).
3. On approval, freeze `art/_anchor.png`. The theme is now locked.

### Phase B — per asset/group (repeat)

1. Generate the asset at low quality, anchored.
2. **User reviews.** Three outcomes:
   - Keep → optional `--final` high-quality pass → done.
   - Close → `--variants N`; user picks; `--promote <name>=<k>` copies the
     winner to `art/<name>.png`.
   - Off → tweak prompt, re-roll with `--force`.
3. Next asset.

The user's role is look-and-judge at two gates (anchor, then each asset).
Claude may `Read` PNGs first to catch obvious failures (wrong color, opaque when
transparency was requested) so the user only reviews plausible candidates.

### How assets are shown to the user

PNGs cannot render in the terminal, so review is macOS-native:

- `open art/_anchor.png` (single) or `open art/` (Finder grid) → Preview.
- For variant picking, the script regenerates `art/index.html`: a gallery
  showing each image next to the exact prompt + quality that produced it, with
  candidates side by side. `open art/index.html` is the richest review surface.

## CLI surface

- Select by group (`belts`) or single asset (`belt-white`).
- `--list` — show groups/assets without generating.
- `--variants N` — write `art/_candidates/<name>-{1..N}.png` instead of a single
  final.
- `--promote <name>=<k>` — copy `art/_candidates/<name>-<k>.png` to
  `art/<name>.png` (+ its sidecar).
- `--final` — run at `high` quality (default is `low`).
- `--force` — overwrite existing finals (default: skip assets whose PNG exists).
- `--yes` — skip the spend confirmation prompt.

## Cost control

- A `(size, quality) → estimated USD` table lives in the script. The numbers are
  verified once against OpenAI's current `gpt-image-1` pricing — not hardcoded
  from memory.
- Before any generation, print the estimate: e.g. "About to generate 8 images
  ≈ \$X.XX" and require confirmation unless `--yes`.
- Print a running total as the run proceeds.
- Default `quality=low` keeps iteration cheap; `--final` is the only path to
  `high`.
- Idempotent-by-default skipping prevents accidental whole-set re-spend.

## Reproducibility

Each generated PNG gets a sidecar `art/<name>.json`: prompt, size, quality,
anchor filename + content hash, model, and timestamp. This makes any asset
reproducible, diffable, and self-explaining (which prompt tweak produced the
keeper).

## Storage & git

- `art/` is the staging area (not the app bundle). Wiring finals into
  `Assets.xcassets` is a separate later task.
- **Committed:** `art/*.png` masters, `art/_anchor.png`, sidecar `art/*.json`.
- **Gitignored:** `art/_candidates/` and `art/index.html` (scratch).

## Scaffolding

- `scripts/README.md` — env setup (`.env`, `OPENAI_API_KEY`), usage examples,
  cost notes, the review loop.
- `.env.example` — `OPENAI_API_KEY=` placeholder.
- Update `docs/art-asset-wishlist.md` — drop the mascot, reflect the anchor
  workflow.

## Out of scope

- Post-processing (downscale to @1x/@2x, build the macOS `.appiconset`, trim
  transparency) — a later task once masters are approved.
- Wiring assets into `Assets.xcassets` and replacing in-app SF Symbols.
- Non-mascot redesign of empty-state / "how it works" art.
