import wave

from generate_combo_sounds import CUE_NAMES, generate


def test_generates_all_cues_nonempty(tmp_path):
    generate(str(tmp_path))
    for name in CUE_NAMES:
        path = tmp_path / f"{name}.wav"
        assert path.exists()
        with wave.open(str(path)) as reader:
            assert reader.getnframes() > 0
            assert reader.getframerate() == 44100
