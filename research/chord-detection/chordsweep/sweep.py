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
    labels = [
        ChordLabel("C", "maj"),
        ChordLabel("C", "min"),
        ChordLabel("G", "dom7"),
        ChordLabel("A", "min7"),
    ]
    train = list(SyntheticAdapter(labels).clips())
    test = list(SyntheticAdapter(labels).clips())
    return train, test


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Run the chord-detection method sweep."
    )
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
