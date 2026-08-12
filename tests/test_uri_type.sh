#!/usr/bin/env bash
# Test: --uri_type declares what --uri points at, and is enforced.
# Run from the repo root: bash tests/test_uri_type.sh
#
# The http(s) cases stub `hapiq` on PATH and assert on the arguments it was
# handed, so the wiring is tested without a network round-trip.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/download.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# ── stub hapiq: record argv, then produce a plausible download ────────────────

stubdir=$(mktemp -d)
argslog="$stubdir/args"
cat > "$stubdir/hapiq" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$ARGSLOG"
out=""
prev=""
for a in "$@"; do
    [[ $prev == "--out" ]] && out=$a
    prev=$a
done
mkdir -p "$out"
echo "data" > "$out/be1.h5ad"
STUB
chmod +x "$stubdir/hapiq"
export ARGSLOG="$argslog"
export PATH="$stubdir:$PATH"
trap 'rm -rf "$stubdir"' EXIT

run_url() { # $1: extra args...  echoes nothing, leaves argv in $argslog
    local outdir
    outdir=$(mktemp -d)
    bash "$SCRIPT" --output_dir "$outdir" --name be1 \
        --uri "https://example.invalid/datasets/be1-fixture/" "$@" >/dev/null 2>&1
    rm -rf "$outdir"
}

# ── test: --uri_type directory reaches hapiq as --directory ──────────────────

run_url --uri_type directory
grep -q -- "--directory" "$argslog" || fail "--uri_type directory should pass --directory to hapiq"
pass "--uri_type directory passes --directory"

# ── test: file and omitted do not ────────────────────────────────────────────

run_url --uri_type file
grep -q -- "--directory" "$argslog" && fail "--uri_type file must not pass --directory"
pass "--uri_type file does not pass --directory"

run_url
grep -q -- "--directory" "$argslog" && fail "omitted --uri_type must not pass --directory"
pass "omitted --uri_type leaves inference to hapiq"

# ── test: declared type is enforced against a local path ─────────────────────

fixture_file=$(mktemp --suffix=.csv)
echo "col1,col2" > "$fixture_file"
fixture_dir=$(mktemp -d)
echo "col1,col2" > "$fixture_dir/be1.csv"
trap 'rm -rf "$stubdir" "$fixture_dir"; rm -f "$fixture_file"' EXIT

expect_die() { # $1: description, rest: args
    local desc=$1; shift
    local outdir output status=0
    outdir=$(mktemp -d)
    output=$(bash "$SCRIPT" --output_dir "$outdir" --name be1 "$@" 2>&1) || status=$?
    rm -rf "$outdir"
    [[ $status -ne 0 ]] || fail "$desc: expected a non-zero exit"
    [[ $output == *"error:"* ]] || fail "$desc: expected an error message, got: $output"
}

expect_die "directory declared, file given" --uri "file://$fixture_file" --uri_type directory
pass "--uri_type directory rejects a regular file"

expect_die "file declared, directory given" --uri "file://$fixture_dir" --uri_type file
pass "--uri_type file rejects a directory"

expect_die "bogus value" --uri "file://$fixture_file" --uri_type folder
pass "--uri_type rejects values other than file/directory"

expect_die "no --uri" --accession GSE1 --source geo --uri_type directory
pass "--uri_type without --uri is an error"

# ── test: a correct declaration still works ──────────────────────────────────

outdir=$(mktemp -d)
bash "$SCRIPT" --output_dir "$outdir" --name be1 \
    --uri "file://$fixture_dir" --uri_type directory >/dev/null 2>&1 \
    || fail "matching declaration should succeed"
[[ -f "$outdir/be1.csv" ]] || fail "expected outdir/be1.csv"
rm -rf "$outdir"
pass "--uri_type directory with a directory copies its contents"

echo "All uri_type tests passed."
