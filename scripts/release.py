import argparse
import json
import os
import re
import shlex
import subprocess
import tempfile
from datetime import date
from pathlib import Path

MARKETING_RE = re.compile(r"(MARKETING_VERSION = )([^;]+)(;)")
BUILD_RE = re.compile(r"(CURRENT_PROJECT_VERSION = )([^;]+)(;)")
TEAM_RE = re.compile(r"DEVELOPMENT_TEAM = ([^;\s]+);")


def version_key(version):
    return tuple(int(part) for part in re.findall(r"\d+", version))


def version_sorts_above(candidate, current):
    return version_key(candidate) > version_key(current)


def development_team(pbxproj):
    teams = {match.group(1) for match in TEAM_RE.finditer(pbxproj)}
    if not teams:
        raise ValueError("no DEVELOPMENT_TEAM found")
    if len(teams) != 1:
        raise ValueError(f"DEVELOPMENT_TEAM not uniform: {sorted(teams)}")
    return teams.pop()


def export_options_plist(team):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>method</key>
\t<string>app-store-connect</string>
\t<key>teamID</key>
\t<string>{team}</string>
\t<key>uploadSymbols</key>
\t<true/>
\t<key>destination</key>
\t<string>export</string>
</dict>
</plist>
"""


def pick_ios_simulator(simctl_json):
    data = json.loads(simctl_json)
    iphones = []
    for devices in data.get("devices", {}).values():
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith(
                "iPhone"
            ):
                iphones.append(device["name"])
    if not iphones:
        raise ValueError("no available iPhone simulator found")

    def sort_key(name):
        numbers = re.findall(r"\d+", name)
        return (int(numbers[0]) if numbers else -1, name)

    iphones.sort(key=sort_key)
    return iphones[-1]


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
    marketing_values = {
        match.group(2).strip() for match in MARKETING_RE.finditer(pbxproj)
    }
    if not marketing_values:
        raise ValueError("no MARKETING_VERSION found")
    if len(marketing_values) != 1:
        raise ValueError(f"MARKETING_VERSION not uniform: {sorted(marketing_values)}")
    current_build_number(pbxproj)
    result = MARKETING_RE.sub(lambda m: f"{m.group(1)}{marketing}{m.group(3)}", pbxproj)
    result = BUILD_RE.sub(lambda m: f"{m.group(1)}{build}{m.group(3)}", result)
    after_marketing = {
        match.group(2).strip() for match in MARKETING_RE.finditer(result)
    }
    after_build = {match.group(2).strip() for match in BUILD_RE.finditer(result)}
    if after_marketing != {marketing}:
        raise ValueError("MARKETING_VERSION not uniform after bump")
    if after_build != {str(build)}:
        raise ValueError("CURRENT_PROJECT_VERSION not uniform after bump")
    return result


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
        first_body_line = next(
            (line.strip() for line in body.splitlines() if line.strip()), ""
        )
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
            if (
                line.startswith("## ")
                or line.startswith("### ")
                or line.startswith("<details")
            ):
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
        subprocess.run([*shlex.split(editor), handle.name])
        return Path(handle.name).read_text()
    finally:
        os.unlink(handle.name)


def _verify_both_platforms(root, ios_sim):
    env = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
    base = [
        "xcodebuild",
        "test",
        "-project",
        "audio_listen.xcodeproj",
        "-scheme",
        "audio_listen",
        "-only-testing:audio_listenTests",
    ]
    mac = subprocess.run(base + ["-destination", "platform=macOS"], cwd=root, env=env)
    if mac.returncode != 0:
        raise SystemExit("macOS tests failed")
    if ios_sim is None:
        listing = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            capture_output=True,
            text=True,
            env=env,
        )
        if listing.returncode != 0:
            raise SystemExit("could not list iOS simulators")
        ios_sim = pick_ios_simulator(listing.stdout)
    ios = subprocess.run(
        base + ["-destination", f"platform=iOS Simulator,name={ios_sim}"],
        cwd=root,
        env=env,
    )
    if ios.returncode != 0:
        raise SystemExit(f"iOS tests failed (simulator: {ios_sim})")


def _archive_for_app_store(root, version):
    env = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
    pbxproj = (root / "audio_listen.xcodeproj" / "project.pbxproj").read_text()
    team = development_team(pbxproj)
    out = root / "build" / f"v{version}"
    out.mkdir(parents=True, exist_ok=True)
    archive = out / "audio_listen.xcarchive"
    options = out / "ExportOptions.plist"
    options.write_text(export_options_plist(team))

    archived = subprocess.run(
        [
            "xcodebuild",
            "archive",
            "-project",
            "audio_listen.xcodeproj",
            "-scheme",
            "audio_listen",
            "-configuration",
            "Release",
            "-destination",
            "generic/platform=iOS",
            "-archivePath",
            str(archive),
        ],
        cwd=root,
        env=env,
    )
    if archived.returncode != 0:
        raise SystemExit("archive failed")

    exported = subprocess.run(
        [
            "xcodebuild",
            "-exportArchive",
            "-archivePath",
            str(archive),
            "-exportPath",
            str(out),
            "-exportOptionsPlist",
            str(options),
        ],
        cwd=root,
        env=env,
    )
    if exported.returncode != 0:
        raise SystemExit("export failed")
    print(f"archived and exported to {out}")
    print("Upload with Xcode Organizer or Transporter.")


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


def run_release(
    root,
    version,
    *,
    dry_run=False,
    verify=False,
    push=False,
    archive=False,
    ios_sim=None,
    edit=None,
):
    root = Path(root)
    edit = edit or _editor_edit
    pbxproj_path = root / "audio_listen.xcodeproj" / "project.pbxproj"
    changelog_path = root / "CHANGELOG.md"
    notes_path = root / "fastlane" / "metadata" / "en-US" / "release_notes.txt"
    tag = f"v{version}"

    def git(*args, check=True):
        result = subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True
        )
        if check and result.returncode != 0:
            raise RuntimeError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
        return result.stdout.strip()

    if not dry_run and git("status", "--porcelain"):
        raise SystemExit("working tree is not clean; commit or stash first")
    branches = set(git("branch", "--format=%(refname:short)").split())
    for name in ("dev", "main"):
        if name not in branches:
            raise SystemExit(f"branch '{name}' does not exist")
    existing_tags = git("tag", "--list").split()
    if tag in existing_tags:
        raise SystemExit(f"tag {tag} already exists")

    current_marketing_versions = sorted(
        {m.group(2).strip() for m in MARKETING_RE.finditer(pbxproj_path.read_text())}
    )
    if len(current_marketing_versions) != 1:
        raise SystemExit(f"MARKETING_VERSION not uniform: {current_marketing_versions}")
    if not version_sorts_above(version, current_marketing_versions[0]):
        raise SystemExit(
            f"version {version} does not sort above the current "
            f"MARKETING_VERSION {current_marketing_versions[0]}"
        )

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
    commit_subjects = [
        line
        for line in git("log", "--no-merges", "--format=%s", rng).splitlines()
        if line.strip()
    ]
    entry = render_changelog_entry(version, date.today(), highlights, commit_subjects)

    if dry_run:
        pbxproj = pbxproj_path.read_text()
        current_marketing = sorted(
            {m.group(2).strip() for m in MARKETING_RE.finditer(pbxproj)}
        )
        current_build = current_build_number(pbxproj)
        print(f"last tag: {last or '(none)'}")
        print(f"range: {rng}\n")
        print(entry)
        print(f"MARKETING_VERSION {current_marketing} -> {version}")
        print(f"CURRENT_PROJECT_VERSION {current_build} -> {current_build + 1}")
        print(f"tag: {tag}")
        return

    try:
        entry = finalize_entry(edit(_EDIT_HEADER + entry))
    except ValueError as exc:
        raise SystemExit(str(exc))

    main_sha = git("rev-parse", "main")
    git("checkout", "main")
    merge = subprocess.run(
        [
            "git",
            "merge",
            "--no-ff",
            "dev",
            "-m",
            f"Merge branch 'dev' for release {tag}",
        ],
        cwd=root,
        capture_output=True,
        text=True,
    )
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
        git("tag", "-a", tag, "-m", highlights_plaintext(entry).strip())
    except Exception:
        git("reset", "--hard", main_sha, check=False)
        git("tag", "-d", tag, check=False)
        git("clean", "-fd", "--", "CHANGELOG.md", "fastlane", check=False)
        raise

    if archive:
        _archive_for_app_store(root, version)

    push_cmd = "git push origin main --tags"
    if push:
        git("push", "origin", "main", "--tags")
        print(f"pushed ({push_cmd})")
    else:
        print(f"Release {tag} committed and tagged locally. To publish:\n  {push_cmd}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Cut a release: merge dev into main, changelog, version bump, tag."
    )
    parser.add_argument("version")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--push", action="store_true")
    parser.add_argument("--archive", action="store_true")
    parser.add_argument("--ios-sim", default=None)
    args = parser.parse_args(argv)
    run_release(
        REPO_ROOT,
        args.version,
        dry_run=args.dry_run,
        verify=args.verify,
        push=args.push,
        archive=args.archive,
        ios_sim=args.ios_sim,
    )


if __name__ == "__main__":
    main()
