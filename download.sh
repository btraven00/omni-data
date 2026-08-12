#!/usr/bin/env bash
# omni-data default entrypoint: download a dataset via hapiq.
#
# Required omnibenchmark args:
#   --output_dir <dir>     Output directory for the downloaded files.
#   --name <id>            Module name/identifier (used as the dataset subfolder).
#
# Provide exactly one of:
#   --accession <id>       Repository accession (e.g. GSE243665, 12345678).
#                          Requires --source.
#   --uri <uri>            URI to fetch. --source is inferred from the scheme:
#                            file://   local path (non-reproducible)
#                            http/https://  passed to hapiq's url downloader
#                            s3://     not yet implemented
#   --uri_type <t>         What --uri points at: "file" or "directory". Optional;
#                          when omitted the type is inferred (an http(s) URI
#                          ending in "/" is a directory; a local path is whatever
#                          it is on disk). Declare it to have the run fail when
#                          the URI is not that type, instead of quietly fetching
#                          the wrong thing: an http directory requested without
#                          its trailing slash otherwise yields its index page.
#
# Required with --accession:
#   --source <src>         Repository source: geo, zenodo, figshare, sra,
#                          ensembl, vcp, scperturb, biostudies, hca,
#                          experimenthub, scanpy.
#
# Optional:
#   --hash <algo:hex>      Verify the single downloaded file against this hash.
#   --include-ext <csv>    Comma-separated extensions to include.
#   --exclude-ext <csv>    Comma-separated extensions to skip.
#   --max-file-size <s>    Skip files larger than this (e.g. 500MB).
#   --filename-pattern     Glob to filter filenames.
#   --subset <csv>         Sub-items to download (e.g. GSM IDs within a GSE).
#   --organism <str>       Restrict to organism substring match.
#   --limit-files <n>      Stop after this many files.
#   --raw                  Also download raw FASTQ via ENA/SRA.
#   --timeout <sec>        Per-run timeout (default: hapiq's own default).
#   --extra <"...">        Pass-through string of additional hapiq flags.

set -euo pipefail

output_dir=""
name=""
source=""
accession=""
uri=""
uri_type=""
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
        --accession)        accession=$2;        shift 2 ;;
        --uri)              uri=$2;              shift 2 ;;
        --uri-type|--uri_type)            uri_type=$2;         shift 2 ;;
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

[[ -n $accession && -n $uri ]] && die "use either --accession or --uri, not both"
[[ -n $accession || -n $uri ]] || die "one of --accession or --uri is required"

case "$uri_type" in
    ""|file|directory) ;;
    *) die "--uri_type must be 'file' or 'directory', got: $uri_type" ;;
esac
[[ -n $uri_type && -z $uri ]] && die "--uri_type only applies to --uri"

if [[ -n $uri ]]; then
    case "$uri" in
        file://*)        source="file" ;;
        http://*|https://*) source="url"; accession="$uri" ;;
        s3://*)          die "URI scheme not yet implemented: s3://" ;;
        *)               die "unrecognised URI — expected a scheme (file://, http://, https://, s3://…): $uri" ;;
    esac
else
    [[ -n $source ]] || die "--source is required with --accession"
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [[ $source == "file" ]]; then
    local_path="${uri#file://}"
    [[ -e $local_path ]] || die "local path does not exist: $local_path"
    echo "WARNING: source=file is non-reproducible — result depends on local filesystem state" >&2
    # A declared type is an assertion about the path, checked before copying:
    # the point of stating it is to fail on a wrong path, not to discover the
    # mismatch later as a missing or unexpected output file.
    [[ $uri_type == directory && ! -d $local_path ]] && die "--uri_type directory but not a directory: $local_path"
    [[ $uri_type == file      && ! -f $local_path ]] && die "--uri_type file but not a regular file: $local_path"
    if [[ -f $local_path ]]; then
        cp "$local_path" "$tmpdir/$(basename "$local_path")"
    elif [[ -d $local_path ]]; then
        cp -r "$local_path"/. "$tmpdir/"
    else
        die "local path is neither a file nor a directory: $local_path"
    fi
else
    args=(download "$source" "$accession" --out "$tmpdir" -y)
    # hapiq infers a directory from a trailing "/"; --directory says so outright,
    # which is what keeps a slash lost in a YAML edit from silently turning a
    # dataset fetch into a download of the server's index page.
    [[ $uri_type == directory ]] && args+=(--directory)
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
fi

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
