defmodule CrucibleDatasets.Registry do
  @moduledoc """
  Central registry of all available datasets with metadata.

  Provides discovery, metadata access, and filtering capabilities
  for the dataset collection.

  ## Examples

      iex> CrucibleDatasets.Registry.list_available()
      [:mmlu, :mmlu_stem, :humaneval, :gsm8k]

      iex> CrucibleDatasets.Registry.get_metadata(:mmlu_stem)
      %{
        name: :mmlu_stem,
        domain: "stem",
        description: "MMLU STEM subset covering science, technology, engineering, and mathematics",
        ...
      }

      iex> CrucibleDatasets.Registry.list_by_domain("math")
      [:gsm8k]

      iex> CrucibleDatasets.Registry.list_by_task_type("question_answering")
      [:mmlu, :mmlu_stem, :gsm8k]
  """

  alias CrucibleDatasets.Loader.{MMLU, HumanEval, GSM8K}

  @type dataset_name :: atom()
  @type dataset_metadata :: %{
          name: dataset_name(),
          loader: module(),
          domain: String.t(),
          task_type: String.t(),
          description: String.t(),
          num_items: non_neg_integer() | :synthetic,
          license: String.t(),
          source_url: String.t(),
          citation: String.t(),
          languages: [String.t()],
          difficulty: String.t(),
          tags: [String.t()]
        }

  @datasets %{
    mmlu: %{
      name: :mmlu,
      loader: MMLU,
      domain: "general_knowledge",
      task_type: "multiple_choice_qa",
      description:
        "Massive Multitask Language Understanding - 57 subjects across STEM, humanities, and social sciences",
      num_items: 15908,
      license: "MIT",
      source_url: "https://huggingface.co/datasets/cais/mmlu",
      citation: "Hendrycks et al., 2021",
      languages: ["en"],
      difficulty: "challenging",
      tags: [
        "knowledge",
        "reasoning",
        "multiple_choice",
        "stem",
        "humanities",
        "social_sciences"
      ]
    },
    mmlu_stem: %{
      name: :mmlu_stem,
      loader: MMLU,
      domain: "stem",
      task_type: "multiple_choice_qa",
      description:
        "MMLU STEM subset covering science, technology, engineering, and mathematics subjects",
      num_items: :synthetic,
      license: "MIT",
      source_url: "https://huggingface.co/datasets/cais/mmlu",
      citation: "Hendrycks et al., 2021",
      languages: ["en"],
      difficulty: "challenging",
      tags: ["knowledge", "reasoning", "multiple_choice", "stem"]
    },
    humaneval: %{
      name: :humaneval,
      loader: HumanEval,
      domain: "code",
      task_type: "code_generation",
      description:
        "Programming problems with function signatures and test cases for Python code generation",
      num_items: 164,
      license: "MIT",
      source_url: "https://github.com/openai/human-eval",
      citation: "Chen et al., 2021",
      languages: ["python"],
      difficulty: "medium",
      tags: ["code", "programming", "python", "generation"]
    },
    gsm8k: %{
      name: :gsm8k,
      loader: GSM8K,
      domain: "math",
      task_type: "math_word_problems",
      description:
        "Grade school math word problems requiring multi-step reasoning with natural language solutions",
      num_items: 8500,
      license: "MIT",
      source_url: "https://huggingface.co/datasets/gsm8k",
      citation: "Cobbe et al., 2021",
      languages: ["en"],
      difficulty: "medium",
      tags: ["math", "reasoning", "word_problems", "arithmetic"]
    }
  }

  @doc """
  List all available dataset names.

  ## Examples

      iex> CrucibleDatasets.Registry.list_available()
      [:mmlu, :mmlu_stem, :humaneval, :gsm8k]
  """
  @spec list_available() :: [dataset_name()]
  def list_available do
    Map.keys(@datasets)
  end

  @doc """
  Get metadata for a specific dataset.

  ## Parameters

    * `name` - Dataset name (atom)

  ## Returns

  Dataset metadata map or `nil` if dataset not found.

  ## Examples

      iex> metadata = CrucibleDatasets.Registry.get_metadata(:mmlu_stem)
      iex> metadata.domain
      "stem"

      iex> CrucibleDatasets.Registry.get_metadata(:unknown)
      nil
  """
  @spec get_metadata(dataset_name()) :: dataset_metadata() | nil
  def get_metadata(name) when is_atom(name) do
    Map.get(@datasets, name)
  end

  @doc """
  List datasets by domain.

  ## Parameters

    * `domain` - Domain string (e.g., "stem", "code", "math")

  ## Examples

      iex> CrucibleDatasets.Registry.list_by_domain("stem")
      [:mmlu_stem]

      iex> CrucibleDatasets.Registry.list_by_domain("code")
      [:humaneval]
  """
  @spec list_by_domain(String.t()) :: [dataset_name()]
  def list_by_domain(domain) when is_binary(domain) do
    @datasets
    |> Enum.filter(fn {_name, metadata} -> metadata.domain == domain end)
    |> Enum.map(fn {name, _metadata} -> name end)
    |> Enum.sort()
  end

  @doc """
  List datasets by task type.

  ## Parameters

    * `task_type` - Task type string (e.g., "multiple_choice_qa", "code_generation")

  ## Examples

      iex> CrucibleDatasets.Registry.list_by_task_type("multiple_choice_qa")
      [:mmlu, :mmlu_stem]

      iex> CrucibleDatasets.Registry.list_by_task_type("code_generation")
      [:humaneval]
  """
  @spec list_by_task_type(String.t()) :: [dataset_name()]
  def list_by_task_type(task_type) when is_binary(task_type) do
    @datasets
    |> Enum.filter(fn {_name, metadata} -> metadata.task_type == task_type end)
    |> Enum.map(fn {name, _metadata} -> name end)
    |> Enum.sort()
  end

  @doc """
  List datasets by difficulty level.

  ## Parameters

    * `difficulty` - Difficulty string ("easy", "medium", "challenging", "hard")

  ## Examples

      iex> CrucibleDatasets.Registry.list_by_difficulty("challenging")
      [:mmlu, :mmlu_stem]
  """
  @spec list_by_difficulty(String.t()) :: [dataset_name()]
  def list_by_difficulty(difficulty) when is_binary(difficulty) do
    @datasets
    |> Enum.filter(fn {_name, metadata} -> metadata.difficulty == difficulty end)
    |> Enum.map(fn {name, _metadata} -> name end)
    |> Enum.sort()
  end

  @doc """
  List datasets by tag.

  ## Parameters

    * `tag` - Tag string (e.g., "reasoning", "knowledge", "code")

  ## Examples

      iex> CrucibleDatasets.Registry.list_by_tag("reasoning")
      [:mmlu, :mmlu_stem, :gsm8k]

      iex> CrucibleDatasets.Registry.list_by_tag("code")
      [:humaneval]
  """
  @spec list_by_tag(String.t()) :: [dataset_name()]
  def list_by_tag(tag) when is_binary(tag) do
    @datasets
    |> Enum.filter(fn {_name, metadata} -> tag in metadata.tags end)
    |> Enum.map(fn {name, _metadata} -> name end)
    |> Enum.sort()
  end

  @doc """
  Search datasets by keyword in description.

  ## Parameters

    * `keyword` - Search term (case-insensitive)

  ## Examples

      iex> CrucibleDatasets.Registry.search("math")
      [:gsm8k, :mmlu_stem]

      iex> CrucibleDatasets.Registry.search("code")
      [:humaneval]
  """
  @spec search(String.t()) :: [dataset_name()]
  def search(keyword) when is_binary(keyword) do
    keyword_lower = String.downcase(keyword)

    @datasets
    |> Enum.filter(fn {_name, metadata} ->
      description_lower = String.downcase(metadata.description)
      String.contains?(description_lower, keyword_lower)
    end)
    |> Enum.map(fn {name, _metadata} -> name end)
    |> Enum.sort()
  end

  @doc """
  Get all metadata as a list.

  Useful for displaying dataset information in tables or UIs.

  ## Examples

      iex> all_metadata = CrucibleDatasets.Registry.all_metadata()
      iex> length(all_metadata)
      4
  """
  @spec all_metadata() :: [dataset_metadata()]
  def all_metadata do
    @datasets
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Check if a dataset is available.

  ## Parameters

    * `name` - Dataset name (atom)

  ## Examples

      iex> CrucibleDatasets.Registry.available?(:mmlu)
      true

      iex> CrucibleDatasets.Registry.available?(:unknown)
      false
  """
  @spec available?(dataset_name()) :: boolean()
  def available?(name) when is_atom(name) do
    Map.has_key?(@datasets, name)
  end

  @doc """
  Get dataset summary statistics.

  Returns aggregate information about the dataset collection.

  ## Examples

      iex> stats = CrucibleDatasets.Registry.stats()
      iex> stats.total_datasets
      4
      iex> stats.domains
      ["code", "general_knowledge", "math", "stem"]
  """
  @spec stats() :: map()
  def stats do
    datasets = Map.values(@datasets)

    %{
      total_datasets: length(datasets),
      domains: datasets |> Enum.map(& &1.domain) |> Enum.uniq() |> Enum.sort(),
      task_types: datasets |> Enum.map(& &1.task_type) |> Enum.uniq() |> Enum.sort(),
      difficulties: datasets |> Enum.map(& &1.difficulty) |> Enum.uniq() |> Enum.sort(),
      all_tags: datasets |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort(),
      by_domain: Enum.frequencies_by(datasets, & &1.domain),
      by_task_type: Enum.frequencies_by(datasets, & &1.task_type),
      by_difficulty: Enum.frequencies_by(datasets, & &1.difficulty)
    }
  end

  @doc """
  Generate a formatted summary of all datasets.

  Returns a human-readable string describing the dataset collection.

  ## Examples

      iex> summary = CrucibleDatasets.Registry.summary()
      iex> String.contains?(summary, "4 datasets")
      true
  """
  @spec summary() :: String.t()
  def summary do
    stats = stats()

    """
    CrucibleDatasets Collection Summary
    ===================================

    Total Datasets: #{stats.total_datasets}

    Domains:
    #{Enum.map_join(stats.domains, "\n", &"  - #{&1}")}

    Task Types:
    #{Enum.map_join(stats.task_types, "\n", &"  - #{&1}")}

    Difficulty Levels:
    #{Enum.map_join(stats.difficulties, "\n", &"  - #{&1}")}

    Available Tags:
    #{stats.all_tags |> Enum.chunk_every(5) |> Enum.map_join("\n", fn chunk -> "  " <> Enum.join(chunk, ", ") end)}

    Datasets by Domain:
    #{Enum.map_join(stats.by_domain, "\n", fn {domain, count} -> "  #{domain}: #{count}" end)}
    """
  end
end
