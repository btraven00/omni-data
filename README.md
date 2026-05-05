# omni-data

Hapiq-backed data download module for [omnibenchmark](https://omnibenchmark.org) pipelines.
Pulls datasets from supported scientific repositories (GEO, Zenodo, Figshare, SRA/ENA, Ensembl, CZI VCP, scPerturb, BioStudies, HCA) into a canonical output directory.

## Usage

Reference this module in a benchmark `parameters` block:

```yaml
modules:
  - id: my-dataset
    repository:
      url: https://github.com/btraven00/omni-data
      commit: main
    parameters:
      - source: "geo"
        accession: "GSE149383"
        include_ext: ".h5ad"
```

Use `uri` instead of `source`/`accession` for URL or local-file sources:

```yaml
    parameters:
      - uri: "https://example.com/data.h5ad"
```

See [`examples/`](examples/) for complete benchmark YAMLs.

## Parameters

| Parameter | Description |
|-----------|-------------|
| `source` | Repository to download from: `geo`, `zenodo`, `figshare`, `sra`, `ensembl`, `vcp`, `scperturb`, `biostudies`, `hca`, `experimenthub`, `scanpy` |
| `accession` | Accession ID within the source repository |
| `uri` | URI to fetch directly — `https://`, `http://`, or `file:///` (mutually exclusive with `source`/`accession`) |
| `hash` | Expected hash for single-file datasets, e.g. `sha256:abc123…` — download fails on mismatch |
| `include_ext` | Comma-separated extensions to keep, e.g. `.h5,.h5ad` |
| `exclude_ext` | Comma-separated extensions to skip, e.g. `.bam,.fastq.gz` |
| `max_file_size` | Skip files larger than this, e.g. `500MB` |
| `filename_pattern` | Glob to filter filenames, e.g. `*.counts.*` |
| `subset` | Comma-separated sample IDs to restrict the download, e.g. `GSM123,GSM456` |
| `organism` | Filter by organism, e.g. `Homo sapiens` |
| `limit_files` | Maximum number of files to download |
| `raw` | Download raw files (flag, no value needed) |
| `timeout` | Download timeout in seconds (default: 3600) |
| `extra` | Any additional flags passed verbatim to `hapiq` |

> `file://` URIs are non-reproducible — the result depends on local filesystem state and cannot be replayed in CI or by others.

## Citation

See `CITATION.cff`.
