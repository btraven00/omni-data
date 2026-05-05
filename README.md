# omni-data

Hapiq-backed data download module for omnibenchmark pipelines.

Wraps [hapiq](https://github.com/btraven00/hapiq) so any omnibenchmark stage
can pull a dataset from a supported scientific repository (GEO, Zenodo,
Figshare, SRA/ENA, Ensembl, CZI VCP, scPerturb, BioStudies, HCA) into a
canonical `<output_dir>/<name>/` folder.

## Setup

```sh
pixi install
pixi run check
```

`pixi run check` invokes `hapiq --help` and prints `OK` if the binary is on
PATH. Run it after install to confirm the environment is healthy.

## Usage

```sh
pixi run bash download.sh \
  --output_dir <dir> \
  --name <id> \
  --source <geo|zenodo|figshare|sra|ensembl|vcp|scperturb|biostudies|hca> \
  --id <accession> \
  [--hash <algo:hex>] \
  [--include-ext .h5,.h5ad] \
  [--exclude-ext .bam,.fastq.gz] \
  [--max-file-size 500MB] \
  [--filename-pattern '*.counts.*'] \
  [--subset GSM123,GSM456] \
  [--organism 'Homo sapiens'] \
  [--limit-files 10] \
  [--raw] \
  [--timeout 3600] \
  [--extra "<extra hapiq flags>"]
```

Files land in `<output_dir>/<name>/` along with hapiq's `hapiq.json` witness
file (provenance + per-file checksums).

### Example

```sh
pixi run bash download.sh \
  --output_dir out \
  --name pbmc3k \
  --source geo \
  --id GSE149383 \
  --include-ext .h5,.h5ad
```

### Local file (non-reproducible)

Use `--source file` with a `file://` URI to copy a file from the local
filesystem instead of fetching from a remote repository. This is useful for
bootstrapping with data you already have on disk.

```sh
pixi run bash download.sh \
  --output_dir out \
  --name mydata \
  --id file:///absolute/path/to/data.csv
```

The `file://` scheme is recognised automatically — `--source` can be omitted.

> **Warning:** `source=file` is flagged as non-reproducible at runtime.
> The result depends on local filesystem state and cannot be replayed by
> others or in CI without the same file present.

### Single-file integrity check

For datasets that resolve to a single file, pin the expected hash:

```sh
pixi run bash download.sh \
  --output_dir out \
  --name palantir \
  --source figshare \
  --id 12345678 \
  --hash sha256:abc123...
```

The download fails (and the file is removed) on mismatch.

## Conda environment export

```sh
pixi run export-env
```

## Citation

See `CITATION.cff`.
