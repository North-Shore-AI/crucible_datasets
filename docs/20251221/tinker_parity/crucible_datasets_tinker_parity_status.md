# CrucibleDatasets Status and Integration Plan (Tinker Parity)

Date: 2025-12-21
Scope: Minimum complete subset required to run all tinker cookbook experiments.
Status: Implemented (v0.4.1)

## Current State (in repo)

Implemented
- Fetcher.HuggingFace (hf_hub integration for parquet/jsonl/json/csv)
- DataFiles resolver for config/split discovery
- Loaders: GSM8K, Math, Chat, Preference, Code, Reasoning, Rubric, Vision (real HF data)
- MMLU + HumanEval real loaders
- DatasetDict + IterableDataset with streaming
- Features schema + Image decode (Vix/libvips)
- Sampler, Evaluator, Exporter, ResultStore

## Dependency Integration Plan

hf_hub_ex (hf_hub) is fully integrated as the HF client. DataFiles, DatasetDict,
IterableDataset, and Features modules are implemented in crucible_datasets.

## Dataset Coverage Fixes (tinker parity)

Repo id mismatches to correct:
- Hendrycks MATH: EleutherAI/hendrycks_math
- DeepMath: zwhe99/DeepMath-103K
- Polaris: POLARIS-Project/Polaris-Dataset-53K
- UltraFeedback: argilla/ultrafeedback-binarized-preferences
- Arena: lmarena-ai/arena-human-preference-140k
- Tulu preference: allenai/llama-3.1-tulu-3-8b-preference-mixture

Add missing datasets:
- Completed (OpenThoughts3, Feedback-Collection, and vision datasets implemented)

## API Parity Required by Tinker
- load_dataset(name, config, split) ✅
- DatasetDict indexing: dataset["train"] ✅
- get_dataset_config_names(name) ✅
- map/filter/select/shuffle/take/skip/batch ✅
- concatenate_datasets ✅
- Dataset.from_list / from_dataframe ✅

## Image Support Requirements (VLM)
- Provide image column values as either:
  - %{bytes: binary(), path: string()} or
  - a decoded image struct from media_ex
- Provide ClassLabel metadata in dataset.features

## Recommended Sequencing
1. Wire Loader/Registry to all loaders and fix repo ids.
2. Integrate hf_hub_ex for config + tree + download + streaming (v0.1.1 ready).
3. Implement DatasetDict and IterableDataset.
4. Implement Features + ClassLabel + MediaRef.Image.
5. Add OpenThoughts and vision dataset loaders.
