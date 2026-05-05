#!/usr/bin/env bash
# Test: file:// URI handler copies a local file to the output directory.
# Run from the repo root: bash tests/test_file_handler.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/download.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# ── fixture ───────────────────────────────────────────────────────────────────

fixture=$(mktemp --suffix=.csv)
echo "col1,col2" > "$fixture"
echo "a,1"       >> "$fixture"
trap 'rm -f "$fixture"' EXIT

# ── test: file:// URI infers source automatically (no --source needed) ────────

outdir=$(mktemp -d)
output=$(bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --id "file://$fixture" 2>&1)

[[ $output == *"non-reproducible"* ]] || fail "expected non-reproducible warning"
[[ -f "$outdir/mydata.csv"         ]] || fail "expected outdir/mydata.csv"
diff "$fixture" "$outdir/mydata.csv"   || fail "file content mismatch"
rm -rf "$outdir"
pass "file:// URI infers source=file and copies with predictable name"

# ── test: explicit --source file also works ───────────────────────────────────

outdir=$(mktemp -d)
bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --source file \
    --id "file://$fixture" 2>/dev/null
[[ -f "$outdir/mydata.csv" ]] || fail "expected outdir/mydata.csv with explicit --source file"
rm -rf "$outdir"
pass "explicit --source file with file:// URI works"

# ── test: bare path (no file://) is rejected ──────────────────────────────────

outdir=$(mktemp -d)
if bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --source file \
    --id "$fixture" 2>/dev/null; then
    rm -rf "$outdir"
    fail "expected error for bare path without file:// prefix"
fi
rm -rf "$outdir"
pass "bare path without file:// prefix is rejected"

# ── test: missing file produces an error ─────────────────────────────────────

outdir=$(mktemp -d)
if bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --id "file:///nonexistent/path/data.csv" 2>/dev/null; then
    rm -rf "$outdir"
    fail "expected error for missing file"
fi
rm -rf "$outdir"
pass "missing file:// path produces error"

echo
echo "All tests passed."
