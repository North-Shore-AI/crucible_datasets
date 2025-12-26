defmodule CrucibleDatasets.Evaluator.F1 do
  @moduledoc """
  Token-level F1 score (precision and recall).

  Used for text generation where partial matches are meaningful.
  Computes F1 based on overlap of tokens between predicted and expected.
  """

  @doc """
  Compute F1 score between predicted and expected text.

  Returns value between 0.0 and 1.0.
  """
  def compute(predicted, expected) when is_binary(predicted) and is_binary(expected) do
    predicted_tokens = tokenize(predicted)
    expected_tokens = tokenize(expected)

    common = MapSet.intersection(predicted_tokens, expected_tokens)
    common_count = MapSet.size(common)
    pred_size = MapSet.size(predicted_tokens)
    exp_size = MapSet.size(expected_tokens)

    compute_f1_score(common_count, pred_size, exp_size)
  end

  # Handle map inputs (extract answer field)
  def compute(predicted, expected) when is_map(predicted) and is_map(expected) do
    pred_text = extract_text(predicted)
    exp_text = extract_text(expected)
    compute(pred_text, exp_text)
  end

  def compute(predicted, expected) when is_map(predicted) and is_binary(expected) do
    pred_text = extract_text(predicted)
    compute(pred_text, expected)
  end

  def compute(predicted, expected) when is_binary(predicted) and is_map(expected) do
    exp_text = extract_text(expected)
    compute(predicted, exp_text)
  end

  # For non-string types, convert to string first
  def compute(predicted, expected) when is_map(predicted) or is_map(expected) do
    pred_str = if is_map(predicted), do: inspect(predicted), else: to_string(predicted)
    exp_str = if is_map(expected), do: inspect(expected), else: to_string(expected)
    compute(pred_str, exp_str)
  end

  def compute(predicted, expected) do
    pred_str = to_string(predicted)
    exp_str = to_string(expected)
    compute(pred_str, exp_str)
  end

  # Tokenize text into set of normalized tokens
  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> MapSet.new()
  end

  # Extract text from map (check common answer fields)
  defp extract_text(map) when is_map(map) do
    Map.get(map, :answer) || Map.get(map, "answer") ||
      Map.get(map, :text) || Map.get(map, "text") ||
      Map.get(map, :response) || Map.get(map, "response") ||
      to_string(map)
  end

  # Compute F1 score from counts using pattern matching to avoid nested conditionals
  defp compute_f1_score(0, _pred_size, _exp_size), do: 0.0
  defp compute_f1_score(_common_count, 0, _exp_size), do: 0.0
  defp compute_f1_score(_common_count, _pred_size, 0), do: 0.0

  defp compute_f1_score(common_count, pred_size, exp_size) do
    precision = common_count / pred_size
    recall = common_count / exp_size
    compute_harmonic_mean(precision, recall)
  end

  defp compute_harmonic_mean(precision, recall) when precision + recall == 0, do: 0.0

  defp compute_harmonic_mean(precision, recall) do
    2 * (precision * recall) / (precision + recall)
  end
end
