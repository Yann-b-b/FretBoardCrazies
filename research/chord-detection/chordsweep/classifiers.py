import numpy as np
from sklearn.neighbors import KNeighborsClassifier


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
        self._model = KNeighborsClassifier(
            n_neighbors=min(self._k, len(X)), metric="cosine"
        )
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
