# Python Module Inventory (datasets/src/datasets)

This document maps the HuggingFace datasets codebase to logical subsystems and proposed Elixir targets.
It is the source of truth for a full parity port.

## Entry Points and Orchestration
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| load.py | load_dataset, dataset resolution | dataset_module_factory, builder selection, split handling, streaming toggle | CrucibleDatasets.Hub + DatasetBuilder pipeline |
| builder.py | DatasetBuilder base classes | build/download/cache flow, split generation, fingerprinting | CrucibleDatasets.Builder + SplitPlanner |
| dataset_dict.py | DatasetDict for multi-split | dict-like wrapper with map/filter across splits | CrucibleDatasets.DatasetDict |
| iterable_dataset.py | IterableDataset streaming | lazy iteration, sharding, interleave | CrucibleDatasets.IterableDataset |
| arrow_dataset.py | Dataset class | map/filter/select/shuffle/cast/format/cache | CrucibleDatasets.Dataset (API parity layer) |
| splits.py | Split and split instructions | Split/NamedSplit/percent helpers | CrucibleDatasets.Splits |
| data_files.py | DataFiles patterns | file globbing, YAML-based split mapping | CrucibleDatasets.DataFiles |

## Download, Cache, and Hub
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| download/download_manager.py | DownloadManager | download, cache, extract, checksums | CrucibleDatasets.DownloadManager |
| download/streaming_download_manager.py | Streaming downloads | lazy HTTP stream, no cache | CrucibleDatasets.StreamingDownloadManager |
| hub.py | Hub utilities | repo id resolution, API helpers | CrucibleDatasets.Hub |
| fingerprint.py | Fingerprinting | cache invalidation hashing | CrucibleDatasets.Fingerprint (optional) |
| filesystems/* | fsspec backends | local, HTTP, S3, GCS, HDFS | CrucibleDatasets.FS (local + HTTP first) |

## IO and Packaged Modules
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| io/parquet.py | Parquet reader | schema inference, projection, pushdown | CrucibleDatasets.IO.Parquet (Explorer/Polars) |
| io/json.py | JSON/JSONL reader | stream + parse | CrucibleDatasets.IO.JSONL |
| io/csv.py | CSV reader | inference, dialects | CrucibleDatasets.IO.CSV (NimbleCSV) |
| io/text.py | Text reader | line-based | CrucibleDatasets.IO.Text |
| io/sql.py | SQL reader | SQLAlchemy integration | Out of scope for tinker |
| io/spark.py | Spark reader | pyspark integration | Out of scope for tinker |
| packaged_modules/* | Format loaders | csv/json/parquet/text/webdataset/imagefolder/etc | CrucibleDatasets.Packaged.* |

Packaged modules present in Python:
- csv, json, parquet, text, arrow
- webdataset, imagefolder, audiofolder, videofolder, pdffolder, niftifolder
- hdf5, xml, sql, spark, pandas, generator, eval, cache

## Features and Type System
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| features/features.py | Feature system | Value/ClassLabel/Sequence/etc | CrucibleDatasets.Features |
| features/image.py | Image feature | Pillow decode | MediaRef.Image (decode via media_ex) |
| features/audio.py | Audio feature | torchcodec decode | MediaRef.Audio (decode via media_ex) |
| features/video.py | Video feature | torchcodec decode | MediaRef.Video (decode via media_ex) |
| features/pdf.py | PDF feature | pdfplumber decode | MediaRef.Pdf (decode via pdf_ex) |
| features/nifti.py | NIfTI feature | nibabel decode | MediaRef.Nifti (decode via nifti_ex) |

## Dataset Core Utilities
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| table.py | Arrow table wrapper | memory mapping, slicing | Likely skip; Explorer alternative |
| arrow_reader.py | Arrow reader | row group reading, streaming | Optional |
| arrow_writer.py | Arrow writer | cache persistence | Optional |
| dataset_dict.py | DatasetDict ops | map/filter across splits | Required for tinker |

## Utils and Tooling
| Python module | Role | Key behaviors | Elixir target |
| --- | --- | --- | --- |
| utils/file_utils.py | file helpers | xopen, remote files | CrucibleDatasets.Utils.File |
| utils/extract.py | extraction | zip/tar/xz | CrucibleDatasets.Utils.Extract |
| utils/sharding.py | sharding | dataset sharding helpers | Optional |
| utils/metadata.py | metadata | dataset card parsing | Optional |
| utils/tqdm.py | progress | progress bars | Optional |
| commands/* | CLI | datasets-cli | Optional |
| search.py | dataset search | hub search | Optional |
| inspect.py | dataset info | splits/configs | Optional |

## Observations
- Most complexity is generic infrastructure: download/cache/extract, Arrow tables, streaming, and dataset ops.
- Dataset-specific scripts live in dataset repos on the Hub, not in this library.
- Full parity requires building the infra; adding datasets becomes straightforward once infra exists.
