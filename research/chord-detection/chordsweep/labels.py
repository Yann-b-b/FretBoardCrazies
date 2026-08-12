from dataclasses import dataclass, field

import numpy as np

PITCH_CLASSES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

_PC_INDEX = {name: i for i, name in enumerate(PITCH_CLASSES)}

_ENHARMONIC = {
    "Db": "C#",
    "Eb": "D#",
    "Fb": "E",
    "Gb": "F#",
    "Ab": "G#",
    "Bb": "A#",
    "Cb": "B",
    "E#": "F",
    "B#": "C",
}

QUALITY_INTERVALS = {
    "maj": [0, 4, 7],
    "min": [0, 3, 7],
    "dom7": [0, 4, 7, 10],
    "maj7": [0, 4, 7, 11],
    "min7": [0, 3, 7, 10],
    "6": [0, 4, 7, 9],
    "min6": [0, 3, 7, 9],
    "sus4": [0, 5, 7],
    "sus2": [0, 2, 7],
    "dim": [0, 3, 6],
    "aug": [0, 4, 8],
}


def normalize_pitch_class(name):
    name = name.strip()
    if name in _PC_INDEX:
        return name
    if name in _ENHARMONIC:
        return _ENHARMONIC[name]
    raise ValueError(f"unknown pitch class: {name}")


@dataclass(frozen=True)
class ChordLabel:
    root: str
    quality: str

    def __post_init__(self):
        object.__setattr__(self, "root", normalize_pitch_class(self.root))
        if self.quality not in QUALITY_INTERVALS:
            raise ValueError(f"unknown quality: {self.quality}")

    @property
    def id(self):
        return f"{self.root}:{self.quality}"

    def pitch_classes(self):
        base = _PC_INDEX[self.root]
        return sorted(
            {(base + interval) % 12 for interval in QUALITY_INTERVALS[self.quality]}
        )


@dataclass
class ChordClip:
    audio: np.ndarray
    sample_rate: int
    label: ChordLabel
    source: str = field(default="unknown")
