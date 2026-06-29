# Art generation

Generates FretBoardCrazies art assets via the OpenAI Images API (`gpt-image-1`).
Standard-library Python only — no `uv`/`pip` install needed.

## Setup

```bash
cp .env.example .env          # then paste your key into .env
export $(grep -v '^#' .env | xargs)   # load it into the shell
```

## The anchored workflow

1. Generate the style anchor, review it, re-roll until you like it:

   ```bash
   python3 scripts/generate_art.py anchor
   ```

   The approved `art/_anchor.png` becomes the reference image every other asset
   is generated from, so the whole set shares one look.

2. Generate an asset or a group; it inherits the anchor automatically:

   ```bash
   python3 scripts/generate_art.py belts          # a whole group
   python3 scripts/generate_art.py belt-white     # a single asset
   ```

## Iterating

- Cheap by default (`low` quality). Add `--final` for the `high`-quality pass.
- Re-roll a settled prompt: edit the prompt in `generate_art.py`, then
  `python3 scripts/generate_art.py belt-white --force`.
- Compare options: `--variants 3` writes `art/_candidates/belt-white-{1,2,3}.png`.
  Pick one and promote it:

  ```bash
  python3 scripts/generate_art.py --promote belt-white=2
  ```

## Reviewing

Every run rewrites `art/index.html` (image + the prompt that made it) and opens
it. Or open a single file: `open art/_anchor.png`.

## Cost

Each run prints an estimate and asks before spending (skip with `--yes`). The
`COST_TABLE` in `generate_art.py` must be verified against OpenAI's current
`gpt-image-1` pricing — the committed numbers are estimates.

## Storage

- Committed: `art/*.png` masters, `art/_anchor.png`, sidecar `art/*.json`.
- Gitignored scratch: `art/_candidates/`, `art/index.html`.
