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
