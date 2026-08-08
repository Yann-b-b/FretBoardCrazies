# App Review notes

Paste the section below into App Review Information → Notes in App Store Connect.

No demo account is needed — the app has no sign-in.

---

## You do not need a guitar to test this app

FretBoard Crazies normally listens through the microphone to hear the notes you play. If you do not
have an instrument to hand, the welcome screen offers a second way in:

1. Launch the app.
2. On the welcome screen, tap **"I'll tap the fretboard"** (the second button).
3. The drill now accepts taps directly on the on-screen fretboard. Tap the fret the prompt asks for.

You can switch between the two at any time in **Settings › Game › Touch mode**, or by relaunching
and choosing the other button.

## Microphone

The microphone permission prompt appears only if you choose "I'm playing an instrument". Audio is
analysed on-device in real time to detect pitch. It is never recorded, stored, or transmitted. The
app makes no network requests of any kind, which is why the privacy declaration reports no data
collection.

If you decline the permission, the app shows an explanatory notice with a button into system
Settings rather than failing silently.

## Orientation

The app is landscape-only on both iPhone and iPad. A fretboard is a wide object; portrait would
either shrink it below usability or crop it.

## What is in this build

Four screens: **Drill** (find the prompted note on the fretboard), **Progress** (accuracy, streaks,
and belt rank), **Tuner** (live pitch and tuning readout), and **Settings**.
