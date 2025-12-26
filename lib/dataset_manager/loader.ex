defmodule CrucibleDatasets.Loader do
  @moduledoc """
  Unified dataset loading with automatic source detection and caching.

  Supports loading from:
  - HuggingFace datasets
  - GitHub repositories
  - Local files
  - HTTP URLs
  - CrucibleIR.DatasetRef structs

  ## Telemetry Events

  The loader emits the following telemetry events:

    * `[:crucible_datasets, :load, :start]` - Emitted when loading begins
      * Measurements: `%{system_time: integer}`
      * Metadata: `%{dataset: atom | String.t(), source: atom}`

    * `[:crucible_datasets, :load, :stop]` - Emitted when loading completes
      * Measurements: `%{duration: integer}` (native time units)
      * Metadata: `%{dataset: atom | String.t(), source: atom, item_count: integer}`

    * `[:crucible_datasets, :load, :exception]` - Emitted when loading fails
      * Measurements: `%{duration: integer}` (native time units)
      * Metadata: `%{dataset: atom | String.t(), source: atom, kind: atom, reason: term}`

    * `[:crucible_datasets, :cache, :hit]` - Emitted on cache hit
      * Measurements: `%{}`
      * Metadata: `%{dataset: atom | String.t()}`

    * `[:crucible_datasets, :cache, :miss]` - Emitted on cache miss
      * Measurements: `%{}`
      * Metadata: `%{dataset: atom | String.t()}`
  """

  alias CrucibleDatasets.{Cache, Dataset}
  alias CrucibleDatasets.Loader.{GSM8K, HumanEval, MMLU, NoRobots}
  alias CrucibleIR.DatasetRef

  @dataset_sources %{
    mmlu: {:huggingface, "cais/mmlu", "all"},
    mmlu_stem: {:huggingface, "cais/mmlu", "stem"},
    humaneval: {:github, "openai/human-eval", "data/HumanEval.jsonl.gz"},
    gsm8k: {:huggingface, "gsm8k", "main"},
    no_robots: {:huggingface, "HuggingFaceH4/no_robots", "main"}
  }

  @doc """
  Load a dataset by name with automatic caching.

  ## Options
    * `:version` - Specific version (default: "1.0")
    * `:subset` - Subset name for multi-config datasets
    * `:cache` - Use cache (default: true)
    * `:sample_size` - Limit items (default: all)
    * `:source` - Custom source path for local datasets

  ## Examples

      iex> CrucibleDatasets.Loader.load(:mmlu_stem)
      {:ok, %Dataset{name: "mmlu_stem", items: [...], ...}}

      iex> CrucibleDatasets.Loader.load(:humaneval, sample_size: 50)
      {:ok, %Dataset{name: "humaneval", items: [50 items], ...}}

      iex> CrucibleDatasets.Loader.load("custom", source: "path/to/data.jsonl")
      {:ok, %Dataset{name: "custom", ...}}

      iex> ref = %CrucibleIR.DatasetRef{name: :mmlu_stem, split: :train, options: [sample_size: 100]}
      iex> CrucibleDatasets.Loader.load(ref)
      {:ok, %Dataset{name: "mmlu_stem", items: [...], ...}}
  """
  @spec load(atom() | String.t() | DatasetRef.t(), keyword()) ::
          {:ok, Dataset.t()} | {:error, term()}
  def load(dataset_or_ref, opts \\ [])

  def load(%DatasetRef{} = ref, _opts) do
    # Convert DatasetRef to load options and emit telemetry
    :telemetry.span(
      [:crucible_datasets, :load],
      %{dataset: ref.name, source: :dataset_ref},
      fn ->
        opts = ref.options || []
        result = do_load(ref.name, opts)

        case result do
          {:ok, dataset} ->
            {result, %{item_count: length(dataset.items)}}

          {:error, _} = error ->
            {error, %{}}
        end
      end
    )
  end

  def load(dataset_name, opts) when is_atom(dataset_name) or is_binary(dataset_name) do
    source_type = if is_atom(dataset_name), do: :registry, else: :local

    :telemetry.span(
      [:crucible_datasets, :load],
      %{dataset: dataset_name, source: source_type},
      fn ->
        result = do_load(dataset_name, opts)

        case result do
          {:ok, dataset} ->
            {result, %{item_count: length(dataset.items)}}

          {:error, _} = error ->
            {error, %{}}
        end
      end
    )
  end

  # Internal load implementation
  defp do_load(dataset_name, opts) do
    use_cache = Keyword.get(opts, :cache, true)
    sample_size = Keyword.get(opts, :sample_size)

    cache_key = build_cache_key(dataset_name, opts)

    # Try to load from cache first
    case use_cache && Cache.get(cache_key) do
      {:ok, dataset} ->
        :telemetry.execute(
          [:crucible_datasets, :cache, :hit],
          %{},
          %{dataset: dataset_name}
        )

        {:ok, maybe_sample(dataset, sample_size)}

      _ ->
        :telemetry.execute(
          [:crucible_datasets, :cache, :miss],
          %{},
          %{dataset: dataset_name}
        )

        with {:ok, source_spec} <- resolve_source(dataset_name, opts),
             {:ok, dataset} <- fetch_and_parse(source_spec, dataset_name, opts),
             {:ok, validated} <- Dataset.validate(dataset) do
          cache_result =
            if use_cache do
              Cache.put(cache_key, validated)
            else
              :ok
            end

          case cache_result do
            :ok -> {:ok, maybe_sample(validated, sample_size)}
            {:error, reason} -> {:error, reason}
          end
        end
    end
  end

  @doc """
  Invalidate cache for a dataset.
  """
  @spec invalidate_cache(atom() | String.t()) :: :ok
  def invalidate_cache(dataset_name) do
    Cache.invalidate(dataset_name)
  end

  # Private helpers

  defp build_cache_key(dataset_name, _opts) when is_atom(dataset_name) do
    dataset_name
  end

  defp build_cache_key(dataset_name, _opts) when is_binary(dataset_name) do
    {:local, dataset_name}
  end

  defp resolve_source(dataset_name, _opts) when is_atom(dataset_name) do
    case Map.get(@dataset_sources, dataset_name) do
      nil -> {:error, {:unknown_dataset, dataset_name}}
      source -> {:ok, {dataset_name, source}}
    end
  end

  defp resolve_source(dataset_name, opts) when is_binary(dataset_name) do
    source = Keyword.get(opts, :source)

    if source do
      {:ok, {dataset_name, {:local, source}}}
    else
      {:error, {:missing_source, dataset_name}}
    end
  end

  defp fetch_and_parse({dataset_name, source_spec}, _name, opts) do
    case dataset_name do
      name when name in [:mmlu, :mmlu_stem] ->
        MMLU.load(dataset_name, opts)

      :humaneval ->
        HumanEval.load(opts)

      :gsm8k ->
        GSM8K.load(opts)

      :no_robots ->
        NoRobots.load(opts)

      _ ->
        load_custom(dataset_name, source_spec, opts)
    end
  end

  defp load_custom(name, {:local, path}, opts) do
    case File.read(path) do
      {:ok, content} ->
        parse_jsonl(content, name, opts)

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  defp load_custom(_name, _source, _opts) do
    {:error, :unsupported_source}
  end

  defp parse_jsonl(content, name, _opts) do
    items =
      content
      |> String.split("\n", trim: true)
      |> Stream.map(&Jason.decode!/1)
      |> Stream.with_index()
      |> Enum.map(fn {raw, idx} ->
        %{
          id: "#{name}_#{idx}",
          input: raw["input"] || raw["question"] || raw["text"],
          expected: raw["expected"] || raw["answer"] || raw["label"],
          metadata: Map.get(raw, "metadata", %{})
        }
      end)

    dataset = Dataset.new(to_string(name), "1.0", items, %{source: "local"})
    {:ok, dataset}
  end

  defp maybe_sample(dataset, nil), do: dataset

  defp maybe_sample(dataset, size) when is_integer(size) do
    sampled_items = Enum.take(dataset.items, size)
    %{dataset | items: sampled_items, metadata: Map.put(dataset.metadata, :sampled, size)}
  end
end
