# Architecture Review: Source Abstraction & Reusability

**Date:** 2025-12-21
**Status:** Design Review

**Status Update (2025-12-21):** Tinker parity shipped without the full Source/Format abstraction.
DataFiles + load_dataset resolve configs/splits directly via hf_hub_ex; Source abstraction remains
deferred for a future refactor.

## Current Architecture Assessment

### What We Have
```
crucible_datasets/
├── Fetcher.HuggingFace     # Tightly coupled to HF
├── Loader.GSM8K            # HF-specific loader
├── Loader.Math             # HF-specific loader
├── Loader.Preference       # HF-specific loader
├── ...
├── Dataset                 # Generic struct (good)
├── Sampler                 # Generic operations (good)
├── Evaluator               # Generic metrics (good)
└── Exporter                # Generic export (good)
```

### Problems
1. **Tight HuggingFace Coupling**: Loaders directly call `HuggingFace.fetch/2`
2. **No Source Abstraction**: Can't easily add local files, S3, GCS, or other hubs
3. **Loader Duplication**: Each loader reimplements fetch → parse → wrap pattern
4. **No Builder Pattern**: Can't compose sources with transforms

---

## Proposed Architecture: Source-Agnostic Design

### Core Principle
Separate **what** (dataset semantics) from **where** (data source) from **how** (format parsing).

### Layer Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                     User API Layer                               │
│  CrucibleDatasets.load("gsm8k", source: :huggingface)           │
│  CrucibleDatasets.load("./data/custom.jsonl", source: :local)   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Dataset Layer                                │
│  Dataset | DatasetDict | IterableDataset                        │
│  Operations: map, filter, shuffle, batch, concat                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Loader Layer                                 │
│  Loader.GSM8K, Loader.MMLU, Loader.Preference, ...              │
│  Defines: schema, field mapping, validation                     │
│  Delegates fetching to Source                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Source Layer (NEW)                           │
│  Source.HuggingFace | Source.Local | Source.S3 | Source.GCS    │
│  Behaviour: list_files, download, stream                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Format Layer                                 │
│  Format.Parquet | Format.JSONL | Format.CSV | Format.JSON       │
│  Behaviour: parse, parse_stream                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Source Behaviour

Define a behaviour that all sources must implement:

```elixir
defmodule CrucibleDatasets.Source do
  @moduledoc """
  Behaviour for dataset sources.

  Sources are responsible for locating and fetching raw data files.
  They do NOT parse the data - that's the Format layer's job.
  """

  @type file_info :: %{
    path: String.t(),
    size: non_neg_integer() | nil,
    format: atom()
  }

  @type fetch_opts :: [
    split: String.t(),
    config: String.t(),
    token: String.t()
  ]

  @doc "List available files for a dataset"
  @callback list_files(dataset_ref :: String.t(), opts :: fetch_opts()) ::
    {:ok, [file_info()]} | {:error, term()}

  @doc "Download a file to local cache, return path"
  @callback download(dataset_ref :: String.t(), file_path :: String.t(), opts :: fetch_opts()) ::
    {:ok, local_path :: String.t()} | {:error, term()}

  @doc "Stream file contents"
  @callback stream(dataset_ref :: String.t(), file_path :: String.t(), opts :: fetch_opts()) ::
    {:ok, Enumerable.t()} | {:error, term()}

  @doc "Check if dataset exists"
  @callback exists?(dataset_ref :: String.t(), opts :: fetch_opts()) ::
    boolean()
end
```

### Source Implementations

```elixir
defmodule CrucibleDatasets.Source.HuggingFace do
  @behaviour CrucibleDatasets.Source

  @impl true
  def list_files(repo_id, opts) do
    config = Keyword.get(opts, :config)
    split = Keyword.get(opts, :split)
    HfHub.Api.list_files(repo_id, config: config, split: split)
  end

  @impl true
  def download(repo_id, file_path, opts) do
    HfHub.Download.hf_hub_download(repo_id, file_path, opts)
  end

  @impl true
  def stream(repo_id, file_path, opts) do
    HfHub.Download.download_stream(repo_id, file_path, opts)
  end

  @impl true
  def exists?(repo_id, _opts) do
    case HfHub.Api.dataset_info(repo_id) do
      {:ok, _} -> true
      _ -> false
    end
  end
end

defmodule CrucibleDatasets.Source.Local do
  @behaviour CrucibleDatasets.Source

  @impl true
  def list_files(path, _opts) do
    if File.dir?(path) do
      files = Path.wildcard(Path.join(path, "**/*"))
      |> Enum.reject(&File.dir?/1)
      |> Enum.map(fn f ->
        %{path: f, size: File.stat!(f).size, format: detect_format(f)}
      end)
      {:ok, files}
    else
      {:ok, [%{path: path, size: File.stat!(path).size, format: detect_format(path)}]}
    end
  end

  @impl true
  def download(path, _file_path, _opts) do
    # Local files don't need download
    {:ok, path}
  end

  @impl true
  def stream(path, _file_path, _opts) do
    {:ok, File.stream!(path)}
  end

  @impl true
  def exists?(path, _opts), do: File.exists?(path)

  defp detect_format(path) do
    case Path.extname(path) do
      ".parquet" -> :parquet
      ".jsonl" -> :jsonl
      ".json" -> :json
      ".csv" -> :csv
      _ -> :unknown
    end
  end
end

# Future: Source.S3, Source.GCS, Source.Azure, Source.HTTP
```

---

## Format Behaviour

```elixir
defmodule CrucibleDatasets.Format do
  @moduledoc """
  Behaviour for data format parsers.

  Formats are responsible for parsing raw data into Elixir maps.
  They should be source-agnostic.
  """

  @doc "Parse file contents into list of maps"
  @callback parse(path :: String.t()) :: {:ok, [map()]} | {:error, term()}

  @doc "Parse streaming contents lazily"
  @callback parse_stream(stream :: Enumerable.t()) :: Enumerable.t()

  @doc "Detect if this format can handle the file"
  @callback handles?(path :: String.t()) :: boolean()
end

defmodule CrucibleDatasets.Format.Parquet do
  @behaviour CrucibleDatasets.Format

  @impl true
  def parse(path) do
    case Explorer.DataFrame.from_parquet(path) do
      {:ok, df} -> {:ok, Explorer.DataFrame.to_rows(df)}
      error -> error
    end
  end

  @impl true
  def parse_stream(_stream) do
    # Parquet doesn't support true streaming
    raise "Parquet streaming not supported"
  end

  @impl true
  def handles?(path), do: String.ends_with?(path, ".parquet")
end

defmodule CrucibleDatasets.Format.JSONL do
  @behaviour CrucibleDatasets.Format

  @impl true
  def parse(path) do
    items =
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&Jason.decode!/1)
      |> Enum.to_list()
    {:ok, items}
  end

  @impl true
  def parse_stream(stream) do
    stream
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)
  end

  @impl true
  def handles?(path), do: String.ends_with?(path, [".jsonl", ".jsonlines"])
end
```

---

## Refactored Loader Pattern

Loaders become thin wrappers that define schema and field mapping:

```elixir
defmodule CrucibleDatasets.Loader.GSM8K do
  @moduledoc "GSM8K dataset loader"

  use CrucibleDatasets.Loader,
    name: "gsm8k",
    default_source: :huggingface,
    default_ref: "openai/gsm8k"

  @impl true
  def parse_item(raw, idx) do
    %{
      id: "gsm8k_#{idx}",
      input: %{question: raw["question"]},
      expected: %{
        answer: extract_numerical_answer(raw["answer"]),
        reasoning: raw["answer"]
      },
      metadata: %{}
    }
  end

  defp extract_numerical_answer(text) do
    # ... existing logic
  end
end
```

### Loader Macro

```elixir
defmodule CrucibleDatasets.Loader do
  @moduledoc """
  Base module for dataset loaders.

  Provides common loading infrastructure while allowing
  loaders to focus on schema definition and parsing.
  """

  @callback parse_item(raw :: map(), index :: non_neg_integer()) :: map()
  @callback validate_item(item :: map()) :: :ok | {:error, term()}

  defmacro __using__(opts) do
    quote do
      @behaviour CrucibleDatasets.Loader

      @name Keyword.fetch!(unquote(opts), :name)
      @default_source Keyword.get(unquote(opts), :default_source, :huggingface)
      @default_ref Keyword.get(unquote(opts), :default_ref)

      def load(opts \\ []) do
        source = resolve_source(opts)
        ref = Keyword.get(opts, :ref, @default_ref)

        with {:ok, raw_data} <- fetch_data(source, ref, opts),
             items <- parse_all(raw_data) do
          dataset = CrucibleDatasets.Dataset.new(@name, "1.0", items, build_metadata(opts))
          {:ok, dataset}
        end
      end

      defp resolve_source(opts) do
        case Keyword.get(opts, :source, @default_source) do
          :huggingface -> CrucibleDatasets.Source.HuggingFace
          :local -> CrucibleDatasets.Source.Local
          module when is_atom(module) -> module
        end
      end

      defp fetch_data(source, ref, opts) do
        CrucibleDatasets.Fetcher.fetch(source, ref, opts)
      end

      defp parse_all(raw_data) do
        raw_data
        |> Enum.with_index()
        |> Enum.map(fn {raw, idx} -> parse_item(raw, idx) end)
        |> Enum.reject(&is_nil/1)
      end

      defp build_metadata(opts) do
        %{
          source: Keyword.get(opts, :source, @default_source),
          split: Keyword.get(opts, :split, "train")
        }
      end

      # Default implementation - override in loader
      @impl true
      def validate_item(_item), do: :ok

      defoverridable validate_item: 1
    end
  end
end
```

---

## Unified Fetcher

```elixir
defmodule CrucibleDatasets.Fetcher do
  @moduledoc """
  Unified data fetcher that works with any Source.

  Handles: file discovery, download, format detection, parsing.
  """

  def fetch(source_module, ref, opts) do
    split = Keyword.get(opts, :split, "train")
    config = Keyword.get(opts, :config)

    with {:ok, files} <- source_module.list_files(ref, split: split, config: config),
         {:ok, file} <- select_file(files, split),
         {:ok, local_path} <- source_module.download(ref, file.path, opts),
         {:ok, data} <- parse_file(local_path, file.format) do
      {:ok, data}
    end
  end

  defp select_file(files, split) do
    # Find file matching split pattern
    file = Enum.find(files, fn f ->
      String.contains?(f.path, split) or String.contains?(f.path, "train")
    end) || hd(files)
    {:ok, file}
  end

  defp parse_file(path, format) do
    format_module = format_for(format)
    format_module.parse(path)
  end

  defp format_for(:parquet), do: CrucibleDatasets.Format.Parquet
  defp format_for(:jsonl), do: CrucibleDatasets.Format.JSONL
  defp format_for(:json), do: CrucibleDatasets.Format.JSON
  defp format_for(:csv), do: CrucibleDatasets.Format.CSV
end
```

---

## User API Examples

With this architecture, users get flexible loading:

```elixir
# HuggingFace (default)
{:ok, ds} = CrucibleDatasets.load("gsm8k")

# Explicit HuggingFace
{:ok, ds} = CrucibleDatasets.load("openai/gsm8k", source: :huggingface)

# Local file
{:ok, ds} = CrucibleDatasets.load("./data/custom.jsonl", source: :local)

# Local directory
{:ok, ds} = CrucibleDatasets.load("./data/my_dataset/", source: :local)

# Custom source (future)
{:ok, ds} = CrucibleDatasets.load("s3://bucket/dataset", source: :s3)

# With schema loader
{:ok, ds} = CrucibleDatasets.Loader.GSM8K.load(source: :local, ref: "./gsm8k.jsonl")
```

---

## Migration Path

### Phase 1: Add Abstractions (non-breaking)
1. Add `Source` behaviour and implementations
2. Add `Format` behaviour and implementations
3. Add `Loader` macro
4. Keep existing loaders working

### Phase 2: Refactor Loaders
1. Migrate loaders to use new macro one-by-one
2. Update Fetcher.HuggingFace to implement Source behaviour
3. Deprecate direct HuggingFace.fetch calls in loaders

### Phase 3: Clean Up
1. Remove old Fetcher.HuggingFace (replaced by Source.HuggingFace)
2. Consolidate Sampler into Dataset
3. Update all docs

---

## Benefits of This Architecture

1. **Source Agnostic**: Add new sources without touching loaders
2. **Format Agnostic**: Add new formats without touching sources
3. **DRY Loaders**: Loaders only define what's unique (schema, parsing)
4. **Testable**: Mock sources for unit tests
5. **Extensible**: Users can add custom sources/formats
6. **Composable**: Chain operations naturally

---

## Open Questions

1. **Registry Integration**: Should named datasets ("gsm8k") route through a registry to resolve source + ref?
2. **Caching Layer**: Where does caching fit? Source level? Fetcher level? Both?
3. **Credentials**: How to handle auth for different sources (HF token, AWS creds, etc.)?
4. **Streaming**: Should `fetch/3` support streaming mode that returns IterableDataset?
