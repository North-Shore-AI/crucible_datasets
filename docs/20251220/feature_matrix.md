# Feature Matrix

This matrix tracks Python datasets features against full parity and tinker-cookbook usage.
Full parity is the target; the tinker column is informational for prioritization.

## Data Formats and Packaged Modules
| Format / Module | Python support | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- | --- |
| Parquet | Yes | Yes | Yes | Yes (Explorer) | No projection or pushdown |
| JSONL | Yes | Yes | Yes | Yes | No streaming yet |
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
| load_dataset | Yes | Yes | Yes | Partial | No DatasetDict/config enumeration |
| get_dataset_config_names | Yes | Yes | Yes | ✅ Yes | HfHub.Api.dataset_configs |
| DatasetDict indexing | Yes | Yes | Yes | 🔲 Design | See remaining_features_design.md |
| IterableDataset | Yes | Yes | Yes | 🔲 Design | See remaining_features_design.md |
| map | Yes | Yes | Yes | 🔲 Design | Add to Dataset struct |
| filter | Yes | Yes | Yes | Sampler.filter | Add to Dataset struct |
| shuffle | Yes | Yes | Yes | Sampler.shuffle | Add to Dataset struct |
| select(range) | Yes | Yes | Yes | 🔲 Design | Add to Dataset struct |
| take / skip | Yes | Yes | Yes | Sampler.take/skip | Add to Dataset struct |
| batch | Yes | Yes | Yes | 🔲 Design | Add to Dataset struct |
| concatenate_datasets | Yes | Yes | Yes | 🔲 Design | Add Dataset.concat |
| from_list / from_pandas | Yes | Yes | Yes | Partial | Dataset.new works |
| save_to_disk / load_from_disk | Yes | No | Yes | No | Full parity |

## Source Abstraction (NEW)
| Component | Status | Notes |
| --- | --- | --- |
| Source behaviour | 🔲 Design | list_files, download, stream, exists? |
| Source.HuggingFace | 🔲 Design | Wraps hf_hub_ex |
| Source.Local | 🔲 Design | Local files/directories |
| Source.S3 | Future | AWS S3 buckets |
| Source.GCS | Future | Google Cloud Storage |
| Format behaviour | 🔲 Design | parse, parse_stream, handles? |
| Format.Parquet | Partial | Explorer-based, needs behaviour |
| Format.JSONL | Partial | Needs behaviour wrapper |
| Format.JSON | Partial | Needs behaviour wrapper |
| Format.CSV | Partial | Needs behaviour wrapper |
| Loader macro | 🔲 Design | Common loader infrastructure |

## Caching and Streaming
| Feature | Python | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- | --- |
| Download cache | Yes | Yes | Yes | ✅ Yes | HfHub.Cache with LRU eviction |
| Dataset cache | Yes | Yes | Yes | Partial | Cache module exists but not wired |
| Streaming | Yes | Yes | Yes | 🔲 Design | IterableDataset + Format.parse_stream |
| Fingerprinting | Yes | No | Yes | No | Full parity |
| Column projection | Yes | Useful | Yes | No | Explorer supports columns |
| Predicate pushdown | Yes | Useful | Yes | No | Depends on Polars |

## Feature Types and Schemas
| Feature | Required for tinker | Required for full parity | Current Elixir | Notes |
| --- | --- | --- | --- | --- |
| Message/Conversation | Yes | Yes | Yes (Types.*) | No schema validation |
| Comparison/LabeledComparison | Yes | Yes | Yes (Types.*) | No schema validation |
| Math item schema | Yes | Yes | Partial | Per-loader parsing only |
| Image feature | Yes | Yes | No | Required for VLM datasets |
| Audio/Video | No | Yes | No | Full parity |
| NIfTI feature | No | Yes | No | Full parity |
| PDF feature | No | Deferred | No | Explicitly deferred |
