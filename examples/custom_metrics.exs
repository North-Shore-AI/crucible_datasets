# Custom Metrics Example
#
# This example demonstrates how to create and use custom evaluation metrics
# alongside built-in metrics for specialized evaluation needs.
#
# Run this file with: mix run examples/custom_metrics.exs

require Logger

Logger.info("=== Custom Metrics Example ===\n")

# Define a custom metric: length similarity
# Returns 1.0 if predicted and expected have similar length, 0.0 otherwise
length_similarity = fn predicted, expected, _item ->
  pred_str = to_string(predicted)
  exp_str = to_string(expected)

  pred_len = String.length(pred_str)
  exp_len = String.length(exp_str)

  # Calculate similarity based on length difference
  if exp_len == 0 do
    if pred_len == 0, do: 1.0, else: 0.0
  else
    diff = abs(pred_len - exp_len)
    max(0.0, 1.0 - diff / exp_len)
  end
end

# Define another custom metric: contains keyword
# Returns 1.0 if predicted contains the expected answer (case-insensitive)
contains_keyword = fn predicted, expected, _item ->
  pred_str = String.downcase(to_string(predicted))
  exp_str = String.downcase(to_string(expected))

  if String.contains?(pred_str, exp_str) do
    1.0
  else
    0.0
  end
end

# Load dataset
Logger.info("Loading GSM8K dataset...")
{:ok, dataset} = CrucibleDatasets.load(:gsm8k, sample_size: 20)
IO.puts("Loaded #{length(dataset.items)} math problems\n")

# Create varied predictions to test custom metrics
Logger.info("Creating test predictions with varying quality...")

predictions =
  dataset.items
  |> Enum.with_index()
  |> Enum.map(fn {item, idx} ->
    answer = item.expected.answer

    # Create different types of predictions
    predicted =
      case rem(idx, 4) do
        0 ->
          # Exact match
          answer

        1 ->
          # Close but wrong (try to parse as number, fallback to string)
          try do
            "#{String.to_integer(answer) + 1}"
          rescue
            _ -> "wrong_answer"
          end

        2 ->
          # Contains answer in longer string
          "The answer is #{answer} because..."

        3 ->
          # Wrong answer
          "999"
      end

    %{
      id: item.id,
      predicted: predicted,
      metadata: %{prediction_type: rem(idx, 4)}
    }
  end)

# Evaluate with both built-in and custom metrics
Logger.info("Evaluating with custom metrics...\n")

{:ok, results} =
  CrucibleDatasets.evaluate(
    predictions,
    dataset: dataset,
    metrics: [
      :exact_match,
      :f1,
      {:custom, "length_similarity", length_similarity},
      {:custom, "contains_keyword", contains_keyword}
    ],
    model_name: "custom_metrics_test"
  )

IO.puts("=== Evaluation Results ===\n")
IO.puts("Model: #{results.model}")
IO.puts("Total Items: #{results.total_items}")
IO.puts("Accuracy: #{Float.round(results.accuracy * 100, 2)}%\n")

IO.puts("Metric Scores:")
IO.puts("  Exact Match: #{Float.round(results.metrics.exact_match * 100, 2)}%")
IO.puts("  F1 Score: #{Float.round(results.metrics.f1 * 100, 2)}%")

# Custom metrics are stored with their tuple keys
length_sim_key = {:custom, "length_similarity", length_similarity}
contains_key = {:custom, "contains_keyword", contains_keyword}

IO.puts("  Length Similarity: #{Float.round(results.metrics[length_sim_key] * 100, 2)}%")
IO.puts("  Contains Keyword: #{Float.round(results.metrics[contains_key] * 100, 2)}%\n")

# Show detailed analysis by prediction type
Logger.info("Analyzing results by prediction type...")

prediction_analysis =
  results.item_results
  |> Enum.group_by(& &1.metadata.prediction_type)
  |> Enum.map(fn {type, items} ->
    exact_matches = Enum.count(items, & &1.correct)
    total = length(items)
    accuracy = exact_matches / total

    type_name =
      case type do
        0 -> "Exact match"
        1 -> "Close but wrong"
        2 -> "Contains answer"
        3 -> "Wrong answer"
      end

    {type_name, accuracy, total}
  end)
  |> Enum.sort()

IO.puts("\nPrediction Type Analysis:")

Enum.each(prediction_analysis, fn {type_name, accuracy, count} ->
  IO.puts("  #{type_name}: #{Float.round(accuracy * 100, 2)}% (#{count} items)")
end)

# Show some example results
Logger.info("\nExample predictions:\n")

results.item_results
|> Enum.take(5)
|> Enum.each(fn item ->
  expected_str =
    case item.expected do
      %{answer: ans} -> ans
      val -> val
    end

  IO.puts("ID: #{item.id}")
  IO.puts("  Expected: #{inspect(expected_str)}")
  IO.puts("  Predicted: #{inspect(item.predicted)}")
  IO.puts("  Exact Match: #{item.correct}")
  IO.puts("  Score: #{Float.round(item.score, 3)}")
  IO.puts("")
end)

Logger.info("=== Custom Metrics Example Completed ===")
