# CrucibleDatasets - Current State Documentation

**Version:** 0.5.1
**Last Updated:** 2025-12-25
**Status:** Production-ready, all tests passing, dialyzer clean

## Overview

CrucibleDatasets is a lightweight dataset management library for AI evaluation research in Elixir. It provides a unified interface for loading, caching, evaluating, and sampling benchmark datasets with support for versioning, reproducible evaluation, and custom datasets.

## Architecture

```
CrucibleDatasets/
├── CrucibleDatasets                    # Main API (lib/dataset_manager.ex)
├── Dataset                             # Core data structure (lib/dataset_manager/dataset.ex)
├── MemoryDataset                       # In-memory dataset construction (lib/dataset_manager/memory_dataset.ex)
├── FieldMapping                        # Declarative field mapping (lib/dataset_manager/field_mapping.ex)
├── EvaluationResult                    # Evaluation result schema (lib/dataset_manager/evaluation_result.ex)
├── Loader/                             # Dataset loaders
│   ├── Loader                          # Main loader (lib/dataset_manager/loader.ex)
│   ├── Generic                         # Generic JSONL/JSON/CSV loader (lib/dataset_manager/loader/generic.ex)
│   ├── MMLU                            # MMLU loader (lib/dataset_manager/loader/mmlu.ex)
│   ├── HumanEval                       # HumanEval loader (lib/dataset_manager/loader/human_eval.ex)
│   └── GSM8K                           # GSM8K loader (lib/dataset_manager/loader/gsm8k.ex)
├── Registry                            # Dataset registry (lib/dataset_manager/registry.ex)
├── Cache                               # Local caching (lib/dataset_manager/cache.ex)
├── Evaluator/                          # Evaluation engine
│   ├── Evaluator                       # Main evaluator (lib/dataset_manager/evaluator.ex)
│   ├── ExactMatch                      # Exact match metric (lib/dataset_manager/evaluator/exact_match.ex)
│   ├── F1                              # F1 score metric (lib/dataset_manager/evaluator/f1.ex)
│   ├── BLEU                            # BLEU score metric (lib/dataset_manager/evaluator/bleu.ex)
│   └── ROUGE                           # ROUGE score metric (lib/dataset_manager/evaluator/rouge.ex)
├── Sampler                             # Sampling utilities (lib/dataset_manager/sampler.ex)
├── ResultStore                         # Result persistence (lib/dataset_manager/result_store.ex)
└── Exporter                            # Export utilities (lib/dataset_manager/exporter.ex)
```

## Module Details

### Core API (`CrucibleDatasets` - lib/dataset_manager.ex)

**Lines 1-195**

Main entry point with delegated functions:

| Function | Delegate To | Line | Description |
|----------|-------------|------|-------------|
| `load/2` | `Loader.load/2` | 62 | Load dataset by name or DatasetRef |
| `evaluate/2` | `Evaluator.evaluate/2` | 69 | Evaluate predictions against dataset |
| `evaluate_batch/2` | `Evaluator.evaluate_batch/2` | 76 | Batch evaluate multiple models |
| `random_sample/2` | `Sampler.random/2` | 83 | Create random sample |
| `stratified_sample/2` | `Sampler.stratified/2` | 90 | Create stratified sample |
| `k_fold/2` | `Sampler.k_fold/2` | 97 | K-fold cross-validation |
| `train_test_split/2` | `Sampler.train_test_split/2` | 104 | Train/test split |
| `list_cached/0` | `Cache.list/0` | 111 | List cached datasets |
| `clear_cache/0` | `Cache.clear_all/0` | 118 | Clear all cache |
| `invalidate_cache/1` | `Loader.invalidate_cache/1` | 125 | Invalidate specific cache |
| `list_available/0` | `Registry.list_available/0` | 134 | List available datasets |
| `get_metadata/1` | `Registry.get_metadata/1` | 141 | Get dataset metadata |
| `save_result/2` | `ResultStore.save/2` | 150 | Save evaluation result |
| `load_result/1` | `ResultStore.load/1` | 157 | Load saved result |
| `query_results/1` | `ResultStore.query/1` | 164 | Query results with filters |
| `export_csv/3` | `Exporter.to_csv/3` | 173 | Export to CSV |
| `export_jsonl/2` | `Exporter.to_jsonl/2` | 180 | Export to JSONL |
| `export_markdown/2` | `Exporter.to_markdown/2` | 187 | Export to Markdown |
| `export_html/2` | `Exporter.to_html/2` | 194 | Export to HTML |

### Dataset Struct (`CrucibleDatasets.Dataset` - lib/dataset_manager/dataset.ex)

**Lines 1-250**

Core data structure for all datasets:

```elixir
%Dataset{
  name: String.t(),
  version: String.t(),
  items: [item()],
  metadata: map()
}
```

**Key Functions:**

| Function | Line | Description |
|----------|------|-------------|
| `new/4` | 38 | Create new dataset with validation |
| `validate/1` | 65 | Validate dataset schema |
| `filter/2` | 127 | Filter items by predicate |
| `sort/2,3` | 146 | Sort items by key or function |
| `shuffle_choices/2` | 171 | Shuffle multiple-choice options |
| `slice/2,3` | 230, 241 | Slice by range or start/count |

### Dataset Loaders

#### Main Loader (`CrucibleDatasets.Loader` - lib/dataset_manager/loader.ex)

**Lines 1-179**

| Function | Line | Description |
|----------|------|-------------|
| `load/2` | 51-87 | Load dataset with caching |
| `invalidate_cache/1` | 93 | Invalidate cache for dataset |

**Supported Datasets:**
- `:mmlu` - Full MMLU
- `:mmlu_stem` - MMLU STEM subset
- `:humaneval` - Code generation
- `:gsm8k` - Math word problems

#### MMLU Loader (`CrucibleDatasets.Loader.MMLU` - lib/dataset_manager/loader/mmlu.ex)

**Lines 1-146**

| Function | Line | Description |
|----------|------|-------------|
| `load/2` | 40 | Load MMLU dataset (synthetic for demo) |
| `parse_csv/2` | 111 | Parse MMLU CSV format |

**STEM Subjects (Lines 12-32):**
- abstract_algebra, anatomy, astronomy, college_biology, college_chemistry
- college_computer_science, college_mathematics, college_physics
- computer_security, conceptual_physics, electrical_engineering
- elementary_mathematics, high_school_biology, high_school_chemistry
- high_school_computer_science, high_school_mathematics, high_school_physics
- high_school_statistics, machine_learning

#### HumanEval Loader (`CrucibleDatasets.Loader.HumanEval` - lib/dataset_manager/loader/human_eval.ex)

**Lines 1-164**

| Function | Line | Description |
|----------|------|-------------|
| `load/1` | 17 | Load HumanEval dataset (synthetic for demo) |
| `parse_jsonl/1` | 117 | Parse HumanEval JSONL format |

#### GSM8K Loader (`CrucibleDatasets.Loader.GSM8K` - lib/dataset_manager/loader/gsm8k.ex)

**Lines 1-162**

| Function | Line | Description |
|----------|------|-------------|
| `load/1` | 16 | Load GSM8K dataset (synthetic for demo) |
| `parse_jsonl/1` | 101 | Parse GSM8K JSONL format |
| `extract_numerical_answer/1` | 133 | Extract answer from "#### N" format |

#### Generic Loader (`CrucibleDatasets.Loader.Generic` - lib/dataset_manager/loader/generic.ex)

**Lines 1-154**

| Function | Line | Description |
|----------|------|-------------|
| `load/2` | 49 | Load from JSONL/JSON/CSV with field mapping |

**Options:**
- `:name` - Dataset name
- `:version` - Version string
- `:format` - File format (`:jsonl`, `:json`, `:csv`, auto-detect)
- `:fields` - FieldMapping specification
- `:auto_id` - Auto-generate IDs
- `:limit` - Max items
- `:shuffle` - Shuffle items
- `:seed` - Random seed

### Evaluation System

#### Main Evaluator (`CrucibleDatasets.Evaluator` - lib/dataset_manager/evaluator.ex)

**Lines 1-223**

| Function | Line | Description |
|----------|------|-------------|
| `evaluate/2` | 46 | Evaluate predictions with metrics |
| `evaluate_batch/2` | 78 | Batch evaluate multiple models |

**Supported Metrics (Lines 158-209):**
- `:exact_match` - Binary match with normalization
- `:f1` - Token-level F1 score
- `:bleu` - BLEU score
- `:rouge` - ROUGE-L F1
- `:rouge1`, `:rouge2`, `:rougel` - Specific ROUGE variants
- Custom function `fn(predicted, expected) -> score`

#### ExactMatch (`CrucibleDatasets.Evaluator.ExactMatch` - lib/dataset_manager/evaluator/exact_match.ex)

**Lines 1-87**

Handles string, numerical, list, and map comparisons with normalization.

#### F1 (`CrucibleDatasets.Evaluator.F1` - lib/dataset_manager/evaluator/f1.ex)

**Lines 1-88**

Token-level F1 score computation.

#### BLEU (`CrucibleDatasets.Evaluator.BLEU` - lib/dataset_manager/evaluator/bleu.ex)

**Lines 1-215**

BLEU score with brevity penalty and n-gram precision.

**Options:**
- `:max_n` - Maximum n-gram length (default: 4)
- `:smoothing` - `:none`, `:add_epsilon`, `:add_k`

#### ROUGE (`CrucibleDatasets.Evaluator.ROUGE` - lib/dataset_manager/evaluator/rouge.ex)

**Lines 1-305**

ROUGE-1, ROUGE-2, ROUGE-L with precision, recall, F1.

| Function | Line | Description |
|----------|------|-------------|
| `compute/3` | 67 | Compute ROUGE scores |
| `compute_aggregate/2` | 281 | Aggregate scores across predictions |

### Sampling (`CrucibleDatasets.Sampler` - lib/dataset_manager/sampler.ex)

**Lines 1-274**

| Function | Line | Description |
|----------|------|-------------|
| `random/2` | 29 | Random sampling with seed |
| `stratified/2` | 73 | Stratified sampling |
| `k_fold/2` | 164 | K-fold cross-validation |
| `train_test_split/2` | 238 | Train/test split |

### Caching (`CrucibleDatasets.Cache` - lib/dataset_manager/cache.ex)

**Lines 1-264**

- Cache directory: `~/.elixir_ai_research/datasets/`
- Max cache size: 10GB
- Default TTL: 30 days

| Function | Line | Description |
|----------|------|-------------|
| `get/1` | 30 | Get cached dataset |
| `put/2` | 53 | Store dataset in cache |
| `invalidate/1` | 68 | Invalidate cache entry |
| `list/0` | 79 | List cached datasets |
| `clear_all/0` | 98 | Clear all cache |

### Registry (`CrucibleDatasets.Registry` - lib/dataset_manager/registry.ex)

**Lines 1-375**

| Function | Line | Description |
|----------|------|-------------|
| `list_available/0` | 125 | List all dataset names |
| `get_metadata/1` | 150 | Get dataset metadata |
| `list_by_domain/1` | 170 | Filter by domain |
| `list_by_task_type/1` | 193 | Filter by task type |
| `list_by_difficulty/1` | 213 | Filter by difficulty |
| `list_by_tag/1` | 236 | Filter by tag |
| `search/1` | 259 | Search by keyword |
| `all_metadata/0` | 283 | Get all metadata |
| `available?/1` | 305 | Check if dataset exists |
| `stats/0` | 323 | Get aggregate statistics |
| `summary/0` | 350 | Generate summary string |

### Result Persistence (`CrucibleDatasets.ResultStore` - lib/dataset_manager/result_store.ex)

**Lines 1-421**

- Storage directory: `~/.elixir_ai_research/results/` (configurable via `CRUCIBLE_DATASETS_RESULTS_DIR`)

| Function | Line | Description |
|----------|------|-------------|
| `save/2` | 77 | Save evaluation result |
| `load/1` | 106 | Load result by ID |
| `query/1` | 141 | Query with filters |
| `list_all/0` | 177 | List all summaries |
| `delete/1` | 198 | Delete result |
| `clear_all/0` | 220 | Clear all results |

### Exporter (`CrucibleDatasets.Exporter` - lib/dataset_manager/exporter.ex)

**Lines 1-535**

| Function | Line | Description |
|----------|------|-------------|
| `to_csv/3` | 62 | Export to CSV |
| `to_jsonl/2` | 105 | Export to JSONL |
| `to_markdown/2` | 147 | Generate Markdown report |
| `to_html/2` | 208 | Generate HTML report |

### Helper Modules

#### MemoryDataset (`CrucibleDatasets.MemoryDataset` - lib/dataset_manager/memory_dataset.ex)

**Lines 1-106**

| Function | Line | Description |
|----------|------|-------------|
| `from_list/2` | 49 | Create dataset from list |
| `from_samples/2` | 83 | Alias for `from_list/2` |

#### FieldMapping (`CrucibleDatasets.FieldMapping` - lib/dataset_manager/field_mapping.ex)

**Lines 1-137**

| Function | Line | Description |
|----------|------|-------------|
| `new/1` | 63 | Create field mapping spec |
| `apply/2` | 85 | Apply mapping to record |

#### EvaluationResult (`CrucibleDatasets.EvaluationResult` - lib/dataset_manager/evaluation_result.ex)

**Lines 1-84**

| Function | Line | Description |
|----------|------|-------------|
| `new/6` | 48 | Create evaluation result |
| `to_json/1` | 70 | Convert to JSON-encodable map |

## Dependencies

```elixir
{:jason, "~> 1.4"}
{:telemetry, "~> 1.3"}
{:crucible_ir, "~> 0.1.1"}
{:dialyxir, "~> 1.4", only: [:dev], runtime: false}
{:ex_doc, "~> 0.38", only: :dev, runtime: false}
```

## Test Coverage

- **142 tests, 0 failures**
- Test files:
  - `test/dataset_manager_test.exs` - Main API tests
  - `test/dataset_ref_test.exs` - DatasetRef integration
  - `test/crucible_datasets_delegates_test.exs` - Delegate tests
  - `test/evaluator_bleu_test.exs` - BLEU metric tests
  - `test/evaluator_rouge_test.exs` - ROUGE metric tests
  - `test/evaluator_rouge_aggregate_test.exs` - ROUGE aggregate tests
  - `test/evaluator_integration_metrics_test.exs` - Integration tests
  - `test/result_store_test.exs` - ResultStore tests
  - `test/exporter_test.exs` - Exporter tests
  - `test/registry_test.exs` - Registry tests
  - `test/memory_dataset_test.exs` - MemoryDataset tests
  - `test/dataset_extensions_test.exs` - Dataset operations tests
  - `test/loader_generic_test.exs` - Generic loader tests
  - `test/field_mapping_test.exs` - FieldMapping tests

## Quality Status

- **Compiler warnings:** 0
- **Dialyzer:** Clean (no type errors)
- **Credo:** Not available in deps (dev-only)
- **All tests:** Passing

## Integration Points

### CrucibleIR Integration

Supports `CrucibleIR.DatasetRef` for unified dataset references:

```elixir
ref = %CrucibleIR.DatasetRef{
  name: :mmlu_stem,
  split: :train,
  options: [sample_size: 100]
}

{:ok, dataset} = CrucibleDatasets.load(ref)
```

### Integration with Other Crucible Components

- **crucible_harness** - Experiment orchestration uses datasets
- **crucible_ensemble** - Multi-model voting evaluates on datasets
- **crucible_bench** - Statistical comparison of evaluation results
- **crucible_train** - Training loops consume datasets
- **tinkex_cookbook** - Uses crucible_datasets for dataset operations

## Storage Locations

| Type | Location |
|------|----------|
| Dataset cache | `~/.elixir_ai_research/datasets/` |
| Evaluation results | `~/.elixir_ai_research/results/` |
| Results (custom) | `$CRUCIBLE_DATASETS_RESULTS_DIR` |
