<p align="center">
  <img src="assets/crucible_datasets.svg" alt="Datasets" width="150"/>
</p>

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

## Advanced Features

### Cross-Validation Workflows

Complete k-fold cross-validation with automatic fold management:

```elixir
# 5-fold cross-validation
{:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 5, shuffle: true, seed: 42)

# Evaluate model on each fold
cv_results = Enum.map(folds, fn {train_fold, test_fold} ->
  # Train model on train_fold
  model = train_model(train_fold)

  # Generate predictions on test_fold
  predictions = generate_predictions(model, test_fold)

  # Evaluate
  {:ok, result} = CrucibleDatasets.evaluate(predictions,
    dataset: test_fold,
    metrics: [:exact_match]
  )

  result.accuracy
end)

# Calculate average performance
mean_accuracy = Enum.sum(cv_results) / length(cv_results)
```

### Stratified Sampling for Balanced Datasets

Maintain class distributions in your samples:

```elixir
# For MMLU, maintain subject proportions
{:ok, sample} = CrucibleDatasets.stratified_sample(dataset,
  size: 200,
  strata_field: [:metadata, :subject]
)

# Check distribution is maintained
original_counts = Enum.frequencies_by(dataset.items, & &1.metadata.subject)
sample_counts = Enum.frequencies_by(sample.items, & &1.metadata.subject)

# Proportions should be similar
IO.puts("Original: #{inspect(original_counts)}")
IO.puts("Sample: #{inspect(sample_counts)}")
```

### Custom Metrics Implementation

Create domain-specific evaluation metrics:

```elixir
# Semantic similarity metric
semantic_similarity = fn predicted, expected, item ->
  # Use embeddings or LLM to compute similarity
  similarity_score = compute_semantic_similarity(predicted, expected)

  # Return score between 0.0 and 1.0
  similarity_score
end

# Code execution metric for HumanEval
code_execution = fn predicted, expected, item ->
  try do
    # Attempt to execute the predicted code
    result = execute_code(predicted)
    expected_result = execute_code(expected)

    if result == expected_result do
      1.0
    else
      0.0
    end
  rescue
    _ -> 0.0  # Failed execution
  end
end

# Use custom metrics
{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:exact_match, semantic_similarity, code_execution]
)
```

### Batch Processing for Large-Scale Evaluation

Efficiently evaluate multiple models and datasets:

```elixir
# Multiple models on multiple datasets
models = ["gpt-4", "claude-2", "gemini-pro"]
datasets = [:mmlu_stem, :humaneval, :gsm8k]

results = for model <- models, dataset_name <- datasets do
  {:ok, dataset} = CrucibleDatasets.load(dataset_name, sample_size: 100)
  predictions = generate_predictions_for_model(model, dataset)

  {:ok, result} = CrucibleDatasets.evaluate(predictions,
    dataset: dataset,
    model_name: model
  )

  {model, dataset_name, result.accuracy}
end

# Create results matrix
results_matrix = Enum.group_by(results, &elem(&1, 0), &{elem(&1, 1), elem(&1, 2)})
```

## Complete API Reference

### Core Functions

#### `CrucibleDatasets.load(dataset_name, opts \\\\ [])`

Load a dataset with optional sampling.

**Parameters:**
- `dataset_name`: Atom or string identifier (`:mmlu`, `:humaneval`, etc.)
- `opts`: Keyword options

**Options:**
- `:sample_size` - Number of items to load (default: all)
- `:source` - Path for custom datasets

**Returns:** `{:ok, Dataset.t()}` or `{:error, term}`

#### `CrucibleDatasets.evaluate(predictions, opts \\\\ [])`

Evaluate predictions against ground truth.

**Parameters:**
- `predictions`: List of prediction maps
- `opts`: Evaluation options

**Options:**
- `:dataset` - Dataset struct or name
- `:metrics` - List of metrics to compute
- `:model_name` - Name for this evaluation

**Returns:** `{:ok, EvaluationResult.t()}`

#### `CrucibleDatasets.evaluate_batch(model_predictions, opts \\\\ [])`

Evaluate multiple models simultaneously.

**Parameters:**
- `model_predictions`: List of `{model_name, predictions}` tuples
- `opts`: Same as `evaluate/2`

### Sampling Functions

#### `CrucibleDatasets.random_sample(dataset, opts \\\\ [])`

**Options:**
- `:size` - Sample size (default: 100)
- `:seed` - Random seed for reproducibility

#### `CrucibleDatasets.stratified_sample(dataset, opts \\\\ [])`

**Options:**
- `:size` - Total sample size
- `:strata_field` - Field to stratify by (atom or list)

#### `CrucibleDatasets.train_test_split(dataset, opts \\\\ [])`

**Options:**
- `:test_size` - Test proportion (default: 0.2)
- `:shuffle` - Whether to shuffle (default: true)
- `:seed` - Random seed

#### `CrucibleDatasets.k_fold(dataset, opts \\\\ [])`

**Options:**
- `:k` - Number of folds (default: 5)
- `:shuffle` - Whether to shuffle (default: true)
- `:seed` - Random seed

### Cache Management

#### `CrucibleDatasets.list_cached()`

Returns list of cached dataset information.

#### `CrucibleDatasets.clear_cache()`

Removes all cached datasets.

#### `CrucibleDatasets.invalidate_cache(dataset_name)`

Removes cache for specific dataset.

## Prediction Format

Predictions must follow this structure:

```elixir
prediction = %{
  id: "dataset_item_id",  # Must match dataset item ID
  predicted: value,       # Model's prediction (any type)
  metadata: %{            # Optional additional data
    latency_ms: 150,
    confidence: 0.95,
    tokens_used: 42
  }
}
```

## Integration Examples

### With LiveBook for Interactive Analysis

```elixir
# In LiveBook cell
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

# Display dataset info
Kino.DataTable.new(dataset.items)

# Interactive evaluation
predictions_input = Kino.Input.textarea("Predictions (JSON)")
model_name_input = Kino.Input.text("Model Name")

Kino.Control.form([predictions: predictions_input, model: model_name_input],
  submit: "Evaluate"
) |> Kino.listen(fn %{data: %{predictions: preds_json, model: name}} ->
  predictions = Jason.decode!(preds_json)

  {:ok, result} = CrucibleDatasets.evaluate(predictions,
    dataset: dataset,
    model_name: name
  )

  # Display results
  Kino.Markdown.new("""
  ## Results for #{name}

  - Accuracy: #{Float.round(result.accuracy * 100, 2)}%
  - Exact Match: #{Float.round(result.metrics.exact_match * 100, 2)}%
  - F1 Score: #{Float.round(result.metrics.f1 * 100, 2)}%
  """)
end)
```

### Research Pipeline Integration

```elixir
defmodule ResearchPipeline do
  def run_evaluation_pipeline(model_configs, datasets) do
    results = for config <- model_configs, dataset_name <- datasets do
      # Load dataset
      {:ok, dataset} = CrucibleDatasets.load(dataset_name)

      # Create train/test split
      {:ok, {train, test}} = CrucibleDatasets.train_test_split(dataset,
        test_size: 0.2,
        seed: 42
      )

      # Train model (your training logic)
      model = train_model(config, train)

      # Generate predictions
      predictions = generate_predictions(model, test)

      # Evaluate
      {:ok, result} = CrucibleDatasets.evaluate(predictions,
        dataset: test,
        model_name: config.name
      )

      # Store detailed results
      save_results(config, dataset_name, result)

      result
    end

    # Generate comparison report
    generate_comparison_report(results)
  end

  def generate_comparison_report(results) do
    # Group by model
    by_model = Enum.group_by(results, & &1.model)

    # Create markdown report
    report = Enum.map(by_model, fn {model, model_results} ->
      avg_accuracy = Enum.map(model_results, & &1.accuracy) |> Enum.sum() |> Kernel./(length(model_results))

      """
      ## #{model}

      - Average Accuracy: #{Float.round(avg_accuracy * 100, 2)}%
      - Datasets: #{Enum.map(model_results, & &1.dataset) |> Enum.join(", ")}
      """
    end) |> Enum.join("\n")

    File.write!("evaluation_report.md", report)
  end
end
```

### Continuous Evaluation System

```elixir
defmodule ContinuousEvaluator do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def evaluate_model(model_name, predictions, dataset_name) do
    GenServer.call(__MODULE__, {:evaluate, model_name, predictions, dataset_name})
  end

  def init(opts) do
    # Load baseline datasets
    datasets = Keyword.get(opts, :datasets, [:mmlu_stem, :humaneval])

    loaded_datasets = Enum.map(datasets, fn name ->
      {:ok, dataset} = CrucibleDatasets.load(name)
      {name, dataset}
    end) |> Map.new()

    {:ok, %{datasets: loaded_datasets, history: []}}
  end

  def handle_call({:evaluate, model_name, predictions, dataset_name}, _from, state) do
    dataset = Map.get(state.datasets, dataset_name)

    {:ok, result} = CrucibleDatasets.evaluate(predictions,
      dataset: dataset,
      model_name: model_name
    )

    # Store in history
    new_history = [{model_name, dataset_name, result, DateTime.utc_now()} | state.history]

    # Check for regressions
    check_for_regressions(model_name, dataset_name, result, state.history)

    {:reply, {:ok, result}, %{state | history: new_history}}
  end

  defp check_for_regressions(model_name, dataset_name, current_result, history) do
    # Find previous results for same model/dataset
    previous_results = Enum.filter(history, fn {m, d, _, _} ->
      m == model_name && d == dataset_name
    end)

    if length(previous_results) > 0 do
      # Compare with baseline (first result)
      {_, _, baseline_result, _} = hd(Enum.reverse(previous_results))

      if current_result.accuracy < baseline_result.accuracy * 0.95 do
        Logger.warning("Performance regression detected for #{model_name} on #{dataset_name}")
      end
    end
  end
end
```

## Performance Optimization

### Memory Management

- **Streaming Evaluation**: For very large datasets, process in chunks
- **Selective Loading**: Only load needed fields from datasets
- **Cache Management**: Regularly clean old cached datasets

```elixir
# Process large datasets in chunks
def evaluate_large_dataset(predictions, dataset, chunk_size \\ 1000) do
  predictions
  |> Enum.chunk_every(chunk_size)
  |> Enum.map(fn chunk ->
    CrucibleDatasets.evaluate(chunk, dataset: dataset, metrics: [:exact_match])
  end)
  |> combine_results()
end
```

### Caching Strategies

```elixir
# Intelligent caching based on usage patterns
defmodule SmartCache do
  @max_cache_age_days 30
  @max_cache_size_gb 10

  def cleanup_cache() do
    cached = CrucibleDatasets.list_cached()

    # Remove old entries
    old_entries = Enum.filter(cached, fn entry ->
      DateTime.diff(DateTime.utc_now(), entry.last_used) > @max_cache_age_days * 24 * 3600
    end)

    Enum.each(old_entries, fn entry ->
      CrucibleDatasets.invalidate_cache(entry.name)
    end)

    # Check total size and remove LRU if needed
    total_size = Enum.sum(Enum.map(cached, & &1.size_bytes))
    max_size_bytes = @max_cache_size_gb * 1024 * 1024 * 1024

    if total_size > max_size_bytes do
      # Remove least recently used entries
      sorted = Enum.sort_by(cached, & &1.last_used)
      Enum.take(sorted, 5) |> Enum.each(&CrucibleDatasets.invalidate_cache(&1.name))
    end
  end
end
```

## Troubleshooting

### Common Issues

#### Dataset Loading Failures

```elixir
# Check if dataset exists
case CrucibleDatasets.load(:invalid_dataset) do
  {:error, :dataset_not_found} ->
    IO.puts("Available datasets: #{Enum.join(CrucibleDatasets.list_available(), ", ")}")

  {:error, :network_error} ->
    IO.puts("Check internet connection or try loading from cache")

  {:ok, dataset} ->
    IO.puts("Loaded successfully")
end
```

#### Prediction Format Errors

```elixir
# Validate prediction format
def validate_predictions(predictions, dataset) do
  dataset_ids = MapSet.new(Enum.map(dataset.items, & &1.id))

  errors = Enum.flat_map(predictions, fn pred ->
    cond do
      not Map.has_key?(pred, :id) -> ["Missing :id field"]
      not MapSet.member?(dataset_ids, pred.id) -> ["Unknown ID: #{pred.id}"]
      not Map.has_key?(pred, :predicted) -> ["Missing :predicted field"]
      true -> []
    end
  end)

  if Enum.empty?(errors) do
    :ok
  else
    {:error, errors}
  end
end
```

#### Memory Issues with Large Datasets

```elixir
# Use streaming for large evaluations
def stream_evaluate(predictions_stream, dataset) do
  predictions_stream
  |> Stream.chunk_every(1000)
  |> Stream.map(fn chunk ->
    {:ok, result} = CrucibleDatasets.evaluate(chunk, dataset: dataset)
    result
  end)
  |> Enum.reduce(&combine_evaluation_results/2)
end
```

#### Cache Corruption

```elixir
# Clear and reload cache
CrucibleDatasets.clear_cache()

# Reload datasets
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, force_refresh: true)
```

## Research Best Practices

### Reproducibility Checklist

- [ ] **Version Control**: Track dataset versions and evaluation code
- [ ] **Random Seeds**: Use fixed seeds for all sampling operations
- [ ] **Environment**: Document Elixir/Erlang versions, dependencies
- [ ] **Caching**: Clear cache between experiments if needed
- [ ] **Audit Trail**: Log all evaluation parameters and results

### Evaluation Protocols

#### Standard Benchmarking

```elixir
def run_standard_benchmark(model_fn, datasets) do
  for dataset_name <- datasets do
    {:ok, dataset} = CrucibleDatasets.load(dataset_name)

    # Use standard train/test split
    {:ok, {train, test}} = CrucibleDatasets.train_test_split(dataset,
      test_size: 0.2,
      seed: 42
    )

    # Generate predictions
    predictions = Enum.map(test.items, fn item ->
      predicted = model_fn.(item.input)
      %{id: item.id, predicted: predicted, metadata: %{}}
    end)

    # Evaluate with standard metrics
    {:ok, result} = CrucibleDatasets.evaluate(predictions,
      dataset: test,
      metrics: [:exact_match, :f1],
      model_name: "benchmark_model"
    )

    result
  end
end
```

#### Cross-Validation Protocols

```elixir
def cross_validate_model(model_fn, dataset, k \\ 5) do
  {:ok, folds} = CrucibleDatasets.k_fold(dataset, k: k, seed: 42)

  scores = Enum.map(folds, fn {train_fold, test_fold} ->
    # Train model on fold
    model = train_on_fold(model_fn, train_fold)

    # Evaluate on test fold
    predictions = Enum.map(test_fold.items, fn item ->
      %{id: item.id, predicted: model.(item.input), metadata: %{}}
    end)

    {:ok, result} = CrucibleDatasets.evaluate(predictions,
      dataset: test_fold,
      metrics: [:exact_match]
    )

    result.accuracy
  end)

  %{
    mean_accuracy: Enum.sum(scores) / length(scores),
    std_accuracy: standard_deviation(scores),
    fold_scores: scores
  }
end

defp standard_deviation(values) do
  mean = Enum.sum(values) / length(values)
  variance = Enum.map(values, &(&1 - mean) ** 2) |> Enum.sum() |> Kernel./(length(values))
  :math.sqrt(variance)
end
```

## Contributing

### Development Setup

```bash
# Clone repository
git clone https://github.com/North-Shore-AI/crucible_datasets.git
cd crucible_datasets

# Install dependencies
mix deps.get

# Run tests
mix test

# Run examples
mix run examples/basic_usage.exs
mix run examples/evaluation_workflow.exs

# Generate documentation
mix docs
```

### Adding New Datasets

1. **Create Loader Module**

```elixir
defmodule CrucibleDatasets.Loader.NewDataset do
  @behaviour CrucibleDatasets.Loader

  @impl true
  def load(opts \\ []) do
    # Fetch data from source
    data = fetch_new_dataset()

    # Convert to standard format
    items = Enum.map(data, &convert_to_standard_format/1)

    dataset = %CrucibleDatasets.Dataset{
      name: "new_dataset",
      version: "1.0",
      items: items,
      metadata: %{
        source: "your_source",
        license: "MIT",
        description: "Description of new dataset"
      }
    }

    {:ok, dataset}
  end

  defp fetch_new_dataset() do
    # Your data fetching logic
  end

  defp convert_to_standard_format(raw_item) do
    %{
      id: "new_dataset_#{raw_item.id}",
      input: raw_item.question,
      expected: raw_item.answer,
      metadata: %{difficulty: raw_item.difficulty}
    }
  end
end
```

2. **Register Dataset**

```elixir
# In loader.ex
def load(:new_dataset, opts), do: Loader.NewDataset.load(opts)
```

3. **Add Tests**

```elixir
test "loads new dataset correctly" do
  {:ok, dataset} = CrucibleDatasets.load(:new_dataset)
  assert length(dataset.items) > 0
  assert dataset.name == "new_dataset"
end
```

### Implementing Custom Metrics

```elixir
defmodule CrucibleDatasets.Evaluator.CustomMetric do
  @behaviour CrucibleDatasets.Evaluator.Metric

  @impl true
  def name(), do: :custom_metric

  @impl true
  def compute(predicted, expected, item \\ nil) do
    # Your metric computation logic
    # Return float between 0.0 and 1.0
    score_custom_metric(predicted, expected)
  end

  defp score_custom_metric(predicted, expected) do
    # Implementation
  end
end
```

### Code Standards

- **Error Handling**: Use `{:ok, result}` / `{:error, reason}` tuples
- **Documentation**: Complete `@doc` and `@moduledoc` with examples
- **Types**: Use type specifications for public functions
- **Testing**: 100% test coverage for new code
- **Performance**: Consider memory usage for large datasets

## License

MIT License - see [LICENSE](https://github.com/North-Shore-AI/crucible_datasets/blob/main/LICENSE) file for details

## Changelog

### v0.1.0 (Current)
- Initial release with comprehensive dataset management
- Support for MMLU, HumanEval, and GSM8K datasets
- Automatic caching and version management
- Multiple evaluation metrics (exact match, F1 score)
- Advanced sampling (stratified, k-fold cross-validation)
- Custom dataset and metric support
- Complete documentation and examples

