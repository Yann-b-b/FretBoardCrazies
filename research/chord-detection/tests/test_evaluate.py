import numpy as np

from chordsweep.classifiers import TemplateMatch, template_vector
from chordsweep.evaluate import evaluate, far_frr_curve, featurize
from chordsweep.labels import ChordClip, ChordLabel


def _clip(label, source):
    return ChordClip(
        audio=template_vector(label).astype(np.float32),
        sample_rate=1,
        label=label,
        source=source,
    )


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
