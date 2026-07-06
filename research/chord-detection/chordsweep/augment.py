import numpy as np

from chordsweep.labels import ChordClip


def augment_clip(clip, rng):
    variants = [clip]
    noise = clip.audio + 0.01 * rng.standard_normal(clip.audio.shape).astype(np.float32)
    variants.append(
        ChordClip(
            audio=noise.astype(np.float32),
            sample_rate=clip.sample_rate,
            label=clip.label,
            source=clip.source + "+noise",
        )
    )
    gain = (clip.audio * 0.6).astype(np.float32)
    variants.append(
        ChordClip(
            audio=gain,
            sample_rate=clip.sample_rate,
            label=clip.label,
            source=clip.source + "+gain",
        )
    )
    return variants
