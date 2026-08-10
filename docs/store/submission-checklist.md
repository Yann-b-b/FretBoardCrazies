# Submission checklist — v1.1.0

Work top to bottom. Steps 1–3 happen outside this repository; 4 onward are commands here.

## 0. Already done

- [x] Bundle identifier `com.yannbaglinbunod.fretboardcrazies`, display name, device family
- [x] Microphone usage string, export-compliance key (`ITSAppUsesNonExemptEncryption = NO`)
- [x] Privacy manifest declaring no tracking and no collected data
- [x] App icon, 1024×1024, **no alpha channel** (a silent rejection cause when wrong)
- [x] Microphone-denial handling with a route into system Settings
- [x] A way into the app that needs no instrument, stated in the review notes
- [x] Privacy policy and support pages live and returning 200
- [x] Unit tests green on macOS and iOS; Release build for device succeeds

## 1. Apple Developer Program membership

Publishing requires the **paid** membership — $99/year, at
[developer.apple.com/programs](https://developer.apple.com/programs/).

A free Apple ID gives you a personal team that can build to your own device but **cannot submit to
the App Store**. The project already carries `DEVELOPMENT_TEAM = M8T92F2RKH`; confirm at
[developer.apple.com/account](https://developer.apple.com/account) that it shows an active paid
membership rather than "Personal Team".

Enrolment as an individual is usually approved within 48 hours. As an organisation it needs a D-U-N-S
number and takes longer.

## 2. Register the bundle identifier

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+**

- Type: App IDs → App
- Bundle ID: **Explicit** → `com.yannbaglinbunod.fretboardcrazies`
- Capabilities: none needed. The app uses only the microphone, which is a usage-string permission
  rather than a capability.

This identifier is permanent. It cannot be renamed or reused later.

## 3. Create the App Store Connect record

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+** → New App

| Field | Value |
|---|---|
| Platform | iOS |
| Name | FretBoard Crazies |
| Primary language | English (U.S.) |
| Bundle ID | `com.yannbaglinbunod.fretboardcrazies` |
| SKU | `fretboardcrazies-ios` (internal only, never shown) |
| User access | Full Access |

The **name must be unique across the entire App Store**. If it is taken, you find out here, and the
fallback is a variant like "FretBoard Crazies: Note Trainer".

## 4. Cut the release

```bash
python3 scripts/release.py 1.1.0 --verify
```

Runs the unit suite on macOS and an iOS simulator, merges `dev` into `main`, bumps
`MARKETING_VERSION` to 1.1.0 and the build number to 3, writes the changelog, and tags `v1.1.0`. It
opens `$EDITOR` for you to curate the release notes.

Then publish the branch and tag — this also deploys the privacy and support pages:

```bash
git push origin main --tags
```

## 5. Capture screenshots

```bash
python3 scripts/capture_screenshots.py
```

Boots each simulator, installs a Release build, and prompts you to navigate to each screen before
capturing. Both sets are **landscape**, since the app pins landscape.

- 6.9" iPhone — 2868 × 1320
- 13" iPad — 2064 × 2752

Output lands in `build/screenshots/`. Five shots per device: drill, correct answer, progress, tuner,
settings.

## 6. Signing

Three pieces must line up. Only the middle one is yours to create.

| Piece | What it is | Made by |
|---|---|---|
| Apple Distribution certificate | Identifies you as the signer; the private key lives in this Mac's Keychain | Xcode, on demand |
| App ID | The registered bundle identifier from step 2 | You, in the portal |
| App Store provisioning profile | Binds the certificate to the App ID | Xcode, on demand |

The project is set to `CODE_SIGN_STYLE = Automatic` with `DEVELOPMENT_TEAM = M8T92F2RKH`, so Xcode
issues the distribution certificate and profile the first time you distribute. Do not create them by
hand.

Before archiving, check **Xcode → Settings → Accounts**: the team must read as a paid membership,
not "(Personal Team)". Enrolment can take an hour to propagate; the refresh arrow forces a re-check.

An `Apple Development` certificate is not enough to submit — that one only builds to your own
devices. `Apple Distribution` is the one the App Store requires.

**Moving machines later:** the certificate is useless without its private key. Export it from
Keychain Access as a `.p12` before you migrate, or you will burn one of the two Apple Distribution
certificates Apple allows per account.

## 7. Archive and upload

The scripted path:

```bash
python3 scripts/release.py 1.1.0 --archive
```

Writes an `.xcarchive` and exports an `.ipa` to `build/v1.1.0/`. Upload it with **Transporter**
(free, Mac App Store).

This step has never run against a live signing certificate. Expect to resolve provisioning on the
first attempt — that is normal, not a sign anything is wrong.

The GUI path, which explains its errors far better and is the better choice for a first submission:

1. **Product → Destination → Any iOS Device (arm64).** Archive stays greyed out while a simulator is
   selected, which is a confusing five minutes if you do not know why.
2. **Product → Archive.**
3. Organizer → **Distribute App → App Store Connect → Upload.**

Either way, App Store Connect takes 10–30 minutes to process the upload before the build becomes
selectable. It is not stuck.

## 8. Fill in the listing

Copy is written and ready in [`description.md`](description.md).

- [ ] Subtitle, promotional text, description, keywords
- [ ] Category: Education (primary), Music (secondary)
- [ ] Screenshots from step 5
- [ ] Privacy Policy URL — `https://yann-b-b.github.io/FretBoardCrazies/privacy/`
- [ ] Support URL — `https://yann-b-b.github.io/FretBoardCrazies/support/`
- [ ] Age rating questionnaire → answer No to everything → 4+
- [ ] App Privacy → **Data Not Collected** → No to every data type
- [ ] Select build 3
- [ ] App Review Information → paste [`review-notes.md`](review-notes.md). No demo account needed.

## 9. Submit

Submit for Review. First reviews typically take 24–48 hours.

If it comes back rejected, that is routine for a first submission and usually a metadata fix rather
than a code change. Read the exact guideline number they cite, fix that one thing, and resubmit —
each resubmission needs a new build number only if you changed the binary.

## Most likely rejection causes, in order

1. **Reviewer cannot get past the drill.** Mitigated by the welcome-screen fork and the review notes,
   which is why those notes lead with it. If it still happens, reply in Resolution Center pointing at
   the second button — do not resubmit blind.
2. **A dead privacy-policy or support URL.** Both return 200 today; re-check right before submitting.
3. **Screenshots that do not match the app.** Do not add marketing frames or text that show features
   the four-tab build does not have.
