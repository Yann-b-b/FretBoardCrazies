# Chord-Detection Sweep Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dataset- and method-adaptable Python harness (`research/chord-detection/`) that benchmarks chord-detection pipelines and emits a ranked comparison (confusion matrix + false-accept/false-reject curves) to choose a chord-*type* verifier for the app.

**Architecture:** Two swappable seams (a `DatasetAdapter` yielding typed `ChordClip`s; a method = feature-function × classifier, both in name registries) around one frozen evaluation protocol. Pure-logic core (labels, templates, metrics) is unit-tested; dataset downloads are manual experiments.

**Tech Stack:** Python ≥3.11, `uv`, `pytest`, `ruff`; `numpy`, `librosa`, `scikit-learn`, `mirdata`, `audiomentations`, `matplotlib`, `soundfile`.

## Global Constraints

- **Self-contained under `research/chord-detection/`** with its own `uv` project — isolated from the iOS app; not part of the Xcode build.
- **No comments, no docstrings** — self-documenting names (matches repo `scripts/*.py` style). No unused imports (ruff F401).
- **Harness module layout, not the pipeline `src/<stage>/run()` convention** — this is a benchmark library; its natural units are labels / features / classifiers / evaluate / adapters / sweep.
- **Labels are `root:quality`** (chord *type* only; root string is not modeled here). Qualities in scope: `maj, min, dom7, maj7, min7, 6, min6, sus4, sus2, dim, aug`.
- **Verification metrics are first-class:** every method emits a confusion matrix AND a false-accept-rate/false-reject-rate curve over an acceptance threshold.
- **Held-out discipline:** train/prototype clips and test clips never overlap; test clips are never augmented. Synthetic clips are never the test set.
- **Commands** (run from `research/chord-detection/`):
  - Install: `uv sync`
  - Test: `uv run pytest -q`
  - Lint/format: `uv run ruff check .` and `uv run ruff format .`

---

## File Structure (all under `research/chord-detection/`)

| File | Responsibility |
|---|---|
| `pyproject.toml` | isolated `uv` project + deps |
| `chordsweep/__init__.py` | package marker (empty) |
| `chordsweep/labels.py` | `ChordLabel`, `ChordClip`, chord→pitch-class theory |
| `chordsweep/features.py` | feature registry: chroma-STFT, chroma-CQT, MFCC |
| `chordsweep/classifiers.py` | `TemplateMatch`, `KNN`; theory template vectors |
| `chordsweep/evaluate.py` | featurize, metrics (accuracy/confusion/precision/recall), FAR-FRR curve |
| `chordsweep/adapters.py` | `FolderAdapter`, `SyntheticAdapter`, `MirdataAdapter` |
| `chordsweep/augment.py` | optional augmentation pipeline |
| `chordsweep/sweep.py` | config-driven runner → CSV + plots (CLI) |
| `tests/` | pytest over the pure logic |

---

## Task 1: Project scaffold + labels/theory

**Files:**
- Create: `research/chord-detection/pyproject.toml`, `research/chord-detection/chordsweep/__init__.py`, `research/chord-detection/chordsweep/labels.py`
- Test: `research/chord-detection/tests/test_labels.py`

**Interfaces:**
- Produces:
  - `PITCH_CLASSES: list[str]` (12, sharps), `QUALITY_INTERVALS: dict[str, list[int]]`.
  - `normalize_pitch_class(name: str) -> str` (flats/enharmonics → sharps; raises on unknown).
  - `ChordLabel(root: str, quality: str)` frozen; `.id -> "root:quality"`; `.pitch_classes() -> list[int]` (sorted 0–11).
  - `ChordClip(audio: np.ndarray, sample_rate: int, label: ChordLabel, source: str)`.

- [ ] **Step 1: Create the uv project**

Create `research/chord-detection/pyproject.toml`:

```toml
[project]
name = "chordsweep"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "numpy>=1.26",
    "librosa>=0.10",
    "scikit-learn>=1.4",
    "mirdata>=0.3.8",
    "audiomentations>=0.35",
    "matplotlib>=3.8",
    "soundfile>=0.12",
]

[dependency-groups]
dev = ["pytest>=8", "ruff>=0.6"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
pythonpath = ["."]
```

Create an empty `research/chord-detection/chordsweep/__init__.py`. Then from `research/chord-detection/` run `uv sync` (downloads deps; may take a few minutes on first run). Expected: a `.venv` is created and `uv run python -c "import librosa, sklearn, mirdata"` succeeds.

- [ ] **Step 2: Write the failing tests**

Create `research/chord-detection/tests/test_labels.py`:

```python
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
    clip = ChordClip(audio=np.zeros(4, dtype=np.float32), sample_rate=22050, label=ChordLabel("C", "maj"), source="unit")
    assert clip.sample_rate == 22050
    assert clip.label.id == "C:maj"
    assert clip.source == "unit"
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `uv run pytest tests/test_labels.py -q`
Expected: collection error — `ModuleNotFoundError: No module named 'chordsweep.labels'`.

- [ ] **Step 4: Implement `labels.py`**

Create `research/chord-detection/chordsweep/labels.py`:

```python
from dataclasses import dataclass, field

import numpy as np

PITCH_CLASSES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

_PC_INDEX = {name: i for i, name in enumerate(PITCH_CLASSES)}

_ENHARMONIC = {
    "Db": "C#", "Eb": "D#", "Fb": "E", "Gb": "F#", "Ab": "G#",
    "Bb": "A#", "Cb": "B", "E#": "F", "B#": "C",
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
        return sorted({(base + interval) % 12 for interval in QUALITY_INTERVALS[self.quality]})


@dataclass
class ChordClip:
    audio: np.ndarray
    sample_rate: int
    label: ChordLabel
    source: str = field(default="unknown")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `uv run pytest tests/test_labels.py -q`
Expected: 6 passed.

- [ ] **Step 6: Lint, format, commit**

```bash
uv run ruff check .
uv run ruff format .
git add research/chord-detection/pyproject.toml research/chord-detection/chordsweep/__init__.py research/chord-detection/chordsweep/labels.py research/chord-detection/tests/test_labels.py
git commit -m "feat: chordsweep scaffold + chord label/theory core"
```
(If `uv.lock` was generated by `uv sync`, add it too: `git add research/chord-detection/uv.lock`.)

---

## Task 2: Feature extractors

**Files:**
- Create: `research/chord-detection/chordsweep/features.py`
- Test: `research/chord-detection/tests/test_features.py`

**Interfaces:**
- Consumes: nothing from earlier tasks (operates on raw audio arrays).
- Produces:
  - `register_feature(name)` decorator; `get_feature(name) -> Callable[[np.ndarray, int], np.ndarray]`; `feature_names() -> list[str]`.
  - Registered features `"chroma_stft"`, `"chroma_cqt"` (return L2-normalized 12-vectors), `"mfcc"` (L2-normalized 13-vector).

- [ ] **Step 1: Write the failing tests**

Create `research/chord-detection/tests/test_features.py`:

```python
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
```

- [ ] **Step 2: Run to verify they fail**

Run: `uv run pytest tests/test_features.py -q`
Expected: `ModuleNotFoundError: No module named 'chordsweep.features'`.

- [ ] **Step 3: Implement `features.py`**

```python
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
```

- [ ] **Step 4: Run to verify they pass**

Run: `uv run pytest tests/test_features.py -q`
Expected: 4 passed. (If `test_chroma_stft_c_major_energy_in_c_e_g` is flaky on the pure-tone edge, the C/E/G bins 0/4/7 remain the three highest — the assertion is exact top-3; keep it.)

- [ ] **Step 5: Lint, format, commit**

```bash
uv run ruff check . && uv run ruff format .
git add research/chord-detection/chordsweep/features.py research/chord-detection/tests/test_features.py
git commit -m "feat: chroma/MFCC feature registry for chordsweep"
```

---

## Task 3: Classifiers

**Files:**
- Create: `research/chord-detection/chordsweep/classifiers.py`
- Test: `research/chord-detection/tests/test_classifiers.py`

**Interfaces:**
- Consumes: `ChordLabel` (Task 1).
- Produces:
  - `template_vector(label: ChordLabel) -> np.ndarray` (L2-normalized 12-bin one-hot of the chord's pitch classes).
  - `TemplateMatch(labels: list[ChordLabel])` and `KNN(k=3)`, each with `fit(X, y) -> None`, `predict(X) -> list[ChordLabel]`, `scores(X) -> np.ndarray` shape `(n_samples, n_classes)`, and attribute `classes: list[ChordLabel]` giving the column order of `scores`.

- [ ] **Step 1: Write the failing tests**

Create `research/chord-detection/tests/test_classifiers.py`:

```python
import numpy as np

from chordsweep.classifiers import KNN, TemplateMatch, template_vector
from chordsweep.labels import ChordLabel


def test_template_vector_is_normalized_onehot():
    vec = template_vector(ChordLabel("C", "maj"))
    nonzero = set(int(i) for i in np.nonzero(vec)[0])
    assert nonzero == {0, 4, 7}
    assert abs(float(np.linalg.norm(vec)) - 1.0) < 1e-6


def test_template_match_picks_correct_chord():
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min"), ChordLabel("G", "dom7")]
    clf = TemplateMatch(labels)
    x = template_vector(ChordLabel("C", "min"))[None, :]
    assert clf.predict(x)[0].id == "C:min"
    assert clf.scores(x).shape == (1, 3)


def test_knn_returns_nearest_label():
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min")]
    X = np.stack([template_vector(labels[0]), template_vector(labels[1])])
    clf = KNN(k=1)
    clf.fit(X, labels)
    query = template_vector(ChordLabel("C", "min"))[None, :]
    assert clf.predict(query)[0].id == "C:min"
    assert clf.scores(query).shape == (1, 2)
```

- [ ] **Step 2: Run to verify they fail**

Run: `uv run pytest tests/test_classifiers.py -q`
Expected: `ModuleNotFoundError: No module named 'chordsweep.classifiers'`.

- [ ] **Step 3: Implement `classifiers.py`**

```python
import numpy as np
from sklearn.neighbors import KNeighborsClassifier

from chordsweep.labels import ChordLabel


def template_vector(label):
    vector = np.zeros(12, dtype=float)
    for pitch_class in label.pitch_classes():
        vector[pitch_class] = 1.0
    norm = float(np.linalg.norm(vector))
    return vector / norm if norm > 0.0 else vector


class TemplateMatch:
    name = "template"

    def __init__(self, labels):
        self.classes = list(labels)
        self._templates = np.stack([template_vector(label) for label in self.classes])

    def fit(self, X, y):
        return None

    def scores(self, X):
        return np.asarray(X) @ self._templates.T

    def predict(self, X):
        indices = np.argmax(self.scores(X), axis=1)
        return [self.classes[i] for i in indices]


class KNN:
    name = "knn"

    def __init__(self, k=3):
        self._k = k
        self._model = KNeighborsClassifier(n_neighbors=k, metric="cosine")
        self.classes = []
        self._by_id = {}

    def fit(self, X, y):
        self._by_id = {label.id: label for label in y}
        ordered_ids = sorted(self._by_id)
        self.classes = [self._by_id[cid] for cid in ordered_ids]
        self._model = KNeighborsClassifier(n_neighbors=min(self._k, len(X)), metric="cosine")
        self._model.fit(np.asarray(X), [label.id for label in y])
        return None

    def predict(self, X):
        predicted_ids = self._model.predict(np.asarray(X))
        return [self._by_id[cid] for cid in predicted_ids]

    def scores(self, X):
        proba = self._model.predict_proba(np.asarray(X))
        model_classes = list(self._model.classes_)
        column_for = {cid: i for i, cid in enumerate(model_classes)}
        result = np.zeros((proba.shape[0], len(self.classes)))
        for j, label in enumerate(self.classes):
            if label.id in column_for:
                result[:, j] = proba[:, column_for[label.id]]
        return result
```

- [ ] **Step 4: Run to verify they pass**

Run: `uv run pytest tests/test_classifiers.py -q`
Expected: 3 passed.

- [ ] **Step 5: Lint, format, commit**

```bash
uv run ruff check . && uv run ruff format .
git add research/chord-detection/chordsweep/classifiers.py research/chord-detection/tests/test_classifiers.py
git commit -m "feat: template-match + kNN classifiers for chordsweep"
```

---

## Task 4: Evaluation

**Files:**
- Create: `research/chord-detection/chordsweep/evaluate.py`
- Test: `research/chord-detection/tests/test_evaluate.py`

**Interfaces:**
- Consumes: `ChordClip`/`ChordLabel` (Task 1), a feature callable (Task 2), a classifier (Task 3, exposing `.classes`, `fit`, `predict`, `scores`).
- Produces:
  - `featurize(clips, feature_fn) -> tuple[np.ndarray, list[ChordLabel]]`.
  - `far_frr_curve(scores, true_indices, thresholds) -> list[tuple[float, float, float]]` (threshold, far, frr).
  - `Metrics` dataclass: `accuracy: float`, `class_ids: list[str]`, `confusion: np.ndarray`, `precision: dict[str, float]`, `recall: dict[str, float]`, `far_frr: list[tuple[float, float, float]]`.
  - `evaluate(feature_fn, classifier, train, test, thresholds=None) -> Metrics` (asserts train/test sources don't overlap by object identity of clips).

- [ ] **Step 1: Write the failing tests**

Create `research/chord-detection/tests/test_evaluate.py`:

```python
import numpy as np

from chordsweep.classifiers import TemplateMatch, template_vector
from chordsweep.evaluate import evaluate, far_frr_curve, featurize
from chordsweep.labels import ChordClip, ChordLabel


def _clip(label, source):
    return ChordClip(audio=template_vector(label).astype(np.float32), sample_rate=1, label=label, source=source)


def _identity_feature(audio, sr):
    return np.asarray(audio, dtype=float)


def test_far_frr_monotonic_extremes():
    scores = np.array([[0.9, 0.1], [0.2, 0.8]])
    true_indices = [0, 1]
    curve = far_frr_curve(scores, true_indices, [0.0, 1.01])
    assert curve[0][1] == 1.0 and curve[0][2] == 0.0
    assert curve[-1][1] == 0.0 and curve[-1][2] == 1.0


def test_evaluate_perfect_on_templates():
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min"), ChordLabel("G", "dom7")]
    train = [_clip(label, "train") for label in labels]
    test = [_clip(label, "test") for label in labels]
    clf = TemplateMatch(labels)
    metrics = evaluate(_identity_feature, clf, train, test)
    assert metrics.accuracy == 1.0
    assert set(metrics.class_ids) == {label.id for label in labels}
    assert int(np.trace(metrics.confusion)) == len(labels)


def test_evaluate_rejects_overlapping_clip():
    labels = [ChordLabel("C", "maj")]
    shared = _clip(labels[0], "shared")
    clf = TemplateMatch(labels)
    try:
        evaluate(_identity_feature, clf, [shared], [shared])
        raise AssertionError("expected overlap to raise")
    except ValueError:
        pass


def test_featurize_shapes():
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min")]
    clips = [_clip(label, "x") for label in labels]
    X, y = featurize(clips, _identity_feature)
    assert X.shape == (2, 12)
    assert [label.id for label in y] == ["C:maj", "C:min"]
```

- [ ] **Step 2: Run to verify they fail**

Run: `uv run pytest tests/test_evaluate.py -q`
Expected: `ModuleNotFoundError: No module named 'chordsweep.evaluate'`.

- [ ] **Step 3: Implement `evaluate.py`**

```python
from dataclasses import dataclass

import numpy as np
from sklearn.metrics import confusion_matrix, precision_recall_fscore_support


@dataclass
class Metrics:
    accuracy: float
    class_ids: list
    confusion: np.ndarray
    precision: dict
    recall: dict
    far_frr: list


def featurize(clips, feature_fn):
    X = np.stack([feature_fn(clip.audio, clip.sample_rate) for clip in clips])
    y = [clip.label for clip in clips]
    return X, y


def far_frr_curve(scores, true_indices, thresholds):
    scores = np.asarray(scores)
    n, c = scores.shape
    curve = []
    for threshold in thresholds:
        accept = scores >= threshold
        rejects = sum(1 for i in range(n) if not accept[i, true_indices[i]])
        frr = rejects / n if n else 0.0
        wrong_accepts = 0
        wrong_total = 0
        for i in range(n):
            for j in range(c):
                if j != true_indices[i]:
                    wrong_total += 1
                    if accept[i, j]:
                        wrong_accepts += 1
        far = wrong_accepts / wrong_total if wrong_total else 0.0
        curve.append((float(threshold), float(far), float(frr)))
    return curve


def evaluate(feature_fn, classifier, train, test, thresholds=None):
    train_ids = {id(clip) for clip in train}
    if any(id(clip) in train_ids for clip in test):
        raise ValueError("train and test clips overlap")

    X_train, y_train = featurize(train, feature_fn)
    classifier.fit(X_train, y_train)
    X_test, y_test = featurize(test, feature_fn)
    predictions = classifier.predict(X_test)

    class_ids = [label.id for label in classifier.classes]
    true_ids = [label.id for label in y_test]
    pred_ids = [label.id for label in predictions]

    accuracy = float(np.mean([t == p for t, p in zip(true_ids, pred_ids)]))
    matrix = confusion_matrix(true_ids, pred_ids, labels=class_ids)
    precision, recall, _, _ = precision_recall_fscore_support(
        true_ids, pred_ids, labels=class_ids, zero_division=0
    )
    precision_map = {cid: float(p) for cid, p in zip(class_ids, precision)}
    recall_map = {cid: float(r) for cid, r in zip(class_ids, recall)}

    column_for = {cid: i for i, cid in enumerate(class_ids)}
    true_indices = [column_for[cid] for cid in true_ids]
    if thresholds is None:
        thresholds = list(np.linspace(0.0, 1.0, 21))
    curve = far_frr_curve(classifier.scores(X_test), true_indices, thresholds)

    return Metrics(
        accuracy=accuracy,
        class_ids=class_ids,
        confusion=matrix,
        precision=precision_map,
        recall=recall_map,
        far_frr=curve,
    )
```

- [ ] **Step 4: Run to verify they pass**

Run: `uv run pytest tests/test_evaluate.py -q`
Expected: 4 passed.

- [ ] **Step 5: Lint, format, commit**

```bash
uv run ruff check . && uv run ruff format .
git add research/chord-detection/chordsweep/evaluate.py research/chord-detection/tests/test_evaluate.py
git commit -m "feat: evaluation protocol (confusion + FAR/FRR) for chordsweep"
```

---

## Task 5: Dataset adapters

**Files:**
- Create: `research/chord-detection/chordsweep/adapters.py`
- Test: `research/chord-detection/tests/test_adapters.py`

**Interfaces:**
- Consumes: `ChordClip`/`ChordLabel` (Task 1).
- Produces:
  - `synth_chord(label, sr=22050, seconds=1.0) -> np.ndarray` (sum of sine tones at the chord's pitch classes, octave 4).
  - `SyntheticAdapter(labels, sr=22050)` with `.name` and `.clips() -> Iterator[ChordClip]`.
  - `FolderAdapter(root, sr=22050)` — loads `*.wav` where the filename before the first `_` is the label id with `-` for `:` and `s` for `#` (e.g. `Cs-min7_001.wav` → `C#:min7`); `.clips()`.
  - `MirdataAdapter(dataset_name, data_home=None, sr=22050)` — iterates a `mirdata` dataset's tracks and yields one `ChordClip` per performed-chord segment; `.clips()`.

- [ ] **Step 1: Write the failing tests**

Create `research/chord-detection/tests/test_adapters.py`:

```python
import numpy as np
import soundfile as sf

from chordsweep.adapters import FolderAdapter, SyntheticAdapter, parse_label_id, synth_chord
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
    sf.write(tmp_path / "G-dom7_001.wav", synth_chord(ChordLabel("G", "dom7"), sr=sr), sr)
    clips = list(FolderAdapter(tmp_path).clips())
    assert {clip.label.id for clip in clips} == {"C:maj", "G:dom7"}
    assert all(clip.source == "folder" for clip in clips)
```

- [ ] **Step 2: Run to verify they fail**

Run: `uv run pytest tests/test_adapters.py -q`
Expected: `ModuleNotFoundError: No module named 'chordsweep.adapters'`.

- [ ] **Step 3: Implement `adapters.py`**

```python
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
            yield ChordClip(audio=synth_chord(label, self._sr), sample_rate=self._sr, label=label, source="synthetic")


class FolderAdapter:
    name = "folder"

    def __init__(self, root, sr=22050):
        self._root = Path(root)
        self._sr = sr

    def clips(self):
        for path in sorted(self._root.glob("*.wav")):
            label = parse_label_id(path.name)
            audio, _ = librosa.load(path, sr=self._sr, mono=True)
            yield ChordClip(audio=audio.astype(np.float32), sample_rate=self._sr, label=label, source="folder")


class MirdataAdapter:
    name = "mirdata"

    def __init__(self, dataset_name, data_home=None, sr=22050, quality_map=None):
        import mirdata

        self._dataset = mirdata.initialize(dataset_name, data_home=data_home)
        self._sr = sr
        self._quality_map = quality_map or {}

    def clips(self):
        for track in self._dataset.load_tracks().values():
            chords = getattr(track, "chords", None)
            audio_path = getattr(track, "audio_mic_path", None) or getattr(track, "audio_path", None)
            if chords is None or audio_path is None:
                continue
            audio, _ = librosa.load(audio_path, sr=self._sr, mono=True)
            for start, end, chord_id in zip(chords.intervals[:, 0], chords.intervals[:, 1], chords.labels):
                label = self._to_label(chord_id)
                if label is None:
                    continue
                segment = audio[int(start * self._sr):int(end * self._sr)]
                if segment.size == 0:
                    continue
                yield ChordClip(audio=segment.astype(np.float32), sample_rate=self._sr, label=label, source=f"mirdata:{self._dataset.name}")

    def _to_label(self, chord_id):
        if chord_id in self._quality_map:
            root, quality = self._quality_map[chord_id]
            return ChordLabel(root, quality)
        if ":" in chord_id:
            root, harte = chord_id.split(":", 1)
            quality = {"maj": "maj", "min": "min", "7": "dom7", "maj7": "maj7", "min7": "min7"}.get(harte)
            if quality is not None:
                try:
                    return ChordLabel(root, quality)
                except ValueError:
                    return None
        return None
```

- [ ] **Step 4: Run to verify they pass**

Run: `uv run pytest tests/test_adapters.py -q`
Expected: 4 passed. (`MirdataAdapter` is not unit-tested — it needs a downloaded dataset; its Harte-label mapping and segmentation are covered by inspection and exercised manually in the sweep. The `import mirdata` is inside `__init__` so importing `adapters.py` never requires the dataset.)

- [ ] **Step 5: Lint, format, commit**

```bash
uv run ruff check . && uv run ruff format .
git add research/chord-detection/chordsweep/adapters.py research/chord-detection/tests/test_adapters.py
git commit -m "feat: synthetic/folder/mirdata dataset adapters for chordsweep"
```

---

## Task 6: Augmentation + sweep runner (CLI)

**Files:**
- Create: `research/chord-detection/chordsweep/augment.py`, `research/chord-detection/chordsweep/sweep.py`, `research/chord-detection/README.md`
- Test: `research/chord-detection/tests/test_sweep.py`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces:
  - `augment_clip(clip, rng) -> list[ChordClip]` (returns the original plus noise/gain variants; deterministic given `rng`).
  - `METHODS: dict[str, tuple[str, Callable]]` mapping a method name → `(feature_name, classifier_factory)` where `classifier_factory(labels)` returns a classifier.
  - `run_sweep(train_clips, test_clips, method_names, out_dir, augment=False) -> dict[str, Metrics]` — evaluates each method, writes `out_dir/summary.csv` and `out_dir/<method>_confusion.png` + `out_dir/<method>_far_frr.png`, returns the metrics map.
  - `main(argv=None)` — CLI: `--out DIR`, `--methods a,b`, `--augment`, and a synthetic demo config when no dataset flags are given.

- [ ] **Step 1: Write the failing test**

Create `research/chord-detection/tests/test_sweep.py`:

```python
import numpy as np

from chordsweep.adapters import SyntheticAdapter
from chordsweep.augment import augment_clip
from chordsweep.labels import ChordClip, ChordLabel
from chordsweep.sweep import METHODS, run_sweep


def test_augment_returns_original_plus_variants():
    clip = ChordClip(audio=np.ones(1000, dtype=np.float32), sample_rate=22050, label=ChordLabel("C", "maj"), source="x")
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
```

- [ ] **Step 2: Run to verify they fail**

Run: `uv run pytest tests/test_sweep.py -q`
Expected: `ModuleNotFoundError: No module named 'chordsweep.augment'` (or `chordsweep.sweep`).

- [ ] **Step 3: Implement `augment.py`**

```python
import numpy as np

from chordsweep.labels import ChordClip


def augment_clip(clip, rng):
    variants = [clip]
    noise = clip.audio + 0.01 * rng.standard_normal(clip.audio.shape).astype(np.float32)
    variants.append(ChordClip(audio=noise.astype(np.float32), sample_rate=clip.sample_rate, label=clip.label, source=clip.source + "+noise"))
    gain = (clip.audio * 0.6).astype(np.float32)
    variants.append(ChordClip(audio=gain, sample_rate=clip.sample_rate, label=clip.label, source=clip.source + "+gain"))
    return variants
```

- [ ] **Step 4: Implement `sweep.py`**

```python
import argparse
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from chordsweep.adapters import SyntheticAdapter
from chordsweep.augment import augment_clip
from chordsweep.classifiers import KNN, TemplateMatch
from chordsweep.evaluate import evaluate
from chordsweep.features import get_feature
from chordsweep.labels import ChordLabel

METHODS = {
    "chroma_stft+template": ("chroma_stft", lambda labels: TemplateMatch(labels)),
    "chroma_cqt+template": ("chroma_cqt", lambda labels: TemplateMatch(labels)),
    "chroma_stft+knn": ("chroma_stft", lambda labels: KNN(k=3)),
    "chroma_cqt+knn": ("chroma_cqt", lambda labels: KNN(k=3)),
    "mfcc+knn": ("mfcc", lambda labels: KNN(k=3)),
}


def _unique_labels(clips):
    seen = {}
    for clip in clips:
        seen[clip.label.id] = clip.label
    return [seen[key] for key in sorted(seen)]


def run_sweep(train_clips, test_clips, method_names, out_dir, augment=False):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if augment:
        rng = np.random.default_rng(0)
        expanded = []
        for clip in train_clips:
            expanded.extend(augment_clip(clip, rng))
        train_clips = expanded

    labels = _unique_labels(train_clips)
    results = {}
    rows = []
    for method_name in method_names:
        feature_name, factory = METHODS[method_name]
        feature_fn = get_feature(feature_name)
        classifier = factory(labels)
        metrics = evaluate(feature_fn, classifier, train_clips, test_clips)
        results[method_name] = metrics
        rows.append({"method": method_name, "accuracy": round(metrics.accuracy, 4)})
        _plot_confusion(metrics, out_dir / f"{method_name}_confusion.png", method_name)
        _plot_far_frr(metrics, out_dir / f"{method_name}_far_frr.png", method_name)

    with open(out_dir / "summary.csv", "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["method", "accuracy"])
        writer.writeheader()
        writer.writerows(rows)
    return results


def _plot_confusion(metrics, path, title):
    fig, ax = plt.subplots()
    ax.imshow(metrics.confusion, cmap="Blues")
    ax.set_title(f"confusion: {title}")
    ax.set_xticks(range(len(metrics.class_ids)))
    ax.set_yticks(range(len(metrics.class_ids)))
    ax.set_xticklabels(metrics.class_ids, rotation=90, fontsize=6)
    ax.set_yticklabels(metrics.class_ids, fontsize=6)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def _plot_far_frr(metrics, path, title):
    thresholds = [row[0] for row in metrics.far_frr]
    far = [row[1] for row in metrics.far_frr]
    frr = [row[2] for row in metrics.far_frr]
    fig, ax = plt.subplots()
    ax.plot(thresholds, far, label="FAR")
    ax.plot(thresholds, frr, label="FRR")
    ax.set_xlabel("threshold")
    ax.set_ylabel("rate")
    ax.set_title(f"FAR/FRR: {title}")
    ax.legend()
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def _demo_clips():
    labels = [ChordLabel("C", "maj"), ChordLabel("C", "min"), ChordLabel("G", "dom7"), ChordLabel("A", "min7")]
    train = list(SyntheticAdapter(labels).clips())
    test = list(SyntheticAdapter(labels).clips())
    return train, test


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run the chord-detection method sweep.")
    parser.add_argument("--out", default="out")
    parser.add_argument("--methods", default=",".join(METHODS))
    parser.add_argument("--augment", action="store_true")
    args = parser.parse_args(argv)

    train, test = _demo_clips()
    method_names = [name for name in args.methods.split(",") if name]
    results = run_sweep(train, test, method_names, args.out, augment=args.augment)
    for method_name, metrics in results.items():
        print(f"{method_name}: accuracy={metrics.accuracy:.3f}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Write the README**

Create `research/chord-detection/README.md`:

```markdown
# chordsweep — chord-detection method sweep

Adaptable benchmark for chord-*type* verification. Two seams (dataset adapters, method
registry) around a frozen eval (confusion matrix + FAR/FRR).

## Run
    uv sync
    uv run pytest -q
    uv run python -m chordsweep.sweep --out out            # synthetic demo
    uv run python -m chordsweep.sweep --out out --augment

## Real datasets
- Folder of clips (Kaggle / your own recordings): name files `<root>-<quality>_<n>.wav`,
  where `#` is written `s` (e.g. `Cs-min7_001.wav`). Load via `FolderAdapter(path)`.
- `mirdata` datasets (e.g. GuitarSet): `MirdataAdapter("guitarset")` after downloading the
  dataset per mirdata's instructions.

Wire train/test adapters into `run_sweep(...)`; keep them disjoint and never augment the test set.
```

- [ ] **Step 6: Run the full suite + the demo**

Run: `uv run pytest -q`
Expected: all tests across all files pass (labels, features, classifiers, evaluate, adapters, sweep).

Run: `uv run python -m chordsweep.sweep --out /tmp/chordsweep_demo`
Expected: prints per-method accuracies and writes `summary.csv` + confusion/FAR-FRR PNGs into `/tmp/chordsweep_demo`.

- [ ] **Step 7: Lint, format, commit**

```bash
uv run ruff check . && uv run ruff format .
git add research/chord-detection/chordsweep/augment.py research/chord-detection/chordsweep/sweep.py research/chord-detection/README.md research/chord-detection/tests/test_sweep.py
git commit -m "feat: augmentation + config-driven sweep runner with report output"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-06-chord-detection-sweep-harness-design.md`):
- Self-contained `research/chord-detection/` uv project → Task 1. ✓
- Dataset seam (`DatasetAdapter`: Mirdata/Folder/Synthetic, `ChordClip`) → Tasks 1 (types) + 5. ✓
- Method seam (feature registry × classifier: chroma-STFT/CQT/MFCC × template/kNN) → Tasks 2 + 3, composed in `METHODS` (Task 6). ✓
- Frozen protocol: held-out split (overlap raises), test never augmented, confusion matrix + FAR/FRR → Task 4 + Task 6 (`run_sweep` augments only train). ✓
- Verification framing (threshold-swept FAR/FRR) → `far_frr_curve` (Task 4). ✓
- Chord-type labels `root:quality`, qualities list → Task 1. ✓
- Report: comparison CSV + confusion/FAR-FRR plots; config-driven runner + CLI → Task 6. ✓
- Augmentation (train-only, toggled) → Task 6 (`augment_clip`, `run_sweep(augment=)`). ✓
- Suggested data path (Kaggle folder → mirdata → own clips) → README (Task 6) + adapters. ✓
- Testing over pure logic (labels/features/templates/metrics/adapters) → each task's tests. ✓
- Out-of-scope (Swift detector, embeddings/Create ML, personal recording, strum UX) — not planned; embedding/model classifier slots intentionally omitted. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases". Every step has complete runnable code and exact commands. The `MirdataAdapter` is real code (not a stub); it's simply exercised manually rather than unit-tested because it needs downloaded data — stated explicitly, not deferred as a placeholder. ✓

**3. Type consistency:** `ChordLabel(.id/.pitch_classes)`, `ChordClip(audio,sample_rate,label,source)`, `register_feature/get_feature/feature_names`, `template_vector`, `TemplateMatch(labels)`/`KNN(k)` with `.classes/fit/predict/scores`, `featurize`, `far_frr_curve(scores,true_indices,thresholds)`, `evaluate(feature_fn,classifier,train,test,thresholds)`, `Metrics(accuracy,class_ids,confusion,precision,recall,far_frr)`, `SyntheticAdapter/FolderAdapter/MirdataAdapter.clips()`, `parse_label_id`, `synth_chord`, `augment_clip(clip,rng)`, `METHODS`, `run_sweep(...)` — spelled identically across tasks and tests. The classifier `.classes` column order is the contract `evaluate` relies on for `scores`/confusion; both `TemplateMatch` and `KNN` expose it. ✓
