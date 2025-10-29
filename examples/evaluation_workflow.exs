# Advanced Evaluation Workflow Example
#
# This example demonstrates a complete evaluation workflow:
# 1. Load dataset
# 2. Create train/test split
# 3. Simulate model predictions
# 4. Evaluate with multiple metrics
# 5. Compare multiple models
#
# Run this file with: mix run examples/evaluation_workflow.exs

require Logger

Logger.info("=== Advanced Evaluation Workflow ===\n")

# Step 1: Load dataset
Logger.info("Step 1: Loading dataset")
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 50)
IO.puts("Loaded #{length(dataset.items)} items from #{dataset.name}\n")

# Step 2: Create train/test split
Logger.info("Step 2: Creating train/test split")

{:ok, {train, test}} =
  CrucibleDatasets.train_test_split(dataset, test_size: 0.3, shuffle: true, seed: 42)

IO.puts("Train set: #{length(train.items)} items")
IO.puts("Test set: #{length(test.items)} items\n")

# Step 3: Simulate predictions from multiple models
Logger.info("Step 3: Simulating predictions from multiple models")

# Model 1: Perfect model (100% accuracy)
perfect_predictions =
  Enum.map(test.items, fn item ->
    %{
      id: item.id,
      predicted: item.expected,
      metadata: %{latency_ms: 50, model: "perfect"}
    }
  end)

# Model 2: Good model (80% accuracy)
good_predictions =
  test.items
  |> Enum.with_index()
  |> Enum.map(fn {item, idx} ->
    # Get 80% correct
    predicted = if rem(idx, 5) == 0, do: (item.expected + 1) |> rem(4), else: item.expected

    %{
      id: item.id,
      predicted: predicted,
      metadata: %{latency_ms: 100, model: "good"}
    }
  end)

# Model 3: Random baseline (25% accuracy for 4-choice questions)
random_predictions =
  Enum.map(test.items, fn item ->
    %{
      id: item.id,
      predicted: :rand.uniform(4) - 1,
      metadata: %{latency_ms: 10, model: "random"}
    }
  end)

IO.puts("Generated predictions for 3 models\n")

# Step 4: Evaluate each model
Logger.info("Step 4: Evaluating models")

model_predictions = [
  {"perfect_model", perfect_predictions},
  {"good_model", good_predictions},
  {"random_baseline", random_predictions}
]

{:ok, all_results} =
  CrucibleDatasets.evaluate_batch(model_predictions,
    dataset: test,
    metrics: [:exact_match, :f1]
  )

IO.puts("\n=== Evaluation Results ===\n")

Enum.each(all_results, fn result ->
  IO.puts("Model: #{result.model}")
  IO.puts("  Accuracy: #{Float.round(result.accuracy * 100, 2)}%")
  IO.puts("  Correct: #{result.correct_items}/#{result.total_items}")
  IO.puts("  Exact Match: #{Float.round(result.metrics.exact_match * 100, 2)}%")
  IO.puts("  F1 Score: #{Float.round(result.metrics.f1 * 100, 2)}%")
  IO.puts("  Duration: #{result.duration_ms}ms")
  IO.puts("")
end)

# Step 5: Rank models by accuracy
Logger.info("Step 5: Model ranking")

ranked =
  all_results
  |> Enum.sort_by(& &1.accuracy, :desc)
  |> Enum.with_index(1)

IO.puts("Model Leaderboard:")

Enum.each(ranked, fn {result, rank} ->
  IO.puts("  #{rank}. #{result.model}: #{Float.round(result.accuracy * 100, 2)}%")
end)

IO.puts("\n")

# Step 6: Analyze per-item results for best model
Logger.info("Step 6: Analyzing per-item results")

best_model = Enum.at(ranked, 0) |> elem(0)

IO.puts("Best model: #{best_model.model}")
IO.puts("Showing incorrect predictions:\n")

incorrect =
  best_model.item_results
  |> Enum.reject(& &1.correct)
  |> Enum.take(5)

if length(incorrect) > 0 do
  Enum.each(incorrect, fn item ->
    IO.puts("  ID: #{item.id}")
    IO.puts("    Expected: #{inspect(item.expected)}")
    IO.puts("    Predicted: #{inspect(item.predicted)}")
    IO.puts("    Score: #{item.score}")
    IO.puts("")
  end)
else
  IO.puts("  No incorrect predictions!\n")
end

# Step 7: Cross-validation example
Logger.info("Step 7: K-fold cross-validation")

{:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 3, shuffle: true)

IO.puts("Running 3-fold cross-validation...")

cv_results =
  folds
  |> Enum.with_index()
  |> Enum.map(fn {{_train_fold, test_fold}, fold_idx} ->
    # Simulate predictions for this fold
    fold_predictions =
      Enum.map(test_fold.items, fn item ->
        %{id: item.id, predicted: item.expected, metadata: %{}}
      end)

    {:ok, result} =
      CrucibleDatasets.evaluate(fold_predictions,
        dataset: test_fold,
        metrics: [:exact_match],
        model_name: "cv_model_fold_#{fold_idx}"
      )

    {fold_idx, result.accuracy}
  end)

IO.puts("\nCross-validation results:")

Enum.each(cv_results, fn {fold, accuracy} ->
  IO.puts("  Fold #{fold}: #{Float.round(accuracy * 100, 2)}%")
end)

avg_accuracy =
  cv_results
  |> Enum.map(&elem(&1, 1))
  |> Enum.sum()
  |> Kernel./(length(cv_results))

IO.puts("  Average: #{Float.round(avg_accuracy * 100, 2)}%")

Logger.info("\n=== Workflow completed successfully! ===")
