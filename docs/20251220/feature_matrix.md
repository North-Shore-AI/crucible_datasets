# Feature Matrix

This matrix tracks Python datasets features against full parity and tinker-cookbook usage.
Full parity is the target; the tinker column is informational for prioritization.

## Data Formats and Packaged Modules
| Format / Module | Python support | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- | --- |
| Parquet | Yes | Yes | Yes | Yes (Explorer) | No projection or pushdown |
| JSONL | Yes | Yes | Yes | Yes | Streaming supported |
| JSON | Yes | Maybe | Yes | Yes | Basic decode only |
| CSV | Yes | Maybe | Yes | Yes (simple parser) | Should use NimbleCSV |
| Text | Yes | No | Yes | No | Needed for text datasets |
| Arrow IPC | Yes | No | Yes | No | Requires arrow_ex |
| Webdataset | Yes | No | Yes | No | Full parity |
| ImageFolder | Yes | Yes | Yes | No | Required for vision datasets |
| AudioFolder | Yes | No | Yes | No | Full parity |
| VideoFolder | Yes | No | Yes | No | Full parity |
| PDF | Yes | No | Yes | No | Requires pdf_ex |
| NIfTI | Yes | No | Yes | No | Requires nifti_ex |
| HDF5 | Yes | No | Yes | No | Full parity |
| XML | Yes | No | Yes | No | Full parity |
| SQL / Spark | Yes | No | Yes | No | Full parity |

## Dataset Operations
| Operation | Python | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- | --- |
| load_dataset | Yes | Yes | Yes | ✅ Yes | DatasetDict + config/split discovery |
| get_dataset_config_names | Yes | Yes | Yes | ✅ Yes | HfHub.Api.dataset_configs |
| DatasetDict indexing | Yes | Yes | Yes | ✅ Yes | Implemented |
| IterableDataset | Yes | Yes | Yes | ✅ Yes | Implemented |
| map | Yes | Yes | Yes | ✅ Yes | Dataset.map/2 |
| filter | Yes | Yes | Yes | ✅ Yes | Dataset.filter/2 |
| shuffle | Yes | Yes | Yes | ✅ Yes | Dataset.shuffle/2 |
| select(range) | Yes | Yes | Yes | ✅ Yes | Dataset.select/2 |
| take / skip | Yes | Yes | Yes | ✅ Yes | Dataset.take/2, Dataset.skip/2 |
| batch | Yes | Yes | Yes | ✅ Yes | Dataset.batch/2 |
| concatenate_datasets | Yes | Yes | Yes | ✅ Yes | Dataset.concat/1 |
| from_list / from_pandas | Yes | Yes | Yes | ✅ Yes | Dataset.from_list/1 + from_dataframe/1 |
| save_to_disk / load_from_disk | Yes | No | Yes | No | Full parity |

## Source Abstraction (NEW)
| Component | Status | Notes |
| --- | --- | --- |
| Source behaviour | ✅ Yes | list_files, download, stream, exists? |
| Source.HuggingFace | ✅ Yes | Wraps hf_hub_ex |
| Source.Local | ✅ Yes | Local files/directories |
| Source.S3 | Future | AWS S3 buckets |
| Source.GCS | Future | Google Cloud Storage |
| Format behaviour | ✅ Yes | parse, parse_stream, handles? |
| Format.Parquet | ✅ Yes | Explorer-based |
| Format.JSONL | ✅ Yes | Streaming + eager parse |
| Format.JSON | ✅ Yes | Eager parse |
| Format.CSV | ✅ Yes | Eager parse |
| Loader macro | 🔲 Design | Common loader infrastructure |

## Caching and Streaming
| Feature | Python | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- | --- |
| Download cache | Yes | Yes | Yes | ✅ Yes | HfHub.Cache with LRU eviction |
| Dataset cache | Yes | Yes | Yes | Partial | Cache module exists but not wired |
| Streaming | Yes | Yes | Yes | ✅ Yes | JSONL streaming; Parquet batch limitation |
| Fingerprinting | Yes | No | Yes | No | Full parity |
| Column projection | Yes | Useful | Yes | No | Explorer supports columns |
| Predicate pushdown | Yes | Useful | Yes | No | Depends on Polars |

## Feature Types and Schemas
| Feature | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- |
| Message/Conversation | Yes | Yes | Yes (Types.*) | No schema validation |
| Comparison/LabeledComparison | Yes | Yes | Yes (Types.*) | No schema validation |
| Math item schema | Yes | Yes | Partial | Per-loader parsing only |
| Image feature | Yes | Yes | Yes | Vix/libvips decode supported |
| Audio/Video | No | Yes | No | Full parity |
| NIfTI feature | No | Yes | No | Full parity |
| PDF feature | No | Deferred | No | Explicitly deferred |
