import hashlib
import pytest

import generate_art
from generate_art import (
    ASSETS,
    Asset,
    STYLE_PREFIX,
    anchor_hash,
    build_edit_fields,
    build_generation_payload,
    build_prompt,
    build_sidecar,
    estimate_cost,
    promote,
    render_gallery,
    resolve_selection,
    should_skip,
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
        "belt-white",
        "belt-yellow",
        "belt-orange",
        "belt-green",
        "belt-blue",
        "belt-purple",
        "belt-brown",
        "belt-black",
    ]


def test_resolve_empty_returns_all():
    assert resolve_selection([], ASSETS) == ASSETS


def test_resolve_group_expands_to_members():
    selected = resolve_selection(["belts"], ASSETS)
    assert [asset.name for asset in selected] == [
        "belt-white",
        "belt-yellow",
        "belt-orange",
        "belt-green",
        "belt-blue",
        "belt-purple",
        "belt-brown",
        "belt-black",
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
    sidecar = build_sidecar(
        asset, "full prompt", "low", "abc123", "gpt-image-1", "2026-06-29T00:00:00Z"
    )
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
    return hashlib.sha256(data).hexdigest()


def test_should_skip_only_when_exists_and_not_forced(tmp_path):
    path = tmp_path / "x.png"
    assert should_skip(str(path), force=False) is False
    path.write_bytes(b"x")
    assert should_skip(str(path), force=False) is True
    assert should_skip(str(path), force=True) is False


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

    def fail_post_edit(*args, **kwargs):
        raise AssertionError("post_edit must not be called on the generations path")

    monkeypatch.setattr(generate_art, "post_generation", fake_post_generation)
    monkeypatch.setattr(generate_art, "post_edit", fail_post_edit)

    anchor_asset = Asset("_anchor", "anchor", "body", "1024x1024", False, False)
    assert (
        generate_art.generate_one(anchor_asset, "p", "low", "key", "missing.png")
        == b"GENERATED"
    )

    belt = Asset("belt-white", "belts", "body", "1024x1024", True, True)
    assert (
        generate_art.generate_one(belt, "p", "low", "key", "missing.png")
        == b"GENERATED"
    )


def test_render_gallery_embeds_name_and_prompt():
    html = render_gallery(
        [
            {
                "name": "belt-white",
                "image": "belt-white.png",
                "prompt": "a white belt",
                "quality": "low",
            },
        ]
    )
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
