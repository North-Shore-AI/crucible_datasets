defmodule CrucibleDatasets.Evaluator.ExactMatch do
  @moduledoc """
  Exact match evaluation (case-insensitive, normalized).

  Handles:
  - String comparison (normalized, case-insensitive)
  - Numerical comparison (with tolerance)
  - Multiple choice (index comparison)
  - Set comparison (unordered lists)
  """

  @doc """
  Compute exact match score (1.0 or 0.0).
  """
  def compute(predicted, expected) when is_binary(predicted) and is_binary(expected) do
    if normalize_string(predicted) == normalize_string(expected), do: 1.0, else: 0.0
  end

  def compute(predicted, expected) when is_float(predicted) and is_float(expected) do
    tolerance = abs(expected) * 0.01
    if abs(predicted - expected) <= tolerance, do: 1.0, else: 0.0
  end

  def compute(predicted, expected) when is_float(predicted) and is_integer(expected) do
    compute(predicted, expected * 1.0)
  end

  def compute(predicted, expected) when is_integer(predicted) and is_float(expected) do
    compute(predicted * 1.0, expected)
  end

  def compute(predicted, expected) when is_integer(predicted) and is_integer(expected) do
    if predicted == expected, do: 1.0, else: 0.0
  end

  def compute(predicted, expected) when is_list(predicted) and is_list(expected) do
    if MapSet.new(predicted) == MapSet.new(expected), do: 1.0, else: 0.0
  end

  # Handle map comparisons (for structured answers)
  def compute(predicted, expected) when is_map(predicted) and is_map(expected) do
    # For maps, compare the answer field if it exists
    pred_answer = Map.get(predicted, :answer) || Map.get(predicted, "answer")
    exp_answer = Map.get(expected, :answer) || Map.get(expected, "answer")

    if pred_answer && exp_answer do
      compute(pred_answer, exp_answer)
    else
      # Full map comparison
      if predicted == expected, do: 1.0, else: 0.0
    end
  end

  # Handle when predicted is simple value but expected is a map (e.g., GSM8K)
  def compute(predicted, expected) when is_map(expected) and not is_map(predicted) do
    exp_answer = Map.get(expected, :answer) || Map.get(expected, "answer")

    if exp_answer do
      compute(predicted, exp_answer)
    else
      0.0
    end
  end

  # Handle when predicted is different type than expected
  def compute(predicted, expected) when is_binary(predicted) and is_integer(expected) do
    case Integer.parse(predicted) do
      {num, _} -> compute(num, expected)
      :error -> 0.0
    end
  end

  def compute(predicted, expected) when is_integer(predicted) and is_binary(expected) do
    compute(Integer.to_string(predicted), expected)
  end

  def compute(_predicted, _expected), do: 0.0

  # Normalize string for comparison
  defp normalize_string(str) do
    str
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/[^\w\s]/, "")
  end
end
