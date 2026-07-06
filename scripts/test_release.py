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
