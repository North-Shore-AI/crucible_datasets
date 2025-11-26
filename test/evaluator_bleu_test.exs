defmodule CrucibleDatasets.EvaluatorBLEUTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Evaluator.BLEU

  test "returns 1.0 for perfect match" do
    assert_in_delta BLEU.compute("the cat sat", "the cat sat", max_n: 3), 1.0, 0.0001
  end

  test "applies brevity penalty when candidate is shorter than reference" do
    score = BLEU.compute("the cat", "the cat sat on the mat", max_n: 2)

    assert_in_delta score, :math.exp(-2), 0.0001
  end

  test "supports smoothing to avoid zero precision" do
    assert BLEU.compute("foo", "bar", max_n: 1) == 0.0

    smoothed = BLEU.compute("foo", "bar", max_n: 1, smoothing: :add_epsilon)
    assert smoothed > 0.0
  end

  test "uses the best matching reference when multiple are provided" do
    score =
      BLEU.compute("the cat sat", ["the cat sat", "completely different text"], max_n: 3)

    assert_in_delta score, 1.0, 0.0001
  end

  test "handles non-string inputs" do
    assert_in_delta BLEU.compute(1, 1, max_n: 1), 1.0, 0.0001
  end

  test "keeps scores within [0, 1]" do
    score = BLEU.compute("random text", "another random sentence", max_n: 2, smoothing: :add_k)

    assert score >= 0.0 and score <= 1.0
  end
end
