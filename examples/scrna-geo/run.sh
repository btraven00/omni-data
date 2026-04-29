#!/usr/bin/env bash
# Standalone invocation of omni-data for the be1 dataset.
# Run from the repo root:
#   bash examples/scrna-geo/run.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pixi run --manifest-path "$ROOT/pixi.toml" bash "$ROOT/download.sh" \
  --output_dir out \
  --name be1 \
  --source geo \
  --id GSE243665 \
  --include-ext ".mtx.gz,.tsv.gz" \
  --max-file-size 200MB

echo "Files written to out/be1/"
