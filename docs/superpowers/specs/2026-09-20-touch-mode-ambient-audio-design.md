# Touch-mode dings must mix over background music

**Date:** 2026-09-20
**Decision log entry:** `docs/decisions.md` — "Mix touch-mode game sounds over other apps' audio with `.ambient`"

## Problem

In touch mode, the first combo ding pauses whatever the user is listening to
(Spotify, Apple Music). The app never configures its `AVAudioSession` on the
touch path — `TouchInputSource.start()` is empty — so the session sits on the
system default category, `.soloAmbient`. When the first
`AVAudioPlayer.play()` in `ComboSoundPlayer` implicitly activates the session,
iOS reads that non-mixable category and pauses every other app's audio. The
ding is innocent; the activation under a non-mixable category is the killer.

The mic paths are not implicated: `AudioKitPitchAdapter.start()` explicitly
sets `.playAndRecord` (line 42), which legitimately owns the session while
recording.

## Change

One edit, in `audio_listen/Infrastructure/Input/TouchInputSource.swift`: fill
in the empty `start()` body so touch mode declares the session it needs, the
same way the mic adapter already declares its own.

```swift
import AVFoundation

func start() throws {
    #if os(iOS)
    try AVAudioSession.sharedInstance().setCategory(.ambient)
    #endif
}
```

`.ambient` is the mixable sibling of `.soloAmbient`: dings layer over other
apps' audio, and the ring/silent switch is respected (a muted phone stays
quiet — chosen deliberately over `.playback` + `.mixWithOthers`, which would
sound on a muted phone).

Nothing else changes. `DrillViewModel` already calls `try input.start()`
polymorphically via the `NoteInputSource` protocol; `AppDependencyContainer`
already picks `TouchInputSource` when touch mode is on; `ComboSoundPlayer`
and both mic paths stay untouched. After this change neither mode relies on
the default category — every input source asserts its own.

## Why this placement holds up

`setCategory` is sticky: a tuner visit sets `.playAndRecord` and it stays set.
`input.start()` runs once per `DrillViewModel` lifetime (guarded by
`engineStarted`, `DrillViewModel.swift:188`, never reset), and that lifetime
is one drill-screen visit — the iOS root swaps whole screens per tab
(`ContentView.swift:18`) and `DrillView` owns the view model as
`@StateObject`. A tuner detour therefore destroys the drill view model, and
returning builds a fresh one whose first round re-asserts `.ambient`. The
tuner stops its mic engine on disappear (`TunerView.swift:63`). Toggling
touch mode in Settings also rebuilds the view (`.id` on `ContentView.swift:44`).

Rejected placements: once at app launch (broken by the sticky category after
any tuner visit); inside `ComboSoundPlayer` (session policy in a
presentation-layer sound effect, `setCategory` on every ding, and it cannot
know the input mode — it also plays in mic mode, where it must not clobber
`.playAndRecord`).

## Error handling

`setCategory` throws; `start()` already `throws` and
`DrillViewModel.startListening()` already surfaces failures as
`errorMessage`. No new handling needed.

## Testing

`AVAudioSession` behavior is not meaningfully unit-testable; existing tests
must stay green (`TouchInputSource.start()` remains a no-op off-iOS thanks to
the `#if os(iOS)` guard). Verification is manual, on the physical test
device:

1. Play music, enter a touch-mode drill, answer correctly — music continues
   through the dings.
2. Visit the tuner (music pauses — expected, mic owns the session), return to
   the drill, start a round — dings mix again.
3. Flip the silent switch — dings go quiet, music unaffected.
4. Guitar (mic) drill and tuner behave exactly as before.
