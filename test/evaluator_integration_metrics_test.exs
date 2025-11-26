defmodule CrucibleDatasets.EvaluatorIntegrationMetricsTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.{Dataset, Evaluator}

  test "computes multiple metrics and forwards options" do
    dataset = dataset_fixture(["the quick brown fox", "jumps over lazy dog"], "demo")
    predictions = predictions_from_dataset(dataset)

    {:ok, result} =
      Evaluator.evaluate(predictions,
        dataset: dataset,
        metrics: [:exact_match, :bleu, :rouge, :rouge1, :rouge2, :rougel],
        model_name: "test-model",
        bleu_opts: [max_n: 2],
        rouge_opts: [variants: [:rouge1, :rouge2, :rougel]]
      )

    assert result.accuracy == 1.0

    Enum.each(result.item_results, fn item ->
      assert Map.has_key?(item.metrics, :bleu)
      assert Map.has_key?(item.metrics, :rouge)
      assert Map.has_key?(item.metrics, :rouge1)
      assert Map.has_key?(item.metrics, :rouge2)
      assert Map.has_key?(item.metrics, :rougel)
    end)

    assert_in_delta result.metrics.bleu, 1.0, 0.0001
    assert_in_delta result.metrics.rouge, 1.0, 0.0001
  end

  test "supports custom and unknown metrics without crashing" do
    dataset = dataset_fixture(["sample text"])
    predictions = predictions_from_dataset(dataset)

    custom_metric = fn predicted, expected ->
      if predicted == expected, do: 0.5, else: 0.0
    end

    {:ok, result} =
      Evaluator.evaluate(predictions,
        dataset: dataset,
        metrics: [custom_metric, :unknown],
        model_name: "test-model"
      )

    assert_in_delta result.metrics[custom_metric], 0.5, 0.0001
    assert result.metrics[:unknown] == 0.0
  end

  test "forwards BLEU options to avoid brevity penalty zeros" do
    dataset = dataset_fixture(["short"], "bleu")
    predictions = predictions_from_dataset(dataset)

    {:ok, result} =
      Evaluator.evaluate(predictions,
        dataset: dataset,
        metrics: [:bleu],
        bleu_opts: [max_n: 1]
      )

    assert_in_delta result.metrics.bleu, 1.0, 0.0001
  end

  defp dataset_fixture(texts, name \\ "dataset") do
    items =
      Enum.with_index(texts, fn text, idx ->
        %{
          id: "item_#{idx}",
          input: text,
          expected: text,
          metadata: %{source: :fixture}
        }
      end)

    dataset = Dataset.new(name, "1.0", items, %{source: "test"})
    {:ok, valid} = Dataset.validate(dataset)
    valid
  end

  defp predictions_from_dataset(dataset) do
    Enum.map(dataset.items, fn item ->
      %{id: item.id, predicted: item.expected, metadata: %{}}
    end)
  end
end
