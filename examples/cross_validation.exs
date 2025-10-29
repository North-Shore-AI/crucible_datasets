# Cross-Validation Example
#
# This example demonstrates k-fold cross-validation workflows
# for robust model evaluation.
#
# Run this file with: mix run examples/cross_validation.exs

require Logger

Logger.info("=== K-Fold Cross-Validation Example ===\n")

# Load dataset
Logger.info("Loading MMLU STEM dataset...")
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)
IO.puts("Loaded #{length(dataset.items)} items\n")

# Create k-fold splits
k = 5
Logger.info("Creating #{k}-fold cross-validation splits...")

{:ok, folds} = CrucibleDatasets.k_fold(dataset, k: k, shuffle: true, seed: 42)
IO.puts("Created #{length(folds)} folds\n")

# Verify fold sizes
Logger.info("Verifying fold sizes...")
IO.puts("\nFold Sizes:")

Enum.each(folds, fn {train, test} ->
  train_size = length(train.items)
  test_size = length(test.items)
  total = train_size + test_size

  IO.puts("  Train: #{train_size}, Test: #{test_size}, Total: #{total}")
end)

# Simulate three different models with different accuracy levels
defmodule ModelSimulator do
  @doc """
  Simulate a model with given accuracy rate.
  """
  def predict(item, accuracy_rate, seed) do
    :rand.seed(:exsss, {seed, seed, seed})

    if :rand.uniform() < accuracy_rate do
      # Correct prediction
      item.expected
    else
      # Random wrong prediction (for multiple choice)
      wrong_choices = [0, 1, 2, 3] -- [item.expected]
      Enum.random(wrong_choices)
    end
  end
end

# Model configurations
models = [
  {"strong_model", 0.85},
  {"medium_model", 0.65},
  {"weak_model", 0.45}
]

Logger.info("\nRunning cross-validation for #{length(models)} models...")

# Perform cross-validation for each model
cv_results =
  Enum.map(models, fn {model_name, accuracy_rate} ->
    Logger.info(
      "Evaluating #{model_name} (target accuracy: #{Float.round(accuracy_rate * 100, 1)}%)..."
    )

    fold_scores =
      folds
      |> Enum.with_index()
      |> Enum.map(fn {{_train_fold, test_fold}, fold_idx} ->
        # Generate predictions for this fold
        predictions =
          Enum.map(test_fold.items, fn item ->
            seed = fold_idx * 1000 + String.to_integer(String.replace(item.id, ~r/\D/, ""))
            predicted = ModelSimulator.predict(item, accuracy_rate, seed)

            %{
              id: item.id,
              predicted: predicted,
              metadata: %{fold: fold_idx}
            }
          end)

        # Evaluate this fold
        {:ok, result} =
          CrucibleDatasets.evaluate(
            predictions,
            dataset: test_fold,
            metrics: [:exact_match, :f1],
            model_name: "#{model_name}_fold#{fold_idx}"
          )

        {fold_idx, result.accuracy, result.metrics.exact_match, result.metrics.f1}
      end)

    # Calculate statistics across folds
    accuracies = Enum.map(fold_scores, &elem(&1, 1))
    mean_accuracy = Enum.sum(accuracies) / length(accuracies)

    # Calculate standard deviation
    variance =
      Enum.reduce(accuracies, 0, fn acc, sum ->
        sum + :math.pow(acc - mean_accuracy, 2)
      end) / length(accuracies)

    std_dev = :math.sqrt(variance)

    min_accuracy = Enum.min(accuracies)
    max_accuracy = Enum.max(accuracies)

    {model_name, mean_accuracy, std_dev, min_accuracy, max_accuracy, fold_scores}
  end)

# Display results
IO.puts("\n=== Cross-Validation Results ===\n")

Enum.each(cv_results, fn {model_name, mean, std_dev, min, max, fold_scores} ->
  IO.puts("Model: #{model_name}")
  IO.puts("  Mean Accuracy: #{Float.round(mean * 100, 2)}%")
  IO.puts("  Std Dev: #{Float.round(std_dev * 100, 2)}%")
  IO.puts("  Min Accuracy: #{Float.round(min * 100, 2)}%")
  IO.puts("  Max Accuracy: #{Float.round(max * 100, 2)}%")

  IO.puts(
    "  95% CI: [#{Float.round((mean - 1.96 * std_dev) * 100, 2)}%, #{Float.round((mean + 1.96 * std_dev) * 100, 2)}%]"
  )

  IO.puts("  Per-Fold Results:")

  Enum.each(fold_scores, fn {fold_idx, accuracy, _exact_match, _f1} ->
    IO.puts("    Fold #{fold_idx}: #{Float.round(accuracy * 100, 2)}%")
  end)

  IO.puts("")
end)

# Statistical comparison between models
Logger.info("Statistical comparison between models:\n")

sorted_models = Enum.sort_by(cv_results, fn {_name, mean, _std, _min, _max, _scores} -> -mean end)

IO.puts("Model Ranking:")

sorted_models
|> Enum.with_index(1)
|> Enum.each(fn {{name, mean, std_dev, _min, _max, _scores}, rank} ->
  IO.puts(
    "  #{rank}. #{name}: #{Float.round(mean * 100, 2)}% ± #{Float.round(std_dev * 100, 2)}%"
  )
end)

# Check if top models are significantly different
if length(sorted_models) >= 2 do
  [{name1, mean1, std1, _, _, _}, {name2, mean2, std2, _, _, _} | _] = sorted_models

  # Simple significance test (t-test approximation)
  pooled_std = :math.sqrt((std1 * std1 + std2 * std2) / 2)
  t_stat = abs(mean1 - mean2) / (pooled_std * :math.sqrt(2.0 / k))

  IO.puts("\nSignificance test between top 2 models:")
  IO.puts("  #{name1} vs #{name2}")
  IO.puts("  Difference: #{Float.round((mean1 - mean2) * 100, 2)}%")
  IO.puts("  T-statistic: #{Float.round(t_stat, 3)}")

  if t_stat > 2.0 do
    IO.puts("  Result: Statistically significant difference (p < 0.05)")
  else
    IO.puts("  Result: Not statistically significant (p >= 0.05)")
  end
end

Logger.info("\n=== Cross-Validation Example Completed ===")
