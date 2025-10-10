defmodule DatasetManager.Evaluator do
  @moduledoc """
  Evaluate model predictions against ground truth with multiple metrics.

  Supports:
  - Exact match (with normalization)
  - F1 score (token-level)
  - Custom metrics
  """

  alias DatasetManager.{Dataset, EvaluationResult, Loader}
  alias DatasetManager.Evaluator.{ExactMatch, F1}

  @type prediction :: %{
          id: String.t(),
          predicted: any(),
          metadata: map()
        }

  @doc """
  Evaluate predictions against a dataset.

  ## Options
    * `:dataset` - Dataset name or dataset struct (required)
    * `:metrics` - List of metrics to compute (default: [:exact_match, :f1])
    * `:model_name` - Model identifier for tracking (default: "unknown")

  ## Examples

      predictions = [
        %{id: "q1", predicted: "Paris", metadata: %{}},
        %{id: "q2", predicted: "42", metadata: %{}}
      ]

      {:ok, results} = DatasetManager.Evaluator.evaluate(
        predictions,
        dataset: :mmlu_stem,
        metrics: [:exact_match, :f1],
        model_name: "ensemble_5x_flash"
      )

      results.accuracy
      # => 0.85
  """
  @spec evaluate([prediction()], keyword()) :: {:ok, EvaluationResult.t()} | {:error, term()}
  def evaluate(predictions, opts \\ []) do
    metrics = Keyword.get(opts, :metrics, [:exact_match, :f1])
    model_name = Keyword.get(opts, :model_name, "unknown")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, dataset} <- load_dataset(opts),
         :ok <- validate_predictions(predictions, dataset),
         {:ok, item_results} <- evaluate_items(predictions, dataset, metrics),
         {:ok, aggregated} <- aggregate_metrics(item_results, metrics) do
      duration_ms = System.monotonic_time(:millisecond) - start_time

      result =
        EvaluationResult.new(
          dataset.name,
          dataset.version,
          model_name,
          item_results,
          aggregated,
          duration_ms
        )

      {:ok, result}
    end
  end

  @doc """
  Batch evaluate multiple models on same dataset.

  Returns comparative results.
  """
  @spec evaluate_batch([{String.t(), [prediction()]}], keyword()) ::
          {:ok, [EvaluationResult.t()]} | {:error, term()}
  def evaluate_batch(model_predictions, opts \\ []) do
    results =
      Enum.map(model_predictions, fn {model_name, predictions} ->
        opts_with_model = Keyword.put(opts, :model_name, model_name)
        evaluate(predictions, opts_with_model)
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, result} -> result end)}
    else
      first_error = Enum.find(results, &match?({:error, _}, &1))
      first_error
    end
  end

  # Private helpers

  defp load_dataset(opts) do
    case Keyword.fetch(opts, :dataset) do
      {:ok, %Dataset{} = dataset} ->
        {:ok, dataset}

      {:ok, dataset_name} ->
        Loader.load(dataset_name)

      :error ->
        {:error, :dataset_required}
    end
  end

  defp validate_predictions(predictions, dataset) do
    dataset_ids = MapSet.new(dataset.items, & &1.id)
    prediction_ids = MapSet.new(predictions, & &1.id)

    # Check if all prediction IDs exist in dataset
    invalid_ids = MapSet.difference(prediction_ids, dataset_ids) |> MapSet.to_list()

    if invalid_ids == [] do
      :ok
    else
      {:error, {:invalid_prediction_ids, invalid_ids}}
    end
  end

  defp evaluate_items(predictions, dataset, metrics) do
    # Create lookup map for expected values
    expected_map = Map.new(dataset.items, fn item -> {item.id, item} end)

    item_results =
      Enum.map(predictions, fn pred ->
        expected_item = Map.fetch!(expected_map, pred.id)
        evaluate_single_item(pred, expected_item, metrics)
      end)

    {:ok, item_results}
  end

  defp evaluate_single_item(prediction, expected_item, metrics) do
    metric_scores =
      metrics
      |> Enum.map(fn metric ->
        score = compute_metric(metric, prediction.predicted, expected_item.expected)
        {metric, score}
      end)
      |> Map.new()

    correct? = Map.get(metric_scores, :exact_match, 0.0) == 1.0

    %{
      id: prediction.id,
      predicted: prediction.predicted,
      expected: expected_item.expected,
      correct: correct?,
      score: Map.get(metric_scores, :exact_match, 0.0),
      metrics: metric_scores,
      metadata: Map.merge(expected_item.metadata || %{}, prediction.metadata || %{})
    }
  end

  defp compute_metric(:exact_match, predicted, expected) do
    ExactMatch.compute(predicted, expected)
  end

  defp compute_metric(:f1, predicted, expected) do
    F1.compute(predicted, expected)
  end

  defp compute_metric(custom_metric, predicted, expected) when is_function(custom_metric, 2) do
    custom_metric.(predicted, expected)
  end

  defp compute_metric(_unknown, _predicted, _expected), do: 0.0

  defp aggregate_metrics(item_results, metrics) do
    aggregated =
      metrics
      |> Enum.map(fn metric ->
        scores = Enum.map(item_results, fn item -> item.metrics[metric] || 0.0 end)
        avg_score = if length(scores) > 0, do: Enum.sum(scores) / length(scores), else: 0.0
        {metric, avg_score}
      end)
      |> Map.new()

    {:ok, aggregated}
  end
end
