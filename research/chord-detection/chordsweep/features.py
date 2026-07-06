import librosa
import numpy as np

_REGISTRY = {}


def register_feature(name):
    def decorator(fn):
        _REGISTRY[name] = fn
        return fn

    return decorator


def get_feature(name):
    return _REGISTRY[name]


def feature_names():
    return sorted(_REGISTRY)


def _normalize(vector):
    norm = float(np.linalg.norm(vector))
    return vector / norm if norm > 0.0 else vector


@register_feature("chroma_stft")
def _chroma_stft(audio, sr):
    frames = librosa.feature.chroma_stft(y=audio, sr=sr)
    return _normalize(frames.mean(axis=1))


@register_feature("chroma_cqt")
def _chroma_cqt(audio, sr):
    frames = librosa.feature.chroma_cqt(y=audio, sr=sr)
    return _normalize(frames.mean(axis=1))


@register_feature("mfcc")
def _mfcc(audio, sr):
    frames = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=13)
    return _normalize(frames.mean(axis=1))
