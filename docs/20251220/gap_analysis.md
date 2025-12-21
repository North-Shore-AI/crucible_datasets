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
- ✅ **hf_hub_ex v0.1.0 is now integrated** - provides Hub API, downloads, caching, auth
- Fetcher.HuggingFace now uses HfHub for all hub operations (API, downloads, caching)
- Loaders exist for gsm8k, math, chat, preference, and code. MMLU and HumanEval are synthetic.
- Loader and Registry APIs are still wired only for mmlu/humaneval/gsm8k.
- Dataset is an in-memory list of maps; no DatasetDict or IterableDataset.
- ✅ Download caching is now available via HfHub.Cache
- No extraction, no streaming (beyond what HfHub.Download provides).

## Gaps vs Tinker Parity (critical)

### 0) Foundation Package ✅ COMPLETE
- **hf_hub_ex v0.1.0 is now integrated**
  - ✅ HfHub.Api - dataset metadata, config/split enumeration
  - ✅ HfHub.FS - local filesystem abstraction with cache structure
  - ✅ HfHub.Download - file downloads with caching and streaming support
  - ✅ HfHub.Cache - file caching with LRU eviction and integrity validation
  - ✅ HfHub.Auth - token management
  - 🔲 Extraction (zip, tar, gz, xz) - not yet implemented in hf_hub_ex

### 1) API Surface
- Missing DatasetDict and IterableDataset
- No dataset methods: map/filter/select/shuffle/batch/concat
- ✅ get_dataset_config_names now available via `HfHub.Api.dataset_configs/2`

### 2) Data Discovery
- ✅ File listing now via HfHub.Api.list_files
- Split/config matching uses heuristics (could be improved)
- No DataFiles pattern resolver (future enhancement)

### 3) Download, Cache, and Extraction
- ✅ Download caching now works via HfHub.Cache
- ✅ Downloads use content-addressed cache with LRU eviction
- 🔲 Extraction pipeline for zip/tar/gz/xz not yet implemented

### 4) Streaming
- ✅ HfHub.Download.download_stream provides basic streaming
- No streaming parse for JSONL or Parquet (need lazy iterators)
- OpenThoughts requires streaming (partially addressed)

### 5) Feature System
- No features schema (Value/ClassLabel/Sequence)
- No dataset-level schema/validation
- Image feature support missing (needed for VLM)

### 6) Format Coverage
- Only parquet/jsonl/json/csv
- Image datasets require image decode support

### 7) Dataset Coverage ✅ MOSTLY COMPLETE
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
- MMLU and HumanEval still synthetic
- 🔲 Missing vision datasets (caltech101, flowers102, oxford_iiit_pet, stanford_cars)

### 8) Integration Gap ✅ COMPLETE
- ✅ crucible_datasets now depends on hf_hub v0.1.0
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
- ~~Building hf_hub_ex is the critical path~~ ✅ Complete - hf_hub_ex v0.1.0 integrated
- Parquet streaming and large dataset handling (Explorer lazy scan needed)
- Image decode integration for VLM recipes (Vix integration pending)
- HF config/split discovery variability (heuristics may need refinement)
- File extraction for compressed archives (not yet in hf_hub_ex)

