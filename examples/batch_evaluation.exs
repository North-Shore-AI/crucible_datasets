# Batch Evaluation Example
#
# This example demonstrates batch evaluation of multiple models
# for efficient model comparison and benchmarking.
#
# Run this file with: mix run examples/batch_evaluation.exs

require Logger

Logger.info("=== Batch Evaluation Example ===\n")

# Load multiple datasets for comprehensive evaluation
Logger.info("Loading multiple benchmark datasets...")

datasets = [
  {:mmlu_stem, 30},
  {:humaneval, 15},
  {:gsm8k, 20}
]

loaded_datasets =
  Enum.map(datasets, fn {name, size} ->
    {:ok, dataset} = CrucibleDatasets.load(name, sample_size: size)
    IO.puts("  Loaded #{name}: #{length(dataset.items)} items")
    {name, dataset}
  end)

IO.puts("")

# Define multiple simulated models with different characteristics
defmodule ModelSimulator do
  @doc """
  Simulate different model behaviors
  """
  def generate_predictions(dataset, model_type) do
    Enum.map(dataset.items, fn item ->
      predicted =
        case model_type do
          :perfect ->
            # Perfect model - always correct
            get_expected(item)

          :strong ->
            # 85% accuracy
            if :rand.uniform() < 0.85 do
              get_expected(item)
            else
              generate_wrong(item)
            end

          :medium ->
            # 60% accuracy
            if :rand.uniform() < 0.60 do
              get_expected(item)
            else
              generate_wrong(item)
            end

          :weak ->
            # 30% accuracy
            if :rand.uniform() < 0.30 do
              get_expected(item)
            else
              generate_wrong(item)
            end

          :random ->
            # Random guessing
            generate_wrong(item)
        end

      %{
        id: item.id,
        predicted: predicted,
        metadata: %{
          model_type: model_type,
          confidence: :rand.uniform()
        }
      }
    end)
  end

  defp get_expected(item) do
    case item.expected do
      %{answer: answer} -> answer
      value -> value
    end
  end

  defp generate_wrong(item) do
    # Generate a plausible wrong answer based on item type
    case item.expected do
      num when is_integer(num) ->
        # For multiple choice, pick different option
        ([0, 1, 2, 3] -- [num]) |> Enum.random()

      %{answer: answer} ->
        # For structured answers, slightly modify
        try do
          "#{String.to_integer(answer) + :rand.uniform(10)}"
        rescue
          _ -> "wrong_answer"
        end

      _ ->
        "wrong_answer"
    end
  end
end

# Model configurations
models = [
  {"gpt4_simulator", :perfect},
  {"strong_model", :strong},
  {"medium_model", :medium},
  {"weak_model", :weak},
  {"random_baseline", :random}
]

Logger.info("Simulating #{length(models)} models on #{length(loaded_datasets)} datasets...\n")

# Evaluate each model on each dataset
all_results =
  Enum.flat_map(models, fn {model_name, model_type} ->
    Logger.info("Evaluating #{model_name}...")

    Enum.map(loaded_datasets, fn {dataset_name, dataset} ->
      # Generate predictions
      predictions = ModelSimulator.generate_predictions(dataset, model_type)

      # Evaluate
      {:ok, result} =
        CrucibleDatasets.evaluate(
          predictions,
          dataset: dataset,
          metrics: [:exact_match, :f1],
          model_name: model_name
        )

      %{
        model: model_name,
        dataset: dataset_name,
        accuracy: result.accuracy,
        exact_match: result.metrics.exact_match,
        f1: result.metrics.f1,
        total_items: result.total_items,
        duration_ms: result.duration_ms
      }
    end)
  end)

IO.puts("")

# Display results in table format
Logger.info("=== Evaluation Results ===\n")

# Group by model for display
results_by_model = Enum.group_by(all_results, & &1.model)

IO.puts("Results by Model:\n")

Enum.each(models, fn {model_name, _type} ->
  model_results = Map.get(results_by_model, model_name, [])

  IO.puts("#{model_name}:")

  Enum.each(model_results, fn result ->
    IO.puts("  #{result.dataset}:")
    IO.puts("    Accuracy: #{Float.round(result.accuracy * 100, 2)}%")
    IO.puts("    Exact Match: #{Float.round(result.exact_match * 100, 2)}%")
    IO.puts("    F1 Score: #{Float.round(result.f1 * 100, 2)}%")
  end)

  # Calculate average across datasets
  avg_accuracy =
    Enum.map(model_results, & &1.accuracy) |> Enum.sum() |> Kernel./(length(model_results))

  IO.puts("  Average: #{Float.round(avg_accuracy * 100, 2)}%")
  IO.puts("")
end)

# Create comparison matrix
Logger.info("Cross-Dataset Performance Matrix:\n")

dataset_names = Enum.map(loaded_datasets, fn {name, _} -> name end)

IO.puts(
  String.pad_trailing("Model", 20) <>
    " | " <>
    Enum.map_join(dataset_names, " | ", &String.pad_trailing(to_string(&1), 12))
)

IO.puts(
  String.duplicate("-", 20) <>
    "-+-" <>
    Enum.map_join(dataset_names, "-+-", fn _ -> String.duplicate("-", 12) end)
)

Enum.each(models, fn {model_name, _type} ->
  model_results = Map.get(results_by_model, model_name, [])
  results_map = Enum.into(model_results, %{}, fn r -> {r.dataset, r.accuracy} end)

  row =
    String.pad_trailing(model_name, 20) <>
      " | " <>
      Enum.map_join(dataset_names, " | ", fn dataset ->
        acc = Map.get(results_map, dataset, 0.0)
        String.pad_trailing("#{Float.round(acc * 100, 1)}%", 12)
      end)

  IO.puts(row)
end)

IO.puts("")

# Find best model per dataset
Logger.info("Best Model per Dataset:\n")

results_by_dataset = Enum.group_by(all_results, & &1.dataset)

Enum.each(loaded_datasets, fn {dataset_name, _dataset} ->
  dataset_results = Map.get(results_by_dataset, dataset_name, [])
  best = Enum.max_by(dataset_results, & &1.accuracy)

  IO.puts("#{dataset_name}:")
  IO.puts("  Winner: #{best.model}")
  IO.puts("  Accuracy: #{Float.round(best.accuracy * 100, 2)}%")
  IO.puts("")
end)

# Overall ranking
Logger.info("Overall Model Ranking:")

model_rankings =
  results_by_model
  |> Enum.map(fn {model_name, results} ->
    avg_accuracy = Enum.map(results, & &1.accuracy) |> Enum.sum() |> Kernel./(length(results))
    avg_f1 = Enum.map(results, & &1.f1) |> Enum.sum() |> Kernel./(length(results))
    total_time = Enum.map(results, & &1.duration_ms) |> Enum.sum()

    {model_name, avg_accuracy, avg_f1, total_time}
  end)
  |> Enum.sort_by(fn {_name, acc, _f1, _time} -> -acc end)

IO.puts("")

model_rankings
|> Enum.with_index(1)
|> Enum.each(fn {{name, acc, f1, time}, rank} ->
  IO.puts("  #{rank}. #{name}")
  IO.puts("     Avg Accuracy: #{Float.round(acc * 100, 2)}%")
  IO.puts("     Avg F1: #{Float.round(f1 * 100, 2)}%")
  IO.puts("     Total Time: #{time}ms")
end)

# Performance vs Speed analysis
Logger.info("\n=== Performance vs Speed Analysis ===\n")

IO.puts("Efficiency Score (Accuracy/ms):")

model_rankings
|> Enum.map(fn {name, acc, _f1, time} ->
  efficiency = if time > 0, do: acc * 100 / time, else: 0.0
  {name, efficiency}
end)
|> Enum.sort_by(fn {_name, eff} -> -eff end)
|> Enum.each(fn {name, eff} ->
  IO.puts("  #{name}: #{Float.round(eff, 4)}")
end)

Logger.info("\n=== Batch Evaluation Example Completed ===")
