<p align="center">
  <img src="assets/crucible_datasets.svg" alt="Datasets" width="150"/>
</p>

# CrucibleDatasets

[![Elixir](https://img.shields.io/badge/elixir-1.14+-purple.svg)](https://elixir-lang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/crucible_datasets.svg)](https://hex.pm/packages/crucible_datasets)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/crucible_datasets)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/North-Shore-AI/crucible_datasets/blob/main/LICENSE)

**HuggingFace dataset integration and evaluation workflows for ML research in Elixir.**

CrucibleDatasets integrates with `hf_datasets_ex` to provide access to HuggingFace benchmark datasets (MMLU, HumanEval, GSM8K, NoRobots) along with comprehensive evaluation metrics (Exact Match, F1, BLEU, ROUGE) and sampling strategies for reproducible ML evaluation.

> **Note on Dataset Libraries**: NSAI has two dataset libraries with distinct purposes:
> - **datasets_ex**: For NSAI's own custom/internal/proprietary datasets with full versioning and lineage
> - **crucible_datasets** (this library): For integrating external HuggingFace datasets via `hf_datasets_ex` plus evaluation workflows
>
> Use `crucible_datasets` when working with standard ML benchmarks and evaluation. Use `datasets_ex` when creating and managing your own datasets.

> **Note:** v0.5.1 adds inspect_ai parity features. v0.5.0 removed the HuggingFace Hub integration from v0.4.x. Versions 0.4.0 and 0.4.1 are deprecated. See [CHANGELOG.md](CHANGELOG.md) for details.

## Features

- **Automatic Caching**: Fast access with local caching and version tracking
- **Comprehensive Metrics**: Exact match, F1 score, BLEU, ROUGE evaluation metrics
- **Dataset Sampling**: Random, stratified, and k-fold cross-validation
- **Reproducibility**: Deterministic sampling with seeds, version tracking
- **Result Persistence**: Save and query evaluation results
- **Export Tools**: CSV, JSONL, Markdown, HTML export
- **CrucibleIR Integration**: Unified dataset references via `DatasetRef`
- **MemoryDataset**: Lightweight in-memory dataset construction
- **Dataset Extensions**: Filter, sort, slice, and shuffle operations
- **FieldMapping**: Declarative field mapping for flexible schema handling
- **Generic Loader**: Load datasets from JSONL, JSON, and CSV files
- **Extensible**: Easy integration of custom datasets and metrics

## Supported Datasets

- **MMLU** (Massive Multitask Language Understanding) - 57 subjects across STEM, humanities, social sciences
- **HumanEval** - Code generation benchmark with 164 programming problems
- **GSM8K** - Grade school math word problems (8,500 problems)
- **NoRobots** - Human-written instruction-response pairs for instruction-following (9,500 examples)
- **Custom Datasets** - Load from local JSONL, JSON, or CSV files

## Installation

Add `crucible_datasets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_datasets, "~> 0.5.4"}
  ]
end
```

## Quick Start

```elixir
# Load a dataset
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

# Create predictions (example with perfect predictions)
predictions = Enum.map(dataset.items, fn item ->
  %{
    id: item.id,
    predicted: item.expected,
    metadata: %{latency_ms: 100}
  }
end)

# Evaluate
{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:exact_match, :f1],
  model_name: "my_model"
)

IO.puts("Accuracy: #{results.accuracy * 100}%")
# => Accuracy: 100.0%
```

## DatasetRef Integration

CrucibleDatasets supports `CrucibleIR.DatasetRef` for unified dataset references across the Crucible framework:

```elixir
alias CrucibleIR.DatasetRef

# Create a DatasetRef
ref = %DatasetRef{
  name: :mmlu_stem,
  split: :train,
  options: [sample_size: 100]
}

# Load dataset using DatasetRef
{:ok, dataset} = CrucibleDatasets.load(ref)

# DatasetRef works seamlessly with all dataset operations
predictions = generate_predictions(dataset)
{:ok, results} = CrucibleDatasets.evaluate(predictions, dataset: dataset)
```

This enables seamless integration with other Crucible components like `crucible_harness`, `crucible_ensemble`, and `crucible_bench`.

## Usage Examples

### Loading Datasets

```elixir
# Load by name
{:ok, mmlu} = CrucibleDatasets.load(:mmlu_stem, sample_size: 200)
{:ok, gsm8k} = CrucibleDatasets.load(:gsm8k)
{:ok, humaneval} = CrucibleDatasets.load(:humaneval)
{:ok, no_robots} = CrucibleDatasets.load(:no_robots, sample_size: 100)

# Load custom dataset from file
{:ok, custom} = CrucibleDatasets.load("my_dataset", source: "path/to/data.jsonl")
```

### In-Memory Datasets

Create datasets directly from lists without files:

```elixir
alias CrucibleDatasets.MemoryDataset

# Create from list of items
dataset = MemoryDataset.from_list([
  %{input: "What is 2+2?", expected: "4"},
  %{input: "What is 3+3?", expected: "6"}
])

# With custom name and metadata
dataset = MemoryDataset.from_list([
  %{input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}},
  %{input: "Q2", expected: "A2", metadata: %{difficulty: "hard"}}
], name: "my_dataset", version: "1.0.0")

# Auto-generates IDs (item_1, item_2, ...)
```

### Generic Loader with Field Mapping

Load datasets from JSONL, JSON, or CSV with declarative field mapping:

```elixir
alias CrucibleDatasets.{FieldMapping, Loader.Generic}

# Define field mapping for your data schema
mapping = FieldMapping.new(
  input: "question",
  expected: "answer",
  id: "item_id",
  metadata: ["difficulty", "subject"]
)

# Load JSONL file
{:ok, dataset} = Generic.load("data.jsonl", fields: mapping)

# Load CSV with options
{:ok, dataset} = Generic.load("data.csv",
  name: "my_dataset",
  fields: mapping,
  limit: 100,
  shuffle: true,
  seed: 42
)

# With transforms
mapping = FieldMapping.new(
  input: "question",
  expected: "answer",
  transforms: %{
    input: &String.upcase/1,
    expected: &String.to_integer/1
  }
)
```

### Dataset Operations

Filter, sort, slice, and transform datasets:

```elixir
alias CrucibleDatasets.Dataset

# Filter by predicate
hard_items = Dataset.filter(dataset, fn item ->
  item.metadata.difficulty == "hard"
end)

# Sort by field
sorted = Dataset.sort(dataset, :id)                      # ascending by atom key
sorted = Dataset.sort(dataset, :id, :desc)               # descending
sorted = Dataset.sort(dataset, fn item -> item.metadata.score end)  # by function

# Slice dataset
first_10 = Dataset.slice(dataset, 0..9)
middle_5 = Dataset.slice(dataset, 10, 5)

# Shuffle multiple-choice options (preserves correct answer mapping)
shuffled = Dataset.shuffle_choices(dataset, seed: 42)
```

### Evaluation

```elixir
# Single model evaluation
{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: :mmlu_stem,
  metrics: [:exact_match, :f1],
  model_name: "gpt4"
)

# Batch evaluation (compare multiple models)
model_predictions = [
  {"model_a", predictions_a},
  {"model_b", predictions_b},
  {"model_c", predictions_c}
]

{:ok, all_results} = CrucibleDatasets.evaluate_batch(model_predictions,
  dataset: :mmlu_stem,
  metrics: [:exact_match, :f1]
)
```

### Sampling and Splitting

```elixir
# Random sampling
{:ok, sample} = CrucibleDatasets.random_sample(dataset,
  size: 50,
  seed: 42
)

# Stratified sampling (maintain subject distribution)
{:ok, stratified} = CrucibleDatasets.stratified_sample(dataset,
  size: 100,
  strata_field: [:metadata, :subject]
)

# Train/test split
{:ok, {train, test}} = CrucibleDatasets.train_test_split(dataset,
  test_size: 0.2,
  shuffle: true
)

# K-fold cross-validation
{:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 5)

Enum.each(folds, fn {train, test} ->
  # Train and evaluate on each fold
end)
```

### Result Persistence

```elixir
# Save evaluation results
CrucibleDatasets.save_result(results, "my_experiment")

# Load saved results
{:ok, saved} = CrucibleDatasets.load_result("my_experiment")

# Query results with filters
{:ok, matching} = CrucibleDatasets.query_results(
  model: "gpt4",
  dataset: "mmlu_stem"
)
```

### Export

```elixir
# Export to various formats
CrucibleDatasets.export_csv(results, "results.csv")
CrucibleDatasets.export_jsonl(results, "results.jsonl")
CrucibleDatasets.export_markdown(results, "results.md")
CrucibleDatasets.export_html(results, "results.html")
```

### Cache Management

```elixir
# List cached datasets
cached = CrucibleDatasets.list_cached()

# Invalidate specific cache
CrucibleDatasets.invalidate_cache(:mmlu_stem)

# Clear all cache
CrucibleDatasets.clear_cache()
```

## Dataset Schema

All datasets follow a unified schema:

```elixir
%CrucibleDatasets.Dataset{
  name: "mmlu_stem",
  version: "1.0",
  items: [
    %{
      id: "mmlu_stem_physics_0",
      input: %{
        question: "What is the speed of light?",
        choices: ["3x10^8 m/s", "3x10^6 m/s", "3x10^5 m/s", "3x10^7 m/s"]
      },
      expected: 0,  # Index of correct answer
      metadata: %{
        subject: "physics",
        difficulty: "medium"
      }
    },
    # ... more items
  ],
  metadata: %{
    source: "huggingface:cais/mmlu",
    license: "MIT",
    domain: "STEM",
    total_items: 200,
    loaded_at: ~U[2024-01-15 10:30:00Z],
    checksum: "abc123..."
  }
}
```

## Evaluation Metrics

### Exact Match

Binary metric (1.0 or 0.0) with normalization:
- Case-insensitive string comparison
- Whitespace normalization
- Numerical comparison with tolerance
- Type coercion (string <-> number)

```elixir
CrucibleDatasets.Evaluator.ExactMatch.compute("Paris", "paris")
# => 1.0

CrucibleDatasets.Evaluator.ExactMatch.compute(42, "42")
# => 1.0
```

### F1 Score

Token-level F1 (precision and recall):

```elixir
CrucibleDatasets.Evaluator.F1.compute(
  "The quick brown fox",
  "The fast brown fox"
)
# => 0.8 (3/4 tokens match)
```

### BLEU and ROUGE

Machine translation and summarization metrics:

```elixir
CrucibleDatasets.Evaluator.BLEU.compute(predicted, reference)
CrucibleDatasets.Evaluator.ROUGE.compute(predicted, reference)
```

### Custom Metrics

Define custom metrics as functions:

```elixir
semantic_similarity = fn predicted, expected ->
  # Your custom metric logic
  0.95
end

{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:exact_match, semantic_similarity]
)
```

## Architecture

```
CrucibleDatasets/
├── CrucibleDatasets             # Main API
├── Dataset                      # Dataset schema + filter/sort/slice/shuffle
├── MemoryDataset                # In-memory dataset construction
├── FieldMapping                 # Declarative field mapping
├── EvaluationResult             # Evaluation result schema
├── Loader/                      # Dataset loaders
│   ├── Generic                  # Generic JSONL/JSON/CSV loader
│   ├── MMLU                     # MMLU loader
│   ├── HumanEval                # HumanEval loader
│   ├── GSM8K                    # GSM8K loader
│   └── NoRobots                 # NoRobots loader
├── Registry                     # Dataset registry
├── Cache                        # Local caching
├── Evaluator/                   # Evaluation engine
│   ├── ExactMatch               # Exact match metric
│   ├── F1                       # F1 score metric
│   ├── BLEU                     # BLEU score metric
│   └── ROUGE                    # ROUGE score metric
├── Sampler                      # Sampling utilities
├── ResultStore                  # Result persistence
└── Exporter                     # Export utilities
```

## Cache Directory

Datasets are cached in: `~/.elixir_ai_research/datasets/`

```
datasets/
├── manifest.json              # Index of all cached datasets
├── mmlu_stem/
│   └── 1.0/
│       ├── data.etf          # Serialized dataset
│       └── metadata.json     # Version info
├── humaneval/
└── gsm8k/
```

## Result Storage Directory

Evaluation results are stored by default in `~/.elixir_ai_research/results/`. To change the location:

```bash
export CRUCIBLE_DATASETS_RESULTS_DIR=/tmp/crucible_results
```

## Testing

```bash
# Run tests
mix test

# Run with coverage
mix test --cover
```

## Static Analysis

```bash
mix dialyzer
mix credo --strict
```

## Telemetry Events

CrucibleDatasets emits telemetry events for observability:

```elixir
# Dataset loading events
[:crucible_datasets, :load, :start]     # Loading begins
[:crucible_datasets, :load, :stop]      # Loading completes
[:crucible_datasets, :load, :exception] # Loading fails

# Cache events
[:crucible_datasets, :cache, :hit]      # Cache hit
[:crucible_datasets, :cache, :miss]     # Cache miss
```

Example handler:

```elixir
:telemetry.attach(
  "crucible-datasets-handler",
  [:crucible_datasets, :load, :stop],
  fn _event, measurements, metadata, _config ->
    IO.puts("Loaded #{metadata.dataset} (#{metadata.item_count} items) in #{measurements.duration}ns")
  end,
  nil
)
```

## Examples

```bash
mix run examples/basic_usage.exs
mix run examples/evaluation_workflow.exs
mix run examples/sampling_strategies.exs
mix run examples/batch_evaluation.exs
mix run examples/cross_validation.exs
mix run examples/custom_metrics.exs
```

## Integration with Crucible Framework

CrucibleDatasets integrates with other Crucible components:

- **crucible_harness**: Experiment orchestration
- **crucible_ensemble**: Multi-model voting
- **crucible_bench**: Statistical comparison
- **crucible_ir**: Unified dataset references

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
