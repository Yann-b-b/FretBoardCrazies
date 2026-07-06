from pathlib import Path

import librosa
import numpy as np

from chordsweep.labels import ChordClip, ChordLabel

_A4_MIDI = 69
_C4_MIDI = 60


def synth_chord(label, sr=22050, seconds=1.0):
    t = np.linspace(0.0, seconds, int(sr * seconds), endpoint=False)
    audio = np.zeros_like(t)
    for pitch_class in label.pitch_classes():
        midi = _C4_MIDI + pitch_class
        freq = 440.0 * (2.0 ** ((midi - _A4_MIDI) / 12.0))
        audio = audio + np.sin(2.0 * np.pi * freq * t)
    peak = np.max(np.abs(audio))
    return (audio / peak if peak > 0 else audio).astype(np.float32)


def parse_label_id(filename):
    stem = Path(filename).name.split("_", 1)[0]
    root_part, quality = stem.split("-", 1)
    root = root_part.replace("s", "#")
    return ChordLabel(root, quality)


class SyntheticAdapter:
    name = "synthetic"

    def __init__(self, labels, sr=22050):
        self._labels = list(labels)
        self._sr = sr

    def clips(self):
        for label in self._labels:
            yield ChordClip(
                audio=synth_chord(label, self._sr),
                sample_rate=self._sr,
                label=label,
                source="synthetic",
            )


class FolderAdapter:
    name = "folder"

    def __init__(self, root, sr=22050):
        self._root = Path(root)
        self._sr = sr

    def clips(self):
        for path in sorted(self._root.glob("*.wav")):
            label = parse_label_id(path.name)
            audio, _ = librosa.load(path, sr=self._sr, mono=True)
            yield ChordClip(
                audio=audio.astype(np.float32),
                sample_rate=self._sr,
                label=label,
                source="folder",
            )


class MirdataAdapter:
    name = "mirdata"

    def __init__(self, dataset_name, data_home=None, sr=22050, quality_map=None):
        import mirdata

        self._dataset = mirdata.initialize(dataset_name, data_home=data_home)
        self._sr = sr
        self._quality_map = quality_map or {}

    def clips(self):
        dropped = 0
        for track in self._dataset.load_tracks().values():
            chords = getattr(track, "chords", None)
            audio_path = getattr(track, "audio_mic_path", None) or getattr(
                track, "audio_path", None
            )
            if chords is None or audio_path is None:
                continue
            audio, _ = librosa.load(audio_path, sr=self._sr, mono=True)
            for start, end, chord_id in zip(
                chords.intervals[:, 0], chords.intervals[:, 1], chords.labels
            ):
                label = self._to_label(chord_id)
                if label is None:
                    dropped += 1
                    continue
                segment = audio[int(start * self._sr) : int(end * self._sr)]
                if segment.size == 0:
                    continue
                yield ChordClip(
                    audio=segment.astype(np.float32),
                    sample_rate=self._sr,
                    label=label,
                    source=f"mirdata:{self._dataset.name}",
                )
        if dropped:
            print(f"MirdataAdapter dropped {dropped} unmapped-quality segments")

    def _to_label(self, chord_id):
        if chord_id in self._quality_map:
            root, quality = self._quality_map[chord_id]
            return ChordLabel(root, quality)
        if ":" in chord_id:
            root, harte = chord_id.split(":", 1)
            quality = {
                "maj": "maj",
                "min": "min",
                "7": "dom7",
                "maj7": "maj7",
                "min7": "min7",
            }.get(harte)
            if quality is not None:
                try:
                    return ChordLabel(root, quality)
                except ValueError:
                    return None
        return None
