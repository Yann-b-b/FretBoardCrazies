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
