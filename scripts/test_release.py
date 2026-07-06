import subprocess
from datetime import date

import pytest

from release import (
    bump_pbxproj,
    current_build_number,
    deslug,
    finalize_entry,
    highlights_from_merges,
    highlights_plaintext,
    latest_version_tag,
    pick_ios_simulator,
    render_changelog_entry,
    run_release,
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
    merges = [
        ("Merge branch 'x' into dev", "Add a bass instrument + a picker\n\nmore detail")
    ]
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
    entry = render_changelog_entry(
        "1.1.0", date(2026, 7, 5), ["Feature A", "Feature B"], ["feat: a"]
    )
    assert highlights_plaintext(entry) == "Feature A\nFeature B\n"


def test_finalize_entry_drops_instruction_lines():
    edited = (
        "# instructions\n# more\n## v1.1.0 — 2026-07-05\n### Highlights\n- Feature A\n"
    )
    result = finalize_entry(edited)
    assert result.startswith("## v1.1.0")
    assert "# instructions" not in result


def test_finalize_entry_rejects_empty():
    with pytest.raises(ValueError):
        finalize_entry("# only instructions, no entry\n")
    with pytest.raises(ValueError):
        finalize_entry("## v1.1.0 — 2026-07-05\n### Highlights\n")


PBX_SAMPLE = """
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tMARKETING_VERSION = 1.0;
"""


def test_current_build_number():
    assert current_build_number(PBX_SAMPLE) == 1


def test_current_build_number_rejects_non_uniform():
    bad = PBX_SAMPLE.replace(
        "CURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;",
        "CURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 2;",
    )
    with pytest.raises(ValueError):
        current_build_number(bad)


def test_bump_pbxproj_updates_all_occurrences():
    result = bump_pbxproj(PBX_SAMPLE, "1.1.0", 2)
    assert result.count("MARKETING_VERSION = 1.1.0;") == 2
    assert result.count("CURRENT_PROJECT_VERSION = 2;") == 2
    assert "MARKETING_VERSION = 1.0;" not in result
    assert "CURRENT_PROJECT_VERSION = 1;" not in result


def test_bump_pbxproj_rejects_non_uniform_marketing():
    bad = PBX_SAMPLE.replace(
        "MARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 1.0;",
        "MARKETING_VERSION = 1.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = 2.0;",
    )
    with pytest.raises(ValueError):
        bump_pbxproj(bad, "1.1.0", 2)


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
    _git(
        root,
        "merge",
        "--no-ff",
        "feat-work",
        "-m",
        "Merge branch 'feat-work' into dev\n\nAdd the cool feature",
    )


def _canned_edit(draft):
    return "## v1.1.0 — 2026-07-05\n### Highlights\n- Add the cool feature\n"


def test_run_release_end_to_end(tmp_path):
    _init_repo(tmp_path)
    run_release(tmp_path, "1.1.0", edit=_canned_edit)

    tags = subprocess.run(
        ["git", "tag"], cwd=tmp_path, capture_output=True, text=True
    ).stdout.split()
    assert "v1.1.0" in tags
    branch = subprocess.run(
        ["git", "branch", "--show-current"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    ).stdout.strip()
    assert branch == "main"
    pbx = (tmp_path / "audio_listen.xcodeproj" / "project.pbxproj").read_text()
    assert "MARKETING_VERSION = 1.1.0;" in pbx and "MARKETING_VERSION = 1.0;" not in pbx
    assert (
        "CURRENT_PROJECT_VERSION = 2;" in pbx
        and "CURRENT_PROJECT_VERSION = 1;" not in pbx
    )
    changelog = (tmp_path / "CHANGELOG.md").read_text()
    assert "## v1.1.0" in changelog and "- Add the cool feature" in changelog
    notes = (
        tmp_path / "fastlane" / "metadata" / "en-US" / "release_notes.txt"
    ).read_text()
    assert notes == "Add the cool feature\n"


def test_run_release_dry_run_mutates_nothing(tmp_path, capsys):
    _init_repo(tmp_path)
    run_release(tmp_path, "1.1.0", dry_run=True, edit=_canned_edit)
    assert not (tmp_path / "CHANGELOG.md").exists()
    tags = subprocess.run(
        ["git", "tag"], cwd=tmp_path, capture_output=True, text=True
    ).stdout.split()
    assert tags == []
    assert "1.1.0" in capsys.readouterr().out


def test_run_release_dry_run_allows_dirty_tree(tmp_path, capsys):
    _init_repo(tmp_path)
    (tmp_path / "uncommitted.txt").write_text("wip")
    run_release(tmp_path, "1.1.0", dry_run=True, edit=_canned_edit)
    assert "1.1.0" in capsys.readouterr().out


def test_run_release_rejects_existing_tag(tmp_path):
    _init_repo(tmp_path)
    _git(tmp_path, "tag", "v1.1.0")
    with pytest.raises(SystemExit):
        run_release(tmp_path, "1.1.0", edit=_canned_edit)


def test_tag_message_uses_curated_highlights(tmp_path):
    _init_repo(tmp_path)

    def edit(draft):
        return "## v1.1.0 — 2026-07-05\n### Highlights\n- Curated line one\n- Curated line two\n"

    run_release(tmp_path, "1.1.0", edit=edit)
    message = subprocess.run(
        ["git", "tag", "-l", "v1.1.0", "--format=%(contents)"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    ).stdout.strip()
    assert message == "Curated line one\nCurated line two"
    notes = (
        tmp_path / "fastlane" / "metadata" / "en-US" / "release_notes.txt"
    ).read_text()
    assert notes == "Curated line one\nCurated line two\n"
