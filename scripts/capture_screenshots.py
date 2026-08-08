import argparse
import json
import os
import subprocess
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.yannbaglinbunod.fretboardcrazies"
DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer"

REQUIRED_DEVICES = {
    "iphone-6.9": "iPhone 17 Pro Max",
    "ipad-13": "iPad Pro 13-inch (M4)",
}


def _env():
    return {**os.environ, "DEVELOPER_DIR": DEVELOPER_DIR}


def _run(command, **kwargs):
    return subprocess.run(command, env=_env(), **kwargs)


def available_devices(simctl_json):
    data = json.loads(simctl_json)
    found = {}
    for devices in data.get("devices", {}).values():
        for device in devices:
            if device.get("isAvailable"):
                found[device["name"]] = device["udid"]
    return found


def resolve_device(name, available):
    if name not in available:
        raise SystemExit(
            f"simulator '{name}' is not available. Install it in Xcode › Settings › Components, "
            f"or pass --device with one of: {', '.join(sorted(available))}"
        )
    return available[name]


def boot(udid):
    _run(["xcrun", "simctl", "boot", udid], capture_output=True, text=True)
    _run(["xcrun", "simctl", "bootstatus", udid, "-b"], capture_output=True, text=True)


def build_for_simulator(udid, derived_data):
    result = _run(
        [
            "xcodebuild",
            "build",
            "-project",
            "audio_listen.xcodeproj",
            "-scheme",
            "audio_listen",
            "-configuration",
            "Release",
            "-destination",
            f"id={udid}",
            "-derivedDataPath",
            str(derived_data),
        ],
        cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        raise SystemExit("build for simulator failed")
    app = (
        derived_data
        / "Build"
        / "Products"
        / "Release-iphonesimulator"
        / "audio_listen.app"
    )
    if not app.exists():
        raise SystemExit(f"built app not found at {app}")
    return app


def install_and_launch(udid, app):
    installed = _run(["xcrun", "simctl", "install", udid, str(app)])
    if installed.returncode != 0:
        raise SystemExit("install failed")
    _run(["xcrun", "simctl", "privacy", udid, "grant", "microphone", BUNDLE_ID])
    launched = _run(["xcrun", "simctl", "launch", udid, BUNDLE_ID], capture_output=True)
    if launched.returncode != 0:
        raise SystemExit("launch failed")


def capture(udid, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = _run(["xcrun", "simctl", "io", udid, "screenshot", str(destination)])
    if result.returncode != 0:
        raise SystemExit(f"screenshot failed for {destination.name}")
    print(f"wrote {destination}")


def capture_device(label, device_name, out_root, shots, pause):
    listing = _run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        capture_output=True,
        text=True,
    )
    if listing.returncode != 0:
        raise SystemExit("could not list simulators")
    udid = resolve_device(device_name, available_devices(listing.stdout))

    print(f"\n=== {label}: {device_name} ===")
    boot(udid)
    derived_data = REPO_ROOT / "build" / "screenshots" / label / "DerivedData"
    app = build_for_simulator(udid, derived_data)
    install_and_launch(udid, app)

    print(
        "The simulator is running. Navigate to each screen when prompted, then press Return.\n"
        "Rotate to landscape with Device › Rotate if it launched upright."
    )
    time.sleep(pause)
    for index, shot in enumerate(shots, start=1):
        input(f"  [{index}/{len(shots)}] Show '{shot}', then press Return: ")
        capture(udid, out_root / label / f"{index:02d}-{shot}.png")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Capture App Store screenshots from simulators."
    )
    parser.add_argument("--out", default=str(REPO_ROOT / "build" / "screenshots"))
    parser.add_argument("--device", action="append", default=None)
    parser.add_argument("--pause", type=float, default=3.0)
    args = parser.parse_args(argv)

    shots = ["drill", "correct", "progress", "tuner", "settings"]
    out_root = Path(args.out)

    targets = (
        {f"custom-{i}": name for i, name in enumerate(args.device, start=1)}
        if args.device
        else REQUIRED_DEVICES
    )
    for label, device_name in targets.items():
        capture_device(label, device_name, out_root, shots, args.pause)

    print(f"\nDone. Screenshots under {out_root}")


if __name__ == "__main__":
    main()
