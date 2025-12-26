defmodule CrucibleDatasets.Loader.NoRobotsTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Loader.NoRobots

  describe "load/1" do
    test "loads NoRobots dataset with defaults" do
      {:ok, dataset} = NoRobots.load()

      assert %Dataset{} = dataset
      assert dataset.name == "no_robots"
      assert is_list(dataset.items)
      refute Enum.empty?(dataset.items)
    end

    test "respects sample_size option" do
      {:ok, dataset} = NoRobots.load(sample_size: 10)

      assert length(dataset.items) <= 10
    end

    test "items have required fields" do
      {:ok, dataset} = NoRobots.load(sample_size: 5)

      Enum.each(dataset.items, fn item ->
        assert Map.has_key?(item, :id)
        assert Map.has_key?(item, :input)
        assert Map.has_key?(item, :expected)
        assert is_binary(item.input)
        assert is_binary(item.expected)
      end)
    end

    test "items have metadata" do
      {:ok, dataset} = NoRobots.load(sample_size: 5)

      Enum.each(dataset.items, fn item ->
        assert Map.has_key?(item, :metadata)
        assert is_map(item.metadata)
      end)
    end

    test "metadata contains category field" do
      {:ok, dataset} = NoRobots.load(sample_size: 5)

      Enum.each(dataset.items, fn item ->
        assert Map.has_key?(item.metadata, :category)
        assert is_binary(item.metadata.category)
      end)
    end

    test "dataset has proper metadata" do
      {:ok, dataset} = NoRobots.load()

      assert dataset.version == "1.0"
      assert dataset.metadata.source == "huggingface:HuggingFaceH4/no_robots"
      assert dataset.metadata.license == "Apache-2.0"
      assert dataset.metadata.domain == "instruction_following"
    end

    test "different splits can be loaded" do
      {:ok, train} = NoRobots.load(split: :train, sample_size: 5)
      {:ok, test} = NoRobots.load(split: :test, sample_size: 5)

      assert train.name == "no_robots"
      assert test.name == "no_robots"
    end

    test "seed option produces reproducible results" do
      {:ok, dataset1} = NoRobots.load(sample_size: 10, seed: 42)
      {:ok, dataset2} = NoRobots.load(sample_size: 10, seed: 42)

      assert Enum.map(dataset1.items, & &1.id) == Enum.map(dataset2.items, & &1.id)
    end
  end
end
