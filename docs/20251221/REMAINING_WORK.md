# Remaining Work for Tinker Parity

**Date:** 2025-12-21
**Python Reference:** `./datasets/` (HuggingFace datasets Python library)
**Status:** Comprehensive gap analysis

---

## Executive Summary

| Category | Priority | Effort | Items |
|----------|----------|--------|-------|
| Core API Gaps | COMPLETE | 0 days | 0 |
| Missing Loaders | COMPLETE | 0 days | 0 |
| Streaming Support | COMPLETE | 0 days | 0 |
| Image Support | COMPLETE | 0 days | 0 |
| Operations & Types | COMPLETE | 0 days | 0 |
| **Total** | - | **0 days** | 0 |

---

**Status Update (2025-12-21):** All items in this checklist are implemented in v0.4.1. The
sections below are preserved for historical context.

## CRITICAL: Core API Gaps (Completed)

### 1. load_dataset Function [CRITICAL]

**Current:** `Loader.load` only handles atom names, returns Dataset
**Needed:** Full HuggingFace-compatible API

**Requirements:**
- Accept repo_id string (e.g., "openai/gsm8k")
- Accept split parameter (:train, :test, "validation")
- Accept config/name parameter for multi-config datasets
- Return DatasetDict when split=nil (all splits)
- Return Dataset when split is specified
- Support `streaming: true` option (returns IterableDataset)

**Files to modify:**
- `lib/crucible_datasets.ex` (create main API)
- `lib/dataset_manager/loader.ex`

### 2. Split and Config Discovery [CRITICAL]

**Current:** Hardcoded split handling in individual loaders
**Needed:** Dynamic split/config enumeration

**Requirements:**
- Use `HfHub.Api.dataset_configs/2` to get configs
- Use `HfHub.Api.dataset_splits/2` when dataset_infos.json is available
- Use `HfHub.Api.list_repo_tree/2` (hf_hub v0.1.1) for split/config inference on large repos
- Infer splits from file listing (train, test, validation patterns)
- Auto-detect split from parquet filenames
- Fallback to "train" if no split specified

**Implementation:**
- Create `CrucibleDatasets.DataFiles` module
- Parse repo file tree to identify splits
- Match config names to subdirectories

### 3. DatasetDict Split Indexing [CRITICAL]

**Current:** DatasetDict implemented but not returned from load
**Needed:** Wire load to return DatasetDict

**Requirements:**
- When split=nil, load all available splits
- Return DatasetDict with split names as keys
- Support `dataset["train"]` syntax (already via Access protocol)

---

## HIGH: Missing Loaders (Completed)

### 4. Real MMLU Loader [HIGH]

**Current:** Synthetic data only
**Needed:** Load from cais/mmlu with 57 configs

**Repo:** cais/mmlu
**Configs:** 57 subjects (abstract_algebra, anatomy, astronomy, ..., world_religions)
**Format:** Parquet
**Splits:** auxiliary_train, test, validation, dev

**Fields:**
- question: string
- choices: list[string] (A, B, C, D options)
- answer: int (0-3 index)
- subject: string

**File:** `lib/dataset_manager/loader/mmlu.ex`
**Effort:** 2-3 hours

### 5. Real HumanEval Loader [HIGH]

**Current:** Synthetic data only
**Needed:** Load from openai/openai_humaneval

**Repo:** openai/openai_humaneval
**Format:** Parquet
**Splits:** test

**Fields:**
- task_id: string (e.g., "HumanEval/0")
- prompt: string (function signature + docstring)
- canonical_solution: string
- test: string (unit tests)
- entry_point: string (function name)

**File:** `lib/dataset_manager/loader/human_eval.ex`
**Effort:** 1-2 hours

### 6. Vision Dataset Loaders [HIGH]

**Current:** Not implemented
**Needed:** 4 vision datasets for VLM training

| Dataset | Repo ID | Classes | Effort |
|---------|---------|---------|--------|
| caltech101 | dpdl-benchmark/caltech101 | 102 | 1h |
| flowers102 | dpdl-benchmark/oxford_flowers102 | 102 | 1h |
| oxford_iiit_pet | dpdl-benchmark/oxford_iiit_pet | 37 | 1h |
| stanford_cars | tanganke/stanford_cars | 196 | 1h |

**Files to create:**
- `lib/dataset_manager/loader/vision.ex` (generic)

---

## HIGH: Streaming Support (Completed)

### 7. JSONL Streaming [HIGH]

**Current:** Full file read only
**Needed:** Line-by-line streaming for large datasets

**Use case:** OpenThoughts3-1.2M (1.2 million examples)

**Requirements:**
- Stream lines from file or HTTP
- Parse each line as JSON lazily
- Wrap in IterableDataset
- Support map/filter/take/skip operations

**Files to modify:**
- `lib/dataset_manager/format/jsonl.ex`

### 8. Parquet Streaming [HIGH]

**Current:** Explorer.DataFrame.from_parquet reads full file
**Needed:** Lazy row-by-row or batch iteration

**Challenge:** Explorer doesn't support lazy Parquet reading
**Recommendation:** Document as known limitation, use full reads for now

**Files affected:**
- `lib/dataset_manager/format/parquet.ex`

---

## MEDIUM: Image Support (Completed)

### 9. Image Decode Integration [MEDIUM]

**Current:** Image feature defined, but no decode implementation
**Needed:** Vix integration for image decoding

**Requirements:**
- Accept image bytes or path in dataset
- Decode using Vix (libvips wrapper)
- Return decoded image or keep as bytes based on decode: flag
- Support common formats: JPEG, PNG, BMP, WEBP

**Dependencies:**
- Add `vix` to mix.exs dependencies
- System requirement: libvips

**Files to create:**
- `lib/dataset_manager/media/image.ex`

### 10. Features Integration with Datasets [MEDIUM]

**Current:** Features module exists but not used in Dataset struct
**Needed:** Dataset.features field with schema validation

**Requirements:**
- Add `features` field to Dataset struct
- Auto-infer features from first item if not provided
- Validate items against features schema
- Cast values to match schema types

**Files to modify:**
- `lib/dataset_manager/dataset.ex`

---

## MEDIUM: Dataset Operations (Completed)

### 11. Wire Dataset Methods to Loader [MEDIUM]

**Current:** Dataset operations exist but Sampler is still separate
**Status:** Dataset already has map, filter, shuffle, select, take, skip, batch, concat

**Tinker operations checklist:**
- [x] .shuffle(seed:) - Dataset.shuffle/2
- [x] .filter(fn) - Dataset.filter/2
- [x] .select(columns) - Dataset.select/2
- [x] .take(n) - Dataset.take/2
- [x] .skip(n) - Dataset.skip/2
- [x] .map(fn) - Dataset.map/2
- [x] .batch(size) - Dataset.batch/2
- [x] concatenate_datasets - Dataset.concat/1
- [x] .select(range) - Index-based select added
- [x] Dataset.from_list/1 - Implemented
- [x] Dataset.from_dataframe/1 - Implemented (Explorer integration)

### 12. get_dataset_config_names [MEDIUM]

**Current:** Available via HfHub.Api.dataset_configs/2
**Needed:** Expose as CrucibleDatasets.get_dataset_config_names/1

---

## LOW: Registry & Polish (Completed)

### 13. Update Loader Repo IDs [LOW]

**Current:** Some loaders have outdated repo IDs
**Status:** Most already fixed per implementation_status.md

**Remaining to verify:**
- EleutherAI/hendrycks_math vs hendrycks/competition_math
- agentica-org/DeepCoder-Preview-Dataset configs

### 14. Wire All Loaders to Registry [LOW]

**Current:** Registry only lists mmlu, mmlu_stem, humaneval, gsm8k
**Needed:** All 18+ datasets

**Datasets to add:**
- Math: MATH-500, Hendrycks, DeepMath, Polaris
- Chat: Tulu-3-SFT, No Robots
- Preference: HH-RLHF, HelpSteer2, HelpSteer3, UltraFeedback, Arena, Tulu-3-Pref
- Code: DeepCoder
- Reasoning: OpenThoughts3
- Rubric: Feedback-Collection
- Vision: caltech101, flowers102, oxford_iiit_pet, stanford_cars

### 15. Wire All Loaders to Loader Dispatcher [LOW]

**Current:** Loader.load only dispatches mmlu, humaneval, gsm8k
**Needed:** All loaders

### 16. Config Handling in Loaders [LOW]

**Current:** Most loaders ignore config parameter
**Needed:** Pass config to HF fetcher

**Affected loaders:**
- DeepCoder (4 configs: primeintellect, taco, lcbv5, codeforces)
- HelpSteer3 (config: "preference")
- MMLU (57 subject configs)

### 17. Error Handling Improvements [LOW]

- Better error messages for missing datasets
- Validate split exists before fetching
- Retry logic for network failures
- Cache invalidation on corruption

### 18. Testing Coverage [LOW]

- Add tests for DatasetDict split indexing
- Add tests for IterableDataset streaming
- Add tests for Features validation
- Integration tests for each loader with real HF data

---

## Summary Checklist

**CRITICAL (blocks tinker):**
- [x] 1. load_dataset function with split/config support
- [x] 2. Split and config discovery
- [x] 3. DatasetDict return from load

**HIGH (core functionality):**
- [x] 4. Real MMLU loader
- [x] 5. Real HumanEval loader
- [x] 6. Vision dataset loaders (4 datasets)
- [x] 7. JSONL streaming
- [x] 8. Parquet streaming (documented limitation)

**MEDIUM (full feature parity):**
- [x] 9. Image decode with Vix
- [x] 10. Features integration with Dataset
- [x] 11. Complete Dataset operations (from_list, from_dataframe, select by range)
- [x] 12. get_dataset_config_names helper

**LOW (polish):**
- [x] 13. Repo ID corrections
- [x] 14. Registry expansion
- [x] 15. Loader dispatcher expansion
- [x] 16. Config handling
- [x] 17. Error handling
- [x] 18. Testing

**Total items:** 0
**Estimated effort:** 0 days (completed)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
