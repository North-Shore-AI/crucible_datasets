# Dataset Coverage Gaps

**Date:** 2025-12-21
**Scope:** Tinker-cookbook dataset requirements
**Python Reference:** `./datasets/` (HuggingFace datasets Python library)

---

## Coverage Status Matrix

| Dataset | Domain | Repo ID | Real HF? | Synthetic? | Missing? | Loader File | Notes |
|---------|--------|---------|----------|------------|----------|-------------|-------|
| **GSM8K** | Math | openai/gsm8k | Yes | No | No | gsm8k.ex | JSONL, working |
| **MATH-500** | Math | HuggingFaceH4/MATH-500 | Yes | No | No | math.ex | Parquet, working |
| **Hendrycks MATH** | Math | EleutherAI/hendrycks_math | Yes | No | No | math.ex | Fixed repo ID |
| **DeepMath** | Math | zwhe99/DeepMath-103K | Yes | No | No | math.ex | 103K examples |
| **Polaris** | Math | POLARIS-Project/Polaris-Dataset-53K | Yes | No | No | math.ex | 53K examples |
| **Tulu-3-SFT** | Chat | allenai/tulu-3-sft-mixture | Yes | No | No | chat.ex | Conversations |
| **No Robots** | Chat | HuggingFaceH4/no_robots | Yes | No | No | chat.ex | Conversations |
| **HH-RLHF** | Preference | Anthropic/hh-rlhf | Yes | No | No | preference.ex | chosen/rejected |
| **HelpSteer2** | Preference | nvidia/HelpSteer2 | Yes | No | No | preference.ex | Response scoring |
| **HelpSteer3** | Preference | nvidia/HelpSteer3 | Yes | No | No | preference.ex | Config: preference |
| **UltraFeedback** | Preference | argilla/ultrafeedback-binarized-preferences | Yes | No | No | preference.ex | Fixed repo ID |
| **Arena-140k** | Preference | lmarena-ai/arena-human-preference-140k | Yes | No | No | preference.ex | Fixed repo ID |
| **Tulu-3-Pref** | Preference | allenai/llama-3.1-tulu-3-8b-preference-mixture | Yes | No | No | preference.ex | Fixed repo ID |
| **DeepCoder** | Code | agentica-org/DeepCoder-Preview-Dataset | Yes | No | No | code.ex | 4 configs |
| **OpenThoughts3** | Reasoning | open-thoughts/OpenThoughts3-1.2M | Yes | No | No | reasoning.ex | Needs streaming |
| **Feedback-Collection** | Rubric | prometheus-eval/Feedback-Collection | Yes | No | No | rubric.ex | Rubric parsing |
| **MMLU** | Knowledge | cais/mmlu | Yes | No | No | mmlu.ex | Real HF data |
| **HumanEval** | Code | openai/openai_humaneval | Yes | No | No | human_eval.ex | Real HF data |
| **caltech101** | Vision | dpdl-benchmark/caltech101 | Yes | No | No | vision.ex | Implemented |
| **flowers102** | Vision | dpdl-benchmark/oxford_flowers102 | Yes | No | No | vision.ex | Implemented |
| **oxford_iiit_pet** | Vision | dpdl-benchmark/oxford_iiit_pet | Yes | No | No | vision.ex | Implemented |
| **stanford_cars** | Vision | tanganke/stanford_cars | Yes | No | No | vision.ex | Implemented |

---

## Summary Statistics

**Total datasets required:** 22

**Coverage:**
- Real HF fetch working: 22 (100%)
- Synthetic only: 0 (0%)
- Missing: 0 (0%)

---

## Synthetic-Only Datasets (HIGH PRIORITY)

None.

---

## Missing Datasets (HIGH PRIORITY)

None.

---

## Repo ID Corrections

### Confirmed Correct

These repo IDs were verified against tinker_requirements.md:
- GSM8K: openai/gsm8k
- DeepMath: zwhe99/DeepMath-103K
- Polaris: POLARIS-Project/Polaris-Dataset-53K
- UltraFeedback: argilla/ultrafeedback-binarized-preferences
- Arena: lmarena-ai/arena-human-preference-140k
- Tulu-3-Pref: allenai/llama-3.1-tulu-3-8b-preference-mixture

### Needs Verification

- Hendrycks MATH: EleutherAI/hendrycks_math
  - Tinker requirement says "EleutherAI/hendrycks_math"
  - Alternative: hendrycks/competition_math

- MMLU: cais/mmlu
  - Confirm this is the correct repo
  - Check if configs match subject names

---

## Format Coverage

### Supported Formats

- Parquet - via Explorer (most datasets)
- JSONL - via line-by-line parsing (GSM8K)
- JSON - via Jason
- CSV - via Explorer

### Unsupported Formats (not needed for tinker)

- Arrow IPC
- WebDataset
- ZIP archives (extraction available in hf_hub_ex v0.1.1; needs wiring)
- TAR/GZ archives (extraction available in hf_hub_ex v0.1.1; needs wiring)

---

## Split Coverage

### Splits Used in Tinker Datasets

Most common splits:
- **train** - 22 datasets (100%)
- **test** - 16 datasets (73%)
- **validation** - 4 datasets (18%)
- **auxiliary_train** - 1 dataset (MMLU)
- **dev** - 1 dataset (MMLU)

### Split Detection Strategy

Current approach uses heuristics:
1. Look for files named `{split}-*.parquet`
2. Look for directories named after splits
3. Fallback to "train" if ambiguous

**Improvement needed:** Use HfHub.Api.list_repo_tree/2 + dataset_splits/2 to enumerate actual splits

---

## Action Items

**IMMEDIATE (this week):**
1. Implement real MMLU loader (2-3 hours)
2. Implement real HumanEval loader (1-2 hours)
3. Verify all repo IDs match HF exactly

**HIGH PRIORITY (next week):**
4. Implement vision dataset loaders (3-4 hours without decode)
5. Wire load() to return DatasetDict for multiple splits
6. Add streaming support for OpenThoughts

**MEDIUM PRIORITY (following week):**
7. Integrate Vix for image decode
8. Add Features to Dataset struct
9. Expand Registry with all 22 datasets

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
