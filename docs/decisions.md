# Decisions

## 2026-08-10 — Rename the app to FretBoardMastery and realign the bundle identifier before registering it
**Choice:** The app ships as **FretBoardMastery**, and the permanent bundle identifier becomes
`com.yannbaglinbunod.fretboardmastery`, replacing `com.yannbaglinbunod.fretboardcrazies`. The
rename covers the display name, the welcome screen, the microphone-permission copy, the store
listing, the review notes, and the published privacy and support pages. The GitHub repository keeps
the name `FretBoardCrazies`, so the Pages URLs stay
`https://yann-b-b.github.io/FretBoardCrazies/{privacy,support}/`.

**Why:** The bundle identifier can never be changed once an App Store Connect record exists, and no
record had been created yet — this was the last moment the two could be aligned for free. Shipping
an identifier that names a product called Crazies under an app called Mastery would have persisted
into crash reports, extensions, and iCloud containers for the life of the app. The repository name
was left alone because renaming it would break two URLs that are already live and verified, for no
benefit Apple can see.

**Considered:** Keeping `fretboardcrazies` as the identifier was rejected for the permanent mismatch
above. Renaming the GitHub repository to match was rejected because the Pages URLs are already
serving and a rename risks them for cosmetic consistency. Keeping the name FretBoard Crazies was
argued for on discoverability grounds — it is a distinctive term the app would rank first for,
whereas "Fretboard Mastery" is a phrase an incumbent (`Fretbrrd: Fretboard Mastery`) already holds,
in a category that also contains a direct mechanical competitor (`Freta`, which likewise validates
played notes by pitch detection rather than tapping). That argument was heard and the name was
chosen anyway; an App Store name, unlike a bundle identifier, can be changed in any later version
that is not in review.

**Prompted by:** The App Store Connect New App form was about to be submitted with the leftover
placeholder identifier `v.audio-listen` and macOS ticked alongside iOS, which surfaced both the
identifier question and the name change before either became permanent.

**Touches:** `audio_listen.xcodeproj/project.pbxproj` (six bundle identifiers, display name,
microphone usage string), `audio_listen/Presentation/Welcome/WelcomeView.swift`,
`audio_listen/Domain/Protocols/MicrophonePermission.swift`,
`audio_listenTests/MicrophonePermissionTests.swift`, `scripts/capture_screenshots.py`,
`scripts/build_app_icon.py`, `scripts/generate_art.py`, `docs/store/*`, `site/*`, `README.md`.

**Note:** The App Store record must be created with **iOS only**. macOS needs its own icon set,
screenshots, and review cycle, and shipping it was never a v1 decision.

## 2026-08-09 — Host the mandatory store URLs on GitHub Pages from a dedicated site/ folder
**Choice:** The privacy-policy and support URLs App Store Connect requires are served by GitHub
Pages from a `site/` folder containing hand-written HTML, deployed by a GitHub Actions workflow that
runs on pushes to `main`. The canonical copy of that content stays in `docs/store/*.md`; `site/` is
the published rendering of it, and the two must be updated together.

**Why:** Branch-based Pages can only serve the repository root or `/docs`, and `/docs` holds this
decision log, the superpowers specs, and the v2 roadmap — pointing Pages at it would publish all
internal planning as a browsable website. An Actions-based deploy can publish an arbitrary
directory, so `site/` exposes exactly the two pages Apple needs and nothing else. GitHub Pages is
free on this already-public repository and requires no domain purchase.

**Considered:** Serving `/docs` was rejected for the exposure above. A raw GitHub file or gist URL
was rejected because Apple accepts it but it renders as a source-code view, which reads as
unfinished to a reviewer clicking through from the listing. Buying a domain was rejected as cost and
DNS work that buys nothing before the app has any users. Notion or Carrd was rejected because it
puts a submission-blocking dependency outside version control.

**Prompted by:** App Store Connect refuses a submission without both URLs, and a reviewer clicking a
dead privacy-policy link is a rejection.

**Touches:** `site/` (new), `.github/workflows/pages.yml` (new), `docs/store/description.md` (URL
table), `docs/store/privacy-policy.md` and `docs/store/support.md` as the source of the page copy.

**Note:** The workflow triggers on `main`, so the site publishes when the release merge lands there
— it must be live before the app is submitted, not after.

## 2026-08-08 — Ship the first submission as 1.1.0 with only the four original screens
**Choice:** The first App Store release contains the guitar drill, progress, tuner, and settings.
The Chords and Suggest destinations are hidden behind a single `ReleaseScope.shippingTabs` list
rather than deleted, so their code stays compiled and their tests keep running. It ships as version
**1.1.0**, build **3** — not 1.0.0, because `v1.0.0` was tagged and pushed to `origin` before an App
Store record existed and a marketing version is never reused. Chords and Suggest are revealed in
2.0.0 by adding two entries to that list.

**Why:** The chord engine is the newest and least exercised part of the app, and every screen in a
first submission is surface area for a reviewer to find a rough edge — narrowing the release lowers
the odds of a rejection that costs a review cycle. Hiding rather than deleting keeps the work
building and tested instead of rotting on a branch, and makes the later reveal a one-line change.

**Considered:** Shipping all six destinations was rejected as needless review risk for features that
are not the app's core promise. Deleting the chord code or parking it on a branch was rejected
because it would drift out of sync with the app it has to rejoin. Reusing 1.0.0 for the store was
rejected because the tag is already published; retagging would rewrite a pushed ref for no benefit
visible to users, since Apple has never seen any version of this app.

**Prompted by:** A scoping decision during App Store readiness work — the request was that the first
store version carry only the screens the repository started with.

**Touches:** `audio_listen/ContentView.swift` (single `AppTab` description replacing three parallel
ones), new `ReleaseScope`, `audio_listen.xcodeproj/project.pbxproj` (`MARKETING_VERSION`,
`CURRENT_PROJECT_VERSION`), `scripts/release.py` (version monotonicity guard),
`docs/store/versioning.md`.

**Long form:** `docs/superpowers/specs/2026-08-08-app-store-readiness-design.md`.

## 2026-08-08 — Fork the welcome screen on input mode so the app is usable without an instrument
**Choice:** The welcome screen stops offering a single "Get started" button and instead forks into
two entry points — one for playing a real instrument, one for tapping the fretboard on screen. The
chosen path writes `GameSettingsKeys.touchMode` before routing into the app, so touch mode becomes a
first-class way in rather than a toggle buried in the sixth Settings pane. Scope for the App Store
push is the code work plus the submission assets (store copy, privacy policy, support page, review
notes, screenshot capture); a VoiceOver accessibility pass is explicitly deferred.

**Why:** App Review tests in an office with no guitar. With microphone input as the only way to
answer a drill prompt, a reviewer sees a screen that never responds and files a Guideline 2.1
rejection. Forking the welcome screen fixes this without adding a step, because the user was already
tapping one button there — it becomes a choice between two. It also serves real users with a dead
microphone, a noisy room, or a borrowed device, which an App Review note would not.

**Considered:** Auto-falling back to touch mode after a silence timeout was rejected as implicit
behaviour that fires on a legitimate pause between attempts. Defaulting touch mode on was rejected
because it hides the app's premise — listening to your playing — behind a toggle most users would
never find. Relying on App Review notes alone was rejected as the cheapest option that fixes nothing
for real users and depends on the reviewer reading them. The accessibility pass was deferred because
it does not gate approval and is large enough to deserve its own cycle.

**Prompted by:** A readiness review found the Release build and test suite green and the store
metadata largely settled, leaving the no-instrument path as the only likely cause of rejection —
alongside microphone-denial handling that was written but never committed.

**Touches:** `audio_listen/Presentation/Welcome/WelcomeView.swift`,
`audio_listen/Presentation/Root/RootView.swift`, `audio_listen/Presentation/Root/RootViewModel.swift`,
the uncommitted microphone-permission files under `audio_listen/Domain/Protocols/` and
`audio_listen/Infrastructure/Audio/`, `scripts/release.py` (archive/export, iOS simulator lookup),
and new store-submission assets under `docs/`.

**Note:** `scripts/release.py --verify` aborts at `could not list iOS simulators` because the
`simctl` subprocess is the one call in `_verify_both_platforms` that does not receive the `env`
carrying `DEVELOPER_DIR`. The macOS leg passes, then the run dies before the iOS leg, so iOS tests
have never run. Fixing that is part of this work.

## 2026-08-06 — Lock the App Store identity and shipping surface for v1
**Choice:** The permanent bundle identifier is `com.yannbaglinbunod.fretboardcrazies`, replacing the
placeholder `v.audio-listen`. v1 ships to iPhone and iPad only (`TARGETED_DEVICE_FAMILY = "1,2"`),
with visionOS dropped from the build configuration. The iOS deployment target stays at 18.2.

**Why:** The bundle identifier can never be changed once registered with Apple, so it had to be
settled before an App Store Connect record exists; reverse-DNS on the developer's own name is
correct without depending on owning a domain. iPad was kept because the app already builds and runs
there and the extra cost is one screenshot set. visionOS was dropped because the asset catalog has
no visionOS icon layers, so a Vision Pro build could not ship regardless. The 18.2 target stays
because lowering it would require re-verifying every API call for availability, which is work that
does not block the first submission.

**Considered:** `com.fretboardcrazies.app` was rejected because it presumes ownership of a domain
that is not registered. iPhone-only was rejected as needlessly narrow given iPad already works.
Keeping all four platforms was rejected because visionOS and macOS each need their own icons,
screenshots, and review cycle, which would delay v1 without adding reach. Lowering the target to
iOS 17.0 was considered for wider device reach and deferred to a later release.

**Prompted by:** An App Store readiness audit found the project was carrying Xcode's placeholder
bundle identifier, no privacy manifest, no display name, and a device family claiming visionOS
without a corresponding app icon.

**Touches:** `audio_listen.xcodeproj/project.pbxproj` (bundle identifier, device family, supported
platforms, display name, export-compliance key), `audio_listen/PrivacyInfo.xcprivacy` (new),
`audio_listen/ContentView.swift` (nav rail tap targets).

**Note:** `macosx` stays in `SUPPORTED_PLATFORMS` even though macOS is not a v1 App Store target —
`scripts/release.py --verify` runs the unit test suite against `platform=macOS`, and removing it
would break that check. Shipping to the Mac App Store remains a separate, explicit decision.

## 2026-08-15 — Answer App Review's seven questions in the notes field, permanently
**Choice:** `docs/store/review-notes.txt` is expanded from a guitar-free testing guide into the full
review package, answering Apple's seven Guideline 2.1 questions in their own numbering: screen
recording, devices tested, function and audience, setup, external services, regional differences, and
third-party material. It stays the single copy of that text; `review-notes.md` stops duplicating it
and becomes the procedure for replying plus a table mapping each factual claim to the one-line
command that verifies it. No new build is cut.

**Why:** The rejection was Guideline 2.1 *Information Needed*, not a defect — the binary was never
the objection, so a resubmission would have burned a review cycle without changing anything. Apple's
message says to include this information "for future submissions", and the notes field persists
across versions, which makes the expanded text a permanent fixture rather than a one-off reply. The
answers assert checkable things (no network calls, two MIT libraries, a 75/25 prompt split, no
accounts or IAP); pairing each with its verification command is what stops the notes drifting from
the code and turning an information request into a credibility problem on a later submission.

**Considered:** Replying only in Resolution Center was rejected because the next version would arrive
with the same thin notes and invite the same rejection. Keeping the long form in `review-notes.md`
and hand-trimming a paste version was rejected as two copies that will diverge — the field is plain
text and caps at 4000 characters, so the `.txt` has to be the authoritative one. Naming a physical
test device on our behalf was rejected outright: the recording Apple asked for would contradict a
guess, so the line carries an explicit placeholder the developer must fill.

**Prompted by:** FretBoardMastery 1.1.0 (build 3) was rejected under Guideline 2.1 on 2026-08-15,
hours after submission, with a seven-item information request and a demand for a screen recording
captured on a physical device running current iOS.

**Touches:** `docs/store/review-notes.txt`, `docs/store/review-notes.md`,
`docs/store/submission-checklist.md`.

**Note:** The app has still never been run on a physical device — every test has been simulator or
macOS. Producing the recording is therefore also the first real-hardware run, and is the one step
here that could surface a genuine bug.

## 2026-09-06 — Pick note-naming system by locale on first read, with a Settings override
**Choice:** The app gains a notation preference (letters vs fixed-do solfège) that defaults from
the device locale (fr/es/it/pt → solfège, everything else → letters) the first time it is read,
and is overridable from a picker in SettingsView. The preference is display-only: `NoteName`
remains the single identity for the twelve pitches, and solfège appears solely where
`displayName` strings are rendered. Solfège spellings mirror the letter strings one-for-one:
do, do#, ré, ré#, mi, fa, fa#, sol, sol#, la, la#, si — accented ré, `#` for sharps, octave
suffix unchanged (`la4`). Long-form accidentals ("do dièse") were rejected because two-character
labels are a layout assumption across fret labels, answer buttons, and the tuner readout;
unaccented "re" was rejected as a misspelling to the very users the feature serves.

**Why:** Solfège users are defined by where they learned music, which locale approximates well
enough to make the common case zero-config, while the override respects players who learned the
other system. Display-only keeps game logic, answer checking, and every UserDefaults store
untouched, since they all traffic in `NoteName` raw values, never strings.

**Considered:** A parallel `SolfegeNoteName` enum was rejected because it duplicates identity —
every store, comparison, and signature would need to know which enum it holds or convert between
them. A Settings-only toggle (no locale default) was rejected as leaving the majority of solfège
users to discover a buried setting. Locale-only with no override was rejected as magic with no
escape hatch and painful to test.

**Prompted by:** Feature request to display "do re mi" note names, raised 2026-09-06, with the
explicit constraint of changing as little existing code as possible.

**Touches:** `audio_listen/Domain/Models/Note.swift` (display path), a new notation store in
`Infrastructure/Game/`, `Presentation/Settings/SettingsView.swift`; remaining display call sites
to be enumerated in the design spec.

## 2026-09-06 — Deliver the notation choice as observed state, not a hidden global
**Choice:** The notation preference flows to the UI as a parameter: `displayName(style:)` on
`NoteName`/`Note`/`ChordNaming`, with a `NotationSettings` ObservableObject injected via the
environment (views) and the DI container (TunerViewModel, DrillViewModel). Roughly a dozen
call sites change by one line each; the no-argument `displayName` stays as the `.letters`
default. Long form: `docs/superpowers/specs/2026-09-06-notation-style-design.md`.

**Why:** SwiftUI re-renders only on tracked dependencies. The call-site edits are what register
the dependency, so every screen flips the moment the Settings picker changes. The chord screens
behind `AppTab.shippingTabs` are converted too — they are compiled, tested, and one line from
shipping, so skipping them plants a bug that detonates at reveal.

**Considered:** Having `displayName` read a global `NotationStyle.current` was rejected despite
being the smallest diff: the read is invisible to SwiftUI, so continuously-updating screens
(tuner) would flip while static ones kept letters — the app disagreeing with itself. A
`NoteNameFormatting` protocol through the DI container was rejected as more files and churn for
identical behavior.

**Prompted by:** The "do re mi" display feature (entry above) needed a route from the stored
preference to twelve render sites without touching game logic.

**Touches:** `Domain/Models/Note.swift`, `Domain/Models/NotationStyle.swift` (new),
`Domain/UseCases/ChordNaming.swift`, `Infrastructure/Game/NotationStyleStore.swift` (new),
`Presentation/Settings/NotationSettings.swift` (new), `SettingsView`, `ContentView`,
`DrillView`, `DrillViewModel`, `TunerViewModel`, `ChordSuggesterView`, `ChordProgressionView`,
`DI/AppDependencyContainer.swift`.

## 2026-09-20 — Mix touch-mode game sounds over other apps' audio with `.ambient`
**Choice:** Touch mode configures the shared `AVAudioSession` with the `.ambient` category so
combo dings layer over whatever the user is already playing (Spotify, Apple Music) instead of
pausing it. Mic-driven paths (tuner, guitar drill) keep `.playAndRecord` untouched — recording
legitimately owns the session there.
**Why:** Today touch mode never configures the session, so the first `AVAudioPlayer.play()`
implicitly activates it under the default `.soloAmbient`, a non-mixable category whose
activation tells iOS to pause other apps' audio. `.ambient` is the mixable sibling built
exactly for game feedback sounds, and it obeys the ring/silent switch — a muted phone stays
quiet, which matches user expectations for a game.
**Considered:** `.playback` + `.mixWithOthers` also mixes but ignores the silent switch, so
dings would sound on a muted phone; that suits apps whose audio is the product, not feedback
blips. Doing nothing per-mode (one app-wide `.ambient` at launch) fails once the tuner runs,
because categories are sticky and the session would stay `.playAndRecord` afterwards.
**Prompted by:** Playing touch-mode drills while listening to music kills the music on the
first correct-answer ding, reported 2026-09-20.
**Touches:** Touch-mode session configuration (placement under design — likely
`Infrastructure/Input/TouchInputSource.swift`), leaving
`Infrastructure/Audio/AudioKitPitchAdapter.swift` and `ComboSoundPlayer.swift` behavior intact.
