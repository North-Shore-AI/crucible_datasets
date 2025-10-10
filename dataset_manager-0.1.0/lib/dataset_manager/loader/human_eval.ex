defmodule DatasetManager.Loader.HumanEval do
  @moduledoc """
  HumanEval code generation benchmark loader.

  HumanEval contains 164 programming problems with function signatures and test cases.
  Used to evaluate code generation capabilities.
  """

  alias DatasetManager.Dataset

  @doc """
  Load HumanEval dataset.

  For demo purposes, generates synthetic data.
  In production, would fetch from GitHub: openai/human-eval
  """
  def load(opts \\ []) do
    # In production, would fetch from:
    # https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz

    items = generate_sample_items(opts)

    dataset =
      Dataset.new(
        "humaneval",
        "1.0",
        items,
        %{
          source: "github:openai/human-eval",
          license: "MIT",
          domain: "code_generation",
          language: "python"
        }
      )

    {:ok, dataset}
  end

  # Generate sample HumanEval items for testing
  defp generate_sample_items(opts) do
    count = Keyword.get(opts, :sample_size, 10)

    problems = [
      {"has_close_elements", "list of numbers",
       "Check if any two numbers are closer than threshold"},
      {"separate_paren_groups", "string", "Separate nested parentheses groups"},
      {"truncate_number", "float", "Return decimal part of number"},
      {"below_zero", "list of operations", "Check if balance goes below zero"},
      {"mean_absolute_deviation", "list of numbers", "Calculate mean absolute deviation"},
      {"intersperse", "list and delimiter", "Insert delimiter between elements"},
      {"parse_nested_parens", "string", "Parse nested parentheses depth"},
      {"filter_by_substring", "list of strings", "Filter strings containing substring"},
      {"sum_product", "list of integers", "Return sum and product"},
      {"rolling_max", "list of numbers", "Generate rolling maximum"}
    ]

    problems
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {{name, inputs, description}, idx} ->
      %{
        id: "humaneval_#{idx}",
        input: %{
          signature: generate_signature(name, inputs),
          tests: generate_tests(name),
          entry_point: name,
          description: description
        },
        expected: generate_solution(name),
        metadata: %{
          task_id: "HumanEval/#{idx}",
          difficulty: Enum.random(["easy", "medium", "hard"])
        }
      }
    end)
  end

  defp generate_signature(name, _inputs) do
    """
    def #{name}(numbers: List[float], threshold: float) -> bool:
        \"\"\" Check if in given list of numbers, are any two numbers closer to each other than
        given threshold.
        >>> #{name}([1.0, 2.0, 3.0], 0.5)
        False
        >>> #{name}([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)
        True
        \"\"\"
    """
  end

  defp generate_tests(_name) do
    """
    def check(candidate):
        assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.3) == True
        assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.05) == False
        assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.95) == True
        assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.8) == False
    """
  end

  defp generate_solution(_name) do
    """
        for idx, elem in enumerate(numbers):
            for idx2, elem2 in enumerate(numbers):
                if idx != idx2:
                    distance = abs(elem - elem2)
                    if distance < threshold:
                        return True

        return False
    """
  end

  @doc """
  Parse HumanEval JSONL format.
  """
  def parse_jsonl(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      case Jason.decode(line) do
        {:ok, item} ->
          %{
            id: "humaneval_#{idx}",
            input: %{
              signature: item["prompt"],
              tests: item["test"],
              entry_point: item["entry_point"],
              description: item["prompt"] |> extract_description()
            },
            expected: item["canonical_solution"],
            metadata: %{
              task_id: item["task_id"],
              difficulty: estimate_difficulty(item)
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_description(prompt) do
    # Extract docstring from prompt
    prompt
    |> String.split("\n")
    |> Enum.find("", &String.contains?(&1, "\"\"\""))
    |> String.trim()
  end

  defp estimate_difficulty(item) do
    # Simple heuristic: longer solutions are harder
    solution_length = String.length(item["canonical_solution"] || "")

    cond do
      solution_length < 100 -> "easy"
      solution_length < 300 -> "medium"
      true -> "hard"
    end
  end
end
