# Versioning

Two numbers live in `project.pbxproj`, and they follow different rules.

`MARKETING_VERSION` is the semantic version users see on the App Store. It never repeats and never
moves backwards. `run_release` refuses a version that does not sort strictly above the one currently
in the project.

`CURRENT_PROJECT_VERSION` is the build number. It must strictly increase on **every** upload to App
Store Connect, including uploads that are later rejected — a burned build number cannot be reused,
even for the same marketing version. `run_release` increments it on every release.

## History and ladder

`v1.0.0` was tagged and pushed to `origin` before an App Store Connect record existed. That version
is spent, so the first submission is 1.1.0.

| Version | Build | Contents |
|---|---|---|
| 1.0.0 | 2 | Pre-store. Tagged in the repository only; never submitted |
| 1.1.0 | 3 | First submission: drill, progress, tuner, settings |
| 1.1.x | 4+ | Fixes to the shipped four |
| 2.0.0 | — | Chords and Suggest revealed |

## Cutting a release

```bash
python3 scripts/release.py 1.1.0 --dry-run          # preview notes and bumps
python3 scripts/release.py 1.1.0 --verify           # run tests on macOS and iOS first
python3 scripts/release.py 1.1.0 --verify --archive # ...and produce an .ipa
```

`--verify` runs the unit suite against macOS and an iOS simulator. `--archive` writes an
`.xcarchive` and an exported `.ipa` under `build/v<version>/`. Upload is manual, through Xcode
Organizer or Transporter.

## Revealing the chord screens

The shipping tab set is one list in `audio_listen/Presentation/Root/AppTab.swift`:

```swift
enum ReleaseScope {
    static let shippingTabs: [AppTab] = [.drill, .progress, .tuner, .settings]
}
```

Adding `.chords` and `.suggest` reveals them in both the iOS nav rail and the macOS tab bar. The
screens are already built and tested; nothing else needs to change. `AppTabTests` asserts the
current set, so that test is the reminder to update it deliberately rather than by accident.
