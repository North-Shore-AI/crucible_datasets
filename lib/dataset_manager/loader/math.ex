defmodule CrucibleDatasets.Loader.Math do
  @moduledoc """
  Loader for advanced math reasoning datasets.

  Supports:
    - MATH-500 (HuggingFaceH4/MATH-500)
    - Hendrycks MATH (hendrycks/competition_math)
    - DeepMath-103K (GAIR/DeepMath-103K)
    - POLARIS-53K (GAIR/POLARIS-53K)

  ## Examples

      # Load MATH-500 (test set)
      {:ok, dataset} = CrucibleDatasets.Loader.Math.load(:math_500)

      # Load Hendrycks MATH with specific subject
      {:ok, dataset} = CrucibleDatasets.Loader.Math.load(:hendrycks_math, config: "algebra")

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace

  require Logger

  @datasets %{
    math_500: %{
      repo_id: "HuggingFaceH4/MATH-500",
      description: "500 challenging math problems for evaluation"
    },
    hendrycks_math: %{
      repo_id: "hendrycks/competition_math",
      description: "Competition-level math problems"
    },
    deepmath: %{
      repo_id: "GAIR/DeepMath-103K",
      description: "DeepMath 103K training dataset"
    },
    polaris: %{
      repo_id: "GAIR/POLARIS-53K",
      description: "POLARIS 53K math dataset"
    }
  }

  @doc """
  Load a math reasoning dataset.

  ## Arguments
    * `dataset_name` - One of `:math_500`, `:hendrycks_math`, `:deepmath`, `:polaris`
    * `opts` - Options (see below)

  ## Options
    * `:split` - Dataset split (default: "test" for MATH-500, "train" for others)
    * `:config` - Subject/config for Hendrycks MATH (e.g., "algebra", "geometry")
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
    default_split = if dataset_name == :math_500, do: "test", else: "train"
    split = Keyword.get(opts, :split, default_split) |> to_string()
    config = Keyword.get(opts, :config)
    sample_size = Keyword.get(opts, :sample_size)
    token = Keyword.get(opts, :token)

    Logger.debug("Loading #{dataset_name} #{split} split from HuggingFace...")

    fetch_opts = [split: split, token: token]
    fetch_opts = if config, do: Keyword.put(fetch_opts, :config, config), else: fetch_opts

    case HuggingFace.fetch(repo_id, fetch_opts) do
      {:ok, raw_data} ->
        items = parse_math_data(raw_data, dataset_name)

        items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            to_string(dataset_name),
            "1.0",
            items,
            %{
              source: "huggingface:#{repo_id}",
              split: split,
              config: config,
              license: "mit",
              domain: "math"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        Logger.error("Failed to load #{dataset_name} from HuggingFace: #{inspect(reason)}")
        {:error, {:huggingface_fetch_failed, reason}}
    end
  end

  defp parse_math_data(raw_data, dataset_name) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      parse_math_item(item, dataset_name, idx)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_math_item(item, :math_500, idx) do
    %{
      id: "math500_#{idx}",
      input: %{
        problem: item["problem"] || item["question"]
      },
      expected: extract_boxed_answer(item["solution"] || item["answer"]),
      metadata: %{
        solution: item["solution"],
        level: item["level"],
        type: item["type"] || item["subject"]
      }
    }
  end

  defp parse_math_item(item, :hendrycks_math, idx) do
    %{
      id: "hendrycks_#{idx}",
      input: %{
        problem: item["problem"]
      },
      expected: extract_boxed_answer(item["solution"]),
      metadata: %{
        solution: item["solution"],
        level: item["level"],
        type: item["type"]
      }
    }
  end

  defp parse_math_item(item, :deepmath, idx) do
    %{
      id: "deepmath_#{idx}",
      input: %{
        problem: item["problem"] || item["question"]
      },
      expected: item["answer"] || extract_boxed_answer(item["solution"]),
      metadata: %{
        solution: item["solution"],
        source: item["source"]
      }
    }
  end

  defp parse_math_item(item, :polaris, idx) do
    %{
      id: "polaris_#{idx}",
      input: %{
        problem: item["problem"] || item["question"]
      },
      expected: item["answer"] || extract_boxed_answer(item["solution"]),
      metadata: %{
        solution: item["solution"],
        difficulty: item["difficulty"]
      }
    }
  end

  @doc """
  Extract the boxed answer from a MATH-style solution.

  MATH solutions contain answers in \\boxed{...} format.

  ## Examples

      iex> extract_boxed_answer("The answer is \\\\boxed{42}")
      "42"

      iex> extract_boxed_answer("\\\\boxed{x^2 + 1}")
      "x^2 + 1"

  """
  @spec extract_boxed_answer(String.t() | nil) :: String.t() | nil
  def extract_boxed_answer(nil), do: nil

  def extract_boxed_answer(text) when is_binary(text) do
    # Try to find \boxed{...} pattern
    case Regex.run(~r/\\boxed\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}/, text) do
      [_, answer] -> String.trim(answer)
      nil -> nil
    end
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
          license: "mit",
          domain: "math"
        }
      )

    {:ok, dataset}
  end

  defp generate_synthetic_items(count) do
    problems = [
      {"Solve for x: 2x + 5 = 13", "4", "algebra", "Level 1"},
      {"What is the area of a circle with radius 3?", "9\\pi", "geometry", "Level 2"},
      {"Find the derivative of f(x) = x^3 + 2x", "3x^2 + 2", "calculus", "Level 3"},
      {"Simplify: (x + 2)(x - 2)", "x^2 - 4", "algebra", "Level 1"},
      {"If log_2(x) = 5, what is x?", "32", "algebra", "Level 2"}
    ]

    for i <- 0..(count - 1) do
      {problem, answer, type, level} = Enum.at(problems, rem(i, length(problems)))

      %{
        id: "math_#{i}",
        input: %{
          problem: problem
        },
        expected: answer,
        metadata: %{
          solution: "Solution steps... \\boxed{#{answer}}",
          level: level,
          type: type
        }
      }
    end
  end

  @doc """
  List available math datasets.
  """
  @spec available_datasets() :: [atom()]
  def available_datasets, do: Map.keys(@datasets)
end
