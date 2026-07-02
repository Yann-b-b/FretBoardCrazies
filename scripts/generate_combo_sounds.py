import os
import wave

import numpy as np

SAMPLE_RATE = 44100


def _note_hz(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))


def _envelope(length):
    t = np.linspace(0.0, 1.0, length, dtype=np.float32)
    attack = np.clip(t / 0.05, 0.0, 1.0)
    decay = np.exp(-3.5 * t)
    return (attack * decay).astype(np.float32)


def _render(semitone_sequence, note_seconds, harmonics):
    chunks = []
    for semitone in semitone_sequence:
        length = int(SAMPLE_RATE * note_seconds)
        t = np.arange(length, dtype=np.float32) / SAMPLE_RATE
        freq = _note_hz(semitone)
        tone = np.zeros(length, dtype=np.float32)
        for multiple, amplitude in harmonics:
            tone += amplitude * np.sin(2.0 * np.pi * freq * multiple * t)
        chunks.append(tone * _envelope(length))
    samples = np.concatenate(chunks)
    peak = float(np.max(np.abs(samples))) or 1.0
    return (samples / peak * 0.9).astype(np.float32)


WARM = [(1.0, 1.0), (2.0, 0.4), (3.0, 0.15)]
BRIGHT = [(1.0, 1.0), (2.0, 0.6), (3.0, 0.35), (4.0, 0.2)]

C5, E5, G5, C6, E6 = 3, 7, 10, 15, 19

CUES = {
    "combo-hit-1": ([C5], 0.16, WARM),
    "combo-hit-2": ([C5, E5], 0.13, WARM),
    "combo-hit-3": ([C5, E5, G5], 0.12, WARM),
    "combo-hit-4": ([C5, E5, G5, C6], 0.11, BRIGHT),
    "combo-tierup-2": ([C5, E5, G5], 0.16, WARM),
    "combo-tierup-3": ([C5, E5, G5, C6], 0.15, BRIGHT),
    "combo-tierup-4": ([C5, E5, G5, C6, E6], 0.14, BRIGHT),
}

CUE_NAMES = list(CUES.keys())


def _write_wav(path, samples):
    data = (samples * 32767.0).astype(np.int16)
    with wave.open(path, "w") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(SAMPLE_RATE)
        writer.writeframes(data.tobytes())


def generate(output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for name, (sequence, note_seconds, harmonics) in CUES.items():
        samples = _render(sequence, note_seconds, harmonics)
        _write_wav(os.path.join(output_dir, f"{name}.wav"), samples)


def main():
    output_dir = os.path.join(os.path.dirname(__file__), "..", "audio_listen", "Sounds")
    generate(output_dir)


if __name__ == "__main__":
    main()
