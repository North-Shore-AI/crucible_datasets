# CrucibleDatasets Implementation Status

**Date:** 2025-12-20
**Version:** 0.3.0 (code reality audit)
**Updated:** 2025-12-21 (hf_hub integration, tinker-cookbook alignment)

## Core Infrastructure
| Component | Status | Notes |
| --- | --- | --- |
| Dataset struct | OK | In-memory list of maps |
| hf_hub_ex integration | ✅ NEW | v0.1.0 integrated for Hub API, downloads, caching |
| Cache | ✅ OK | Now uses HfHub.Cache (LRU eviction, integrity validation) |
| Fetcher.HuggingFace | ✅ OK | Refactored to use HfHub.Api + HfHub.Download |
| Sampler | OK | random/stratified/k_fold/train_test_split + shuffle/take/skip/filter |
| Evaluator | OK | exact_match, f1, bleu, rouge |
| Exporter | OK | csv/jsonl/markdown/html |
| ResultStore | OK | JSONL storage + query |

## API Surface
| Component | Status | Notes |
| --- | --- | --- |
| CrucibleDatasets.Loader | Partial | Only mmlu/humaneval/gsm8k wired |
| Registry | Partial | Only mmlu/humaneval/gsm8k listed |
| DatasetDict | Missing | Required for split indexing |
| IterableDataset | Missing | Required for streaming |
| Dataset operations | Partial | Only via Sampler helpers |

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
| Code: DeepCoder | agentica-org/DeepCoder-Preview-Dataset | Yes | config handling missing |
| HumanEval | openai/human-eval | No | Synthetic only |
| MMLU | cais/mmlu | No | Synthetic only |

## Missing Datasets (tinker)
- Vision datasets (caltech101, flowers102, oxford_iiit_pet, stanford_cars)

## Tests
- Unit tests exist for Sampler, Evaluator, Fetcher, and loader parsing.
- Integration tests exist but are network-gated; not run by default.

## Known Limitations
- ~~No DataFiles/config enumeration~~ ✅ Config enumeration now via HfHub.Api.dataset_configs
- Split matching is still heuristic-based.
- ~~No download cache~~ ✅ Now uses HfHub.Cache with LRU eviction
- ✅ Basic streaming available via HfHub.Download.download_stream
- No DatasetDict or IterableDataset.
- No media decoding (images/audio/video).
- No file extraction (zip/tar/gz/xz).

