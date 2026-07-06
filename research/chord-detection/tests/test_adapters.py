import numpy as np
import soundfile as sf

from chordsweep.adapters import (
    FolderAdapter,
    SyntheticAdapter,
    parse_label_id,
    synth_chord,
)
from chordsweep.features import get_feature
from chordsweep.labels import ChordLabel


def test_synth_chord_has_expected_chroma():
    label = ChordLabel("C", "maj")
    audio = synth_chord(label, sr=22050, seconds=1.0)
    chroma = get_feature("chroma_stft")(audio, 22050)
    top3 = set(int(i) for i in np.argsort(chroma)[-3:])
    assert top3 == {0, 4, 7}


def test_synthetic_adapter_yields_labeled_clips():
    labels = [ChordLabel("C", "maj"), ChordLabel("G", "dom7")]
    clips = list(SyntheticAdapter(labels).clips())
    assert len(clips) == 2
    assert {clip.label.id for clip in clips} == {"C:maj", "G:dom7"}
    assert all(clip.source == "synthetic" for clip in clips)


def test_parse_label_id_convention():
    assert parse_label_id("Cs-min7_001.wav") == ChordLabel("C#", "min7")
    assert parse_label_id("G-maj_take2.wav") == ChordLabel("G", "maj")


def test_folder_adapter_reads_labeled_wavs(tmp_path):
    sr = 22050
    audio = synth_chord(ChordLabel("C", "maj"), sr=sr)
    sf.write(tmp_path / "C-maj_001.wav", audio, sr)
    sf.write(
        tmp_path / "G-dom7_001.wav", synth_chord(ChordLabel("G", "dom7"), sr=sr), sr
    )
    clips = list(FolderAdapter(tmp_path).clips())
    assert {clip.label.id for clip in clips} == {"C:maj", "G:dom7"}
    assert all(clip.source == "folder" for clip in clips)
