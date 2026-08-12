# App Store readiness for the first FretBoard Crazies submission

## Goal

Put the repository in a state where an App Store submission can be built, signed, uploaded, and
approved. The submission ships a deliberately narrow app — the guitar drill, the tuner, progress,
and settings — and nothing else.

## Scope

In scope: the shipping tab set, the no-instrument entry path, microphone-permission handling, the
release and archive tooling, the versioning scheme, and the written submission assets.

Out of scope: a VoiceOver accessibility pass, and automated upload to App Store Connect. Both are
deferred deliberately; see [Deferred](#deferred).

## Current state

A Release build for `generic/platform=iOS` compiles clean. The macOS unit-test leg passes. Bundle
identifier, display name, microphone usage string, export-compliance key, device family, privacy
manifest, and the 1024px iOS icon are all settled. The app makes no network calls of any kind, so a
"Data Not Collected" privacy declaration is accurate.

Three problems stand between that and a submission, plus one scope decision.

## 1. Shipping tab set

`ContentView` exposes six destinations: Drill, Chords, Suggest, Progress, Tuner, Settings. The first
release ships four — Drill, Progress, Tuner, Settings. Chords and Suggest are recent, less exercised,
and carry the most surface area for a reviewer to find a rough edge.

They are hidden, not deleted. The code stays compiled and its tests keep running, so it does not rot
while it waits for the release that reveals it.

### The refactor this forces

`ContentView` currently describes its destinations three times: a `TabView` for macOS, a parallel
`items` array in `NavRail` for iOS, and a `screen(for: Int)` switch keyed on magic indices that must
stay aligned with both. Adding or hiding a destination means editing three places correctly, and
nothing catches a mismatch.

Replace all three with one description:

```swift
enum AppTab: CaseIterable {
    case drill, chords, suggest, progress, tuner, settings

    var title: String { ... }
    var systemImage: String { ... }
}

enum ReleaseScope {
    static let shippingTabs: [AppTab] = [.drill, .progress, .tuner, .settings]
}
```

`ContentView.selection` becomes an `AppTab` rather than an `Int`. `screen(for:)` switches on the
enum, keeping the `.chords` and `.suggest` cases intact. Both the iOS nav rail and the macOS
`TabView` iterate `ReleaseScope.shippingTabs`. Revealing a destination in a later release is one
line, and the index-alignment failure mode is gone.

`screen(for:)` keeps no `default:` case, so a future tab that nobody wired up is a compile error
rather than a silent fallback to Settings.

## 2. The no-instrument entry path

This is the likeliest cause of rejection. App Review tests in an office with no guitar. Microphone
input is currently the only way to answer a drill prompt, so a reviewer sees a screen that never
responds and files a Guideline 2.1 report. Touch mode exists but defaults off and sits behind the
sixth Settings pane.

The welcome screen stops offering one "Get started" button and offers two entry points instead:

- **"I'm playing an instrument"** sets touch mode off.
- **"I'll tap the fretboard"** sets touch mode on.

`WelcomeView.onStart` changes from `() -> Void` to `(InputMode) -> Void`. `RootViewModel.enterApp`
takes the mode, writes it through an injected store, and routes to `.main`.

This costs the user nothing — they were already pressing one button on this screen, and now they
press one of two. The welcome screen shows on every launch (`route` defaults to `.welcome` with no
persistence), so the fork doubles as the mode switch. The Settings toggle stays as the way to change
mode mid-session.

`ContentView` already carries `.id("\(touchMode)-\(selectedInstrumentId)")` on `DrillView`, so the
drill rebuilds when the mode changes. No further plumbing.

### Why not the alternatives

Auto-falling back to touch mode after a silence timeout was rejected: it fires on a legitimate pause
between attempts, and implicit mode changes are hard to reason about. Defaulting touch mode on was
rejected because it hides the premise of the app. App Review notes alone were rejected because they
fix nothing for a real user with a dead microphone and depend on the reviewer following them.

## 3. Microphone-permission handling

`MicrophonePermission.swift`, `SystemMicrophonePermission.swift`, and `MicrophoneAccessNotice.swift`
are written but untracked, alongside uncommitted changes to `DrillViewModel`, `TunerViewModel`, and
`AppDependencyContainer`. Reviewers routinely deny the permission prompt to see what an app does.
Until this is committed it is not in a release build.

The work is to review, test, and commit it as one unit. `MicrophonePermissionRequesting` is already
a protocol, so a fake drives the three status paths — `granted`, `denied`, and `undetermined`
resolving through `statusRequestingIfNeeded()`. None of this is covered today.

## 4. Versioning

Two numbers, with distinct rules.

`MARKETING_VERSION` is the semver string users see. It never repeats and never goes backwards.
`CURRENT_PROJECT_VERSION` is the build number: an integer that must strictly increase on every
upload to App Store Connect, including uploads that get rejected — a burned build number cannot be
reused.

The repository already tagged `v1.0.0` and pushed it to `origin` before any App Store existed, so
that version is spent. The first submission ships as **1.1.0**, build **3**.

The release ladder:

| Version | Contents |
|---|---|
| 1.1.0 | First submission: drill, progress, tuner, settings |
| 1.1.x | Fixes to the shipped four |
| 2.0.0 | Chords and Suggest revealed via `ReleaseScope.shippingTabs` |

`run_release` already bumps both numbers and refuses a tag that exists. It gains a guard that the
requested `MARKETING_VERSION` sorts strictly above the current one, so a typo cannot ship a version
that moves backwards.

## 5. Release tooling

Two changes to `scripts/release.py`.

**Fix the simulator lookup.** In `_verify_both_platforms`, the `xcodebuild` calls receive an `env`
carrying `DEVELOPER_DIR`, but the `xcrun simctl list` call does not. It therefore fails with
`could not list iOS simulators`, which raises `SystemExit` after the macOS leg has already passed.
The iOS test leg has never run. Passing `env=env` to that call fixes it.

**Add an archive path.** A `--archive` flag runs `xcodebuild archive` followed by `-exportArchive`
with an `ExportOptions.plist` set to `app-store-connect`, producing an `.ipa`.

Upload stays manual for the first submission, through Xcode Organizer or Transporter. Automating
`altool` credentials before a single successful upload has happened would be debugging two unproven
things at once.

## 6. Submission assets

Under `docs/store/`:

- `description.md` — description, subtitle, keywords, promotional text
- `review-notes.md` — App Review notes, stating plainly that the welcome screen offers a
  "I'll tap the fretboard" entry that needs no instrument
- `privacy-policy.md` — the app collects nothing and makes no network calls; this says so
- `support.md` — contact route and common questions
- `versioning.md` — the scheme in section 4, as the durable reference

Plus `scripts/capture_screenshots.py`, driving simulators to shoot the required sets. Both are
**landscape**, because the app pins landscape on both idioms:

- 6.9" iPhone
- 13" iPad

### Open item

App Store Connect requires a publicly reachable **privacy policy URL** and **support URL**. This
work produces the content; hosting is a separate decision. GitHub Pages off this repository is the
zero-cost option and is the recommendation, but it is not assumed here.

## Testing

| Area | Test |
|---|---|
| `AppTab` / `ReleaseScope` | Shipping set is exactly drill, progress, tuner, settings; every shipping tab has a non-empty title and SF Symbol name |
| Welcome fork | Each entry point writes the expected touch-mode value and routes to `.main` |
| Permission | Fake requester drives granted, denied, and undetermined-then-resolved |
| `release.py` | Marketing-version monotonicity guard accepts a higher version, rejects equal and lower |

Existing suites for the chord engine keep running unchanged — hiding the tabs must not touch them.

## Deferred

**Accessibility.** Two `accessibilityLabel` calls across 269 Swift files. The fretboard and drill
prompts are unusable with VoiceOver. This does not gate approval and is large enough to deserve its
own cycle.

**Automated upload.** See section 5.

**Chords and Suggest.** Section 1. The code ships in the binary but is unreachable until 2.0.0.
