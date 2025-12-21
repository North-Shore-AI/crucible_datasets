defmodule CrucibleDatasets.Loader.ChatTest do
  use ExUnit.Case, async: false

  alias CrucibleDatasets.Loader.Chat
  alias CrucibleDatasets.Types.Conversation

  describe "available_datasets/0" do
    test "returns list of available datasets" do
      datasets = Chat.available_datasets()

      assert :tulu3_sft in datasets
      assert :no_robots in datasets
    end
  end

  describe "load/2 with synthetic data" do
    test "loads synthetic chat data" do
      {:ok, dataset} = Chat.load(:tulu3_sft, synthetic: true)

      assert dataset.name == "tulu3_sft"
      assert length(dataset.items) > 0
      assert dataset.metadata.source == "synthetic"
    end

    test "respects sample_size option" do
      {:ok, dataset} = Chat.load(:tulu3_sft, synthetic: true, sample_size: 5)

      assert length(dataset.items) == 5
    end

    test "synthetic items have correct structure" do
      {:ok, dataset} = Chat.load(:no_robots, synthetic: true, sample_size: 1)

      first = hd(dataset.items)
      assert is_binary(first.id)
      assert is_map(first.input)
      assert Map.has_key?(first.input, :conversation)
      assert is_struct(first.input.conversation, Conversation)
    end
  end

  describe "load/2 with unknown dataset" do
    test "returns error for unknown dataset" do
      {:error, {:unknown_dataset, :unknown, available}} = Chat.load(:unknown)

      assert is_list(available)
    end
  end

  describe "load/2 with real data" do
    @moduletag :integration
    @tag timeout: 120_000

    test "loads real No Robots data from HuggingFace" do
      {:ok, dataset} = Chat.load(:no_robots, sample_size: 10)

      assert dataset.name == "no_robots"
      assert length(dataset.items) <= 10
      assert dataset.metadata.source =~ "huggingface"
    end
  end
end
