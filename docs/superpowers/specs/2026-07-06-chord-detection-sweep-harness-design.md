# Chord-Detection Method-Sweep Harness — Design

**Date:** 2026-07-06
**Status:** Approved for planning
**Branch context:** `dev`
**Part of:** v2.0 chord trainer (`docs/v2-chord-trainer-vision.md`) — the first foundation deliverable (audio-detection feasibility).

## Goal

A **dataset- and method-adaptable** Python benchmark that ranks candidate chord-detection
pipelines and outputs the evidence to choose one for the app's chord *verification*. The
deliverable is a decision — *"method X clears the accuracy bar for tiers T1/T2; here is its
confusion matrix and false-accept/false-reject curve"* — that unblocks Mode A's input design.
This is a self-contained **research spike**, not app code; the winning method is later
reimplemented in Swift.

## Framing (locked from brainstorming)

- **Verification, not identification.** The drill knows the target chord, so the detector
  answers *"is this consistent with `Cm7`?"* (one-vs-target similarity + threshold), not
  open classification. Metrics reflect this (threshold-swept false-accept/false-reject).
- **Chord *type* only.** Root string is a UI/setting dimension the drill prescribes; audio
  need not discern voicing. Labels are `root:quality`.
- **Two adaptable seams + one frozen protocol.** Swap datasets freely; swap methods freely;
  judge every (dataset × method) combo through an identical evaluation so results compare.
- **Start narrow:** tiers **T1/T2**, a subset of roots, a few conditions. Enough for signal.

## Location & stack

Self-contained under `research/chord-detection/` with its **own** `uv` project (isolated
from the iOS app — it pulls heavy audio/ML deps). Python 3.12, `uv`, `pytest`, `ruff`.
Dependencies: `numpy`, `librosa` (chroma/CQT/features), `scikit-learn` (kNN, metrics),
`mirdata` (public-dataset loaders), `audiomentations` (augmentation), `matplotlib` (plots).

## Seam 1 — Dataset adapter (swap the data)

One interface; everything yields the same typed clips.

```python
@dataclass(frozen=True)
class ChordLabel:
    root: str        # pitch class: "C", "C#", ... "B"
    quality: str     # "maj" | "min" | "dom7" | "maj7" | "min7" | "sus4" | "6" | ...
    # id property -> f"{root}:{quality}"

@dataclass
class ChordClip:
    audio: np.ndarray   # mono float32
    sample_rate: int
    label: ChordLabel
    source: str         # adapter/dataset id (provenance)

class DatasetAdapter(Protocol):
    name: str
    def clips(self) -> Iterator[ChordClip]: ...
```

Adapters (each behind the same interface):
- **`MirdataAdapter`** — wraps `mirdata` (GuitarSet, etc.); segments chord regions from the
  dataset's chord annotations into clips. Handles the excerpt-based datasets.
- **`FolderAdapter`** — a directory of labeled clips (Kaggle sets, *your own phone recordings*);
  label parsed from a folder-name or filename convention (documented, configurable).
- **`SyntheticAdapter`** — renders "golden" chords from theory (sampled-guitar soft-synth or
  additive tones) for prototypes / pipeline sanity / augmentation seeds. **Never used as the
  test set** (domain gap) — enforced by the split config.

A run's config names which adapter(s) supply **prototypes/train** vs the **held-out test** set,
and they must not overlap (asserted).

## Seam 2 — Method (swap the detector)

A **Method** = `FeatureExtractor` × `Classifier`, both pluggable via a name registry.

```python
class FeatureExtractor(Protocol):
    name: str
    def extract(self, audio: np.ndarray, sr: int) -> np.ndarray: ...   # fixed-length vector

class Classifier(Protocol):
    name: str
    def fit(self, X: np.ndarray, y: list[ChordLabel]) -> None: ...
    def predict(self, X: np.ndarray) -> list[ChordLabel]: ...
    def scores(self, X: np.ndarray) -> np.ndarray: ...   # per-class similarity/distance (for threshold sweep)
```

- **FeatureExtractors:** `ChromaSTFT`, `ChromaCQT` (log-spaced, better for pitch), `MFCC`
  (baseline/timbre control), and a stub `Embedding` slot (frozen encoder) left registered-but-
  optional for the T3/T4 escalation path — not required for this spike.
- **Classifiers:** `TemplateMatch` (theory prototypes: `Cm7 → {C,E♭,G,B♭}` one-hot chroma,
  cosine similarity), `KNN` (`sklearn.KNeighborsClassifier` over real prototype vectors).
  A registered `SklearnModel` slot is allowed but out of scope for the spike.

Registering a new feature or classifier is a few lines; the sweep picks up every registered
method automatically. This is the "very adaptable" requirement.

## Frozen evaluation protocol (do not let this vary)

```python
def evaluate(method, train: list[ChordClip], test: list[ChordClip]) -> Metrics
```

- **Held-out split:** train/prototype clips and test clips never overlap (asserted). Test is
  **never augmented**; augmentation applies only to train/prototypes.
- **Metrics (all emitted per method):**
  - overall accuracy + per-class precision/recall,
  - **confusion matrix** (the key artifact — shows *which* chords/qualities/tiers blur, e.g.
    maj7↔dom7↔6, and whether T2 degrades),
  - **false-accept-rate / false-reject-rate vs. acceptance threshold** (the verification
    curve — sweep the `scores()` threshold; this is how a real rep decides accept/replay).
- **Report:** a comparison table (method × metric) as CSV + per-method confusion-matrix and
  FAR/FRR plots (PNG) written to an output dir. `sweep` runs all (dataset × method) combos
  from a config and produces the ranked report.

## Augmentation (optional, config-toggled)

`audiomentations` on train/prototype clips only: additive noise, room-impulse-response
convolution (reverb), gain, and **pitch-shift** (transposition — covers roots from one
recorded quality). Measured as an on/off variable so the report shows augmentation's *lift*.

## Deliverable

Running `sweep --config <toml>` over the initial config produces the ranked report and a
one-paragraph readout: the chosen `(feature, classifier)` and the tiers it clears, with the
confusion matrix and FAR/FRR as evidence. That decision feeds Mode A (audio vs touch vs hybrid,
and which tiers get audio).

## Suggested initial data path (config, not code)

Prototype fast on **Kaggle isolated-chord** sets → rank methods on **GuitarSet / Guitar-TECHS**
(real guitars, sevenths, timbre variation) via `mirdata`/folder adapters → reality-check the
top method on a handful of **your own phone-mic** clips (a `FolderAdapter`) before trusting it.

## Files (module layout)

| Path (under `research/chord-detection/`) | Responsibility |
|---|---|
| `pyproject.toml` | isolated `uv` project + deps |
| `chordsweep/labels.py` | `ChordLabel`, `ChordClip`, chord→pitch-class theory |
| `chordsweep/adapters/` | `DatasetAdapter` + `MirdataAdapter`/`FolderAdapter`/`SyntheticAdapter` |
| `chordsweep/features.py` | `FeatureExtractor` registry: chroma STFT/CQT, MFCC, (embedding stub) |
| `chordsweep/classifiers.py` | `Classifier` registry: template-match, kNN |
| `chordsweep/evaluate.py` | held-out split, metrics (accuracy, confusion, FAR/FRR) |
| `chordsweep/augment.py` | optional augmentation pipeline |
| `chordsweep/sweep.py` | config-driven runner → CSV + plots (CLI entry) |
| `tests/` | pytest over the pure logic |

## Testing

`pytest` over the deterministic/pure logic (dataset downloads are experiments, not unit tests):
- `labels`: `Cm7 → {C, E♭, G, B♭}` pitch classes; `id` formatting; enharmonic handling.
- `features`: chroma/CQT output shape + determinism on a synthetic tone; a pure C-major-triad
  tone produces chroma energy in C/E/G bins (sanity).
- `classifiers`: `TemplateMatch` picks the right template for a clean synthetic chord; `KNN`
  wiring on toy vectors returns the nearest label; `scores()` shape.
- `evaluate`: confusion matrix / precision / recall on hand-constructed predictions;
  FAR/FRR monotonic as threshold sweeps; held-out split raises on train/test overlap.
- `adapters`: `FolderAdapter` label parsing from the naming convention; `SyntheticAdapter`
  renders the requested chord's pitch classes.

## Out of scope

- The iOS/Swift implementation of the winning detector (a later foundation piece, once the
  sweep decides).
- Learned-embedding feature + `SklearnModel`/Create ML classifier (registered slots exist for
  the T3/T4 escalation path, but building them is deferred until the sweep shows chroma is
  insufficient).
- Recording the personal phone-mic validation set (the user does that; the `FolderAdapter`
  consumes it).
- Real-time streaming / strum-onset detection and the rep UX (that's Mode A's design, informed
  by this spike's result).
