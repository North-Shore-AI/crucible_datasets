# CrucibleDatasets

**Centralized dataset management library for AI evaluation research in Elixir.**

CrucibleDatasets provides a unified interface for loading, caching, evaluating, and sampling benchmark datasets (MMLU, HumanEval, GSM8K) with support for versioning, reproducible evaluation, and custom datasets.

## Features

- **Unified Dataset Interface**: Single API for all benchmark types
- **Automatic Caching**: Fast access with local caching and version tracking
- **Comprehensive Metrics**: Exact match, F1 score, and custom evaluation metrics
- **Dataset Sampling**: Random, stratified, and k-fold cross-validation
- **Reproducibility**: Deterministic sampling with seeds, version tracking
- **Extensible**: Easy integration of custom datasets and metrics

## Supported Datasets

- **MMLU** (Massive Multitask Language Understanding) - 57 subjects across STEM, humanities, social sciences
- **HumanEval** - Code generation benchmark with 164 programming problems
- **GSM8K** - Grade school math word problems (8,500 problems)
- **Custom Datasets** - Load from local JSONL files

## Installation

Add `dataset_manager` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_datasets, "~> 0.1.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:crucible_datasets, github: "nshkrdotcom/elixir_ai_research", sparse: "apps/dataset_manager"}
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

## Usage Examples

### Loading Datasets

```elixir
# Load MMLU STEM subset
{:ok, mmlu} = CrucibleDatasets.load(:mmlu_stem, sample_size: 200)

# Load HumanEval
{:ok, humaneval} = CrucibleDatasets.load(:humaneval)

# Load GSM8K
{:ok, gsm8k} = CrucibleDatasets.load(:gsm8k, sample_size: 150)

# Load custom dataset from file
{:ok, custom} = CrucibleDatasets.load("my_dataset",
  source: "path/to/data.jsonl"
)
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
        choices: ["3×10⁸ m/s", "3×10⁶ m/s", "3×10⁵ m/s", "3×10⁷ m/s"]
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
- Type coercion (string ↔ number)

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

## Examples

Run the included examples:

```bash
# Basic usage
mix run examples/basic_usage.exs

# Advanced evaluation workflow
mix run examples/evaluation_workflow.exs
```

## Testing

Run the test suite:

```bash
cd apps/dataset_manager
mix test
```

## Architecture

```
DatasetManager/
├── DatasetManager              # Main API
├── CrucibleDatasets.Dataset      # Dataset schema
├── CrucibleDatasets.EvaluationResult  # Evaluation result schema
├── CrucibleDatasets.Loader       # Dataset loading
│   ├── Loader.MMLU            # MMLU loader
│   ├── Loader.HumanEval       # HumanEval loader
│   └── Loader.GSM8K           # GSM8K loader
├── CrucibleDatasets.Cache        # Local caching
├── CrucibleDatasets.Evaluator    # Evaluation engine
│   ├── Evaluator.ExactMatch   # Exact match metric
│   └── Evaluator.F1           # F1 score metric
└── CrucibleDatasets.Sampler      # Sampling utilities
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

## Integration with Research Infrastructure

DatasetManager integrates with other research infrastructure libraries:

- **Ensemble**: Evaluate ensemble model predictions
- **Bench**: Statistical comparison of model performance
- **ReqLLM**: Generate predictions from LLM models

## Contributing

1. Add new dataset loaders in `lib/dataset_manager/loader/`
2. Implement custom metrics in `lib/dataset_manager/evaluator/`
3. Add tests in `test/`
4. Update documentation

## License

MIT

