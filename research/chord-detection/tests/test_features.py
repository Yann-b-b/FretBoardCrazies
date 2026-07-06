import numpy as np

from chordsweep.features import feature_names, get_feature


def _triad_tone(freqs, sr=22050, seconds=1.0):
    t = np.linspace(0.0, seconds, int(sr * seconds), endpoint=False)
    audio = sum(np.sin(2.0 * np.pi * f * t) for f in freqs)
    return (audio / np.max(np.abs(audio))).astype(np.float32)


def test_registry_lists_all_features():
    assert set(feature_names()) == {"chroma_stft", "chroma_cqt", "mfcc"}


def test_chroma_outputs_normalized_12_vector():
    sr = 22050
    audio = _triad_tone([261.63, 329.63, 392.00], sr)
    for name in ("chroma_stft", "chroma_cqt"):
        vec = get_feature(name)(audio, sr)
        assert vec.shape == (12,)
        assert abs(float(np.linalg.norm(vec)) - 1.0) < 1e-6


def test_chroma_stft_c_major_energy_in_c_e_g():
    sr = 22050
    audio = _triad_tone([261.63, 329.63, 392.00], sr)
    vec = get_feature("chroma_stft")(audio, sr)
    top3 = set(int(i) for i in np.argsort(vec)[-3:])
    assert {0, 4, 7} == top3


def test_mfcc_shape_and_determinism():
    sr = 22050
    audio = _triad_tone([261.63, 329.63, 392.00], sr)
    a = get_feature("mfcc")(audio, sr)
    b = get_feature("mfcc")(audio, sr)
    assert a.shape == (13,)
    assert np.allclose(a, b)
