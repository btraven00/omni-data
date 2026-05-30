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

# ── test: extension-less file is named by sniffed magic bytes (zip) ──────────
# Regression: a download with no extension (e.g. an API endpoint basename like
# .../datafile/6154417) must still get a sensible suffix, and the extension must
# be derived from the basename — not from a dot in the (mktemp) temp dir path.

zipfix=$(mktemp -d)/6154417            # extension-less basename
printf 'PK\x03\x04rest-of-zip' > "$zipfix"
outdir=$(mktemp -d)
bash "$SCRIPT" --output_dir "$outdir" --name adamson --uri "file://$zipfix" >/dev/null 2>&1
[[ -f "$outdir/adamson.zip" ]] || fail "extension-less zip should be named adamson.zip (got: $(ls "$outdir"))"
rm -rf "$outdir" "$(dirname "$zipfix")"
pass "extension-less file with zip magic is named <name>.zip"

# ── test: extension-less gzip magic -> .gz ───────────────────────────────────

gzfix=$(mktemp -d)/blob
printf '\x1f\x8b\x08\x00data' > "$gzfix"
outdir=$(mktemp -d)
bash "$SCRIPT" --output_dir "$outdir" --name d --uri "file://$gzfix" >/dev/null 2>&1
[[ -f "$outdir/d.gz" ]] || fail "extension-less gzip should be named d.gz (got: $(ls "$outdir"))"
rm -rf "$outdir" "$(dirname "$gzfix")"
pass "extension-less file with gzip magic is named <name>.gz"

echo
echo "All tests passed."
