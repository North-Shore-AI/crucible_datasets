defmodule CrucibleDatasets.Loader.MathTest do
  use ExUnit.Case, async: false

  alias CrucibleDatasets.Loader.Math

  describe "available_datasets/0" do
    test "returns list of available datasets" do
      datasets = Math.available_datasets()

      assert :math_500 in datasets
      assert :hendrycks_math in datasets
      assert :deepmath in datasets
      assert :polaris in datasets
    end
  end

  describe "extract_boxed_answer/1" do
    test "extracts simple boxed answer" do
      assert Math.extract_boxed_answer("The answer is \\boxed{42}") == "42"
    end

    test "extracts expression from boxed" do
      assert Math.extract_boxed_answer("\\boxed{x^2 + 1}") == "x^2 + 1"
    end

    test "extracts nested braces" do
      assert Math.extract_boxed_answer("\\boxed{\\frac{1}{2}}") == "\\frac{1}{2}"
    end

    test "returns nil for no boxed answer" do
      assert Math.extract_boxed_answer("No boxed answer here") == nil
    end

    test "returns nil for nil input" do
      assert Math.extract_boxed_answer(nil) == nil
    end
  end

  describe "load/2 with synthetic data" do
    test "loads synthetic math data" do
      {:ok, dataset} = Math.load(:math_500, synthetic: true)

      assert dataset.name == "math_500"
      assert length(dataset.items) > 0
      assert dataset.metadata.source == "synthetic"
    end

    test "respects sample_size option" do
      {:ok, dataset} = Math.load(:hendrycks_math, synthetic: true, sample_size: 5)

      assert length(dataset.items) == 5
    end

    test "synthetic items have correct structure" do
      {:ok, dataset} = Math.load(:math_500, synthetic: true, sample_size: 1)

      first = hd(dataset.items)
      assert is_binary(first.id)
      assert is_map(first.input)
      assert Map.has_key?(first.input, :problem)
      assert is_binary(first.expected) or is_nil(first.expected)
      assert is_map(first.metadata)
    end
  end

  describe "load/2 with unknown dataset" do
    test "returns error for unknown dataset" do
      {:error, {:unknown_dataset, :unknown, available}} = Math.load(:unknown)

      assert is_list(available)
    end
  end
end
