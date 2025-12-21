defmodule CrucibleDatasets.Loader.HumanEval do
  @moduledoc """
  HumanEval code generation benchmark loader.

  HumanEval contains 164 programming problems with function signatures and test cases.
  Used to evaluate code generation capabilities.

  ## HuggingFace Dataset

  The official HumanEval dataset is hosted at `openai/openai_humaneval` on HuggingFace.

  ## Example

      {:ok, dataset} = CrucibleDatasets.Loader.HumanEval.load()
      {:ok, dataset} = CrucibleDatasets.Loader.HumanEval.load(sample_size: 50)

  """

  alias CrucibleDatasets.{Dataset, Source, Format}

  @repo_id "openai/openai_humaneval"

  @doc """
  Load HumanEval dataset from HuggingFace.

  ## Options

    * `:sample_size` - Limit number of items. Default: all (164)
    * `:offline` - If true, use synthetic data for testing. Default: false

  ## Examples

      {:ok, dataset} = HumanEval.load()
      {:ok, dataset} = HumanEval.load(sample_size: 50)

  """
  @spec load(keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(opts \\ []) do
    # Support both :synthetic and legacy :offline option
    synthetic = Keyword.get(opts, :synthetic, Keyword.get(opts, :offline, false))

    if synthetic do
      load_synthetic(opts)
    else
      load_from_huggingface(opts)
    end
  end

  # Load from HuggingFace
  defp load_from_huggingface(opts) do
    sample_size = Keyword.get(opts, :sample_size)

    # HumanEval on HuggingFace is stored as parquet
    file_path = "openai_humaneval/test-00000-of-00001.parquet"

    case Source.HuggingFace.download(@repo_id, file_path, []) do
      {:ok, local_path} ->
        case parse_humaneval_parquet(local_path, sample_size) do
          {:ok, _} = success -> success
          {:error, _} -> load_synthetic(opts)
        end

      {:error, _reason} ->
        # Try alternative path
        case Source.HuggingFace.download(@repo_id, "data/test-00000-of-00001.parquet", []) do
          {:ok, local_path} ->
            case parse_humaneval_parquet(local_path, sample_size) do
              {:ok, _} = success ->
                success

              {:error, reason} ->
                if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
                  load_synthetic(opts)
                else
                  {:error, {:parse_failed, reason}}
                end
            end

          {:error, reason} ->
            if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
              load_synthetic(opts)
            else
              {:error, {:huggingface_download_failed, reason}}
            end
        end
    end
  end

  defp parse_humaneval_parquet(path, sample_size) do
    case Format.Parquet.parse(path) do
      {:ok, rows} ->
        items =
          rows
          |> Enum.with_index()
          |> Enum.map(fn {row, idx} ->
            task_id = row["task_id"] || row[:task_id] || "HumanEval/#{idx}"
            prompt = row["prompt"] || row[:prompt]
            canonical = row["canonical_solution"] || row[:canonical_solution]
            test_code = row["test"] || row[:test]
            entry_point = row["entry_point"] || row[:entry_point]

            %{
              id: "humaneval_#{idx}",
              input: %{
                signature: prompt,
                tests: test_code,
                entry_point: entry_point,
                description: extract_description(prompt)
              },
              expected: canonical,
              metadata: %{
                task_id: task_id,
                difficulty: estimate_difficulty(canonical)
              }
            }
          end)

        final_items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            "humaneval",
            "1.0",
            final_items,
            %{
              source: "huggingface:#{@repo_id}",
              license: "MIT",
              domain: "code_generation",
              language: "python"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  # Load synthetic data for offline testing
  defp load_synthetic(opts) do
    items = generate_sample_items(opts)

    dataset =
      Dataset.new(
        "humaneval",
        "1.0",
        items,
        %{
          source: "synthetic",
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
              difficulty: estimate_difficulty(item["canonical_solution"])
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_description(nil), do: ""

  defp extract_description(prompt) do
    # Extract docstring from prompt
    prompt
    |> String.split("\n")
    |> Enum.find("", &String.contains?(&1, "\"\"\""))
    |> String.trim()
  end

  defp estimate_difficulty(nil), do: "medium"

  defp estimate_difficulty(solution) do
    # Simple heuristic: longer solutions are harder
    solution_length = String.length(solution)

    cond do
      solution_length < 100 -> "easy"
      solution_length < 300 -> "medium"
      true -> "hard"
    end
  end
end
