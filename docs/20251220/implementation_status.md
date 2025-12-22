# CrucibleDatasets Implementation Status

**Date:** 2025-12-20
**Version:** 0.4.1 (tinker parity)
**Updated:** 2025-12-21 (API parity, streaming, vision, features)

## Core Infrastructure
| Component | Status | Notes |
| --- | --- | --- |
| Dataset struct | OK | In-memory list of maps |
| hf_hub_ex integration | ✅ NEW | v0.1.1 integrated for Hub API, downloads, caching, tree listing, extraction |
| Cache | ✅ OK | Now uses HfHub.Cache (LRU eviction, integrity validation) |
| Fetcher.HuggingFace | ✅ OK | Refactored to use HfHub.Api + HfHub.Download |
| DataFiles | ✅ OK | Config/split resolution via list_repo_tree + dataset_splits |
| Features | ✅ OK | Value/ClassLabel/Sequence/Image with inference + decode |
| Media.Image | ✅ OK | Vix/libvips image decode |
| Sampler | OK | random/stratified/k_fold/train_test_split + shuffle/take/skip/filter |
| Evaluator | OK | exact_match, f1, bleu, rouge |
| Exporter | OK | csv/jsonl/markdown/html |
| ResultStore | OK | JSONL storage + query |

## API Surface
| Component | Status | Notes |
| --- | --- | --- |
| CrucibleDatasets.Loader | ✅ OK | All tinker datasets wired |
| Registry | ✅ OK | All tinker datasets listed |
| DatasetDict | ✅ OK | Split indexing + transforms |
| IterableDataset | ✅ OK | Streaming iterator + transforms |
| Dataset operations | ✅ OK | map/filter/select/take/skip/batch/concat |

## Loader Status
| Loader | Repo id in code | Real data | Notes |
| --- | --- | --- | --- |
| GSM8K | openai/gsm8k | Yes | JSONL via HF fetcher |
| Math: MATH-500 | HuggingFaceH4/MATH-500 | Yes | Parquet via HF fetcher |
| Math: Hendrycks | EleutherAI/hendrycks_math | Yes | ✅ Fixed to match tinker |
| Math: DeepMath | zwhe99/DeepMath-103K | Yes | ✅ Fixed to match tinker |
| Math: Polaris | POLARIS-Project/Polaris-Dataset-53K | Yes | ✅ Fixed to match tinker |
| Chat: Tulu-3-SFT | allenai/tulu-3-sft-mixture | Yes | Conversation parsing |
| Chat: No Robots | HuggingFaceH4/no_robots | Yes | Conversation parsing |
| Preference: HH-RLHF | Anthropic/hh-rlhf | Yes | chosen/rejected parsing |
| Preference: HelpSteer3 | nvidia/HelpSteer3 | Yes | ✅ Config "preference" now set |
| Preference: HelpSteer2 | nvidia/HelpSteer2 | Yes | single response + scores |
| Preference: UltraFeedback | argilla/ultrafeedback-binarized-preferences | Yes | ✅ Fixed to match tinker |
| Preference: Arena | lmarena-ai/arena-human-preference-140k | Yes | ✅ Fixed repo + field patterns |
| Preference: Tulu-3-Pref | allenai/llama-3.1-tulu-3-8b-preference-mixture | Yes | ✅ Fixed to match tinker |
| Reasoning: OpenThoughts3 | open-thoughts/OpenThoughts3-1.2M | Yes | ✅ NEW - chain-of-thought traces |
| Reasoning: DeepMath | zwhe99/DeepMath-103K | Yes | ✅ NEW - reasoning variant |
| Rubric: Feedback-Collection | prometheus-eval/Feedback-Collection | Yes | ✅ NEW - rubric-based evaluation |
| Code: DeepCoder | agentica-org/DeepCoder-Preview-Dataset | Yes | config handling supported |
| HumanEval | openai/openai_humaneval | Yes | Real HF data |
| MMLU | cais/mmlu | Yes | Real HF data |
| Vision: caltech101 | dpdl-benchmark/caltech101 | Yes | Image decode + ClassLabel |
| Vision: flowers102 | dpdl-benchmark/oxford_flowers102 | Yes | Image decode + ClassLabel |
| Vision: oxford_iiit_pet | dpdl-benchmark/oxford_iiit_pet | Yes | Image decode + ClassLabel |
| Vision: stanford_cars | tanganke/stanford_cars | Yes | Image decode + ClassLabel |

## Missing Datasets (tinker)
- None

## Tests
- Unit tests cover DataFiles, load_dataset, Dataset, DatasetDict, vision loader.
- Live tests are tagged with `:live` and excluded by default.

## Known Limitations
- Parquet streaming is limited (batch iteration; no true row-group streaming).
- Split matching still relies on repo conventions in some datasets.
