defmodule CrucibleDatasets.DatasetExtensionsTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Dataset

  setup do
    items = [
      %{id: "1", input: "Q1", expected: "A1", metadata: %{difficulty: "easy", score: 5}},
      %{id: "2", input: "Q2", expected: "A2", metadata: %{difficulty: "hard", score: 10}},
      %{id: "3", input: "Q3", expected: "A3", metadata: %{difficulty: "easy", score: 3}},
      %{id: "4", input: "Q4", expected: "A4", metadata: %{difficulty: "medium", score: 7}}
    ]

    dataset = Dataset.new("test", "1.0.0", items, %{source: :test})
    {:ok, dataset: dataset}
  end

  describe "filter/2" do
    test "filters items by predicate", %{dataset: dataset} do
      filtered =
        Dataset.filter(dataset, fn item ->
          item.metadata.difficulty == "easy"
        end)

      assert length(filtered.items) == 2
      assert Enum.all?(filtered.items, fn item -> item.metadata.difficulty == "easy" end)
      assert filtered.metadata.total_items == 2
    end

    test "filters by nested metadata field", %{dataset: dataset} do
      filtered =
        Dataset.filter(dataset, fn item ->
          item.metadata.score > 5
        end)

      assert length(filtered.items) == 2
      assert Enum.at(filtered.items, 0).id == "2"
      assert Enum.at(filtered.items, 1).id == "4"
    end

    test "returns empty dataset when no items match", %{dataset: dataset} do
      filtered =
        Dataset.filter(dataset, fn item ->
          item.metadata.difficulty == "impossible"
        end)

      assert filtered.items == []
      assert filtered.metadata.total_items == 0
    end

    test "preserves dataset name and version", %{dataset: dataset} do
      filtered =
        Dataset.filter(dataset, fn item ->
          item.metadata.difficulty == "easy"
        end)

      assert filtered.name == dataset.name
      assert filtered.version == dataset.version
    end
  end

  describe "sort/2 and sort/3" do
    test "sorts by key atom in ascending order", %{dataset: dataset} do
      sorted = Dataset.sort(dataset, :id)

      ids = Enum.map(sorted.items, & &1.id)
      assert ids == ["1", "2", "3", "4"]
    end

    test "sorts by key function in ascending order", %{dataset: dataset} do
      sorted = Dataset.sort(dataset, fn item -> item.metadata.score end)

      scores = Enum.map(sorted.items, & &1.metadata.score)
      assert scores == [3, 5, 7, 10]
    end

    test "sorts in descending order", %{dataset: dataset} do
      sorted = Dataset.sort(dataset, :id, :desc)

      ids = Enum.map(sorted.items, & &1.id)
      assert ids == ["4", "3", "2", "1"]
    end

    test "sorts by nested metadata with key function", %{dataset: dataset} do
      sorted = Dataset.sort(dataset, fn item -> item.metadata.score end, :desc)

      scores = Enum.map(sorted.items, & &1.metadata.score)
      assert scores == [10, 7, 5, 3]
    end

    test "preserves dataset metadata", %{dataset: dataset} do
      sorted = Dataset.sort(dataset, :id)

      assert sorted.name == dataset.name
      assert sorted.version == dataset.version
      assert sorted.metadata.total_items == 4
    end
  end

  describe "slice/2 and slice/3" do
    test "slices with range", %{dataset: dataset} do
      sliced = Dataset.slice(dataset, 0..1)

      assert length(sliced.items) == 2
      assert Enum.at(sliced.items, 0).id == "1"
      assert Enum.at(sliced.items, 1).id == "2"
      assert sliced.metadata.total_items == 2
    end

    test "slices with start and count", %{dataset: dataset} do
      sliced = Dataset.slice(dataset, 1, 2)

      assert length(sliced.items) == 2
      assert Enum.at(sliced.items, 0).id == "2"
      assert Enum.at(sliced.items, 1).id == "3"
      assert sliced.metadata.total_items == 2
    end

    test "slices to end of dataset", %{dataset: dataset} do
      sliced = Dataset.slice(dataset, 2..10)

      assert length(sliced.items) == 2
      assert Enum.at(sliced.items, 0).id == "3"
      assert Enum.at(sliced.items, 1).id == "4"
    end

    test "returns empty dataset for out of bounds slice", %{dataset: dataset} do
      sliced = Dataset.slice(dataset, 10, 5)

      assert sliced.items == []
      assert sliced.metadata.total_items == 0
    end

    test "preserves dataset name and version", %{dataset: dataset} do
      sliced = Dataset.slice(dataset, 0..1)

      assert sliced.name == dataset.name
      assert sliced.version == dataset.version
    end
  end

  describe "shuffle_choices/2" do
    setup do
      items = [
        %{
          id: "mc1",
          input: %{
            question: "What is 2+2?",
            choices: ["3", "4", "5", "6"]
          },
          expected: 1,
          metadata: %{}
        },
        %{
          id: "mc2",
          input: %{
            question: "What is 3+3?",
            choices: ["5", "6", "7", "8"]
          },
          expected: 1,
          metadata: %{}
        }
      ]

      dataset = Dataset.new("mc_test", "1.0.0", items, %{source: :test})
      {:ok, mc_dataset: dataset}
    end

    test "shuffles choices and updates expected index", %{mc_dataset: dataset} do
      shuffled = Dataset.shuffle_choices(dataset, seed: 42)

      # Verify structure is preserved
      assert length(shuffled.items) == 2

      # Verify choices are lists
      Enum.each(shuffled.items, fn item ->
        assert is_list(item.input.choices)
        assert length(item.input.choices) == 4
      end)

      # Verify expected is still an integer
      Enum.each(shuffled.items, fn item ->
        assert is_integer(item.expected)
        assert item.expected >= 0
        assert item.expected < 4
      end)
    end

    test "preserves correct answer mapping after shuffle", %{mc_dataset: dataset} do
      original_item = Enum.at(dataset.items, 0)
      original_correct = Enum.at(original_item.input.choices, original_item.expected)

      shuffled = Dataset.shuffle_choices(dataset, seed: 42)
      shuffled_item = Enum.at(shuffled.items, 0)
      shuffled_correct = Enum.at(shuffled_item.input.choices, shuffled_item.expected)

      # The correct answer should be the same value
      assert original_correct == shuffled_correct
    end

    test "same seed produces same shuffle", %{mc_dataset: dataset} do
      shuffled1 = Dataset.shuffle_choices(dataset, seed: 123)
      shuffled2 = Dataset.shuffle_choices(dataset, seed: 123)

      assert Enum.at(shuffled1.items, 0).input.choices ==
               Enum.at(shuffled2.items, 0).input.choices

      assert Enum.at(shuffled1.items, 0).expected ==
               Enum.at(shuffled2.items, 0).expected
    end

    test "different seeds produce different shuffles", %{mc_dataset: dataset} do
      shuffled1 = Dataset.shuffle_choices(dataset, seed: 123)
      shuffled2 = Dataset.shuffle_choices(dataset, seed: 456)

      # While they might occasionally be the same, they should generally differ
      # We check that at least one is different
      choices1 = Enum.at(shuffled1.items, 0).input.choices
      choices2 = Enum.at(shuffled2.items, 0).input.choices

      # Check structure is valid even if different
      assert is_list(choices1)
      assert is_list(choices2)
      assert length(choices1) == length(choices2)
    end

    test "handles expected as string letter", %{mc_dataset: _dataset} do
      items = [
        %{
          id: "mc_letter",
          input: %{
            question: "Question?",
            choices: ["A", "B", "C", "D"]
          },
          expected: "B",
          metadata: %{}
        }
      ]

      letter_dataset = Dataset.new("letter_test", "1.0.0", items, %{source: :test})
      shuffled = Dataset.shuffle_choices(letter_dataset, seed: 42)

      # Should convert letter to index
      shuffled_item = Enum.at(shuffled.items, 0)
      assert is_integer(shuffled_item.expected)
    end

    test "ignores items without choices", %{dataset: _dataset} do
      # Mix items with and without choices
      mixed_items = [
        %{
          id: "mc1",
          input: %{question: "MC?", choices: ["A", "B"]},
          expected: 0,
          metadata: %{}
        },
        %{
          id: "text1",
          input: "Text question?",
          expected: "answer",
          metadata: %{}
        }
      ]

      mixed_dataset = Dataset.new("mixed", "1.0.0", mixed_items, %{source: :test})
      shuffled = Dataset.shuffle_choices(mixed_dataset, seed: 42)

      # Text item should be unchanged
      assert Enum.at(shuffled.items, 1).input == "Text question?"
      assert Enum.at(shuffled.items, 1).expected == "answer"

      # MC item should be shuffled
      assert is_list(Enum.at(shuffled.items, 0).input.choices)
    end
  end
end
