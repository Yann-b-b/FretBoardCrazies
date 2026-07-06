import numpy as np
import pytest

from chordsweep.labels import ChordClip, ChordLabel, normalize_pitch_class


def test_cm7_pitch_classes():
    assert ChordLabel("C", "min7").pitch_classes() == [0, 3, 7, 10]


def test_g_dom7_pitch_classes_wrap():
    assert ChordLabel("G", "dom7").pitch_classes() == [2, 5, 7, 11]


def test_enharmonic_normalizes_to_sharp():
    assert normalize_pitch_class("Bb") == "A#"
    assert ChordLabel("Eb", "min").root == "D#"


def test_id_format():
    assert ChordLabel("G", "dom7").id == "G:dom7"


def test_unknown_root_and_quality_raise():
    with pytest.raises(ValueError):
        ChordLabel("H", "maj")
    with pytest.raises(ValueError):
        ChordLabel("C", "septachord")


def test_chord_clip_holds_fields():
    clip = ChordClip(
        audio=np.zeros(4, dtype=np.float32),
        sample_rate=22050,
        label=ChordLabel("C", "maj"),
        source="unit",
    )
    assert clip.sample_rate == 22050
    assert clip.label.id == "C:maj"
    assert clip.source == "unit"
