defmodule CrucibleDatasets.EvaluatorROUGEAggregateTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Evaluator.ROUGE

  test "averages precision, recall, and f1 across predictions" do
    predictions = [
      %{predicted: "the cat sat", expected: "the cat sat on mat"},
      %{predicted: "dog ran", expected: "the dog ran fast"}
    ]

    scores = ROUGE.compute_aggregate(predictions)

    assert_in_delta scores.rouge1.precision, 1.0, 0.0001
    assert_in_delta scores.rouge1.recall, 0.55, 0.0001
    assert_in_delta scores.rouge1.f1, 0.7083, 0.0001

    assert_in_delta scores.rouge2.precision, 1.0, 0.0001
    assert_in_delta scores.rouge2.recall, 0.4167, 0.0001
    assert_in_delta scores.rouge2.f1, 0.5833, 0.0001

    assert_in_delta scores.rougel.precision, 1.0, 0.0001
    assert_in_delta scores.rougel.recall, 0.55, 0.0001
    assert_in_delta scores.rougel.f1, 0.7083, 0.0001
  end
end
