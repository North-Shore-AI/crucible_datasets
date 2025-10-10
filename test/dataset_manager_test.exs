defmodule DatasetManagerTest do
  use ExUnit.Case
  doctest CrucibleDatasets

  alias CrucibleDatasets.{Dataset, Cache}

  setup do
    # Clear cache before each test
    Cache.clear_all()
    :ok
  end

  describe "load/2" do
    test "loads MMLU STEM dataset" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 50)

      assert dataset.name == "mmlu_stem"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 50
      assert dataset.metadata.domain == "STEM"
    end

    test "loads HumanEval dataset" do
      {:ok, dataset} = CrucibleDatasets.load(:humaneval, sample_size: 10)

      assert dataset.name == "humaneval"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 10
      assert dataset.metadata.domain == "code_generation"
    end

    test "loads GSM8K dataset" do
      {:ok, dataset} = CrucibleDatasets.load(:gsm8k, sample_size: 20)

      assert dataset.name == "gsm8k"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 20
      assert dataset.metadata.domain == "math_word_problems"
    end

    test "returns error for unknown dataset" do
      assert {:error, {:unknown_dataset, :unknown}} = CrucibleDatasets.load(:unknown)
    end

    test "caches loaded datasets" do
      # First load
      {:ok, dataset1} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10)

      # Second load should use cache
      {:ok, dataset2} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10)

      assert dataset1.name == dataset2.name
      assert dataset1.metadata.checksum == dataset2.metadata.checksum
    end

    test "respects cache: false option" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10, cache: false)

      assert dataset.name == "mmlu_stem"
      # Cache should not contain this dataset
      assert {:error, :not_cached} = Cache.get(:mmlu_stem)
    end
  end

  describe "evaluate/2" do
    test "evaluates predictions with exact match" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 5)

      predictions =
        Enum.map(dataset.items, fn item ->
          %{
            id: item.id,
            predicted: item.expected,
            metadata: %{}
          }
        end)

      {:ok, results} =
        CrucibleDatasets.evaluate(predictions,
          dataset: dataset,
          metrics: [:exact_match],
          model_name: "test_model"
        )

      assert results.accuracy == 1.0
      assert results.total_items == 5
      assert results.correct_items == 5
      assert results.model == "test_model"
    end

    test "evaluates predictions with multiple metrics" do
      {:ok, dataset} = CrucibleDatasets.load(:gsm8k, sample_size: 3)

      predictions =
        Enum.map(dataset.items, fn item ->
          %{
            id: item.id,
            predicted: item.expected.answer,
            metadata: %{}
          }
        end)

      {:ok, results} =
        CrucibleDatasets.evaluate(predictions,
          dataset: dataset,
          metrics: [:exact_match, :f1],
          model_name: "test_model"
        )

      assert results.accuracy == 1.0
      assert Map.has_key?(results.metrics, :exact_match)
      assert Map.has_key?(results.metrics, :f1)
    end

    test "returns error for invalid prediction IDs" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 5)

      predictions = [
        %{id: "invalid_id", predicted: 0, metadata: %{}}
      ]

      assert {:error, {:invalid_prediction_ids, ["invalid_id"]}} =
               CrucibleDatasets.evaluate(predictions, dataset: dataset)
    end
  end

  describe "random_sample/2" do
    test "creates random sample of specified size" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)
      {:ok, sample} = CrucibleDatasets.random_sample(dataset, size: 20)

      assert length(sample.items) == 20
      assert sample.metadata.sample_method == :random
      assert sample.metadata.sample_size == 20
      assert sample.metadata.original_size == length(dataset.items)
    end

    test "uses seed for reproducible sampling" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

      {:ok, sample1} = CrucibleDatasets.random_sample(dataset, size: 20, seed: 42)
      {:ok, sample2} = CrucibleDatasets.random_sample(dataset, size: 20, seed: 42)

      # Same seed should produce same sample
      assert Enum.map(sample1.items, & &1.id) == Enum.map(sample2.items, & &1.id)
    end
  end

  describe "stratified_sample/2" do
    test "maintains distribution of stratification field" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

      {:ok, sample} =
        CrucibleDatasets.stratified_sample(dataset,
          size: 30,
          strata_field: [:metadata, :subject]
        )

      assert length(sample.items) <= 30
      assert sample.metadata.sample_method == :stratified
    end

    test "returns error when missing required options" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

      assert {:error, :missing_required_option} = CrucibleDatasets.stratified_sample(dataset)
    end
  end

  describe "k_fold/2" do
    test "creates k-fold splits" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 50)
      {:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 5)

      assert length(folds) == 5

      Enum.each(folds, fn {train, test} ->
        assert is_struct(train, Dataset)
        assert is_struct(test, Dataset)
        assert length(train.items) + length(test.items) == length(dataset.items)
      end)
    end

    test "creates folds without shuffle" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 50)
      {:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 5, shuffle: false)

      assert length(folds) == 5
    end
  end

  describe "train_test_split/2" do
    test "splits dataset into train and test sets" do
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)
      {:ok, {train, test}} = CrucibleDatasets.train_test_split(dataset, test_size: 0.2)

      total = length(dataset.items)
      assert length(train.items) + length(test.items) == total
      assert_in_delta length(test.items) / total, 0.2, 0.05
    end
  end

  describe "cache management" do
    test "lists cached datasets" do
      {:ok, _dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10)

      cached = CrucibleDatasets.list_cached()
      assert is_list(cached)
    end

    test "invalidates specific dataset cache" do
      {:ok, _dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10)

      assert :ok = CrucibleDatasets.invalidate_cache(:mmlu_stem)
      assert {:error, :not_cached} = Cache.get(:mmlu_stem)
    end

    test "clears all cache" do
      {:ok, _dataset1} = CrucibleDatasets.load(:mmlu_stem, sample_size: 10)
      {:ok, _dataset2} = CrucibleDatasets.load(:gsm8k, sample_size: 10)

      assert :ok = CrucibleDatasets.clear_cache()

      assert {:error, :not_cached} = Cache.get(:mmlu_stem)
      assert {:error, :not_cached} = Cache.get(:gsm8k)
    end
  end
end
