defmodule CrucibleDatasets.EvaluatorROUGETest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Evaluator.ROUGE

  test "computes rouge1/rouge2/rougel for simple strings" do
    scores = ROUGE.compute("the cat sat on the mat", "the cat is on the mat")

    assert_in_delta scores.rouge1.f1, 5 / 6, 0.0001
    assert_in_delta scores.rouge2.f1, 0.6, 0.0001
    assert_in_delta scores.rougel.f1, 5 / 6, 0.0001
  end

  test "selects the best reference when multiple are provided" do
    candidate = "the cat sat"
    ref1 = "the cat sat on mat"
    ref2 = "completely different text"

    scores = ROUGE.compute(candidate, [ref1, ref2], variants: [:rouge1])
    direct = ROUGE.compute(candidate, ref1, variants: [:rouge1])

    assert_in_delta scores.rouge1.f1, direct.rouge1.f1, 0.0001
  end

  test "normalizes casing and punctuation" do
    scores = ROUGE.compute("The, CAT!", "the cat")

    assert_in_delta scores.rouge1.f1, 1.0, 0.0001
    assert_in_delta scores.rouge2.f1, 1.0, 0.0001
    assert_in_delta scores.rougel.f1, 1.0, 0.0001
  end

  test "returns zeros for unknown variants" do
    scores = ROUGE.compute("foo", "bar", variants: [:rouge99])

    assert scores.rouge99 == %{precision: 0.0, recall: 0.0, f1: 0.0}
  end

  test "handles empty candidate gracefully" do
    scores = ROUGE.compute("", "some text")

    assert Enum.all?(scores, fn {_variant, metrics} -> metrics.f1 == 0.0 end)
  end
end
