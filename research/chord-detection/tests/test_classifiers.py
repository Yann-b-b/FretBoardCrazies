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
