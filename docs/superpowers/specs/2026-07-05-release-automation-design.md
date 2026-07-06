# Release Automation (`release.py`) — Design

**Date:** 2026-07-05
**Status:** Approved for planning
**Branch context:** `dev`

## Goal

A single, tested command that turns "merge `dev` into `main`" into a real, versioned
release: it merges, generates a **version header with the main features added**, bumps the
app version, records a `CHANGELOG.md` entry, tags the release, and writes the "What's New"
text where the App Store upload tool will later find it. Run deliberately at release time —
never as an automatic hook.

## Guiding decisions (locked)

- **One command wraps the whole release**, run explicitly: `uv run python scripts/release.py <version>`.
  Not a git hook (a merge is not always a release; auto-triggering misfires).
- **Manual version.** You type the full version string (`1.1.0`); the tool never infers
  MAJOR/MINOR/PATCH. The tool is format-agnostic — it uses the string verbatim.
- **Draft-then-curate.** The tool assembles a draft entry and opens `$EDITOR`; you edit the
  Highlights, save to finalize. An empty save aborts.
- **No auto-push.** Releasing is outward-facing; the tool prints the exact `git push` command
  (or `--push` opts in). Store upload is entirely out of scope.
- **Lives in `scripts/`** as Python with `pytest` tests, matching the repo's existing
  `scripts/*.py` + `test_*.py` convention and the global stack (uv / pytest / ruff). This is a
  standalone utility — it does NOT follow the `src/<stage>/run()` pipeline layout.

## The release flow

`release.py 1.1.0` executes, in order, aborting cleanly (undoing partial work) on any failure:

1. **Guard.** Working tree clean (`git status --porcelain` empty); branches `dev` and `main`
   both exist; tag `v1.1.0` does not already exist. With `--verify`, run the two-platform gate
   first (see below) and abort if either command fails.
2. **Collect features.** Merge commits on `dev` since the last `v*` tag (or all merges on `dev`
   if no tag exists yet).
3. **Draft + curate.** Assemble the draft entry (Highlights + collapsed full commit list),
   open it in `$EDITOR`. You edit, save. Empty content (no Highlights) → abort.
4. **Merge.** Capture `main`'s current SHA, then `git checkout main && git merge --no-ff dev`.
   On conflict: `git merge --abort`, restore, and exit non-zero.
5. **Bump version** in `audio_listen.xcodeproj/project.pbxproj` (see below).
6. **Write** the finalized entry to the top of `CHANGELOG.md` (created if absent) and the
   Highlights plaintext to `fastlane/metadata/en-US/release_notes.txt` (dirs created if absent).
7. **Commit** the merge's version bump + changelog + notes on `main`; **tag** an annotated
   `v1.1.0` whose message is the Highlights.
8. **Print** `git push origin main --tags` for you to run. `--push` runs it instead.

`--dry-run` performs steps 1–2 and the draft assembly, prints the drafted Highlights + full
list, the `MARKETING_VERSION` and build-number changes, and the tag name, then exits — no
editor, no merge, no writes.

**Rollback:** if any step after the merge (5–7) fails, reset `main` to the captured pre-merge
SHA (`git reset --hard <sha>`) and delete the tag if it was created, so a failed release leaves
no partial state.

**`--verify` runs the test suite on BOTH platforms.** The app ships on iOS and macOS, so the
gate runs the full `audio_listenTests` suite against a macOS destination AND an iOS Simulator
destination (both must pass). Running on iOS as well as macOS covers platform-conditional
(`#if os(iOS)` / `#if os(macOS)`) compilation and any platform-specific test behavior — not just
the shared logic:

```bash
# macOS — fast, no simulator boot
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination 'platform=macOS' -only-testing:audio_listenTests

# iOS Simulator — boots a simulator (device chosen per note below)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project audio_listen.xcodeproj -scheme audio_listen \
  -destination "platform=iOS Simulator,name=$IOS_SIM" -only-testing:audio_listenTests
```

**iOS simulator selection:** the tool picks a concrete available iPhone simulator by querying
`xcrun simctl list devices available` (newest iPhone by default), overridable with
`--ios-sim NAME`. Booting a simulator makes `--verify` slower than a macOS-only run — acceptable
for a deliberate, occasional release gate. `--verify` is opt-in; without it the release proceeds
on the assumption that `dev` was already tested per-feature.

## Feature extraction + changelog format

- **Range:** `<last v* tag>..dev`, or all of `dev` if no tag exists.
- **Highlights source:** each merge commit in the range. Prefer the first non-empty line of the
  merge commit **body** (e.g. `ca3d912`'s body → "Add a bass instrument + a Settings picker…").
  If a merge has no body, **de-slug** the branch name from its subject
  (`Merge branch 'instrument-picker-per-instrument-progress' into dev` →
  "Instrument picker per instrument progress").
- **Full list:** non-merge commit subjects in the range (`git log --no-merges --format='- %s'`),
  placed in a collapsed `<details>` block.
- **Format** (*Keep a Changelog* style, newest entry prepended below the file's title header):

```markdown
## v1.1.0 — 2026-07-05
### Highlights
- Instrument picker + per-instrument progress
- Per-instrument string presets
<details><summary>All changes</summary>

- feat: add bass to the instrument catalog
- fix: thread instrument into MasteryView's fretboard and prompt universe
</details>
```

- The **editor draft** carries instruction lines above the entry; the finalizer keeps everything
  from the first line beginning with `## ` onward (so instructions can't leak into the changelog).

## Version bump (`project.pbxproj`)

- **`MARKETING_VERSION`** → the version arg (`1.1.0`), replacing **every** occurrence
  (it appears once per build-config × target — macOS Debug/Release + iOS Debug/Release).
- **`CURRENT_PROJECT_VERSION`** (build number) → **auto-increment by 1** each release, all
  occurrences kept in sync.
- **Sync assertion:** the tool asserts all `MARKETING_VERSION` occurrences are identical before
  and after, and likewise all `CURRENT_PROJECT_VERSION` occurrences, so the two targets never
  drift. If they are not uniform to begin with, abort with a clear message.

## App Store "What's New"

The finalized Highlights (bullets, stripped of markdown) are written as plaintext to
`fastlane/metadata/en-US/release_notes.txt` — the exact path `fastlane deliver` reads. This
pre-wires automated store upload with zero rework: whenever fastlane is set up (a separate,
credentialed task requiring an Apple Developer account + App Store Connect API key), it pushes
this file to the version's "What's New" field. **Building the actual upload is out of scope.**

iOS and macOS ship as **one App Store listing** (a single app record, shared version), so a
single `fastlane/metadata/en-US/release_notes.txt` is the correct and only destination — the
version bump and these notes cover both platforms at once.

## Files touched

| File | Change |
|---|---|
| `scripts/release.py` | **new** — the release command (pure functions + git orchestration) |
| `scripts/test_release.py` | **new** — pytest suite |
| `CHANGELOG.md` | **created on first run** (not in this repo yet) |
| `fastlane/metadata/en-US/release_notes.txt` | **written each release** |
| `audio_listen.xcodeproj/project.pbxproj` | **rewritten each release** (version lines only) |

No Swift code changes. The tool only reads git history and rewrites the version lines,
changelog, and notes.

## Structure (isolation)

`release.py` separates **pure functions** (unit-tested in isolation) from a thin
**git-orchestration** layer:

- `latest_version_tag(tags: list[str]) -> str | None`
- `deslug(branch: str) -> str`
- `highlights_from_merges(merge_entries: list[str]) -> list[str]`
- `render_changelog_entry(version, date, highlights, commit_subjects) -> str`
- `highlights_plaintext(entry: str) -> str`
- `current_build_number(pbxproj: str) -> int` (asserts uniform)
- `bump_pbxproj(pbxproj: str, marketing: str, build: int) -> str` (asserts uniform in/out)
- `finalize_entry(edited_text: str) -> str` (keep from first `## ` line)
- `pick_ios_simulator(simctl_json: str) -> str` (newest available iPhone name; raises if none)

The orchestration (`main()`) calls `git`/`$EDITOR` via `subprocess`, wires the pure functions,
and enforces the guards/rollback. Dates come from `datetime.date.today()`.

## Testing

`pytest` over the pure functions:
- `latest_version_tag`: picks highest `v*` by version sort; `None` when no tags.
- `deslug`: `"instrument-string-presets"` → `"Instrument string presets"`.
- `highlights_from_merges`: body-first-line preferred; de-slug fallback when body empty;
  empty range → `[]`.
- `render_changelog_entry`: exact header, Highlights bullets, `<details>` full list.
- `highlights_plaintext`: bullets only, markdown/`<details>` stripped.
- `current_build_number` / `bump_pbxproj`: all occurrences updated, uniform-in/uniform-out
  assertions, raises on non-uniform input.
- `finalize_entry`: instruction lines above the first `## ` are dropped; empty → raises.
- `pick_ios_simulator`: picks the newest available iPhone from `simctl list -j` output; raises a
  clear error when no iPhone simulator is available.

Git orchestration is exercised against a **temporary throwaway git repo fixture** (init, make
commits + feature merges + a `v*` tag, run the flow, assert the new `CHANGELOG.md` entry, the
annotated tag, the pbxproj version/build changes, and the `release_notes.txt` contents). No
network, no real App Store calls.

## Out of scope

- The actual App Store Connect upload / `fastlane deliver` / API integration (separate task;
  needs Apple credentials, is outward-facing).
- SemVer inference from commit types (deliberately manual).
- Auto-pushing by default (opt-in via `--push`).
- Per-locale release notes beyond `en-US` (add more locale files later if needed).
- Signing, archiving, or building the `.ipa` — this tool only handles versioning + notes.
