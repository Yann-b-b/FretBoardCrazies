# App Review notes

The notes themselves live in [`review-notes.txt`](review-notes.txt) — that file is the single copy.
Paste it, do not retype it, and do not paste this file: the App Store Connect field is plain text and
renders Markdown syntax literally.

```bash
pbcopy < docs/store/review-notes.txt
```

The field caps at **4000 characters** and the current text is **3976**, so check before pasting if
you add anything:

```bash
python3 -c "import pathlib; t=pathlib.Path('docs/store/review-notes.txt').read_text(); print(len(t), 4000-len(t))"
```

## The device line

Item 2 and item 1 both name **iPhone 17 on iOS 26.6**. Keep them in step: Apple checks the stated
device against the screen recording, and a mismatch turns an information request into a credibility
problem. If you record on a different phone, change both lines.

## Responding to a Guideline 2.1 "Information Needed" rejection

This is not a bug report and not a metadata violation. It is Apple asking for the review package up
front, and it is close to routine for a first submission from a new account. **No new build and no
new build number are required** — the binary was never the objection.

1. Run the app on a physical iPhone and screen-record it (see below).
2. Check the device line in `review-notes.txt` still matches the phone you recorded on.
3. Paste the file into **App Review Information → Notes** on the version page, replacing what is
   there. This is what Apple means by "include this information for future submissions" — it carries
   forward to every later version.
4. Go to **Resolution Center**, attach the recording, and reply. Answer in the same 1–7 order Apple
   used so the reviewer can tick them off; say the notes field has been updated with the same text.
5. Replying returns the app to the review queue on its own. Do not resubmit and do not upload a new
   build.

### The screen recording

Apple is specific: a **physical device**, **current iOS**, starting from launch.

- Install to your iPhone from Xcode, or via TestFlight.
- Control Centre → Screen Recording. Keep it under about two minutes.
- Cover, in order: launch → welcome screen → tap **"I'm playing an instrument"** so the microphone
  permission prompt is on camera → the drill answering a prompt → back to welcome → tap **"I'll tap
  the fretboard"** → answer a prompt by tapping → Progress → Tuner → Settings.
- Showing **both** input modes is the point. It answers the permission-prompt question in item 1 and
  pre-empts a reviewer who has no guitar, which is the app's main standing rejection risk.

## What the seven answers commit us to

These are checkable claims. If any stops being true, the notes must change in the same commit as the
code:

| Claim | Verify with |
|---|---|
| No network requests of any kind | `grep -rn --include="*.swift" "URLSession\|NWConnection" audio_listen/` returns nothing |
| Only AudioKit and SoundpipeAudioKit are linked | `XCRemoteSwiftPackageReference` entries in `project.pbxproj` |
| No accounts, IAP, subscriptions, ads, or user content | none present in the target |
| 75/25 prompt split | `nameNoteProbability: Double = 0.25` in `SelectNextPromptUseCase` |
| Guitar and bass only | `Instruments.all` |
| Minimum iOS 18.2 | `IPHONEOS_DEPLOYMENT_TARGET` |
| Four screens ship | `ReleaseScope.shippingTabs` |
