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

# ── test: --uri file:// infers source, copies with predictable name ───────────

outdir=$(mktemp -d)
output=$(bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --uri "file://$fixture" 2>&1)

[[ $output == *"non-reproducible"* ]] || fail "expected non-reproducible warning"
[[ -f "$outdir/mydata.csv"         ]] || fail "expected outdir/mydata.csv"
diff "$fixture" "$outdir/mydata.csv"   || fail "file content mismatch"
rm -rf "$outdir"
pass "--uri file:// infers source=file and copies with predictable name"

# ── test: --accession and --uri together is rejected ─────────────────────────

outdir=$(mktemp -d)
if bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --accession GSE123 \
    --uri "file://$fixture" 2>/dev/null; then
    rm -rf "$outdir"
    fail "expected error when both --accession and --uri are given"
fi
rm -rf "$outdir"
pass "--accession and --uri together is rejected"

# ── test: --uri with no scheme (bare path) is rejected ───────────────────────

outdir=$(mktemp -d)
if bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --uri "$fixture" 2>/dev/null; then
    rm -rf "$outdir"
    fail "expected error for bare path with no URI scheme"
fi
rm -rf "$outdir"
pass "--uri with no scheme (bare path) is rejected"

# ── test: --uri s3:// (unimplemented) gives clear error ──────────────────────

outdir=$(mktemp -d)
errmsg=$(bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --uri "s3://my-bucket/data.csv" 2>&1 || true)
rm -rf "$outdir"
[[ $errmsg == *"not yet implemented"* ]] || fail "expected 'not yet implemented' for s3:// URI"
pass "--uri s3:// gives 'not yet implemented' error"

# ── test: missing file produces an error ─────────────────────────────────────

outdir=$(mktemp -d)
if bash "$SCRIPT" \
    --output_dir "$outdir" \
    --name mydata \
    --uri "file:///nonexistent/path/data.csv" 2>/dev/null; then
    rm -rf "$outdir"
    fail "expected error for missing file"
fi
rm -rf "$outdir"
pass "missing file:// path produces error"

echo
echo "All tests passed."
