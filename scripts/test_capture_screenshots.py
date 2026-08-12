import subprocess

import pytest

from capture_screenshots import (
    REQUIRED_DEVICES,
    available_devices,
    image_size,
    resolve_device,
    rotate_to_landscape,
)

SIMCTL_JSON = """
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
      {"name": "iPhone 17 Pro Max", "udid": "AAA", "isAvailable": true},
      {"name": "iPad Pro 13-inch (M5)", "udid": "BBB", "isAvailable": true},
      {"name": "iPhone 15 Pro Max", "udid": "CCC", "isAvailable": false}
    ]
  }
}
"""


def test_available_devices_maps_names_to_udids():
    assert available_devices(SIMCTL_JSON) == {
        "iPhone 17 Pro Max": "AAA",
        "iPad Pro 13-inch (M5)": "BBB",
    }


def test_resolve_device_takes_the_first_available_candidate():
    available = available_devices(SIMCTL_JSON)
    assert resolve_device(["iPhone 99", "iPhone 17 Pro Max"], available) == (
        "iPhone 17 Pro Max",
        "AAA",
    )


def test_resolve_device_raises_when_no_candidate_is_available():
    with pytest.raises(SystemExit):
        resolve_device(["iPhone 99"], available_devices(SIMCTL_JSON))


def test_required_devices_resolve_against_a_current_toolchain():
    available = available_devices(SIMCTL_JSON)
    for candidates in REQUIRED_DEVICES.values():
        assert resolve_device(candidates, available)


def test_rotate_to_landscape_turns_a_portrait_capture(tmp_path):
    portrait = tmp_path / "portrait.png"
    subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "png",
            "-z",
            "400",
            "200",
            "/System/Library/CoreServices/DefaultDesktop.heic",
            "--out",
            str(portrait),
        ],
        capture_output=True,
    )
    if not portrait.exists():
        pytest.skip("no source image available to build a fixture")
    assert image_size(portrait) == (200, 400)
    assert rotate_to_landscape(portrait) == (400, 200)


def test_rotate_to_landscape_leaves_a_landscape_capture_alone(tmp_path):
    landscape = tmp_path / "landscape.png"
    subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "png",
            "-z",
            "200",
            "400",
            "/System/Library/CoreServices/DefaultDesktop.heic",
            "--out",
            str(landscape),
        ],
        capture_output=True,
    )
    if not landscape.exists():
        pytest.skip("no source image available to build a fixture")
    assert rotate_to_landscape(landscape) == (400, 200)
