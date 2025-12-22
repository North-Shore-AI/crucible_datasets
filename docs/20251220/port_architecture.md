# CrucibleDatasets Port Architecture

**Date:** 2025-12-20
**Status:** Updated after full audit

## Python datasets Architecture (reference)

```
load_dataset
  -> dataset_module_factory (load.py)
  -> DatasetBuilder (builder.py)
       -> DownloadManager (download_manager.py)
       -> DataFiles + Splits (data_files.py, splits.py)
       -> Arrow tables (table.py, arrow_reader.py)
  -> Dataset / DatasetDict (arrow_dataset.py, dataset_dict.py)
  -> IterableDataset for streaming (iterable_dataset.py)
  -> Features system (features/*.py)
```

Core complexity lives in download/cache/extract, Arrow tables, streaming, and dataset ops.

## Current Elixir Architecture (today)

```
CrucibleDatasets.load_dataset
  -> DataFiles (config + split discovery)
  -> HfHub.Download + Format.parse
  -> Dataset | DatasetDict | IterableDataset

Loader.<dataset>
  -> Fetcher.HuggingFace (list files, download, parse)
  -> Dataset struct (list of maps)

Sampler / Evaluator / Exporter / ResultStore are separate modules.
```

## Target Elixir Architecture (tinker subset + full parity)

```
CrucibleDatasets.load_dataset
  -> DatasetResolver (Hub vs local)
  -> DataFiles (config + split discovery)
  -> DownloadManager
       -> download cache + extraction
  -> FileReader (parquet/jsonl/json/csv)
  -> DatasetBuilder (dataset-specific parse/adapt)
  -> Dataset or IterableDataset
  -> DatasetDict for multi-split
```

### Component Mapping
- Hub client: `CrucibleDatasets.Hub` (wrap HF API)
- DataFiles: `CrucibleDatasets.DataFiles` (split/config mapping)
- Download manager: `CrucibleDatasets.DownloadManager`
- Streamed downloads: `CrucibleDatasets.StreamingDownloadManager`
- Dataset ops: `CrucibleDatasets.Dataset` (API parity layer)
- DatasetDict: `CrucibleDatasets.DatasetDict`
- IterableDataset: `CrucibleDatasets.IterableDataset`
- Features: `CrucibleDatasets.Features` (optional for full parity)

## Streaming Strategy
- JSONL: true streaming via File.stream!/Stream.resource
- Parquet: evaluate Explorer/Polars lazy scan or row-group iteration
- If Parquet streaming is not viable, fall back to chunked reads with bounded memory

## Media Strategy
- Default: MediaRef struct with path/bytes metadata
- Optional decode: Vix (images), ffmpeg via Membrane/FFmpex (audio/video)
