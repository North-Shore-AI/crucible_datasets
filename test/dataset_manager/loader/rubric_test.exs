defmodule CrucibleDatasets.Loader.RubricTest do
  use ExUnit.Case, async: false

  alias CrucibleDatasets.Loader.Rubric

  describe "load/2" do
    test "loads rubric data" do
      {:ok, dataset} = Rubric.load(:feedback_collection, TestHelper.data_opts())

      assert dataset.name == "feedback_collection"
      assert length(dataset.items) > 0
      assert dataset.metadata.domain == "rubric_evaluation"
    end

    test "respects sample_size option" do
      {:ok, dataset} = Rubric.load(:feedback_collection, TestHelper.data_opts(sample_size: 5))

      assert length(dataset.items) == 5
    end

    test "items have correct structure" do
      {:ok, dataset} = Rubric.load(:feedback_collection, TestHelper.data_opts(sample_size: 1))

      first = hd(dataset.items)
      assert is_binary(first.id)
      assert is_map(first.input)
      assert Map.has_key?(first.input, :instruction)
      assert Map.has_key?(first.input, :criteria)
      assert is_map(first.expected)
      assert Map.has_key?(first.expected, :reference_answer)
      assert Map.has_key?(first.expected, :rubric)
      assert is_map(first.expected.rubric)
      assert is_map(first.metadata)
      assert Map.has_key?(first.metadata, :has_rubric)
    end

    test "rubric contains score descriptions" do
      {:ok, dataset} = Rubric.load(:feedback_collection, TestHelper.data_opts(sample_size: 1))

      first = hd(dataset.items)
      rubric = first.expected.rubric

      assert Map.has_key?(rubric, 1)
      assert Map.has_key?(rubric, 5)
      assert is_binary(rubric[1])
      assert is_binary(rubric[5])
    end
  end

  describe "available_datasets/0" do
    test "returns list of available datasets" do
      datasets = Rubric.available_datasets()

      assert :feedback_collection in datasets
    end
  end

  describe "error handling" do
    test "returns error for unknown dataset" do
      assert {:error, {:unknown_dataset, :nonexistent, _}} =
               Rubric.load(:nonexistent, TestHelper.data_opts())
    end
  end

  describe "load/2 with real data" do
    @moduletag :integration
    @tag timeout: 120_000

    test "loads Feedback-Collection data (with fallback to synthetic)" do
      {:ok, dataset} = Rubric.load(:feedback_collection, sample_size: 10)

      assert dataset.name == "feedback_collection"
      assert length(dataset.items) == 10
      # May fallback to synthetic if HuggingFace unavailable
      assert dataset.metadata.source =~ "huggingface" or dataset.metadata.source == "synthetic"
    end

    @tag timeout: 120_000
    test "items have correct structure (with fallback to synthetic)" do
      {:ok, dataset} = Rubric.load(:feedback_collection, sample_size: 5)

      first = hd(dataset.items)
      assert is_binary(first.id)
      assert is_map(first.input)
      assert Map.has_key?(first.input, :instruction)
      assert is_map(first.expected)
      assert is_map(first.metadata)
    end
  end
end
