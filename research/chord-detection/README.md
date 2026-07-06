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
