#!/usr/bin/env bash
# omni-data default entrypoint: download a dataset via hapiq.
#
# Required omnibenchmark args:
#   --output_dir <dir>   Output directory for the downloaded files.
#   --name <id>          Module name/identifier (used as the dataset subfolder).
#
# Required hapiq args:
#   --source <src>       Repository source (geo, zenodo, figshare, sra,
#                        ensembl, vcp, scperturb, biostudies, hca).
#   --id <accession>     Accession ID within that source.
#
# Optional:
#   --hash <algo:hex>    Verify the single downloaded file against this hash.
#   --include-ext <csv>  Comma-separated extensions to include.
#   --exclude-ext <csv>  Comma-separated extensions to skip.
#   --max-file-size <s>  Skip files larger than this (e.g. 500MB).
#   --filename-pattern   Glob to filter filenames.
#   --subset <csv>       Sub-items to download (e.g. GSM IDs within a GSE).
#   --organism <str>     Restrict to organism substring match.
#   --limit-files <n>    Stop after this many files.
#   --raw                Also download raw FASTQ via ENA/SRA.
#   --timeout <sec>      Per-run timeout (default: hapiq's own default).
#   --extra <"...">      Pass-through string of additional hapiq flags.

set -euo pipefail

output_dir=""
name=""
source=""
id=""
hash=""
include_ext=""
exclude_ext=""
max_file_size=""
filename_pattern=""
subset=""
organism=""
limit_files=""
raw=""
timeout=""
extra=""

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output_dir)       output_dir=$2;       shift 2 ;;
        --name)             name=$2;             shift 2 ;;
        --source)           source=$2;           shift 2 ;;
        --id|--accession)   id=$2;               shift 2 ;;
        --hash)             hash=$2;             shift 2 ;;
        --include-ext|--include_ext)      include_ext=$2;      shift 2 ;;
        --exclude-ext|--exclude_ext)      exclude_ext=$2;      shift 2 ;;
        --max-file-size|--max_file_size)  max_file_size=$2;    shift 2 ;;
        --filename-pattern|--filename_pattern) filename_pattern=$2; shift 2 ;;
        --subset)           subset=$2;           shift 2 ;;
        --organism)         organism=$2;         shift 2 ;;
        --limit-files|--limit_files)      limit_files=$2;      shift 2 ;;
        --raw)              raw=1;               shift   ;;
        --timeout)          timeout=$2;          shift 2 ;;
        --extra)            extra=$2;            shift 2 ;;
        -h|--help)
            awk 'NR>=2 && /^#/{sub(/^# ?/,""); print} NR>=2 && !/^#/{exit}' "$0"
            exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[[ -n $output_dir ]] || die "--output_dir is required"
[[ -n $name       ]] || die "--name is required"
[[ -n $source     ]] || die "--source is required"
[[ -n $id         ]] || die "--id is required"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

args=(download "$source" "$id" --out "$tmpdir" -y)
[[ -n $hash             ]] && args+=(--hash "$hash")
[[ -n $include_ext      ]] && args+=(--include-ext "$include_ext")
[[ -n $exclude_ext      ]] && args+=(--exclude-ext "$exclude_ext")
[[ -n $max_file_size    ]] && args+=(--max-file-size "$max_file_size")
[[ -n $filename_pattern ]] && args+=(--filename-pattern "$filename_pattern")
[[ -n $subset           ]] && args+=(--subset "$subset")
[[ -n $organism         ]] && args+=(--organism "$organism")
[[ -n $limit_files      ]] && args+=(--limit-files "$limit_files")
[[ -n $raw              ]] && args+=(--raw)
[[ -n $timeout          ]] && args+=(--timeout "$timeout")

if [[ -n $extra ]]; then
    # shellcheck disable=SC2206
    extra_arr=($extra)
    args+=("${extra_arr[@]}")
fi

echo "Full command: hapiq ${args[*]}"
hapiq "${args[@]}"

# collect matching files; if include_ext is set filter by it, otherwise take all data files
if [[ -n $include_ext ]]; then
    # include_ext may be comma-separated; build a find expression for each extension
    mapfile -t exts < <(tr ',' '\n' <<< "$include_ext")
    find_args=()
    for ext in "${exts[@]}"; do
        [[ ${#find_args[@]} -gt 0 ]] && find_args+=(-o)
        find_args+=(-name "*${ext}")
    done
    mapfile -t matches < <(find "$tmpdir" \( "${find_args[@]}" \) -type f | sort)
else
    mapfile -t matches < <(find "$tmpdir" -type f -not -name "hapiq.json" | sort)
fi

[[ ${#matches[@]} -eq 0 ]] && { echo "error: no matching files found after download" >&2; exit 1; }

# enforce limit_files via the wrapper (hapiq may not honour it for cached runs)
if [[ -n $limit_files && $limit_files -gt 0 ]]; then
    matches=("${matches[@]:0:$limit_files}")
fi

mkdir -p "$output_dir"

if [[ ${#matches[@]} -eq 1 ]]; then
    # single file: rename to $name<ext> for a predictable output path
    src="${matches[0]}"
    ext="${src##*.}"
    # preserve compound extensions like .mtx.gz
    case "$src" in
        *.tar.gz|*.mtx.gz|*.tsv.gz|*.csv.gz|*.txt.gz|*.h5ad.gz) ext="${src##*${src%.*.*}.}" ;;
    esac
    cp "$src" "$output_dir/$name.$ext"
else
    for f in "${matches[@]}"; do
        cp "$f" "$output_dir/$(basename "$f")"
    done
fi
