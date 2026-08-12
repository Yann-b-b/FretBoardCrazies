import numpy as np

from chordsweep.adapters import SyntheticAdapter
from chordsweep.augment import augment_clip
from chordsweep.labels import ChordClip, ChordLabel
from chordsweep.sweep import METHODS, run_sweep


def test_augment_returns_original_plus_variants():
    clip = ChordClip(
        audio=np.ones(1000, dtype=np.float32),
        sample_rate=22050,
        label=ChordLabel("C", "maj"),
        source="x",
    )
    out = augment_clip(clip, np.random.default_rng(0))
    assert len(out) >= 2
    assert out[0].label.id == "C:maj"
    assert all(c.sample_rate == 22050 for c in out)


def test_methods_registry_has_chroma_template_and_knn():
    assert "chroma_stft+template" in METHODS
    assert "chroma_stft+knn" in METHODS


def test_run_sweep_on_synthetic_writes_report(tmp_path):
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min"), ChordLabel("G", "dom7")]
    train = list(SyntheticAdapter(labels, sr=22050).clips())
    test = list(SyntheticAdapter(labels, sr=22050).clips())
    results = run_sweep(train, test, ["chroma_stft+template"], tmp_path, augment=False)
    assert "chroma_stft+template" in results
    assert results["chroma_stft+template"].accuracy == 1.0
    assert (tmp_path / "summary.csv").exists()
    assert (tmp_path / "chroma_stft+template_confusion.png").exists()
