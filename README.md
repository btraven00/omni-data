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

### `uri` and `uri_type`

A `uri` can point at a single file or at a directory of files. Which one is
inferred: an `http(s)` URI is a directory when it ends in `/`, and a `file://`
path is whatever it happens to be on disk.

`uri_type` states it outright instead — `file` or `directory` — and the run
fails if the URI is not that type:

```yaml
    parameters:
      - uri: "https://example.org/datasets/pbmc3k/"
        uri_type: directory
```

The inference is one character wide, which is the reason to declare it. Drop
the trailing slash in an edit and the fetch does not fail: the server answers
with its index page, that HTML is saved under the dataset's name, and the
stage's declared outputs go missing several steps later. `uri_type: directory`
turns that into an error at the fetch.

Directory mode needs the server to expose a **machine-readable JSON listing**
of the directory — there is no HTML scraping. Both common static servers can:

```
# Caddy
example.org {
    root * /srv/datasets
    file_server browse          # serves JSON to Accept: application/json
}
```

```nginx
# nginx
location /datasets/ {
    autoindex on;
    autoindex_format json;
}
```

Object stores that return an XML listing (plain S3 buckets over `https://`) do
not work this way; a directory behind them needs a JSON-listing front end.

`uri_type: directory` also requires a `hapiq` new enough to have `--directory`.
`envs/omni-data.yml` pins one on purpose: `hapiq *` resolves by version string
rather than by date and can land on an older build without the flag.

## Parameters

| Parameter | Description |
|-----------|-------------|
| `source` | Repository to download from: `geo`, `zenodo`, `figshare`, `sra`, `ensembl`, `vcp`, `scperturb`, `biostudies`, `hca`, `experimenthub`, `scanpy` |
| `accession` | Accession ID within the source repository |
| `uri` | URI to fetch directly — `https://`, `http://`, or `file:///` (mutually exclusive with `source`/`accession`) |
| `uri_type` | What `uri` points at: `file` or `directory`. Optional; inferred when omitted. Declaring it makes a mismatch an error instead of a silent wrong fetch |
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
