# Basic Usage Examples for DatasetManager
#
# Run this file with: mix run examples/basic_usage.exs

require Logger

Logger.info("=== DatasetManager Basic Usage Examples ===\n")

# Example 1: Load a dataset
Logger.info("Example 1: Loading MMLU STEM dataset")
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 20)

IO.puts("Dataset: #{dataset.name}")
IO.puts("Version: #{dataset.version}")
IO.puts("Items: #{length(dataset.items)}")
IO.puts("Domain: #{dataset.metadata.domain}")
IO.puts("First item: #{inspect(Enum.at(dataset.items, 0))}\n")

# Example 2: Evaluate predictions
Logger.info("Example 2: Evaluating predictions")
{:ok, eval_dataset} = CrucibleDatasets.load(:gsm8k, sample_size: 10)

# Simulate predictions (for demo, use correct answers)
predictions =
  Enum.map(eval_dataset.items, fn item ->
    %{
      id: item.id,
      predicted: item.expected.answer,
      metadata: %{latency_ms: 100}
    }
  end)

{:ok, results} =
  CrucibleDatasets.evaluate(predictions,
    dataset: eval_dataset,
    metrics: [:exact_match, :f1],
    model_name: "demo_model"
  )

IO.puts("Evaluation Results:")
IO.puts("  Model: #{results.model}")
IO.puts("  Accuracy: #{Float.round(results.accuracy * 100, 2)}%")
IO.puts("  Correct: #{results.correct_items}/#{results.total_items}")
IO.puts("  Metrics: #{inspect(results.metrics)}\n")

# Example 3: Random sampling
Logger.info("Example 3: Random sampling")
{:ok, large_dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

{:ok, sample} = CrucibleDatasets.random_sample(large_dataset, size: 20, seed: 42)

IO.puts("Original size: #{length(large_dataset.items)}")
IO.puts("Sample size: #{length(sample.items)}")
IO.puts("Sample method: #{sample.metadata.sample_method}\n")

# Example 4: Stratified sampling
Logger.info("Example 4: Stratified sampling")

{:ok, stratified} =
  CrucibleDatasets.stratified_sample(large_dataset,
    size: 30,
    strata_field: [:metadata, :subject]
  )

IO.puts("Stratified sample size: #{length(stratified.items)}")
IO.puts("Stratification field: #{inspect(stratified.metadata.strata_field)}")

# Show distribution
subjects = Enum.frequencies_by(stratified.items, & &1.metadata.subject)
IO.puts("Subject distribution:")

Enum.each(subjects, fn {subject, count} ->
  IO.puts("  #{subject}: #{count}")
end)

IO.puts("")

# Example 5: Train/test split
Logger.info("Example 5: Train/test split")

{:ok, {train, test}} =
  CrucibleDatasets.train_test_split(large_dataset, test_size: 0.2, shuffle: true)

IO.puts("Total items: #{length(large_dataset.items)}")
IO.puts("Train items: #{length(train.items)}")
IO.puts("Test items: #{length(test.items)}")

train_ratio = length(train.items) / length(large_dataset.items)
IO.puts("Train ratio: #{Float.round(train_ratio * 100, 2)}%\n")

# Example 6: K-fold cross-validation
Logger.info("Example 6: K-fold cross-validation")

{:ok, folds} = CrucibleDatasets.k_fold(large_dataset, k: 5)

IO.puts("Number of folds: #{length(folds)}")

Enum.with_index(folds, fn {train_fold, test_fold}, idx ->
  IO.puts("  Fold #{idx}: train=#{length(train_fold.items)}, test=#{length(test_fold.items)}")
end)

IO.puts("")

# Example 7: Cache management
Logger.info("Example 7: Cache management")

cached = CrucibleDatasets.list_cached()
IO.puts("Cached datasets: #{length(cached)}")

if length(cached) > 0 do
  IO.puts("Cached items:")

  Enum.each(cached, fn item ->
    IO.puts("  - #{item["name"]} (v#{item["version"]})")
  end)
end

Logger.info("\n=== Examples completed successfully! ===")
