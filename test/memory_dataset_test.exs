defmodule CrucibleDatasets.MemoryDatasetTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.{Dataset, MemoryDataset}

  describe "from_list/2" do
    test "creates dataset from simple list of items" do
      items = [
        %{input: "What is 2+2?", expected: "4"},
        %{input: "What is 3+3?", expected: "6"}
      ]

      dataset = MemoryDataset.from_list(items)

      assert %Dataset{} = dataset
      assert String.starts_with?(dataset.name, "memory_")
      assert dataset.version == "1.0.0"
      assert length(dataset.items) == 2
      assert dataset.metadata.source == :memory
      assert dataset.metadata.total_items == 2
    end

    test "auto-generates IDs when not provided" do
      items = [
        %{input: "Q1", expected: "A1"},
        %{input: "Q2", expected: "A2"}
      ]

      dataset = MemoryDataset.from_list(items)

      assert Enum.at(dataset.items, 0).id == "item_1"
      assert Enum.at(dataset.items, 1).id == "item_2"
    end

    test "preserves explicit IDs when provided" do
      items = [
        %{id: "custom_1", input: "Q1", expected: "A1"},
        %{id: "custom_2", input: "Q2", expected: "A2"}
      ]

      dataset = MemoryDataset.from_list(items)

      assert Enum.at(dataset.items, 0).id == "custom_1"
      assert Enum.at(dataset.items, 1).id == "custom_2"
    end

    test "disables auto-ID generation when auto_id: false" do
      items = [
        %{id: "custom_1", input: "Q1", expected: "A1"},
        %{input: "Q2", expected: "A2"}
      ]

      dataset = MemoryDataset.from_list(items, auto_id: false)

      assert Enum.at(dataset.items, 0).id == "custom_1"
      assert Enum.at(dataset.items, 1).id == nil
    end

    test "accepts custom name" do
      items = [%{input: "Q1", expected: "A1"}]

      dataset = MemoryDataset.from_list(items, name: "my_dataset")

      assert dataset.name == "my_dataset"
    end

    test "accepts custom version" do
      items = [%{input: "Q1", expected: "A1"}]

      dataset = MemoryDataset.from_list(items, version: "2.0.0")

      assert dataset.version == "2.0.0"
    end

    test "preserves metadata from items" do
      items = [
        %{input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}},
        %{input: "Q2", expected: "A2", metadata: %{difficulty: "hard"}}
      ]

      dataset = MemoryDataset.from_list(items)

      assert Enum.at(dataset.items, 0).metadata == %{difficulty: "easy"}
      assert Enum.at(dataset.items, 1).metadata == %{difficulty: "hard"}
    end

    test "sets empty metadata when not provided" do
      items = [%{input: "Q1", expected: "A1"}]

      dataset = MemoryDataset.from_list(items)

      assert Enum.at(dataset.items, 0).metadata == %{}
    end

    test "sets empty expected when not provided" do
      items = [%{input: "Q1"}]

      dataset = MemoryDataset.from_list(items)

      assert Enum.at(dataset.items, 0).expected == ""
    end

    test "creates empty dataset from empty list" do
      dataset = MemoryDataset.from_list([])

      assert %Dataset{} = dataset
      assert dataset.items == []
      assert dataset.metadata.total_items == 0
    end

    test "generates unique names for multiple datasets" do
      dataset1 = MemoryDataset.from_list([%{input: "Q1", expected: "A1"}])
      dataset2 = MemoryDataset.from_list([%{input: "Q2", expected: "A2"}])

      assert dataset1.name != dataset2.name
    end

    test "raises when input is missing" do
      items = [%{expected: "A1"}]

      assert_raise KeyError, fn ->
        MemoryDataset.from_list(items)
      end
    end
  end

  describe "from_samples/2" do
    test "creates dataset from samples" do
      samples = [
        %{input: "What is 2+2?", expected: "4"},
        %{input: "What is 3+3?", expected: "6"}
      ]

      dataset = MemoryDataset.from_samples(samples)

      assert %Dataset{} = dataset
      assert length(dataset.items) == 2
    end

    test "accepts options like from_list" do
      samples = [%{input: "Q1", expected: "A1"}]

      dataset = MemoryDataset.from_samples(samples, name: "samples_dataset")

      assert dataset.name == "samples_dataset"
    end
  end
end
