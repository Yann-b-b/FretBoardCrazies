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
