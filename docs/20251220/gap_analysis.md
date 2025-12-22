# CrucibleDatasets Gap Analysis (2025-12-20)

This gap analysis compares the current Elixir code against the subset required to run all
tinker cookbook experiments (tinker parity). Full parity gaps are noted separately.

**Last Updated:** 2025-12-21 (tinker-cookbook review complete)

## Target Architecture

The port targets a **2-package architecture**:

1. **hf_hub_ex** - Single shared core package (mirrors Python's huggingface_hub)
   - Contains: HfHub.Api, HfHub.FS, HfHub.Download, HfHub.Cache, HfHub.Auth
   - Used by both tinkex and crucible_datasets

2. **crucible_datasets** - Dataset library (depends on hf_hub_ex)
   - Contains: Dataset/DatasetDict/IterableDataset, Features, format parsers, media wrappers

## Current State (facts)
- ✅ **hf_hub_ex v0.1.1 is now integrated** - provides Hub API, downloads, caching, auth, tree listing, and extraction
- Fetcher.HuggingFace now uses HfHub for all hub operations (API, downloads, caching)
- Loaders cover all tinker datasets (MMLU, HumanEval, Reasoning, Rubric, Vision included).
- Loader and Registry APIs are wired for all tinker datasets.
- DatasetDict and IterableDataset are implemented.
- ✅ Download caching is now available via HfHub.Cache
- JSONL streaming is available via HfHub.Download.download_stream; extraction is wired via hf_hub_ex v0.1.1.
- Features system is integrated with Image decode via Vix/libvips.

## Gaps vs Tinker Parity (critical)

### 0) Foundation Package ✅ COMPLETE
- **hf_hub_ex v0.1.1 is now integrated**
  - ✅ HfHub.Api - dataset metadata, config/split enumeration
  - ✅ HfHub.FS - local filesystem abstraction with cache structure
  - ✅ HfHub.Download - file downloads with caching and streaming support
  - ✅ HfHub.Cache - file caching with LRU eviction and integrity validation
  - ✅ HfHub.Auth - token management
  - ✅ Extraction (zip, tar, gz, xz) implemented in hf_hub_ex v0.1.1

### 1) API Surface ✅ COMPLETE
- DatasetDict and IterableDataset implemented and returned from `load_dataset/2`
- Dataset methods: map/filter/select/shuffle/batch/concat implemented
- ✅ get_dataset_config_names available via `HfHub.Api.dataset_configs/2`

### 2) Data Discovery ✅ COMPLETE
- ✅ File listing via HfHub.Api.list_repo_tree/2
- ✅ Config/split discovery via DataFiles + dataset_splits/2
- ✅ Default config inference supported

### 3) Download, Cache, and Extraction ✅ COMPLETE
- ✅ Download caching via HfHub.Cache
- ✅ Downloads use content-addressed cache with LRU eviction
- ✅ Extraction pipeline wired via hf_hub_ex v0.1.1

### 4) Streaming ✅ COMPLETE (with Parquet limitation)
- ✅ JSONL streaming implemented with line buffering
- ⚠️ Parquet streaming uses batch iteration (no true lazy row groups)
- ✅ OpenThoughts can stream via `load_dataset/2` with `streaming: true`

### 5) Feature System ✅ COMPLETE
- ✅ Features schema (Value/ClassLabel/Sequence/Image)
- ✅ Dataset-level features integration + inference
- ✅ Image decode via Vix/libvips

### 6) Format Coverage ✅ COMPLETE (tinker scope)
- parquet/jsonl/json/csv supported
- Image decode supported via Vix/libvips

### 7) Dataset Coverage ✅ COMPLETE
- ✅ Fixed all repo id mismatches vs tinker requirements:
  - Math: hendrycks_math → EleutherAI/hendrycks_math
  - Math: deepmath → zwhe99/DeepMath-103K
  - Math: polaris → POLARIS-Project/Polaris-Dataset-53K
  - Preference: ultrafeedback → argilla/ultrafeedback-binarized-preferences
  - Preference: arena_140k → lmarena-ai/arena-human-preference-140k
  - Preference: tulu3_preference → allenai/llama-3.1-tulu-3-8b-preference-mixture
  - Preference: helpsteer3 config → "preference"
- ✅ Added Reasoning loader (OpenThoughts3, DeepMath reasoning)
- ✅ Added Rubric loader (Feedback-Collection)
- ✅ Fixed field access patterns to match tinker-cookbook:
  - Arena: now uses conversation_a/conversation_b (not prompt/answer_a/answer_b)
  - HelpSteer3: now uses context/response1/response2/overall_preference
  - UltraFeedback: now uses instruction/chosen_response/rejected_response
- ✅ MMLU and HumanEval load real data
- ✅ Vision datasets implemented (caltech101, flowers102, oxford_iiit_pet, stanford_cars)

### 8) Integration Gap ✅ COMPLETE
- ✅ crucible_datasets now depends on hf_hub v0.1.1
- ✅ Fetcher.HuggingFace refactored to use HfHub API
  - Uses HfHub.Api for file listing and dataset metadata
  - Uses HfHub.Download for cached file downloads
  - Uses HfHub.Cache for cache management
  - Added new functions: dataset_info, dataset_configs, cached?, cache_path, download_file_to_cache

## Full-Parity Gaps (optional later)
- Arrow IPC and memory-mapped tables
- PDF and NIfTI features
- Audio/video decoding
- Webdataset/audiofolder/videofolder/hdf5/xml/sql/spark

## Risk Areas
- ~~Building hf_hub_ex is the critical path~~ ✅ Complete - hf_hub_ex v0.1.1 integrated
- Parquet streaming remains limited (batch iteration only)
- HF config/split discovery variability across repos (fallbacks may need refinement)
