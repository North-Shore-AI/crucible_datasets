# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] - 2025-12-22

### Breaking Changes

This release reverts to the v0.3.0 codebase, removing the HuggingFace Hub integration that was added in v0.4.x. **Versions 0.4.0 and 0.4.1 are deprecated.**

### Removed

- **HuggingFace Hub Integration:**
  - Removed `hf_hub` dependency
  - Removed `explorer` dependency (Parquet support)
  - Removed `vix` dependency (image processing)
  - Removed `Source.HuggingFace` module
  - Removed `Format.Parquet` module
  - Removed `DatasetDict` and `IterableDataset` modules
  - Removed Features schema system
  - Removed streaming support
  - Removed vision/chat/code/preference/reasoning/rubric loaders
  - Removed `load_dataset/2` HuggingFace-style API

### Retained

- Core dataset management (GSM8K, HumanEval, MMLU loaders)
- CrucibleIR `DatasetRef` integration from v0.3.0
- Evaluation metrics (exact match, F1, BLEU, ROUGE)
- Dataset registry and metadata
- Result persistence and export (CSV, JSONL, Markdown, HTML)
- Sampling strategies (random, stratified, k-fold)
- Local JSONL file support
- Caching with version tracking

### Why This Change

The HuggingFace integration was experimental and added heavy dependencies (Explorer, Vix/libvips) that complicated installation. This library returns to its focused purpose: lightweight dataset management for AI research benchmarks within the Crucible framework.

---

## [0.4.1] - 2025-12-21 (DEPRECATED)

### Added

- **HuggingFace Parity API:** `load_dataset/2` with repo_id/config/split/streaming options
- **Data Discovery:** New `CrucibleDatasets.DataFiles` resolver using `HfHub.Api.list_repo_tree/2` and `dataset_splits/2`
- **Dataset Types:** DatasetDict and IterableDataset wired to the public API
- **Streaming:** JSONL streaming support; Parquet streaming supported with batch warning
- **Features + Images:** Features integrated into Dataset with Image decode via Vix/libvips
- **New Loaders:** Real MMLU, HumanEval, and vision datasets (caltech101, oxford_flowers102, oxford_iiit_pet, stanford_cars)
- **Examples/Docs:** New examples for `load_dataset`, DatasetDict, streaming, and vision; docs updated

### Changed

- **Registry + Loader Dispatcher:** Expanded to include all tinker datasets
- **Live Tests:** `mix test.live` uses `@tag :live`
- **Version:** 0.4.0 -> 0.4.1

## [0.4.0] - 2025-12-21 (DEPRECATED)

### Fixed

- **HuggingFace Source:** Fixed nil path handling in `filter_by_config/2` and `filter_by_split/2` - HuggingFace API returns files with `rfilename` key instead of `path`
- **Test Configuration:** Integration tests are now excluded by default to avoid slow network-dependent tests. Run with `mix test --include integration` to include them.

### Added

- **Source Abstraction Layer:**
  - New `Source` behaviour for data source abstraction
  - `Source.Local` - Local filesystem source with file listing and streaming
  - `Source.HuggingFace` - HuggingFace Hub source with download/stream support
  - Unified API: `list_files/2`, `download/3`, `stream/3`, `exists?/2`
  - Extensible design for future sources (S3, GCS, etc.)

- **Format Parser Layer:**
  - New `Format` behaviour for file format parsing
  - `Format.JSONL` - JSON Lines parser with streaming support
  - `Format.JSON` - JSON file parser
  - `Format.CSV` - CSV parser with header detection
  - `Format.Parquet` - Parquet parser via Explorer
  - Auto-detection of formats by file extension

- **Dataset Operations:**
  - `Dataset.map/2` - Transform each item
  - `Dataset.filter/2` - Filter items by predicate
  - `Dataset.shuffle/2` - Randomize order (with optional seed)
  - `Dataset.select/2` - Select specific columns
  - `Dataset.take/2`, `Dataset.skip/2` - Pagination
  - `Dataset.slice/3` - Slice with negative index support
  - `Dataset.batch/2` - Group into batches
  - `Dataset.concat/1,2` - Concatenate datasets
  - `Dataset.split/2` - Train/test splitting
  - `Dataset.shard/2` - Create shards for distributed processing
  - Column operations: `rename_column/3`, `add_column/3`, `remove_columns/2`
  - `Dataset.unique/2`, `Dataset.sort/2`, `Dataset.flatten/2`
  - Enumerable protocol for `for` comprehensions and Enum functions
  - Access behaviour for bracket notation (`dataset[0]`)

- **DatasetDict:**
  - Dictionary of splits (train/test/validation)
  - Python-like bracket access: `dd["train"]`
  - Operations across all splits: `map/2`, `filter/2`, `select/2`, `shuffle/2`
  - `flatten/1` - Combine all splits into single dataset
  - Enumerable protocol for iteration over splits

- **IterableDataset:**
  - Lazy, streaming dataset for memory-efficient processing
  - Lazy transformations: `map/2`, `filter/2`, `batch/2`
  - Buffered shuffle with seed support
  - Conversion: `from_stream/2`, `from_dataset/1`, `to_dataset/1`, `to_list/1`
  - Enumerable protocol for lazy consumption

- **Features Schema System:**
  - Type system for dataset columns
  - `Value` - Scalar types (int8-64, uint8-64, float16-64, string, bool, binary)
  - `ClassLabel` - Categorical with encode/decode
  - `Sequence` - Lists with fixed length support
  - `Image` - Image data with mode (RGB, L, RGBA)
  - `Audio` - Audio data with sample rate
  - Schema inference from dataset items
  - Value validation and casting

- **Enhanced Loaders:**
  - MMLU: HuggingFace integration
  - HumanEval: HuggingFace integration

### Changed

- Version bump from 0.3.0 to 0.4.0
- Loaders now use Source/Format abstractions internally
- All tests passing (282 tests, 0 failures)
- No dialyzer warnings

## [0.3.0] - 2025-11-26

### Added
- **CrucibleIR Integration:**
  - Added `crucible_ir` ~> 0.1.1 dependency for intermediate representation support
  - Added support for `CrucibleIR.DatasetRef` in `load/1` function
  - DatasetRef provides unified dataset references across Crucible framework components
  - Seamless integration: `CrucibleDatasets.load(%DatasetRef{name: :mmlu_stem, ...})`
- **Enhanced Documentation:**
  - Updated module documentation with DatasetRef usage examples
  - Added comprehensive test suite for DatasetRef functionality (220+ test cases)
  - Updated README with DatasetRef integration examples

### Changed
- Version bump from 0.2.0 to 0.3.0
- `CrucibleDatasets.Loader.load/2` now accepts `DatasetRef` struct in addition to atoms and strings
- Enhanced type specifications to include `DatasetRef.t()` in function signatures

## [0.2.0] - 2025-11-25

### Added
- **New Evaluation Metrics:**
  - BLEU score metric for machine translation and text generation evaluation
  - ROUGE score metrics (ROUGE-1, ROUGE-2, ROUGE-L) for summarization evaluation
  - Support for multiple ROUGE variants with precision, recall, and F1 scores
- **Dataset Registry:**
  - Centralized dataset registry with comprehensive metadata
  - Dataset discovery by domain, task type, difficulty, and tags
  - Search functionality for finding datasets by keyword
  - Dataset statistics and summary generation
- **Result Persistence:**
  - ResultStore module for persistent storage of evaluation results
  - Organized storage by date with searchable index
  - Query interface with filters (model, dataset, accuracy, date range)
  - Result management (save, load, delete, clear)
- **Export Functionality:**
  - CSV export for spreadsheet applications and data analysis
  - JSON Lines export for streaming processing
  - Markdown report generation with customizable formatting
  - HTML report generation with styling and theming options
  - Flexible export options (sorting, grouping, detail levels)
- **Enhanced API:**
  - Convenience delegates in main CrucibleDatasets module
  - `list_available()` - List all available datasets
  - `get_metadata/1` - Get dataset metadata
  - `save_result/2` - Save evaluation results
  - `load_result/1` - Load saved results
  - `query_results/1` - Query results with filters
  - `export_csv/3`, `export_jsonl/2`, `export_markdown/2`, `export_html/2`

### Changed
- Version bump from 0.1.0 to 0.2.0
- Enhanced Evaluator to support new metrics (`:bleu`, `:rouge`, `:rouge1`, `:rouge2`, `:rougel`)
- Expanded documentation with new features and examples
- Updated README with version 0.2.0

### Documentation
- Comprehensive design document at `docs/20251125/enhancement_design.md`
- Detailed architecture and implementation plans
- Enhanced examples for new features
- API documentation for all new modules

## [0.1.0] - 2025-10-07

### Added
- Initial release
- Centralized dataset management for AI evaluation research
- Unified interface for benchmark datasets (MMLU, HumanEval, GSM8K)
- Automatic caching with version tracking for fast access
- Comprehensive evaluation metrics (exact match, F1 score, custom metrics)
- Dataset sampling strategies (random, stratified, k-fold cross-validation)
- Support for custom datasets from local JSONL files
- Reproducibility features with deterministic sampling and version control

### Documentation
- Comprehensive README with examples
- API documentation for dataset loading and evaluation
- Usage examples for common research workflows
- Integration guide for research infrastructure libraries
