#!/usr/bin/env bash
# Example: use a local file as input via the file:// handler.
#
# The file:// scheme is recognised automatically — no --source needed.
# This is useful for bootstrapping with data already on disk, but the
# result is non-reproducible (tied to local filesystem state).
#
# Usage:
#   bash examples/local-file/run.sh /path/to/your/data.csv
#   bash examples/local-file/run.sh  # uses the bundled sample fixture

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ $# -gt 0 ]]; then
    input="$1"
else
    input="$ROOT/examples/local-file/sample.csv"
fi

[[ -f $input ]] || { echo "error: file not found: $input" >&2; exit 1; }

pixi run --manifest-path "$ROOT/pixi.toml" bash "$ROOT/download.sh" \
  --output_dir "$ROOT/examples/local-file/out" \
  --name localdata \
  --uri "file://$input"

echo "Files written to examples/local-file/out/"
