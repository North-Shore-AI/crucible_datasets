defmodule DatasetManager.EvaluationResult do
  @moduledoc """
  Results of evaluating predictions against a dataset.

  Contains both aggregate metrics and per-item results.
  """

  @type item_result :: %{
          id: String.t(),
          predicted: any(),
          expected: any(),
          correct: boolean(),
          score: float(),
          metrics: map(),
          metadata: map()
        }

  @type t :: %__MODULE__{
          dataset_name: String.t(),
          dataset_version: String.t(),
          model: String.t(),
          total_items: non_neg_integer(),
          correct_items: non_neg_integer(),
          accuracy: float(),
          metrics: map(),
          item_results: [item_result()],
          timestamp: DateTime.t(),
          duration_ms: non_neg_integer()
        }

  @enforce_keys [:dataset_name, :dataset_version, :model, :accuracy, :metrics]
  defstruct [
    :dataset_name,
    :dataset_version,
    :model,
    :total_items,
    :correct_items,
    :accuracy,
    :metrics,
    :item_results,
    :timestamp,
    :duration_ms
  ]

  @doc """
  Create a new evaluation result.
  """
  def new(dataset_name, dataset_version, model, item_results, metrics, duration_ms) do
    total = length(item_results)
    correct = Enum.count(item_results, & &1.correct)
    accuracy = if total > 0, do: correct / total, else: 0.0

    %__MODULE__{
      dataset_name: dataset_name,
      dataset_version: dataset_version,
      model: model,
      total_items: total,
      correct_items: correct,
      accuracy: accuracy,
      metrics: metrics,
      item_results: item_results,
      timestamp: DateTime.utc_now(),
      duration_ms: duration_ms
    }
  end

  @doc """
  Convert evaluation result to JSON-encodable map.
  """
  def to_json(%__MODULE__{} = result) do
    %{
      dataset_name: result.dataset_name,
      dataset_version: result.dataset_version,
      model: result.model,
      total_items: result.total_items,
      correct_items: result.correct_items,
      accuracy: result.accuracy,
      metrics: result.metrics,
      item_results: result.item_results,
      timestamp: DateTime.to_iso8601(result.timestamp),
      duration_ms: result.duration_ms
    }
  end
end
