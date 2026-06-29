import hashlib
import json
import struct
import zlib

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
    parse_args,
    promote,
    render_gallery,
    resolve_selection,
    run,
    should_skip,
    verify_transparency,
)


def _png_chunk(tag, data):
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def _make_rgba_png(width, height, alpha):
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    pixel = bytes([255, 128, 0, alpha])
    raw = b"".join(b"\x00" + pixel * width for _ in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", zlib.compress(raw))
        + _png_chunk(b"IEND", b"")
    )


def test_verify_transparency_true_for_transparent_corners():
    assert verify_transparency(_make_rgba_png(4, 4, alpha=0)) is True


def test_verify_transparency_false_for_opaque_corners():
    assert verify_transparency(_make_rgba_png(4, 4, alpha=255)) is False


def test_verify_transparency_false_for_non_png():
    assert verify_transparency(b"not a png") is False


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


def test_run_records_anchor_hash_for_assets_after_anchor(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    monkeypatch.setattr(generate_art, "ANCHOR_PATH", str(tmp_path / "_anchor.png"))
    monkeypatch.setattr(generate_art, "GALLERY_PATH", str(tmp_path / "index.html"))
    monkeypatch.setattr(generate_art, "generate_one", lambda *a, **k: b"ANCHORBYTES")

    args = parse_args(["_anchor", "belt-white", "--yes"])
    run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    expected = hashlib.sha256(b"ANCHORBYTES").hexdigest()
    belt_sidecar = json.loads((tmp_path / "belt-white.json").read_text())
    assert belt_sidecar["anchor_hash"] == expected
    anchor_sidecar = json.loads((tmp_path / "_anchor.json").read_text())
    assert anchor_sidecar["anchor_hash"] is None


def test_run_promote_branch(tmp_path, monkeypatch):
    monkeypatch.setattr(generate_art, "OUTPUT_DIR", str(tmp_path))
    monkeypatch.setattr(generate_art, "CANDIDATES_DIR", str(tmp_path / "_candidates"))
    (tmp_path / "_candidates").mkdir()
    (tmp_path / "_candidates" / "belt-white-1.png").write_bytes(b"CAND")

    args = parse_args(["--promote", "belt-white=1", "--yes"])
    code = run(args, generate_art.ASSETS, "key", "2026-06-29T00:00:00Z")

    assert code == 0
    assert (tmp_path / "belt-white.png").read_bytes() == b"CAND"
