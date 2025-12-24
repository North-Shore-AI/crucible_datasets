defmodule CrucibleDatasets.FieldMappingTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.FieldMapping

  describe "new/1" do
    test "creates mapping with default values" do
      mapping = FieldMapping.new()

      assert mapping.input == :input
      assert mapping.expected == :expected
      assert mapping.id == :id
      assert mapping.choices == nil
      assert mapping.metadata == nil
      assert mapping.transforms == %{}
    end

    test "creates mapping with custom input field" do
      mapping = FieldMapping.new(input: "question")

      assert mapping.input == "question"
    end

    test "creates mapping with custom expected field" do
      mapping = FieldMapping.new(expected: "answer")

      assert mapping.expected == "answer"
    end

    test "creates mapping with custom id field" do
      mapping = FieldMapping.new(id: "item_id")

      assert mapping.id == "item_id"
    end

    test "creates mapping with choices field" do
      mapping = FieldMapping.new(choices: "options")

      assert mapping.choices == "options"
    end

    test "creates mapping with metadata fields" do
      mapping = FieldMapping.new(metadata: ["difficulty", "subject"])

      assert mapping.metadata == ["difficulty", "subject"]
    end

    test "creates mapping with transforms" do
      transforms = %{
        input: &String.upcase/1,
        expected: &String.downcase/1
      }

      mapping = FieldMapping.new(transforms: transforms)

      assert mapping.transforms == transforms
    end

    test "creates mapping with all options" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "item_id",
          choices: "options",
          metadata: ["difficulty"],
          transforms: %{input: &String.upcase/1}
        )

      assert mapping.input == "question"
      assert mapping.expected == "answer"
      assert mapping.id == "item_id"
      assert mapping.choices == "options"
      assert mapping.metadata == ["difficulty"]
      assert is_map(mapping.transforms)
    end
  end

  describe "apply/2" do
    test "applies basic field mapping" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "item_id"
        )

      record = %{
        "item_id" => "123",
        "question" => "What is 2+2?",
        "answer" => "4"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.id == "123"
      assert result.input == "What is 2+2?"
      assert result.expected == "4"
      assert result.metadata == %{}
    end

    test "applies mapping with atom keys" do
      mapping =
        FieldMapping.new(
          input: :question,
          expected: :answer,
          id: :item_id
        )

      record = %{
        item_id: "123",
        question: "What is 2+2?",
        answer: "4"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.id == "123"
      assert result.input == "What is 2+2?"
      assert result.expected == "4"
    end

    test "applies mapping with metadata fields" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          metadata: ["difficulty", "subject"]
        )

      record = %{
        "id" => "1",
        "question" => "Q1",
        "answer" => "A1",
        "difficulty" => "easy",
        "subject" => "math"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.metadata == %{difficulty: "easy", subject: "math"}
    end

    test "applies mapping with choices" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          choices: "options"
        )

      record = %{
        "id" => "1",
        "question" => "What is 2+2?",
        "answer" => "4",
        "options" => ["3", "4", "5", "6"]
      }

      result = FieldMapping.apply(mapping, record)

      assert result.input == %{
               question: "What is 2+2?",
               choices: ["3", "4", "5", "6"]
             }
    end

    test "wraps single choice value in list" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          choices: "options"
        )

      record = %{
        "id" => "1",
        "question" => "Q1",
        "answer" => "A1",
        "options" => "single"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.input == %{
               question: "Q1",
               choices: ["single"]
             }
    end

    test "applies input transform" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          transforms: %{input: &String.upcase/1}
        )

      record = %{
        "id" => "1",
        "question" => "what is 2+2?",
        "answer" => "4"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.input == "WHAT IS 2+2?"
    end

    test "applies expected transform" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          transforms: %{expected: &String.to_integer/1}
        )

      record = %{
        "id" => "1",
        "question" => "What is 2+2?",
        "answer" => "4"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.expected == 4
    end

    test "applies multiple transforms" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: "id",
          transforms: %{
            input: &String.upcase/1,
            expected: &String.downcase/1
          }
        )

      record = %{
        "id" => "1",
        "question" => "question text",
        "answer" => "ANSWER TEXT"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.input == "QUESTION TEXT"
      assert result.expected == "answer text"
    end

    test "handles missing id field" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: "answer",
          id: nil
        )

      record = %{
        "question" => "What is 2+2?",
        "answer" => "4"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.id == nil
    end

    test "handles mixed string and atom keys in record" do
      mapping =
        FieldMapping.new(
          input: "question",
          expected: :answer,
          id: "id"
        )

      record = %{
        "id" => "1",
        "question" => "Q1",
        answer: "A1"
      }

      result = FieldMapping.apply(mapping, record)

      assert result.id == "1"
      assert result.input == "Q1"
      assert result.expected == "A1"
    end
  end
end
