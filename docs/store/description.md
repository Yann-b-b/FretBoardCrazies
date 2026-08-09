# App Store listing copy

Character limits are Apple's. Counts below are for the text as written.

## Name (30 max)

```
FretBoard Crazies
```

## Subtitle (30 max)

```
Learn the fretboard by ear
```

## Promotional text (170 max, editable without review)

```
Every note on the neck, drilled until you find it without thinking. Play it on your instrument and
the app hears you — or tap the fretboard if you're practising away from your guitar.
```

## Description (4000 max)

```
Most guitarists learn shapes. Very few learn the neck.

FretBoard Crazies drills the fretboard one note at a time until finding any note anywhere becomes
instant. It asks for a note on a string. You play it. The app listens through the microphone and
tells you whether you got it — no tapping, no guessing, no looking away from your instrument.

LEARN BY PLAYING, NOT BY TAPPING
Pitch detection runs live on your device. Play the note the drill asks for and it knows. That closes
the loop between the name of a note and the physical act of finding it, which is the part that
actually transfers to playing music.

NO GUITAR? NO PROBLEM
Practising on a train, or away from your instrument? Choose "I'll tap the fretboard" on the welcome
screen and answer by tapping the fret instead. Same drills, same progress.

BUILT-IN TUNER
A live tuner with note name, frequency, and signal readout. Tune up without leaving the app.

PROGRESS THAT MEANS SOMETHING
Track accuracy and reaction time per note and per string. Build combos for fast, correct answers.
Climb the belt ranks from white to black as your recall gets sharper. The progress screen shows you
exactly which notes you still hesitate on.

PRACTISE WHAT YOU CHOOSE
Pick which strings to drill. Limit targets to the first twelve frets while you're learning, then
open up the whole neck. Turn on a countdown if you want the pressure. Switch between guitar and
bass — progress is tracked separately for each.

PRIVATE BY DESIGN
No account. No ads. No analytics. No network connections at all. Microphone audio is analysed on
your device in real time to work out pitch, and is never recorded, stored, or sent anywhere. Your
progress stays on your device.

Requires iOS 18.2 or later. Landscape orientation. Pitch detection works best on one clear note at a
time.
```

## Keywords (100 max, comma-separated, no spaces)

```
guitar,fretboard,notes,ear,training,tuner,bass,practice,music,theory,neck,memorize,drill,scales
```

## Category

Primary: **Education**
Secondary: **Music**

## Age rating

4+. No objectionable content, no user-generated content, no web access, no in-app purchases.

## App Privacy declaration

**Data Not Collected.** Answer "No" to every data-type question. This is accurate — the app makes no
network requests, and the microphone stream is analysed on-device and discarded.

## URLs

Both are mandatory in App Store Connect. They are served by GitHub Pages from `site/`, deployed by
`.github/workflows/pages.yml` on pushes to `main`.

| Field | URL | Source of copy |
|---|---|---|
| Privacy Policy URL | `https://yann-b-b.github.io/FretBoardCrazies/privacy/` | `docs/store/privacy-policy.md` → `site/privacy/index.html` |
| Support URL | `https://yann-b-b.github.io/FretBoardCrazies/support/` | `docs/store/support.md` → `site/support/index.html` |

The Markdown under `docs/store/` is the canonical copy and `site/` is its published rendering. Edit
both together, or the live pages drift from the source.

## Screenshots

Required, **landscape** (the app pins landscape on both idioms):

- 6.9" iPhone — 2868 × 1320 or 1320 × 2868
- 13" iPad — 2064 × 2752 or 2752 × 2064

Suggested order, one message per shot:

1. **Drill mid-prompt** — the ask is legible, the fretboard fills the frame
2. **Correct answer revealed** — string and fret shown, combo flame visible
3. **Progress** — belt rank and per-note accuracy
4. **Tuner** — live needle and note name
5. **Settings** — instrument picker and touch mode, showing the app adapts

Capture with `python3 scripts/capture_screenshots.py`.
