defmodule CrucibleDatasets.Loader.GenericTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.{Dataset, FieldMapping, Loader.Generic}

  @fixtures_dir Path.join([__DIR__, "fixtures", "generic_loader"])

  setup_all do
    File.mkdir_p!(@fixtures_dir)

    # Create JSONL fixture
    jsonl_path = Path.join(@fixtures_dir, "test.jsonl")

    jsonl_content = """
    {"question": "What is 2+2?", "answer": "4", "difficulty": "easy"}
    {"question": "What is 3+3?", "answer": "6", "difficulty": "easy"}
    {"question": "What is 10*10?", "answer": "100", "difficulty": "medium"}
    """

    File.write!(jsonl_path, jsonl_content)

    # Create JSON fixture
    json_path = Path.join(@fixtures_dir, "test.json")

    json_content =
      Jason.encode!([
        %{"question" => "Q1", "answer" => "A1", "difficulty" => "easy"},
        %{"question" => "Q2", "answer" => "A2", "difficulty" => "hard"}
      ])

    File.write!(json_path, json_content)

    # Create CSV fixture
    csv_path = Path.join(@fixtures_dir, "test.csv")

    csv_content = """
    question,answer,difficulty
    What is 1+1?,2,easy
    What is 5+5?,10,medium
    What is 100+100?,200,hard
    """

    File.write!(csv_path, csv_content)

    # Create multiple choice JSONL fixture
    mc_jsonl_path = Path.join(@fixtures_dir, "multiple_choice.jsonl")

    mc_content = """
    {"id": "mc1", "question": "What is 2+2?", "choices": ["3", "4", "5", "6"], "answer": 1}
    {"id": "mc2", "question": "What is 3+3?", "choices": ["5", "6", "7", "8"], "answer": 1}
    """

    File.write!(mc_jsonl_path, mc_content)

    on_exit(fn ->
      File.rm_rf!(@fixtures_dir)
    end)

    {:ok,
     jsonl_path: jsonl_path,
     json_path: json_path,
     csv_path: csv_path,
     mc_jsonl_path: mc_jsonl_path}
  end

  describe "load/2 with JSONL" do
    test "loads JSONL file with default field mapping", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert %Dataset{} = dataset
      assert dataset.name == "test"
      assert length(dataset.items) == 3
      assert dataset.metadata.format == :jsonl
    end

    test "loads JSONL with custom name", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, name: "custom_dataset", fields: mapping)

      assert dataset.name == "custom_dataset"
    end

    test "loads JSONL with metadata fields", %{jsonl_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          metadata: ["difficulty"]
        )

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert Enum.at(dataset.items, 0).metadata.difficulty == "easy"
      assert Enum.at(dataset.items, 2).metadata.difficulty == "medium"
    end

    test "loads JSONL with auto-generated IDs", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert Enum.at(dataset.items, 0).id == "item_1"
      assert Enum.at(dataset.items, 1).id == "item_2"
      assert Enum.at(dataset.items, 2).id == "item_3"
    end

    test "loads JSONL with limit", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping, limit: 2)

      assert length(dataset.items) == 2
      assert dataset.metadata.total_items == 2
    end

    test "loads JSONL with shuffle", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset1} = Generic.load(path, fields: mapping, shuffle: true, seed: 42)
      {:ok, dataset2} = Generic.load(path, fields: mapping, shuffle: true, seed: 42)

      # Same seed should produce same order
      assert Enum.map(dataset1.items, & &1.id) == Enum.map(dataset2.items, & &1.id)
    end

    test "auto-detects JSONL format", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert dataset.metadata.format == :jsonl
    end
  end

  describe "load/2 with JSON" do
    test "loads JSON file", %{json_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert %Dataset{} = dataset
      assert length(dataset.items) == 2
      assert dataset.metadata.format == :json
    end

    test "auto-detects JSON format", %{json_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert dataset.metadata.format == :json
    end
  end

  describe "load/2 with CSV" do
    test "loads CSV file", %{csv_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert %Dataset{} = dataset
      assert length(dataset.items) == 3
      assert dataset.metadata.format == :csv
    end

    test "parses CSV headers correctly", %{csv_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          metadata: ["difficulty"]
        )

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert Enum.at(dataset.items, 0).input == "What is 1+1?"
      assert Enum.at(dataset.items, 0).expected == "2"
      assert Enum.at(dataset.items, 0).metadata.difficulty == "easy"
    end

    test "auto-detects CSV format", %{csv_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert dataset.metadata.format == :csv
    end
  end

  describe "load/2 with multiple choice" do
    test "loads multiple choice items", %{mc_jsonl_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          choices: "choices"
        )

      {:ok, dataset} = Generic.load(path, fields: mapping)

      first_item = Enum.at(dataset.items, 0)
      assert first_item.id == "mc1"
      assert first_item.input.question == "What is 2+2?"
      assert first_item.input.choices == ["3", "4", "5", "6"]
      assert first_item.expected == 1
    end
  end

  describe "load/2 with transforms" do
    test "applies input transform", %{jsonl_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          transforms: %{input: &String.upcase/1}
        )

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert Enum.at(dataset.items, 0).input == "WHAT IS 2+2?"
    end

    test "applies expected transform", %{jsonl_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          transforms: %{expected: &String.to_integer/1}
        )

      {:ok, dataset} = Generic.load(path, fields: mapping)

      assert Enum.at(dataset.items, 0).expected == 4
      assert Enum.at(dataset.items, 2).expected == 100
    end
  end

  describe "load/2 with options" do
    test "uses custom version", %{jsonl_path: path} do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      {:ok, dataset} = Generic.load(path, fields: mapping, version: "2.0.0")

      assert dataset.version == "2.0.0"
    end

    test "disables auto_id when specified", %{mc_jsonl_path: path} do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          choices: "choices"
        )

      {:ok, dataset} = Generic.load(path, fields: mapping, auto_id: false)

      # IDs from file should be preserved
      assert Enum.at(dataset.items, 0).id == "mc1"
      assert Enum.at(dataset.items, 1).id == "mc2"
    end
  end

  describe "load/2 error handling" do
    test "returns error for non-existent file" do
      mapping = FieldMapping.new(input: "question", expected: "answer")

      result = Generic.load("/nonexistent/file.jsonl", fields: mapping)

      assert {:error, _} = result
    end
  end

  describe "load/2 with default field mapping" do
    test "uses default field mapping when not specified" do
      # Create a file with default field names
      path = Path.join(@fixtures_dir, "default_fields.jsonl")

      # JSON.decode! will create atom keys when the JSON has string keys
      # So the file needs string keys "input" and "expected"
      content = """
      {"input": "Q1", "expected": "A1", "id": "1"}
      {"input": "Q2", "expected": "A2", "id": "2"}
      """

      File.write!(path, content)

      # Default FieldMapping uses atoms :input, :expected, :id
      # But get_field will also check string keys
      {:ok, dataset} = Generic.load(path)

      assert length(dataset.items) == 2
      # After FieldMapping.apply, the result should have the values
      first_item = Enum.at(dataset.items, 0)
      assert first_item.input == "Q1"
      assert first_item.expected == "A1"
    end
  end
end
