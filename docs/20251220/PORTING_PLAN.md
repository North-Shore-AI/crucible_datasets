# PORTING PLAN: Tinker-Cookbook Parity for CrucibleDatasets

**Date:** 2025-12-20
**Status:** Planning (tinker parity)

## Executive Summary

Goal: implement the complete subset of HuggingFace datasets functionality required to run all
tinker cookbook experiments, including VLM image classification and OpenThoughts streaming.
This requires a dependency-first approach: build a small set of Elixir libraries and integrate
into CrucibleDatasets.

## Scope (Tinker Parity)
- Datasets API: load_dataset, Dataset, DatasetDict, IterableDataset
- Streaming, caching, extraction, file discovery
- Features system (Value/ClassLabel/Sequence) for dataset features
- Packaged formats: parquet/json/jsonl/csv + image datasets
- Media decode for VLM datasets (image decode required)

## Out of Scope (for this milestone)
- Arrow IPC and memory-mapped tables
- PDF and NIfTI features
- Audio/video decoding
- Webdataset/audiofolder/videofolder/hdf5/xml/sql/spark

## Architecture

The port follows a **2-package architecture**:

1. **hf_hub_ex** - Single shared core package (mirrors Python's huggingface_hub)
   - Contains: HfHub.Api, HfHub.Download, HfHub.Cache, HfHub.FS, HfHub.Auth
   - Used by both tinkex (training SDK) and crucible_datasets
   - Foundation for the broader HF ecosystem in Elixir

2. **crucible_datasets** - Dataset library (depends on hf_hub_ex)
   - Contains: Dataset/DatasetDict/IterableDataset, Features system, format parsers, media wrappers
   - Uses hf_hub_ex for all hub operations

See `docs/20251220/dependency_projects.md` for detailed architecture rationale.

## Phase Plan

### Phase 0: Align Current Code (1-2 weeks)
- Rewire `CrucibleDatasets.Loader` to include all existing loaders.
- Rebuild `CrucibleDatasets.Registry` to list the tinker dataset inventory.
- Fix repo id mismatches for tinker datasets.
- Make split/config handling consistent with HF patterns.

### Phase 1: Build hf_hub_ex ✅ COMPLETE (2025-12-21)
Built the single unified hf_hub_ex package containing all foundational capabilities:

**HfHub.Api** ✅ (dataset metadata and discovery)
- ✅ dataset list/search
- ✅ config enumeration (get_dataset_config_names → dataset_configs)
- 🔲 split enumeration (get_dataset_split_names) - not yet implemented
- ✅ file listing for repo + config
- ✅ dataset metadata and info (dataset_info)

**HfHub.FS** ✅ (filesystem abstraction)
- ✅ local file access with cache structure
- ✅ file path construction for cache
- ✅ cache directory management
- ✅ file locking for concurrent downloads

**HfHub.Download** ✅ (downloads and streaming)
- ✅ streaming read interface (download_stream)
- ✅ single file downloads with caching (hf_hub_download)
- ✅ snapshot downloads (snapshot_download)
- ✅ resume support for interrupted downloads

**HfHub.Cache** ✅ (content-addressed caching)
- ✅ download caching
- ✅ checksum validation (SHA256)
- ✅ file locking for concurrent access
- ✅ LRU eviction policy
- ✅ cache statistics and integrity validation
- 🔲 extraction (zip, tar, gz, bz2, xz) - not yet implemented

**HfHub.Auth** ✅ (token management)
- ✅ token storage and retrieval
- ✅ environment variable support (HF_TOKEN)
- ✅ config-based token
- ✅ whoami endpoint

**Deliverables:**
- ✅ Hex package: hf_hub v0.1.0
- ✅ Test coverage for all modules
- ✅ Examples for common use cases

### Phase 2: Integrate hf_hub_ex into crucible_datasets ✅ COMPLETE (2025-12-21)
- ✅ Add hf_hub dependency to crucible_datasets (v0.1.0)
- ✅ Refactor Fetcher.HuggingFace to use HfHub API
  - Uses HfHub.Api.list_files for file discovery
  - Uses HfHub.Download.hf_hub_download for cached downloads
  - Uses HfHub.Cache for cache queries
- ✅ New functions: dataset_info, dataset_configs, cached?, cache_path, download_file_to_cache
- 🔲 Extraction flows (pending hf_hub_ex extraction support)

### Phase 3: Source Abstraction (NEW)
Refactor architecture for source-agnostic design. See `architecture_review.md` for full design.

**Source Layer:**
- Define `Source` behaviour (list_files, download, stream, exists?)
- Implement `Source.HuggingFace` (wraps hf_hub_ex)
- Implement `Source.Local` (local files and directories)
- Future: `Source.S3`, `Source.GCS`, `Source.HTTP`

**Format Layer:**
- Define `Format` behaviour (parse, parse_stream, handles?)
- Implement `Format.Parquet`, `Format.JSONL`, `Format.JSON`, `Format.CSV`

**Loader Refactor:**
- Create `use CrucibleDatasets.Loader` macro
- Migrate existing loaders to use macro
- Loaders only define: schema, field mapping, validation

### Phase 4: Dataset Types + Operations
See `remaining_features_design.md` for detailed specs.

**DatasetDict:**
- Struct with `splits` map for split indexing
- Access protocol for `dataset["train"]` syntax
- Load returns DatasetDict when multiple splits available

**IterableDataset:**
- Lazy streaming for large datasets
- Transform chain (map/filter/batch/shuffle)
- Enumerable protocol for Enum compatibility

**Dataset Operations:**
- Add methods directly to Dataset: map, filter, shuffle, select, take, skip, batch, concat
- Deprecate Sampler module (or make it delegate to Dataset)

### Phase 5: Real Loaders
- Implement real MMLU loader (cais/mmlu, 57 configs)
- Implement real HumanEval loader (openai/openai_humaneval)
- Validate field mappings match HuggingFace schema

### Phase 6: Features + Streaming
**Features Schema:**
- Value (string/int/float/bool)
- ClassLabel (names, int2str, str2int)
- Sequence (nested feature)
- Image (decode flag, mode)

**Streaming:**
- JSONL streaming via File.stream + Format.JSONL.parse_stream
- Parquet chunked reads via Explorer

### Phase 7: Media (image-only)
- MediaRef struct (path, bytes, mime, metadata)
- Image decode via Vix/libvips
- Tensor conversion via Nx
- Integration with Features.Image

## Optional Full-Parity Phases (later)
- arrow_ex (Arrow IPC, memory-mapped tables)
- pdf_ex, nifti_ex (specialized media formats)
- audio/video decoding (extend media support)
- additional packaged modules (webdataset, hdf5, xml, etc.)
- compression_ex (zstd/lz4 - can be added to hf_hub_ex if needed)

## Dependencies and System Requirements
- See `docs/20251220/library_and_system_deps.md`.

## Validation
- See `docs/20251220/validation_plan.md`.

## Risks
- Parquet streaming is the highest-risk technical component for tinker parity.
- Image decoding is required for VLM recipes.
- Dataset repo quirks require robust config/split discovery.

