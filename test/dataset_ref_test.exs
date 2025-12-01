defmodule CrucibleDatasets.DatasetRefTest do
  use ExUnit.Case

  alias CrucibleDatasets.{Dataset, Cache}
  alias CrucibleIR.DatasetRef

  setup do
    # Clear cache before each test
    Cache.clear_all()
    :ok
  end

  describe "load/1 with DatasetRef" do
    test "loads dataset using DatasetRef struct" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 50]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "mmlu_stem"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 50
      assert dataset.metadata.domain == "STEM"
    end

    test "loads HumanEval dataset using DatasetRef" do
      ref = %DatasetRef{
        name: :humaneval,
        split: :test,
        options: [sample_size: 10]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "humaneval"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 10
      assert dataset.metadata.domain == "code_generation"
    end

    test "loads GSM8K dataset using DatasetRef" do
      ref = %DatasetRef{
        name: :gsm8k,
        split: :train,
        options: [sample_size: 20]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "gsm8k"
      assert dataset.version == "1.0"
      assert length(dataset.items) <= 20
      assert dataset.metadata.domain == "math_word_problems"
    end

    test "loads dataset with nil options in DatasetRef" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: nil
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "mmlu_stem"
      assert dataset.version == "1.0"
    end

    test "loads dataset with empty options in DatasetRef" do
      ref = %DatasetRef{
        name: :humaneval,
        split: :test,
        options: []
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "humaneval"
      assert dataset.version == "1.0"
    end

    test "returns error for unknown dataset in DatasetRef" do
      ref = %DatasetRef{
        name: :unknown_dataset,
        split: :train,
        options: []
      }

      assert {:error, {:unknown_dataset, :unknown_dataset}} = CrucibleDatasets.load(ref)
    end

    test "respects cache option in DatasetRef" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 10, cache: false]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

      assert dataset.name == "mmlu_stem"
      # Cache should not contain this dataset
      assert {:error, :not_cached} = Cache.get(:mmlu_stem)
    end

    test "caches dataset when loaded via DatasetRef" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 10]
      }

      # First load
      {:ok, dataset1} = CrucibleDatasets.load(ref)

      # Second load should use cache
      {:ok, dataset2} = CrucibleDatasets.load(ref)

      assert dataset1.name == dataset2.name
      assert dataset1.metadata.checksum == dataset2.metadata.checksum
    end

    test "works with different sample sizes in DatasetRef" do
      ref1 = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 10]
      }

      ref2 = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 20]
      }

      {:ok, dataset1} = CrucibleDatasets.load(ref1)
      {:ok, dataset2} = CrucibleDatasets.load(ref2)

      assert length(dataset1.items) <= 10
      assert length(dataset2.items) <= 20
    end
  end

  describe "DatasetRef integration with evaluation" do
    test "can evaluate predictions using dataset loaded from DatasetRef" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 5]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)

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
    end
  end

  describe "DatasetRef integration with sampling" do
    test "can sample dataset loaded from DatasetRef" do
      ref = %DatasetRef{
        name: :mmlu_stem,
        split: :train,
        options: [sample_size: 100]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)
      {:ok, sample} = CrucibleDatasets.random_sample(dataset, size: 20)

      assert length(sample.items) == 20
      assert sample.metadata.sample_method == :random
    end

    test "can create k-fold splits from DatasetRef-loaded dataset" do
      ref = %DatasetRef{
        name: :gsm8k,
        split: :train,
        options: [sample_size: 50]
      }

      {:ok, dataset} = CrucibleDatasets.load(ref)
      {:ok, folds} = CrucibleDatasets.k_fold(dataset, k: 5)

      assert length(folds) == 5

      Enum.each(folds, fn {train, test} ->
        assert is_struct(train, Dataset)
        assert is_struct(test, Dataset)
        assert length(train.items) + length(test.items) == length(dataset.items)
      end)
    end
  end
end
