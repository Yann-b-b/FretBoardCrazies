# Release Automation (`release.py`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tested `scripts/release.py` that cuts a release — merge `dev → main`, generate a curated version header of the main features, bump the app version, write `CHANGELOG.md` + fastlane "What's New", and tag.

**Architecture:** One Python file (`scripts/release.py`) split into pure functions (git-log parsing, changelog rendering, pbxproj version bump, simulator selection) that are unit-tested in isolation, plus a `run_release()` orchestration that does the git/`$EDITOR`/`xcodebuild` side effects and is integration-tested against a temporary throwaway git repo. Stdlib only.

**Tech Stack:** Python 3.12+ (stdlib only), pytest. No third-party deps, no `pyproject.toml` (matches the repo's existing `scripts/*.py` + `test_*.py` convention).

## Global Constraints

- **Stdlib only** — no third-party imports. No `pyproject.toml`/uv setup is added; this follows the existing `scripts/` pattern (e.g. `generate_combo_sounds.py` + `test_generate_combo_sounds.py`).
- **No comments and no docstrings** — code must be self-documenting via names (global rule; existing repo scripts have none). String *content* shown to the user (e.g. the editor header) is data, not a comment.
- **No unused imports** (ruff F401) — each task adds only the imports it uses.
- **Run from the repo root.** The command is `python3 scripts/release.py <version>`. Tests run with `python3 -m pytest scripts/test_release.py -v` from the repo root (pytest prepends `scripts/` to `sys.path`, so `from release import ...` resolves).
- **pbxproj facts (verbatim):** `audio_listen.xcodeproj/project.pbxproj` has exactly **6** occurrences of `MARKETING_VERSION = <v>;` and **6** of `CURRENT_PROJECT_VERSION = <n>;`, all currently `1.0` and `1` respectively, tab-indented.
- **Version is manual** — the tool uses the version arg string verbatim (format-agnostic); no SemVer inference.
- **Keys/paths (verbatim):** changelog `CHANGELOG.md`; notes `fastlane/metadata/en-US/release_notes.txt`; tag `v<version>`.
- **Lint/format** each Python change with `python3 -m ruff check scripts/release.py scripts/test_release.py` and `python3 -m ruff format scripts/release.py scripts/test_release.py` before committing.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/release.py` | the release command — pure functions + `run_release()` orchestration + `main()` CLI |
| `scripts/test_release.py` | pytest suite: pure-function unit tests + a temp-repo integration test |

Everything lives in these two files; each task adds functions and their tests.

---

## Task 1: Changelog content generation (pure functions)

Creates `scripts/release.py` with the git-log → changelog-text functions. No git, no I/O.

**Files:**
- Create: `scripts/release.py`
- Create: `scripts/test_release.py`

**Interfaces:**
- Produces:
  - `latest_version_tag(tags: list[str]) -> str | None` — highest `v<n(.n)*>` tag by numeric order; `None` if none.
  - `deslug(branch: str) -> str` — `"instrument-string-presets"` → `"Instrument string presets"`.
  - `highlights_from_merges(merges: list[tuple[str, str]]) -> list[str]` — each `(subject, body)`; first non-empty body line, else de-slugged branch from `Merge branch '<x>'`.
  - `render_changelog_entry(version: str, entry_date: date, highlights: list[str], commit_subjects: list[str]) -> str`.
  - `highlights_plaintext(entry: str) -> str` — the `### Highlights` bullets as bare lines.
  - `finalize_entry(edited_text: str) -> str` — keep from first `## ` line; raise if empty/no highlights.

- [ ] **Step 1: Write the failing tests**

Create `scripts/test_release.py`:

```python
from datetime import date

import pytest

from release import (
    deslug,
    finalize_entry,
    highlights_from_merges,
    highlights_plaintext,
    latest_version_tag,
    render_changelog_entry,
)


def test_latest_version_tag_picks_highest():
    assert latest_version_tag(["v1.0.0", "v1.2.0", "v1.10.0", "v1.9.0"]) == "v1.10.0"


def test_latest_version_tag_handles_two_part_and_none():
    assert latest_version_tag(["v1.0", "v1.1"]) == "v1.1"
    assert latest_version_tag(["random", "notag"]) is None
    assert latest_version_tag([]) is None


def test_deslug():
    assert deslug("instrument-string-presets") == "Instrument string presets"
    assert deslug("fix_daily-history") == "Fix daily history"


def test_highlights_prefer_body_first_line():
    merges = [("Merge branch 'x' into dev", "Add a bass instrument + a picker\n\nmore detail")]
    assert highlights_from_merges(merges) == ["Add a bass instrument + a picker"]


def test_highlights_fall_back_to_deslugged_branch():
    merges = [("Merge branch 'instrument-string-presets' into dev", "")]
    assert highlights_from_merges(merges) == ["Instrument string presets"]


def test_highlights_empty_range():
    assert highlights_from_merges([]) == []


def test_render_changelog_entry():
    entry = render_changelog_entry(
        "1.1.0", date(2026, 7, 5), ["Feature A", "Feature B"], ["feat: a", "fix: b"]
    )
    assert entry.splitlines()[0] == "## v1.1.0 — 2026-07-05"
    assert "### Highlights" in entry
    assert "- Feature A" in entry and "- Feature B" in entry
    assert "<details><summary>All changes</summary>" in entry
    assert "- feat: a" in entry and "- fix: b" in entry
    assert "</details>" in entry


def test_highlights_plaintext_strips_markdown():
    entry = render_changelog_entry("1.1.0", date(2026, 7, 5), ["Feature A", "Feature B"], ["feat: a"])
    assert highlights_plaintext(entry) == "Feature A\nFeature B\n"


def test_finalize_entry_drops_instruction_lines():
    edited = "# instructions\n# more\n## v1.1.0 — 2026-07-05\n### Highlights\n- Feature A\n"
    result = finalize_entry(edited)
    assert result.startswith("## v1.1.0")
    assert "# instructions" not in result


def test_finalize_entry_rejects_empty():
    with pytest.raises(ValueError):
        finalize_entry("# only instructions, no entry\n")
    with pytest.raises(ValueError):
        finalize_entry("## v1.1.0 — 2026-07-05\n### Highlights\n")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: collection/import error — `ModuleNotFoundError: No module named 'release'` (the file does not exist yet).

- [ ] **Step 3: Create `scripts/release.py` with the content functions**

```python
import re
from datetime import date


def latest_version_tag(tags):
    parsed = []
    for tag in tags:
        text = tag.strip()
        match = re.fullmatch(r"v(\d+(?:\.\d+)*)", text)
        if match:
            key = tuple(int(part) for part in match.group(1).split("."))
            parsed.append((key, text))
    if not parsed:
        return None
    parsed.sort()
    return parsed[-1][1]


def deslug(branch):
    words = branch.replace("-", " ").replace("_", " ").split()
    if not words:
        return branch
    return " ".join(words).capitalize()


def _branch_from_subject(subject):
    match = re.search(r"Merge branch '([^']+)'", subject)
    return match.group(1) if match else None


def highlights_from_merges(merges):
    result = []
    for subject, body in merges:
        first_body_line = next((line.strip() for line in body.splitlines() if line.strip()), "")
        if first_body_line:
            result.append(first_body_line)
        else:
            branch = _branch_from_subject(subject)
            result.append(deslug(branch) if branch else subject.strip())
    return result


def render_changelog_entry(version, entry_date, highlights, commit_subjects):
    lines = [f"## v{version} — {entry_date.isoformat()}", "### Highlights"]
    lines.extend(f"- {item}" for item in highlights)
    lines.append("<details><summary>All changes</summary>")
    lines.append("")
    lines.extend(f"- {subject}" for subject in commit_subjects)
    lines.append("</details>")
    return "\n".join(lines) + "\n"


def highlights_plaintext(entry):
    out = []
    in_highlights = False
    for line in entry.splitlines():
        if line.strip() == "### Highlights":
            in_highlights = True
            continue
        if in_highlights:
            if line.startswith("## ") or line.startswith("### ") or line.startswith("<details"):
                break
            if line.strip().startswith("- "):
                out.append(line.strip()[2:])
    return "\n".join(out) + "\n"


def finalize_entry(edited_text):
    lines = edited_text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("## ")), None)
    if start is None:
        raise ValueError("release notes are empty (no '## ' header found)")
    kept = "\n".join(lines[start:]).strip()
    has_highlights = "### Highlights" in kept
    has_bullet = any(line.strip().startswith("- ") for line in kept.splitlines())
    if not (has_highlights and has_bullet):
        raise ValueError("release notes have no highlights")
    return kept + "\n"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: all tests PASS.

- [ ] **Step 5: Lint, format, commit**

```bash
python3 -m ruff check scripts/release.py scripts/test_release.py
python3 -m ruff format scripts/release.py scripts/test_release.py
git add scripts/release.py scripts/test_release.py
git commit -m "feat: changelog content generation for release.py"
```

---

## Task 2: pbxproj version bump (pure functions)

Adds the version-bump functions to `scripts/release.py`.

**Files:**
- Modify: `scripts/release.py`
- Modify: `scripts/test_release.py`

**Interfaces:**
- Consumes: `re` (already imported in Task 1).
- Produces:
  - `MARKETING_RE`, `BUILD_RE` — module-level compiled patterns.
  - `current_build_number(pbxproj: str) -> int` — the single uniform build number; raises if missing/non-uniform/non-integer.
  - `bump_pbxproj(pbxproj: str, marketing: str, build: int) -> str` — every `MARKETING_VERSION` → `marketing`, every `CURRENT_PROJECT_VERSION` → `build`; asserts uniform before and after; raises otherwise.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/test_release.py` (add `bump_pbxproj, current_build_number` to the existing `from release import (...)` block):

```python
PBX_SAMPLE = """
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tMARKETING_VERSION = 1.0;
"""


def test_current_build_number():
    assert current_build_number(PBX_SAMPLE) == 1


def test_current_build_number_rejects_non_uniform():
    bad = PBX_SAMPLE.replace("CURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;", "CURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 2;")
    with pytest.raises(ValueError):
        current_build_number(bad)


def test_bump_pbxproj_updates_all_occurrences():
    result = bump_pbxproj(PBX_SAMPLE, "1.1.0", 2)
    assert result.count("MARKETING_VERSION = 1.1.0;") == 2
    assert result.count("CURRENT_PROJECT_VERSION = 2;") == 2
    assert "MARKETING_VERSION = 1.0;" not in result
    assert "CURRENT_PROJECT_VERSION = 1;" not in result


def test_bump_pbxproj_rejects_non_uniform_marketing():
    bad = PBX_SAMPLE.replace("MARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;", "MARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 2.0;")
    with pytest.raises(ValueError):
        bump_pbxproj(bad, "1.1.0", 2)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: ImportError on `bump_pbxproj` / `current_build_number` (not defined yet).

- [ ] **Step 3: Add the bump functions to `scripts/release.py`**

Add after the `import` line group (keep `import re`) and among the functions:

```python
MARKETING_RE = re.compile(r"(MARKETING_VERSION = )([^;]+)(;)")
BUILD_RE = re.compile(r"(CURRENT_PROJECT_VERSION = )([^;]+)(;)")


def current_build_number(pbxproj):
    values = [match.group(2).strip() for match in BUILD_RE.finditer(pbxproj)]
    if not values:
        raise ValueError("no CURRENT_PROJECT_VERSION found")
    unique = set(values)
    if len(unique) != 1:
        raise ValueError(f"CURRENT_PROJECT_VERSION not uniform: {sorted(unique)}")
    if not values[0].isdigit():
        raise ValueError(f"CURRENT_PROJECT_VERSION is not an integer: {values[0]}")
    return int(values[0])


def bump_pbxproj(pbxproj, marketing, build):
    marketing_values = {match.group(2).strip() for match in MARKETING_RE.finditer(pbxproj)}
    if not marketing_values:
        raise ValueError("no MARKETING_VERSION found")
    if len(marketing_values) != 1:
        raise ValueError(f"MARKETING_VERSION not uniform: {sorted(marketing_values)}")
    current_build_number(pbxproj)
    result = MARKETING_RE.sub(lambda m: f"{m.group(1)}{marketing}{m.group(3)}", pbxproj)
    result = BUILD_RE.sub(lambda m: f"{m.group(1)}{build}{m.group(3)}", result)
    after_marketing = {match.group(2).strip() for match in MARKETING_RE.finditer(result)}
    after_build = {match.group(2).strip() for match in BUILD_RE.finditer(result)}
    if after_marketing != {marketing}:
        raise ValueError("MARKETING_VERSION not uniform after bump")
    if after_build != {str(build)}:
        raise ValueError("CURRENT_PROJECT_VERSION not uniform after bump")
    return result
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: all tests PASS (Task 1 + Task 2).

- [ ] **Step 5: Lint, format, commit**

```bash
python3 -m ruff check scripts/release.py scripts/test_release.py
python3 -m ruff format scripts/release.py scripts/test_release.py
git add scripts/release.py scripts/test_release.py
git commit -m "feat: pbxproj version + build bump for release.py"
```

---

## Task 3: iOS simulator selection (pure function)

Adds the simulator picker (parses `xcrun simctl list ... -j`).

**Files:**
- Modify: `scripts/release.py`
- Modify: `scripts/test_release.py`

**Interfaces:**
- Produces: `pick_ios_simulator(simctl_json: str) -> str` — newest available iPhone by trailing number; raises `ValueError` if none available.

- [ ] **Step 1: Write the failing test**

Append to `scripts/test_release.py` (add `pick_ios_simulator` to the `from release import (...)` block):

```python
SIMCTL_JSON = """
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
      {"name": "iPhone 16", "isAvailable": true},
      {"name": "iPhone 17", "isAvailable": true},
      {"name": "iPhone 15 (unavailable)", "isAvailable": false},
      {"name": "iPad Pro", "isAvailable": true}
    ]
  }
}
"""


def test_pick_ios_simulator_prefers_newest_iphone():
    assert pick_ios_simulator(SIMCTL_JSON) == "iPhone 17"


def test_pick_ios_simulator_raises_when_none():
    empty = '{"devices": {"rt": [{"name": "iPad Pro", "isAvailable": true}]}}'
    with pytest.raises(ValueError):
        pick_ios_simulator(empty)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: ImportError on `pick_ios_simulator`.

- [ ] **Step 3: Add the picker and its import**

Add `import json` to the top of `scripts/release.py` (alphabetically before `import re`), and add:

```python
def pick_ios_simulator(simctl_json):
    data = json.loads(simctl_json)
    iphones = []
    for devices in data.get("devices", {}).values():
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
                iphones.append(device["name"])
    if not iphones:
        raise ValueError("no available iPhone simulator found")

    def sort_key(name):
        numbers = re.findall(r"\d+", name)
        return (int(numbers[0]) if numbers else -1, name)

    iphones.sort(key=sort_key)
    return iphones[-1]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: all tests PASS.

- [ ] **Step 5: Lint, format, commit**

```bash
python3 -m ruff check scripts/release.py scripts/test_release.py
python3 -m ruff format scripts/release.py scripts/test_release.py
git add scripts/release.py scripts/test_release.py
git commit -m "feat: iOS simulator selection for release.py --verify"
```

---

## Task 4: Orchestration + CLI (`run_release`, `main`)

Wires the pure functions into the end-to-end release, with guards, `$EDITOR` curation, the `dev → main` merge, version bump, changelog/notes writes, tag, rollback, and the `--dry-run`/`--verify`/`--push`/`--ios-sim` flags. Integration-tested against a temporary git repo (the `--verify` xcodebuild path is not exercised in tests — it is a thin `subprocess` wrapper; tests use `verify=False`).

**Files:**
- Modify: `scripts/release.py`
- Modify: `scripts/test_release.py`

**Interfaces:**
- Consumes: all functions from Tasks 1–3.
- Produces:
  - `run_release(root, version, *, dry_run=False, verify=False, push=False, ios_sim=None, edit=None) -> None`.
  - `main(argv=None) -> None` — argparse CLI calling `run_release(REPO_ROOT, ...)` with the real `$EDITOR` editor.
  - Module constants `REPO_ROOT`, `_EDIT_HEADER`.

- [ ] **Step 1: Write the failing integration tests**

Append to `scripts/test_release.py` (add `run_release` to the `from release import (...)` block; add `import subprocess` and `from pathlib import Path` at the top of the test file):

```python
def _git(root, *args):
    subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True)


def _init_repo(root):
    pbx = root / "audio_listen.xcodeproj"
    pbx.mkdir(parents=True)
    (pbx / "project.pbxproj").write_text(PBX_SAMPLE + PBX_SAMPLE + PBX_SAMPLE)
    _git(root, "init", "-b", "main")
    _git(root, "config", "user.email", "t@t.t")
    _git(root, "config", "user.name", "t")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "initial")
    _git(root, "checkout", "-b", "dev")
    (root / "feature.txt").write_text("x")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "feat: a feature")
    _git(root, "checkout", "-b", "feat-work")
    (root / "feature2.txt").write_text("y")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "feat: more work")
    _git(root, "checkout", "dev")
    _git(root, "merge", "--no-ff", "feat-work", "-m", "Merge branch 'feat-work' into dev\n\nAdd the cool feature")


def _canned_edit(draft):
    return "## v1.1.0 — 2026-07-05\n### Highlights\n- Add the cool feature\n"


def test_run_release_end_to_end(tmp_path):
    _init_repo(tmp_path)
    run_release(tmp_path, "1.1.0", edit=_canned_edit)

    tags = subprocess.run(["git", "tag"], cwd=tmp_path, capture_output=True, text=True).stdout.split()
    assert "v1.1.0" in tags
    branch = subprocess.run(["git", "branch", "--show-current"], cwd=tmp_path, capture_output=True, text=True).stdout.strip()
    assert branch == "main"
    pbx = (tmp_path / "audio_listen.xcodeproj" / "project.pbxproj").read_text()
    assert "MARKETING_VERSION = 1.1.0;" in pbx and "MARKETING_VERSION = 1.0;" not in pbx
    assert "CURRENT_PROJECT_VERSION = 2;" in pbx and "CURRENT_PROJECT_VERSION = 1;" not in pbx
    changelog = (tmp_path / "CHANGELOG.md").read_text()
    assert "## v1.1.0" in changelog and "- Add the cool feature" in changelog
    notes = (tmp_path / "fastlane" / "metadata" / "en-US" / "release_notes.txt").read_text()
    assert notes == "Add the cool feature\n"


def test_run_release_dry_run_mutates_nothing(tmp_path, capsys):
    _init_repo(tmp_path)
    run_release(tmp_path, "1.1.0", dry_run=True, edit=_canned_edit)
    assert not (tmp_path / "CHANGELOG.md").exists()
    tags = subprocess.run(["git", "tag"], cwd=tmp_path, capture_output=True, text=True).stdout.split()
    assert tags == []
    assert "1.1.0" in capsys.readouterr().out


def test_run_release_rejects_existing_tag(tmp_path):
    _init_repo(tmp_path)
    _git(tmp_path, "tag", "v1.1.0")
    with pytest.raises(SystemExit):
        run_release(tmp_path, "1.1.0", edit=_canned_edit)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: ImportError on `run_release`.

- [ ] **Step 3: Add the orchestration + CLI to `scripts/release.py`**

Add these imports to the top import block (keep them sorted; final block is `import argparse`, `import json`, `import os`, `import re`, `import subprocess`, `import tempfile`, `from datetime import date`, `from pathlib import Path`), then add:

```python
REPO_ROOT = Path(__file__).resolve().parent.parent

_EDIT_HEADER = (
    "# Edit the release notes below, then save to finalize (an empty file aborts).\n"
    "# Lines above the first '## ' are instructions and are dropped.\n"
)


def _editor_edit(draft):
    editor = os.environ.get("EDITOR", "vi")
    handle = tempfile.NamedTemporaryFile("w+", suffix=".md", delete=False)
    try:
        handle.write(draft)
        handle.close()
        subprocess.run([editor, handle.name])
        return Path(handle.name).read_text()
    finally:
        os.unlink(handle.name)


def _verify_both_platforms(root, ios_sim):
    env = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
    base = ["xcodebuild", "test", "-project", "audio_listen.xcodeproj", "-scheme", "audio_listen", "-only-testing:audio_listenTests"]
    mac = subprocess.run(base + ["-destination", "platform=macOS"], cwd=root, env=env)
    if mac.returncode != 0:
        raise SystemExit("macOS tests failed")
    if ios_sim is None:
        listing = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"], capture_output=True, text=True)
        ios_sim = pick_ios_simulator(listing.stdout)
    ios = subprocess.run(base + ["-destination", f"platform=iOS Simulator,name={ios_sim}"], cwd=root, env=env)
    if ios.returncode != 0:
        raise SystemExit(f"iOS tests failed (simulator: {ios_sim})")


def _prepend_changelog(path, entry):
    title = "# Changelog\n\n"
    if path.exists():
        existing = path.read_text()
        if existing.startswith("# Changelog"):
            body = existing[len("# Changelog") :].lstrip("\n")
            path.write_text(title + entry + "\n" + body)
        else:
            path.write_text(title + entry + "\n" + existing)
    else:
        path.write_text(title + entry)


def run_release(root, version, *, dry_run=False, verify=False, push=False, ios_sim=None, edit=None):
    root = Path(root)
    edit = edit or _editor_edit
    pbxproj_path = root / "audio_listen.xcodeproj" / "project.pbxproj"
    changelog_path = root / "CHANGELOG.md"
    notes_path = root / "fastlane" / "metadata" / "en-US" / "release_notes.txt"
    tag = f"v{version}"

    def git(*args, check=True):
        result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
        if check and result.returncode != 0:
            raise RuntimeError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
        return result.stdout.strip()

    if git("status", "--porcelain"):
        raise SystemExit("working tree is not clean; commit or stash first")
    branches = set(git("branch", "--format=%(refname:short)").split())
    for name in ("dev", "main"):
        if name not in branches:
            raise SystemExit(f"branch '{name}' does not exist")
    existing_tags = git("tag", "--list").split()
    if tag in existing_tags:
        raise SystemExit(f"tag {tag} already exists")

    if verify:
        _verify_both_platforms(root, ios_sim)

    last = latest_version_tag(existing_tags)
    rng = f"{last}..dev" if last else "dev"
    separator = "\x1f"
    record_sep = "\x1e"
    raw_merges = git("log", "--merges", f"--format=%s{separator}%b{record_sep}", rng)
    merges = []
    for record in raw_merges.split(record_sep):
        record = record.strip("\n")
        if not record.strip():
            continue
        subject, _, body = record.partition(separator)
        merges.append((subject.strip(), body))
    highlights = highlights_from_merges(merges)
    commit_subjects = [line for line in git("log", "--no-merges", "--format=%s", rng).splitlines() if line.strip()]
    entry = render_changelog_entry(version, date.today(), highlights, commit_subjects)

    if dry_run:
        pbxproj = pbxproj_path.read_text()
        current_marketing = sorted({m.group(2).strip() for m in MARKETING_RE.finditer(pbxproj)})
        current_build = current_build_number(pbxproj)
        print(f"last tag: {last or '(none)'}")
        print(f"range: {rng}\n")
        print(entry)
        print(f"MARKETING_VERSION {current_marketing} -> {version}")
        print(f"CURRENT_PROJECT_VERSION {current_build} -> {current_build + 1}")
        print(f"tag: {tag}")
        return

    entry = finalize_entry(edit(_EDIT_HEADER + entry))

    main_sha = git("rev-parse", "main")
    git("checkout", "main")
    merge = subprocess.run(["git", "merge", "--no-ff", "dev", "-m", f"Merge branch 'dev' for release {tag}"], cwd=root, capture_output=True, text=True)
    if merge.returncode != 0:
        subprocess.run(["git", "merge", "--abort"], cwd=root)
        raise SystemExit(f"merge conflict; aborted:\n{merge.stderr.strip()}")

    try:
        build = current_build_number(pbxproj_path.read_text()) + 1
        pbxproj_path.write_text(bump_pbxproj(pbxproj_path.read_text(), version, build))
        _prepend_changelog(changelog_path, entry)
        notes_path.parent.mkdir(parents=True, exist_ok=True)
        notes_path.write_text(highlights_plaintext(entry))
        git("add", "-A")
        git("commit", "-m", f"chore(release): {tag}")
        git("tag", "-a", tag, "-m", "\n".join(highlights))
    except Exception:
        git("reset", "--hard", main_sha, check=False)
        git("tag", "-d", tag, check=False)
        raise

    push_cmd = "git push origin main --tags"
    if push:
        git("push", "origin", "main", "--tags")
        print(f"pushed ({push_cmd})")
    else:
        print(f"Release {tag} committed and tagged locally. To publish:\n  {push_cmd}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Cut a release: merge dev into main, changelog, version bump, tag.")
    parser.add_argument("version")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--push", action="store_true")
    parser.add_argument("--ios-sim", default=None)
    args = parser.parse_args(argv)
    run_release(REPO_ROOT, args.version, dry_run=args.dry_run, verify=args.verify, push=args.push, ios_sim=args.ios_sim)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m pytest scripts/test_release.py -v`
Expected: all tests PASS (all four tasks' tests green).

- [ ] **Step 5: Manually smoke-test `--dry-run` against the real repo (no mutation)**

Run: `python3 scripts/release.py 1.1.0 --dry-run`
Expected: prints `last tag: (none)`, the `dev` range, a drafted `## v1.1.0` entry whose Highlights come from the recent merge commits (bass/string-presets/CQS), `MARKETING_VERSION ['1.0'] -> 1.1.0`, `CURRENT_PROJECT_VERSION 1 -> 2`, `tag: v1.1.0` — and changes nothing (`git status` clean afterward, no tag created).

- [ ] **Step 6: Lint, format, commit**

```bash
python3 -m ruff check scripts/release.py scripts/test_release.py
python3 -m ruff format scripts/release.py scripts/test_release.py
git add scripts/release.py scripts/test_release.py
git commit -m "feat: release.py orchestration + CLI (dev->main, changelog, version, tag)"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-05-release-automation-design.md`):

- One explicit command, run from repo root → Task 4 `main()` / CLI. ✓
- Manual version arg, format-agnostic → `run_release(version)` uses the string verbatim; `latest_version_tag` handles 2- and 3-part. ✓
- Draft-then-curate in `$EDITOR`, empty aborts → `_EDIT_HEADER` + `_editor_edit` + `finalize_entry` (raises on empty). ✓ (Tasks 1, 4)
- Guards: clean tree, `dev`+`main` exist, tag absent → Task 4 guards. ✓
- `--verify` two-platform gate (macOS test + iOS Simulator test), device via `simctl`/`--ios-sim` → `_verify_both_platforms` + `pick_ios_simulator`. ✓ (Tasks 3, 4)
- Collect features from merges since last `v*` tag (or all of `dev`) → Task 4 range + `highlights_from_merges`. ✓
- Merge `dev → main` `--no-ff`, abort on conflict → Task 4. ✓
- Bump `MARKETING_VERSION` (arg) + `CURRENT_PROJECT_VERSION` (+1), all occurrences, uniform-asserted → `bump_pbxproj` (Task 2). ✓
- Prepend `CHANGELOG.md`; Keep-a-Changelog format with `<details>` → `render_changelog_entry` + `_prepend_changelog`. ✓
- Plaintext Highlights → `fastlane/metadata/en-US/release_notes.txt` → `highlights_plaintext` + write (Task 4). ✓
- Commit + annotated tag `v<version>` with Highlights message → Task 4. ✓
- No auto-push; print command; `--push` opts in → Task 4. ✓
- `--dry-run` previews, no mutation → Task 4 + `test_run_release_dry_run_mutates_nothing`. ✓
- Rollback on post-merge failure → Task 4 `try/except` reset + tag delete. ✓
- Pure functions unit-tested; orchestration tested against temp repo → Tasks 1–4 tests. ✓
- Out of scope (real App Store upload, SemVer inference) — not planned. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". Every step has complete code and exact commands. ✓

**3. Type consistency:** `latest_version_tag`, `deslug`, `highlights_from_merges` ((subject, body) tuples), `render_changelog_entry(version, entry_date, highlights, commit_subjects)`, `highlights_plaintext`, `finalize_entry`, `current_build_number`, `bump_pbxproj(pbxproj, marketing, build)`, `pick_ios_simulator`, `run_release(root, version, *, dry_run, verify, push, ios_sim, edit)`, and the module constants `MARKETING_RE`/`BUILD_RE`/`REPO_ROOT`/`_EDIT_HEADER` are named identically everywhere they're referenced across Tasks 1→4 and the tests. The test `PBX_SAMPLE` (2 occurrences each) is tripled in `_init_repo` (6 occurrences), matching the real pbxproj count so the uniform-assertion path is exercised. ✓
