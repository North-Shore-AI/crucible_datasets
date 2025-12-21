defmodule CrucibleDatasets.Loader.Code do
  @moduledoc """
  Loader for code generation and understanding datasets.

  Supports:
    - DeepCoder (agentica-org/DeepCoder-Preview-Dataset)
    - HumanEval (openai/human-eval) - uses existing implementation

  ## Examples

      # Load DeepCoder
      {:ok, dataset} = CrucibleDatasets.Loader.Code.load(:deepcoder)

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace

  require Logger

  @datasets %{
    deepcoder: %{
      repo_id: "agentica-org/DeepCoder-Preview-Dataset",
      description: "DeepCoder code generation dataset"
    }
  }

  @doc """
  Load a code generation dataset.

  ## Arguments
    * `dataset_name` - Currently supports `:deepcoder`
    * `opts` - Options (see below)

  ## Options
    * `:split` - Dataset split (default: "train")
    * `:sample_size` - Limit number of items
    * `:synthetic` - Use synthetic data for testing (default: false)
    * `:token` - HuggingFace API token

  """
  @spec load(atom(), keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(dataset_name, opts \\ [])

  def load(dataset_name, opts) when is_atom(dataset_name) do
    case Map.get(@datasets, dataset_name) do
      nil ->
        {:error, {:unknown_dataset, dataset_name, Map.keys(@datasets)}}

      dataset_info ->
        synthetic = Keyword.get(opts, :synthetic, false)

        if synthetic do
          load_synthetic(dataset_name, opts)
        else
          load_from_huggingface(dataset_name, dataset_info, opts)
        end
    end
  end

  defp load_from_huggingface(dataset_name, %{repo_id: repo_id}, opts) do
    split = Keyword.get(opts, :split, "train") |> to_string()
    sample_size = Keyword.get(opts, :sample_size)
    token = Keyword.get(opts, :token)

    case HuggingFace.fetch(repo_id, split: split, token: token) do
      {:ok, raw_data} ->
        items = parse_code_data(raw_data, dataset_name)

        items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            to_string(dataset_name),
            "1.0",
            items,
            %{
              source: "huggingface:#{repo_id}",
              split: split,
              license: "apache-2.0",
              domain: "code"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
          Logger.warning(
            "Failed to load #{dataset_name} from HuggingFace: #{inspect(reason)}, falling back to synthetic"
          )

          load_synthetic(dataset_name, opts)
        else
          {:error, {:huggingface_fetch_failed, reason}}
        end
    end
  end

  defp parse_code_data(raw_data, :deepcoder) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      %{
        id: "deepcoder_#{idx}",
        input: %{
          problem: item["problem"] || item["prompt"] || item["instruction"],
          language: item["language"] || "python"
        },
        expected: item["solution"] || item["code"] || item["response"],
        metadata: %{
          source: item["source"],
          difficulty: item["difficulty"],
          tags: item["tags"]
        }
      }
    end)
  end

  defp load_synthetic(dataset_name, opts) do
    sample_size = Keyword.get(opts, :sample_size, 20)

    items = generate_synthetic_items(sample_size)

    dataset =
      Dataset.new(
        to_string(dataset_name),
        "1.0",
        items,
        %{
          source: "synthetic",
          license: "apache-2.0",
          domain: "code"
        }
      )

    {:ok, dataset}
  end

  defp generate_synthetic_items(count) do
    problems = [
      {"Write a function to add two numbers.", "def add(a, b):\n    return a + b", "python"},
      {"Implement a function to check if a string is a palindrome.",
       "def is_palindrome(s):\n    return s == s[::-1]", "python"},
      {"Write a function to find the factorial of a number.",
       "def factorial(n):\n    if n <= 1:\n        return 1\n    return n * factorial(n - 1)",
       "python"},
      {"Implement a function to reverse a list.", "def reverse_list(lst):\n    return lst[::-1]",
       "python"},
      {"Write a function to find the maximum element in a list.",
       "def find_max(lst):\n    return max(lst)", "python"}
    ]

    for i <- 0..(count - 1) do
      {problem, solution, language} = Enum.at(problems, rem(i, length(problems)))

      %{
        id: "code_#{i}",
        input: %{
          problem: problem,
          language: language
        },
        expected: solution,
        metadata: %{
          source: "synthetic",
          difficulty: "easy"
        }
      }
    end
  end

  @doc """
  List available code datasets.
  """
  @spec available_datasets() :: [atom()]
  def available_datasets, do: Map.keys(@datasets)
end
