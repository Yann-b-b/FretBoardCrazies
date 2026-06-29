# Anchored Art Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `scripts/generate_art.py` into an anchored, cost-aware, single-asset-reroll-friendly tool that generates a visually consistent set of FretBoardCrazies art assets via the OpenAI Images API.

**Architecture:** A single dependency-free Python script. A frozen `Asset` dataclass + an `ASSETS` registry describe what to generate. Pure functions (selection, cost, prompt/payload/sidecar builders, gallery HTML) are unit-tested; a thin network layer routes the anchor through `/v1/images/generations` and every other asset through `/v1/images/edits` (passing `art/_anchor.png` as the reference image that carries the shared style). A thin `main()` wires selection → cost confirmation → generation → sidecar → gallery.

**Tech Stack:** Python 3.11 standard library only (`urllib`, `json`, `base64`, `hashlib`, `argparse`, `dataclasses`, `shutil`, `uuid`). Tests use `pytest` run via `python3 -m pytest scripts/`. No `uv` project, no third-party deps — this is a helper script inside a Swift repo, not a pipeline project.

## Global Constraints

- Python 3.11+, standard library only at runtime — no third-party imports.
- `OPENAI_API_KEY` is read from the environment only; never hardcoded, never logged.
- Model is `gpt-image-1`. All assets are `1024x1024`.
- Anchor file path is `art/_anchor.png`; it is the only non-anchored generation.
- Default run quality is `low`; `--final` raises the whole run to `high`.
- No code comments — code must be self-documenting (clear names).
- Explicit error handling — never silently swallow failures.
- Tests run with `python3 -m pytest scripts/test_generate_art.py -v` (no `__init__.py` in `scripts/`; pytest's default prepend import mode puts `scripts/` on `sys.path`).
- Belt colors, in order: white, yellow, orange, green, blue, purple, brown, black.
- Committed to git: `art/*.png` masters, `art/_anchor.png`, sidecar `art/*.json`. Gitignored: `art/_candidates/`, `art/index.html`.

---

### Task 1: Repo scaffolding (gitignore + env example)

**Files:**
- Modify: `.gitignore`
- Create: `.env.example`

**Interfaces:**
- Consumes: nothing.
- Produces: gitignore rules relied on by Task 6 (candidates dir / gallery are scratch); `.env.example` referenced by Task 7 README.

- [ ] **Step 1: Add scratch paths to `.gitignore`**

Append these lines to `.gitignore` (the file currently ends with `.env` and no trailing newline — add a newline first):

```
art/_candidates/
art/index.html
```

- [ ] **Step 2: Create `.env.example`**

Create `.env.example`:

```
OPENAI_API_KEY=
```

- [ ] **Step 3: Verify the ignore rules resolve**

Run:
```bash
mkdir -p art/_candidates && touch art/_candidates/x.png art/index.html
git check-ignore art/_candidates/x.png art/index.html
```
Expected output (both paths printed = both ignored):
```
art/_candidates/x.png
art/index.html
```
Then clean up: `rm -rf art/_candidates art/index.html`

- [ ] **Step 4: Commit**

```bash
git add .gitignore .env.example
git commit -m "chore: gitignore art scratch dirs, add .env.example"
```

---

### Task 2: Asset model, style spec, registry, selection + cost

**Files:**
- Create (replaces existing): `scripts/generate_art.py`
- Create: `scripts/test_generate_art.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Asset` frozen dataclass with fields `name: str, group: str, prompt_body: str, size: str, transparent: bool, anchored: bool`.
  - `ASSETS: list[Asset]` — groups `anchor`, `icon`, `belts`, `combo`, `success`.
  - `resolve_selection(tokens: list[str], assets: list[Asset]) -> list[Asset]` — tokens may be group names or asset names; empty tokens means all; raises `ValueError` on unknown; dedupes preserving order.
  - `estimate_cost(assets: list[Asset], quality: str, variants: int, cost_table: dict[tuple[str, str], float]) -> float`.
  - `COST_TABLE: dict[tuple[str, str], float]`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/test_generate_art.py`:

```python
import pytest

from generate_art import (
    ASSETS,
    COST_TABLE,
    Asset,
    estimate_cost,
    resolve_selection,
)


def test_registry_has_no_mascot_and_one_anchor():
    groups = {asset.group for asset in ASSETS}
    assert "mascot" not in groups
    anchors = [asset for asset in ASSETS if asset.group == "anchor"]
    assert [asset.name for asset in anchors] == ["_anchor"]
    assert anchors[0].anchored is False


def test_eight_belts_in_canonical_order():
    belts = [asset.name for asset in ASSETS if asset.group == "belts"]
    assert belts == [
        "belt-white", "belt-yellow", "belt-orange", "belt-green",
        "belt-blue", "belt-purple", "belt-brown", "belt-black",
    ]


def test_resolve_empty_returns_all():
    assert resolve_selection([], ASSETS) == ASSETS


def test_resolve_group_expands_to_members():
    selected = resolve_selection(["belts"], ASSETS)
    assert [asset.name for asset in selected] == [
        "belt-white", "belt-yellow", "belt-orange", "belt-green",
        "belt-blue", "belt-purple", "belt-brown", "belt-black",
    ]


def test_resolve_single_asset_by_name():
    selected = resolve_selection(["belt-white"], ASSETS)
    assert [asset.name for asset in selected] == ["belt-white"]


def test_resolve_dedupes_group_and_member():
    selected = resolve_selection(["belts", "belt-white"], ASSETS)
    names = [asset.name for asset in selected]
    assert names.count("belt-white") == 1


def test_resolve_unknown_raises():
    with pytest.raises(ValueError, match="nope"):
        resolve_selection(["nope"], ASSETS)


def test_estimate_cost_scales_with_variants():
    table = {("1024x1024", "low"): 0.01}
    one = Asset("x", "g", "body", "1024x1024", True, True)
    assert estimate_cost([one], "low", 1, table) == pytest.approx(0.01)
    assert estimate_cost([one], "low", 3, table) == pytest.approx(0.03)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'generate_art'` (or import error).

- [ ] **Step 3: Write the module foundation**

Create `scripts/generate_art.py` (this replaces the existing file entirely):

```python
#!/usr/bin/env python3
"""Generate FretBoardCrazies art assets via the OpenAI Images API.

Reads OPENAI_API_KEY from the environment. The anchor asset is generated from
the style spec; every other asset is generated by editing the anchor so the set
shares one visual identity. See scripts/README.md.
"""

import argparse
import base64
import hashlib
import json
import os
import shutil
import sys
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

API_GENERATIONS_URL = "https://api.openai.com/v1/images/generations"
API_EDITS_URL = "https://api.openai.com/v1/images/edits"
MODEL = "gpt-image-1"
OUTPUT_DIR = "art"
CANDIDATES_DIR = os.path.join(OUTPUT_DIR, "_candidates")
ANCHOR_PATH = os.path.join(OUTPUT_DIR, "_anchor.png")
GALLERY_PATH = os.path.join(OUTPUT_DIR, "index.html")

STYLE_SPEC = {
    "shape_language": "chunky rounded shapes",
    "line_weight": "thick clean outlines",
    "lighting": "soft drop shadow and gentle gradients",
    "palette": (
        "warm orange #FF8A3D and amber #FFB23E primaries, teal #2DD4BF accents, "
        "soft cream #FFF6EC background"
    ),
}


def build_style_prefix(spec):
    return (
        f"flat vector illustration, playful and friendly, {spec['shape_language']}, "
        f"{spec['line_weight']}, {spec['lighting']}, warm palette ({spec['palette']}), "
        "Duolingo-style illustration, high detail, centered. "
    )


STYLE_PREFIX = build_style_prefix(STYLE_SPEC)

BELT_COLORS = ["white", "yellow", "orange", "green", "blue", "purple", "brown", "black"]


@dataclass(frozen=True)
class Asset:
    name: str
    group: str
    prompt_body: str
    size: str
    transparent: bool
    anchored: bool


ASSETS = [
    Asset(
        "_anchor", "anchor",
        "a style reference tile arranging a guitar pick, a five-point star, and a "
        "rounded badge together to showcase the palette, line weight, and shading",
        "1024x1024", False, False,
    ),
    Asset(
        "app-icon", "icon",
        "app icon: a cheerful stylized guitar fretboard with one glowing note dot, "
        "rounded-square composition, warm orange-to-amber background, iconic and "
        "simple, readable when small",
        "1024x1024", False, True,
    ),
    *[
        Asset(
            f"belt-{color}", "belts",
            f"a cute knotted martial-arts belt icon in {color}, tied in a bow with "
            "two hanging ends, glossy, rounded, badge style, with a thin light "
            "outline so it reads on dark backgrounds",
            "1024x1024", True, True,
        )
        for color in BELT_COLORS
    ],
    Asset(
        "flame-small", "combo",
        "a small friendly cartoon flame spark, orange-yellow gradient, expressive",
        "1024x1024", True, True,
    ),
    Asset(
        "flame-large", "combo",
        "a big roaring friendly cartoon flame, orange-yellow gradient, energetic "
        "and expressive",
        "1024x1024", True, True,
    ),
    Asset(
        "combo-burst", "combo",
        "a celebratory burst graphic with stars and sparks conveying combo energy, "
        "warm colors",
        "1024x1024", True, True,
    ),
    Asset(
        "correct-sticker", "success",
        "a happy confetti starburst sticker conveying a 'Nice!' celebration moment, "
        "rounded and bright",
        "1024x1024", True, True,
    ),
]

COST_TABLE = {
    ("1024x1024", "low"): 0.011,
    ("1024x1024", "medium"): 0.042,
    ("1024x1024", "high"): 0.167,
}


def resolve_selection(tokens, assets):
    if not tokens:
        return list(assets)
    by_name = {asset.name: asset for asset in assets}
    group_names = {asset.group for asset in assets}
    selected = []
    unknown = []
    for token in tokens:
        if token in by_name:
            selected.append(by_name[token])
        elif token in group_names:
            selected.extend(asset for asset in assets if asset.group == token)
        else:
            unknown.append(token)
    if unknown:
        raise ValueError(f"Unknown group(s)/asset(s): {', '.join(unknown)}")
    seen = set()
    deduped = []
    for asset in selected:
        if asset.name not in seen:
            seen.add(asset.name)
            deduped.append(asset)
    return deduped


def estimate_cost(assets, quality, variants, cost_table):
    return sum(cost_table[(asset.size, quality)] * variants for asset in assets)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: PASS (8 passed).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_art.py scripts/test_generate_art.py
git commit -m "feat: asset registry, selection, and cost estimation (no mascot)"
```

---

### Task 3: Prompt, payload, sidecar, anchor-hash, and skip builders

**Files:**
- Modify: `scripts/generate_art.py`
- Modify: `scripts/test_generate_art.py`

**Interfaces:**
- Consumes: `Asset`, `STYLE_PREFIX`, `MODEL` from Task 2.
- Produces:
  - `build_prompt(asset: Asset, style_prefix: str) -> str`
  - `build_generation_payload(asset: Asset, prompt: str, quality: str) -> dict`
  - `build_edit_fields(asset: Asset, prompt: str, quality: str) -> dict[str, str]`
  - `build_sidecar(asset, prompt, quality, anchor_digest, model, timestamp) -> dict`
  - `anchor_hash(path: str) -> str | None`
  - `should_skip(path: str, force: bool) -> bool`

- [ ] **Step 1: Write the failing tests**

Append to `scripts/test_generate_art.py`:

```python
from generate_art import (
    STYLE_PREFIX,
    anchor_hash,
    build_edit_fields,
    build_generation_payload,
    build_prompt,
    build_sidecar,
    should_skip,
)


def test_build_prompt_prepends_style_prefix():
    asset = Asset("x", "g", "a red box", "1024x1024", True, True)
    prompt = build_prompt(asset, STYLE_PREFIX)
    assert prompt.startswith(STYLE_PREFIX)
    assert prompt.endswith("a red box")


def test_generation_payload_opaque_vs_transparent():
    opaque = Asset("o", "g", "body", "1024x1024", False, False)
    clear = Asset("c", "g", "body", "1024x1024", True, True)
    assert build_generation_payload(opaque, "p", "low")["background"] == "opaque"
    assert build_generation_payload(clear, "p", "high")["background"] == "transparent"
    assert build_generation_payload(clear, "p", "high")["quality"] == "high"


def test_edit_fields_are_all_strings():
    asset = Asset("c", "g", "body", "1024x1024", True, True)
    fields = build_edit_fields(asset, "p", "low")
    assert all(isinstance(value, str) for value in fields.values())
    assert fields["background"] == "transparent"


def test_sidecar_carries_reproducibility_metadata():
    asset = Asset("belt-white", "belts", "body", "1024x1024", True, True)
    sidecar = build_sidecar(asset, "full prompt", "low", "abc123", "gpt-image-1", "2026-06-29T00:00:00Z")
    assert sidecar["name"] == "belt-white"
    assert sidecar["prompt"] == "full prompt"
    assert sidecar["anchor_hash"] == "abc123"
    assert sidecar["timestamp"] == "2026-06-29T00:00:00Z"


def test_anchor_hash_none_when_missing(tmp_path):
    assert anchor_hash(str(tmp_path / "absent.png")) is None


def test_anchor_hash_stable_for_same_bytes(tmp_path):
    path = tmp_path / "a.png"
    path.write_bytes(b"hello")
    assert anchor_hash(str(path)) == hashlib_sha256(b"hello")


def hashlib_sha256(data):
    import hashlib
    return hashlib.sha256(data).hexdigest()


def test_should_skip_only_when_exists_and_not_forced(tmp_path):
    path = tmp_path / "x.png"
    assert should_skip(str(path), force=False) is False
    path.write_bytes(b"x")
    assert should_skip(str(path), force=False) is True
    assert should_skip(str(path), force=True) is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: FAIL — `ImportError: cannot import name 'build_prompt'`.

- [ ] **Step 3: Add the builder functions**

Append to `scripts/generate_art.py` (after `estimate_cost`):

```python
def build_prompt(asset, style_prefix):
    return style_prefix + asset.prompt_body


def build_generation_payload(asset, prompt, quality):
    return {
        "model": MODEL,
        "prompt": prompt,
        "size": asset.size,
        "n": 1,
        "quality": quality,
        "background": "transparent" if asset.transparent else "opaque",
    }


def build_edit_fields(asset, prompt, quality):
    return {
        "model": MODEL,
        "prompt": prompt,
        "size": asset.size,
        "n": "1",
        "quality": quality,
        "background": "transparent" if asset.transparent else "opaque",
    }


def build_sidecar(asset, prompt, quality, anchor_digest, model, timestamp):
    return {
        "name": asset.name,
        "group": asset.group,
        "prompt": prompt,
        "size": asset.size,
        "quality": quality,
        "transparent": asset.transparent,
        "anchored": asset.anchored,
        "anchor_hash": anchor_digest,
        "model": model,
        "timestamp": timestamp,
    }


def anchor_hash(path):
    if not os.path.exists(path):
        return None
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def should_skip(path, force):
    return os.path.exists(path) and not force
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: PASS (all prior + 7 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_art.py scripts/test_generate_art.py
git commit -m "feat: prompt, payload, sidecar, anchor-hash, skip builders"
```

---

### Task 4: Network layer and endpoint routing

**Files:**
- Modify: `scripts/generate_art.py`
- Modify: `scripts/test_generate_art.py`

**Interfaces:**
- Consumes: `Asset`, `API_GENERATIONS_URL`, `API_EDITS_URL`, `MODEL`, `build_generation_payload`, `build_edit_fields` from Tasks 2-3.
- Produces:
  - `encode_multipart(fields: dict, files: dict) -> tuple[str, bytes]` — returns `(boundary, body)`.
  - `post_generation(url, payload, api_key) -> bytes` — returns raw PNG bytes.
  - `post_edit(url, fields, image_path, api_key) -> bytes` — returns raw PNG bytes.
  - `generate_one(asset, prompt, quality, api_key, anchor_path) -> bytes` — routes to edits when `asset.anchored` and the anchor file exists, else generations.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/test_generate_art.py`:

```python
import generate_art


def test_encode_multipart_includes_field_and_file():
    boundary, body = generate_art.encode_multipart(
        {"prompt": "hi"}, {"image": ("anchor.png", b"PNGDATA", "image/png")}
    )
    assert boundary in body.decode("latin-1")
    assert 'name="prompt"' in body.decode("latin-1")
    assert b"PNGDATA" in body
    assert 'filename="anchor.png"' in body.decode("latin-1")


def test_generate_one_routes_to_edits_when_anchored(tmp_path, monkeypatch):
    anchor = tmp_path / "_anchor.png"
    anchor.write_bytes(b"anchorbytes")
    calls = {}

    def fake_post_edit(url, fields, image_path, api_key):
        calls["edit"] = (url, image_path)
        return b"EDITED"

    def fake_post_generation(url, payload, api_key):
        calls["generation"] = url
        return b"GENERATED"

    monkeypatch.setattr(generate_art, "post_edit", fake_post_edit)
    monkeypatch.setattr(generate_art, "post_generation", fake_post_generation)

    asset = Asset("belt-white", "belts", "body", "1024x1024", True, True)
    result = generate_art.generate_one(asset, "p", "low", "key", str(anchor))
    assert result == b"EDITED"
    assert "generation" not in calls
    assert calls["edit"][0] == generate_art.API_EDITS_URL


def test_generate_one_uses_generations_for_anchor_or_missing_anchor(monkeypatch):
    def fake_post_generation(url, payload, api_key):
        return b"GENERATED"

    monkeypatch.setattr(generate_art, "post_generation", fake_post_generation)

    anchor_asset = Asset("_anchor", "anchor", "body", "1024x1024", False, False)
    assert generate_art.generate_one(anchor_asset, "p", "low", "key", "missing.png") == b"GENERATED"

    belt = Asset("belt-white", "belts", "body", "1024x1024", True, True)
    assert generate_art.generate_one(belt, "p", "low", "key", "missing.png") == b"GENERATED"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: FAIL — `AttributeError: module 'generate_art' has no attribute 'encode_multipart'`.

- [ ] **Step 3: Add the network layer**

Append to `scripts/generate_art.py`:

```python
def encode_multipart(fields, files):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n".encode("utf-8")
        )
    for name, (filename, content, content_type) in files.items():
        header = (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; '
            f'filename="{filename}"\r\nContent-Type: {content_type}\r\n\r\n'
        ).encode("utf-8")
        parts.append(header + content + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return boundary, b"".join(parts)


def post_generation(url, payload, api_key):
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        body = json.loads(response.read().decode("utf-8"))
    return base64.b64decode(body["data"][0]["b64_json"])


def post_edit(url, fields, image_path, api_key):
    with open(image_path, "rb") as handle:
        image_bytes = handle.read()
    boundary, body = encode_multipart(
        fields, {"image": (os.path.basename(image_path), image_bytes, "image/png")}
    )
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        result = json.loads(response.read().decode("utf-8"))
    return base64.b64decode(result["data"][0]["b64_json"])


def generate_one(asset, prompt, quality, api_key, anchor_path):
    if asset.anchored and os.path.exists(anchor_path):
        return post_edit(API_EDITS_URL, build_edit_fields(asset, prompt, quality), anchor_path, api_key)
    return post_generation(API_GENERATIONS_URL, build_generation_payload(asset, prompt, quality), api_key)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: PASS (all prior + 3 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_art.py scripts/test_generate_art.py
git commit -m "feat: network layer with anchor-aware endpoint routing"
```

---

### Task 5: Gallery renderer and promote command

**Files:**
- Modify: `scripts/generate_art.py`
- Modify: `scripts/test_generate_art.py`

**Interfaces:**
- Consumes: `CANDIDATES_DIR`, `OUTPUT_DIR` from Task 2.
- Produces:
  - `render_gallery(entries: list[dict]) -> str` — each entry has keys `name`, `image`, `prompt`, `quality`; returns an HTML document string.
  - `promote(name: str, index: int, candidates_dir: str, output_dir: str) -> str` — copies `<candidates>/<name>-<index>.png` to `<output>/<name>.png` (and the matching `.json` if present); returns the destination path; raises `FileNotFoundError` if the candidate PNG is absent.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/test_generate_art.py`:

```python
from generate_art import promote, render_gallery


def test_render_gallery_embeds_name_and_prompt():
    html = render_gallery([
        {"name": "belt-white", "image": "belt-white.png", "prompt": "a white belt", "quality": "low"},
    ])
    assert "<img" in html
    assert "belt-white" in html
    assert "a white belt" in html
    assert "belt-white.png" in html


def test_promote_copies_png_and_sidecar(tmp_path):
    candidates = tmp_path / "_candidates"
    output = tmp_path / "out"
    candidates.mkdir()
    output.mkdir()
    (candidates / "belt-white-2.png").write_bytes(b"PNG2")
    (candidates / "belt-white-2.json").write_text('{"k": 1}')

    dest = promote("belt-white", 2, str(candidates), str(output))

    assert dest == str(output / "belt-white.png")
    assert (output / "belt-white.png").read_bytes() == b"PNG2"
    assert (output / "belt-white.json").read_text() == '{"k": 1}'


def test_promote_missing_candidate_raises(tmp_path):
    candidates = tmp_path / "_candidates"
    output = tmp_path / "out"
    candidates.mkdir()
    output.mkdir()
    with pytest.raises(FileNotFoundError):
        promote("belt-white", 9, str(candidates), str(output))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: FAIL — `ImportError: cannot import name 'promote'`.

- [ ] **Step 3: Add the gallery + promote functions**

Append to `scripts/generate_art.py`:

```python
def render_gallery(entries):
    figures = []
    for entry in entries:
        figures.append(
            f'<figure><img src="{entry["image"]}" width="256" loading="lazy">'
            f'<figcaption><b>{entry["name"]}</b> ({entry["quality"]})<br>'
            f'{entry["prompt"]}</figcaption></figure>'
        )
    return (
        "<!doctype html><meta charset=utf-8><title>FretBoardCrazies art</title>"
        "<style>body{font-family:-apple-system,sans-serif;background:#FFF6EC;padding:24px}"
        "figure{display:inline-block;width:288px;vertical-align:top;margin:0 16px 24px 0}"
        "img{background:#e9ddcc;border-radius:12px}"
        "figcaption{font-size:12px;color:#221A14}</style>"
        "<body>" + "".join(figures) + "</body>"
    )


def promote(name, index, candidates_dir, output_dir):
    source_png = os.path.join(candidates_dir, f"{name}-{index}.png")
    if not os.path.exists(source_png):
        raise FileNotFoundError(source_png)
    destination_png = os.path.join(output_dir, f"{name}.png")
    shutil.copyfile(source_png, destination_png)
    source_json = os.path.join(candidates_dir, f"{name}-{index}.json")
    if os.path.exists(source_json):
        shutil.copyfile(source_json, os.path.join(output_dir, f"{name}.json"))
    return destination_png
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: PASS (all prior + 3 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_art.py scripts/test_generate_art.py
git commit -m "feat: review gallery renderer and candidate promote"
```

---

### Task 6: CLI parsing and main orchestration

**Files:**
- Modify: `scripts/generate_art.py`
- Modify: `scripts/test_generate_art.py`

**Interfaces:**
- Consumes: every function from Tasks 2-5.
- Produces:
  - `parse_args(argv: list[str]) -> argparse.Namespace` with attributes `selection: list[str]`, `list: bool`, `variants: int`, `promote: str | None`, `final: bool`, `force: bool`, `yes: bool`.
  - `run(args, assets, api_key, timestamp) -> int` — the orchestration core, returns an exit code; writes PNGs + sidecars, regenerates the gallery, does not call `open` or read the environment (those live in `main`).
  - `main()` — reads env, parses args, calls `run`, opens the gallery.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/test_generate_art.py`:

```python
from generate_art import parse_args, run


def test_parse_args_defaults():
    args = parse_args(["belts"])
    assert args.selection == ["belts"]
    assert args.variants == 1
    assert args.final is False
    assert args.force is False
    assert args.list is False


def test_parse_args_flags():
    args = parse_args(["belt-white", "--variants", "3", "--final", "--force", "--yes"])
    assert args.selection == ["belt-white"]
    assert args.variants == 3
    assert args.final is True
    assert args.force is True
    assert args.yes is True


def test_parse_args_promote():
    args = parse_args(["--promote", "belt-white=2"])
    assert args.promote == "belt-white=2"


def test_run_generates_single_asset_with_sidecar(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    monkeypatch.setattr(generate_art, "ANCHOR_PATH", str(tmp_path / "_anchor.png"))
    monkeypatch.setattr(generate_art, "GALLERY_PATH", str(tmp_path / "index.html"))
    monkeypatch.setattr(generate_art, "generate_one", lambda *a, **k: b"PNGBYTES")

    args = parse_args(["belt-white", "--yes"])
    code = run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    assert code == 0
    assert (tmp_path / "belt-white.png").read_bytes() == b"PNGBYTES"
    sidecar = json.loads((tmp_path / "belt-white.json").read_text())
    assert sidecar["name"] == "belt-white"
    assert sidecar["quality"] == "low"
    assert (tmp_path / "index.html").exists()


def test_run_variants_write_candidates(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    monkeypatch.setattr(generate_art, "ANCHOR_PATH", str(tmp_path / "_anchor.png"))
    monkeypatch.setattr(generate_art, "GALLERY_PATH", str(tmp_path / "index.html"))
    monkeypatch.setattr(generate_art, "generate_one", lambda *a, **k: b"PNGBYTES")

    args = parse_args(["belt-white", "--variants", "2", "--yes"])
    code = run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    assert code == 0
    assert (tmp_path / "_candidates" / "belt-white-1.png").exists()
    assert (tmp_path / "_candidates" / "belt-white-2.png").exists()
    assert not (tmp_path / "belt-white.png").exists()


def test_run_skips_existing_without_force(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    monkeypatch.setattr(generate_art, "ANCHOR_PATH", str(tmp_path / "_anchor.png"))
    monkeypatch.setattr(generate_art, "GALLERY_PATH", str(tmp_path / "index.html"))
    (tmp_path / "belt-white.png").write_bytes(b"OLD")

    def fail_if_called(*a, **k):
        raise AssertionError("should not generate when skipping")

    monkeypatch.setattr(generate_art, "generate_one", fail_if_called)

    args = parse_args(["belt-white", "--yes"])
    code = run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    assert code == 0
    assert (tmp_path / "belt-white.png").read_bytes() == b"OLD"


def test_run_promote_branch(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    (tmp_path / "_candidates").mkdir()
    (tmp_path / "_candidates" / "belt-white-1.png").write_bytes(b"CAND")

    args = parse_args(["--promote", "belt-white=1", "--yes"])
    code = run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    assert code == 0
    assert (tmp_path / "belt-white.png").read_bytes() == b"CAND"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: FAIL — `ImportError: cannot import name 'parse_args'`.

- [ ] **Step 3: Add CLI parsing, the run core, and main**

Append to `scripts/generate_art.py`:

```python
def parse_args(argv):
    parser = argparse.ArgumentParser(description="Generate FretBoardCrazies art assets.")
    parser.add_argument("selection", nargs="*", help="group or asset names; empty means all")
    parser.add_argument("--list", action="store_true", help="list groups/assets and exit")
    parser.add_argument("--variants", type=int, default=1, help="write N candidates instead of a final")
    parser.add_argument("--promote", help="promote a candidate, format name=index")
    parser.add_argument("--final", action="store_true", help="generate at high quality")
    parser.add_argument("--force", action="store_true", help="overwrite existing finals")
    parser.add_argument("--yes", action="store_true", help="skip the spend confirmation")
    return parser.parse_args(argv)


def _write_image_and_sidecar(directory, filename, image_bytes, asset, prompt, quality, digest, timestamp):
    os.makedirs(directory, exist_ok=True)
    image_path = os.path.join(directory, f"{filename}.png")
    with open(image_path, "wb") as handle:
        handle.write(image_bytes)
    sidecar = build_sidecar(asset, prompt, quality, digest, MODEL, timestamp)
    with open(os.path.join(directory, f"{filename}.json"), "w") as handle:
        json.dump(sidecar, handle, indent=2)
    return image_path


def _gallery_entries(directory, quality, src_prefix=""):
    entries = []
    for filename in sorted(os.listdir(directory)):
        if not filename.endswith(".png"):
            continue
        name = filename[:-4]
        sidecar_path = os.path.join(directory, f"{name}.json")
        prompt = ""
        if os.path.exists(sidecar_path):
            with open(sidecar_path) as handle:
                prompt = json.load(handle).get("prompt", "")
        entries.append({"name": name, "image": src_prefix + filename, "prompt": prompt, "quality": quality})
    return entries


def run(args, assets, api_key, timestamp):
    if args.promote:
        name, _, index = args.promote.partition("=")
        promote(name, int(index), CANDIDATES_DIR, OUTPUT_DIR)
        print(f"Promoted {name}-{index} to {OUTPUT_DIR}/{name}.png")
        return 0

    selected = resolve_selection(args.selection, assets)
    quality = "high" if args.final else "low"

    if args.list:
        for asset in selected:
            print(f"{asset.group}/{asset.name}")
        return 0

    estimate = estimate_cost(selected, quality, args.variants, COST_TABLE)
    print(f"About to generate {len(selected) * args.variants} image(s) at {quality} "
          f"quality (~${estimate:.2f}).")
    if not args.yes:
        if input("Proceed? [y/N] ").strip().lower() != "y":
            print("Aborted.")
            return 1

    digest = anchor_hash(ANCHOR_PATH)
    spent = 0.0
    for asset in selected:
        prompt = build_prompt(asset, STYLE_PREFIX)
        final_path = os.path.join(OUTPUT_DIR, f"{asset.name}.png")
        if args.variants == 1 and should_skip(final_path, args.force):
            print(f"  skip {asset.name} (exists; use --force)")
            continue
        if args.variants > 1:
            for index in range(1, args.variants + 1):
                image_bytes = generate_one(asset, prompt, quality, api_key, ANCHOR_PATH)
                _write_image_and_sidecar(CANDIDATES_DIR, f"{asset.name}-{index}",
                                         image_bytes, asset, prompt, quality, digest, timestamp)
                spent += COST_TABLE[(asset.size, quality)]
                print(f"  candidate {asset.name}-{index}  (~${spent:.2f})")
        else:
            image_bytes = generate_one(asset, prompt, quality, api_key, ANCHOR_PATH)
            _write_image_and_sidecar(OUTPUT_DIR, asset.name, image_bytes, asset,
                                     prompt, quality, digest, timestamp)
            spent += COST_TABLE[(asset.size, quality)]
            print(f"  {asset.name}  (~${spent:.2f})")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if args.variants > 1:
        entries = _gallery_entries(CANDIDATES_DIR, quality, "_candidates/")
    else:
        entries = _gallery_entries(OUTPUT_DIR, quality)
    with open(GALLERY_PATH, "w") as handle:
        handle.write(render_gallery(entries))
    print(f"Gallery written to {GALLERY_PATH}")
    return 0


def main():
    args = parse_args(sys.argv[1:])
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and not args.list and not args.promote:
        print("OPENAI_API_KEY is not set. Copy .env.example to .env, fill it, and "
              "load it (see scripts/README.md).")
        sys.exit(1)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        code = run(args, ASSETS, api_key, timestamp)
    except (ValueError, FileNotFoundError) as error:
        print(f"Error: {error}")
        sys.exit(1)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        print(f"OpenAI API error: HTTP {error.code} {detail[:300]}")
        sys.exit(1)
    if code == 0 and not args.list and not args.promote:
        os.system(f"open {GALLERY_PATH}")
    sys.exit(code)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest scripts/test_generate_art.py -v`
Expected: PASS (all prior + 7 new).

- [ ] **Step 5: Verify the CLI runs without spending (list mode)**

Run: `python3 scripts/generate_art.py --list`
Expected: prints `anchor/_anchor`, `icon/app-icon`, the eight belts, the three combo assets, and `success/correct-sticker` — no network calls, no error.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate_art.py scripts/test_generate_art.py
git commit -m "feat: CLI parsing and run orchestration with cost gate and gallery"
```

---

### Task 7: Documentation — README and wishlist update

**Files:**
- Create: `scripts/README.md`
- Modify: `docs/art-asset-wishlist.md`

**Interfaces:**
- Consumes: the finished CLI from Task 6.
- Produces: human-facing docs. No code, no tests.

- [ ] **Step 1: Write `scripts/README.md`**

Create `scripts/README.md`:

````markdown
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
````

- [ ] **Step 2: Update the wishlist — remove the mascot and reflect the anchor workflow**

In `docs/art-asset-wishlist.md`, make these edits:

Replace the "Mascot concept" section (the `## Mascot concept` heading and its paragraph) with:

```markdown
## Consistency: the style anchor
Cohesion comes from a single approved **anchor image** (`art/_anchor.png`), not a
character. Every asset is generated by editing the anchor, so palette, line
weight, and shading carry across the set. See `scripts/README.md`.
```

Delete section "### 5. Mascot poses" entirely (its heading through its `Output:` line).

In "### 8. Empty-state illustrations" replace the Prompt line with:

```markdown
- **Prompt:** prefix + "a friendly empty-state illustration — a relaxed guitar
  next to an empty chart, warm and encouraging" (no mascot character)
```

In "### 9. "How it works" 3-step art" leave the three scenes as written (they are
object-based, not mascot-based) — no change needed.

- [ ] **Step 3: Verify the wishlist no longer references a mascot**

Run: `grep -in "mascot\|Fret " docs/art-asset-wishlist.md`
Expected: only the line in the new "Consistency: the style anchor" section that says "not a character" context — i.e. no "Fret the guitar character" poses remain. If any pose reference remains, remove it.

- [ ] **Step 4: Commit**

```bash
git add scripts/README.md docs/art-asset-wishlist.md
git commit -m "docs: art generation README; drop mascot for anchor workflow"
```

---

## Notes for the implementer

- Run the full suite after every task: `python3 -m pytest scripts/test_generate_art.py -v`.
- Never run a real generation during implementation — all generation is mocked in tests via `monkeypatch`. The only live command is `--list` (Task 6, Step 5), which makes no network call.
- The `COST_TABLE` numbers are placeholders to be verified against OpenAI pricing before the user does a real run; this is called out in the README and is intentionally not blocking implementation.
