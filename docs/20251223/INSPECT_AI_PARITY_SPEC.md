# Crucible Datasets: inspect_ai Parity Implementation Spec

**Date:** 2025-12-23
**Status:** Implementation Specification
**Purpose:** Define modules needed to achieve inspect_ai dataset pattern parity

---

## Executive Summary

Crucible Datasets is a production-ready dataset management library with strong caching, versioning, and result persistence. It exceeds inspect_ai in result tracking but needs enhancements for in-memory datasets, filtering, and field mapping.

**Required additions:** ~400-500 LOC across 4 modules

---

## Current Strengths (EXCEEDS inspect_ai)

| Feature | Status | Notes |
|---------|--------|-------|
| Built-in Loaders | MMLU, GSM8K, HumanEval | Production ready |
| Caching System | Full versioned cache | Better than inspect_ai |
| Registry/Discovery | Complete | Filter by domain/difficulty/tags |
| Result Persistence | Full ResultStore | inspect_ai lacks this |
| Sampling Methods | K-fold, stratified, train/test | More complete |

---

## Gaps to Address

| Gap | Severity | Current State | Required |
|-----|----------|---------------|----------|
| MemoryDataset | HIGH | No in-memory builder | Lightweight constructor |
| Dataset Filtering | HIGH | Via Sampler only | Native `.filter()` method |
| Field Mapping | MEDIUM | Hardcoded per loader | Declarative FieldSpec |
| Choice Shuffling | MEDIUM | Not implemented | shuffle_choices method |
| Auto-ID Generation | LOW | Explicit IDs required | Optional auto-increment |

---

## Module Specifications

### 1. CrucibleDatasets.MemoryDataset (NEW)

**File:** `lib/dataset_manager/memory_dataset.ex`

```elixir
defmodule CrucibleDatasets.MemoryDataset do
  @moduledoc """
  Lightweight in-memory dataset construction.
  Maps to inspect_ai's MemoryDataset.
  """

  alias CrucibleDatasets.Dataset

  @doc """
  Create a dataset from a list of items.

  ## Examples

      iex> CrucibleDatasets.memory([
      ...>   %{input: "What is 2+2?", expected: "4"},
      ...>   %{input: "What is 3+3?", expected: "6"}
      ...> ])
      %Dataset{name: "memory_...", items: [...]}

      iex> CrucibleDatasets.memory([
      ...>   %{input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}}
      ...> ], name: "my_dataset")
      %Dataset{name: "my_dataset", items: [...]}
  """
  @spec from_list([map()], keyword()) :: Dataset.t()
  def from_list(items, opts \\ []) when is_list(items) do
    name = Keyword.get(opts, :name, generate_name())
    version = Keyword.get(opts, :version, "1.0.0")
    auto_id = Keyword.get(opts, :auto_id, true)

    normalized_items = items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, idx} ->
      normalize_item(item, idx, auto_id)
    end)

    Dataset.new(name, version, normalized_items, %{
      source: :memory,
      total_items: length(normalized_items)
    })
  end

  @spec from_samples([map()], keyword()) :: Dataset.t()
  def from_samples(samples, opts \\ []) do
    # Alias for clarity when using Sample structs
    from_list(samples, opts)
  end

  defp normalize_item(item, idx, auto_id) do
    id = if auto_id and not Map.has_key?(item, :id) do
      "item_#{idx}"
    else
      Map.get(item, :id)
    end

    %{
      id: id,
      input: Map.fetch!(item, :input),
      expected: Map.get(item, :expected, ""),
      metadata: Map.get(item, :metadata, %{})
    }
  end

  defp generate_name do
    "memory_#{:erlang.unique_integer([:positive])}"
  end
end
```

**LOC Estimate:** ~70

### 2. CrucibleDatasets.Dataset Extensions (ENHANCE)

**File:** `lib/dataset_manager/dataset.ex` (additions)

```elixir
defmodule CrucibleDatasets.Dataset do
  # ... existing code ...

  @doc """
  Filter dataset items by predicate.

  ## Examples

      iex> dataset |> Dataset.filter(fn item ->
      ...>   item.metadata.difficulty == "hard"
      ...> end)
  """
  @spec filter(t(), (item() -> boolean())) :: t()
  def filter(%__MODULE__{} = dataset, predicate) when is_function(predicate, 1) do
    filtered_items = Enum.filter(dataset.items, predicate)

    %{dataset |
      items: filtered_items,
      metadata: Map.put(dataset.metadata, :total_items, length(filtered_items))
    }
  end

  @doc """
  Sort dataset items by key function.

  ## Examples

      iex> dataset |> Dataset.sort(fn item -> item.id end)
      iex> dataset |> Dataset.sort(:id, :desc)
  """
  @spec sort(t(), (item() -> term()) | atom(), :asc | :desc) :: t()
  def sort(%__MODULE__{} = dataset, key_or_fn, order \\ :asc)

  def sort(dataset, key, order) when is_atom(key) do
    sort(dataset, fn item -> Map.get(item, key) end, order)
  end

  def sort(dataset, key_fn, order) when is_function(key_fn, 1) do
    sorted_items = Enum.sort_by(dataset.items, key_fn, order)
    %{dataset | items: sorted_items}
  end

  @doc """
  Shuffle multiple-choice options while preserving correct answer mapping.
  """
  @spec shuffle_choices(t(), keyword()) :: t()
  def shuffle_choices(%__MODULE__{} = dataset, opts \\ []) do
    seed = Keyword.get(opts, :seed)

    if seed do
      :rand.seed(:exsplus, {seed, seed, seed})
    end

    shuffled_items = Enum.map(dataset.items, &shuffle_item_choices/1)
    %{dataset | items: shuffled_items}
  end

  defp shuffle_item_choices(%{input: %{choices: choices}} = item) when is_list(choices) do
    # Get correct answer index
    correct_idx = case item.expected do
      idx when is_integer(idx) -> idx
      letter when is_binary(letter) -> letter_to_index(letter)
      _ -> nil
    end

    # Shuffle with position tracking
    indexed_choices = choices |> Enum.with_index()
    shuffled = Enum.shuffle(indexed_choices)

    # Find new position of correct answer
    new_idx = if correct_idx do
      Enum.find_index(shuffled, fn {_, orig_idx} -> orig_idx == correct_idx end)
    end

    # Update item
    new_choices = Enum.map(shuffled, fn {choice, _} -> choice end)

    %{item |
      input: Map.put(item.input, :choices, new_choices),
      expected: new_idx || item.expected
    }
  end

  defp shuffle_item_choices(item), do: item

  defp letter_to_index(letter) do
    letter
    |> String.upcase()
    |> String.to_charlist()
    |> hd()
    |> Kernel.-(?A)
  end

  @doc """
  Slice dataset by index range.

  ## Examples

      iex> dataset |> Dataset.slice(0..9)   # First 10 items
      iex> dataset |> Dataset.slice(10, 5)  # 5 items starting at index 10
  """
  @spec slice(t(), Range.t() | {non_neg_integer(), non_neg_integer()}) :: t()
  def slice(%__MODULE__{} = dataset, range) when is_struct(range, Range) do
    sliced_items = Enum.slice(dataset.items, range)
    %{dataset |
      items: sliced_items,
      metadata: Map.put(dataset.metadata, :total_items, length(sliced_items))
    }
  end

  def slice(%__MODULE__{} = dataset, start, count) when is_integer(start) and is_integer(count) do
    sliced_items = Enum.slice(dataset.items, start, count)
    %{dataset |
      items: sliced_items,
      metadata: Map.put(dataset.metadata, :total_items, length(sliced_items))
    }
  end
end
```

**LOC Estimate:** ~120

### 3. CrucibleDatasets.FieldMapping (NEW)

**File:** `lib/dataset_manager/field_mapping.ex`

```elixir
defmodule CrucibleDatasets.FieldMapping do
  @moduledoc """
  Declarative field mapping for dataset loading.
  Maps to inspect_ai's FieldSpec pattern.
  """

  @type field_spec :: %{
    source: String.t() | atom(),
    target: :input | :expected | :id | {:metadata, atom()},
    transform: (term() -> term()) | nil
  }

  @type t :: %__MODULE__{
    input: String.t() | atom(),
    expected: String.t() | atom(),
    id: String.t() | atom() | nil,
    choices: String.t() | atom() | nil,
    metadata: [String.t() | atom()] | nil,
    transforms: %{atom() => (term() -> term())}
  }

  defstruct [
    input: :input,
    expected: :expected,
    id: :id,
    choices: nil,
    metadata: nil,
    transforms: %{}
  ]

  @doc """
  Create a field mapping specification.

  ## Examples

      iex> FieldMapping.new(
      ...>   input: "question",
      ...>   expected: "answer",
      ...>   metadata: ["difficulty", "subject"]
      ...> )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      input: Keyword.get(opts, :input, :input),
      expected: Keyword.get(opts, :expected, :expected),
      id: Keyword.get(opts, :id, :id),
      choices: Keyword.get(opts, :choices),
      metadata: Keyword.get(opts, :metadata),
      transforms: Keyword.get(opts, :transforms, %{})
    }
  end

  @doc """
  Apply field mapping to a raw record.
  """
  @spec apply(t(), map()) :: map()
  def apply(%__MODULE__{} = mapping, record) when is_map(record) do
    base = %{
      id: get_field(record, mapping.id),
      input: build_input(record, mapping),
      expected: get_and_transform(record, mapping.expected, mapping.transforms[:expected])
    }

    metadata = if mapping.metadata do
      mapping.metadata
      |> Enum.map(fn field ->
        {to_atom(field), get_field(record, field)}
      end)
      |> Map.new()
    else
      %{}
    end

    Map.put(base, :metadata, metadata)
  end

  defp build_input(record, %{choices: nil} = mapping) do
    get_and_transform(record, mapping.input, mapping.transforms[:input])
  end

  defp build_input(record, mapping) do
    %{
      question: get_and_transform(record, mapping.input, mapping.transforms[:input]),
      choices: get_field(record, mapping.choices) |> List.wrap()
    }
  end

  defp get_field(record, nil), do: nil
  defp get_field(record, field) when is_atom(field), do: Map.get(record, field)
  defp get_field(record, field) when is_binary(field) do
    Map.get(record, field) || Map.get(record, String.to_atom(field))
  end

  defp get_and_transform(record, field, nil), do: get_field(record, field)
  defp get_and_transform(record, field, transform) do
    record |> get_field(field) |> transform.()
  end

  defp to_atom(field) when is_atom(field), do: field
  defp to_atom(field) when is_binary(field), do: String.to_atom(field)
end
```

**LOC Estimate:** ~100

### 4. CrucibleDatasets.Loader.Generic (NEW)

**File:** `lib/dataset_manager/loader/generic.ex`

```elixir
defmodule CrucibleDatasets.Loader.Generic do
  @moduledoc """
  Generic dataset loader with field mapping support.
  Load CSV, JSON, JSONL with declarative field specs.
  """

  alias CrucibleDatasets.{Dataset, FieldMapping}

  @doc """
  Load a dataset from a file with field mapping.

  ## Examples

      iex> Loader.Generic.load("data.jsonl",
      ...>   name: "my_dataset",
      ...>   format: :jsonl,
      ...>   fields: FieldMapping.new(
      ...>     input: "question",
      ...>     expected: "answer",
      ...>     metadata: ["difficulty"]
      ...>   )
      ...> )
  """
  @spec load(String.t(), keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(path, opts \\ []) do
    name = Keyword.get(opts, :name, Path.basename(path, Path.extname(path)))
    version = Keyword.get(opts, :version, "1.0.0")
    format = Keyword.get(opts, :format) || detect_format(path)
    fields = Keyword.get(opts, :fields, FieldMapping.new())
    auto_id = Keyword.get(opts, :auto_id, true)
    limit = Keyword.get(opts, :limit)
    shuffle = Keyword.get(opts, :shuffle, false)
    seed = Keyword.get(opts, :seed)

    with {:ok, records} <- read_file(path, format),
         items <- process_records(records, fields, auto_id),
         items <- maybe_limit(items, limit),
         items <- maybe_shuffle(items, shuffle, seed) do
      {:ok, Dataset.new(name, version, items, %{
        source: path,
        format: format,
        total_items: length(items)
      })}
    end
  end

  defp detect_format(path) do
    case Path.extname(path) do
      ".json" -> :json
      ".jsonl" -> :jsonl
      ".csv" -> :csv
      _ -> :unknown
    end
  end

  defp read_file(path, :jsonl) do
    case File.read(path) do
      {:ok, content} ->
        records = content
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)
        {:ok, records}
      error -> error
    end
  end

  defp read_file(path, :json) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, records} when is_list(records) -> {:ok, records}
          {:ok, record} -> {:ok, [record]}
          error -> error
        end
      error -> error
    end
  end

  defp read_file(path, :csv) do
    # Simplified CSV parsing
    case File.read(path) do
      {:ok, content} ->
        [header | rows] = String.split(content, "\n", trim: true)
        keys = String.split(header, ",") |> Enum.map(&String.trim/1)

        records = Enum.map(rows, fn row ->
          values = String.split(row, ",") |> Enum.map(&String.trim/1)
          Enum.zip(keys, values) |> Map.new()
        end)

        {:ok, records}
      error -> error
    end
  end

  defp process_records(records, fields, auto_id) do
    records
    |> Enum.with_index(1)
    |> Enum.map(fn {record, idx} ->
      item = FieldMapping.apply(fields, record)

      if auto_id and (is_nil(item.id) or item.id == "") do
        Map.put(item, :id, "item_#{idx}")
      else
        item
      end
    end)
  end

  defp maybe_limit(items, nil), do: items
  defp maybe_limit(items, limit), do: Enum.take(items, limit)

  defp maybe_shuffle(items, false, _), do: items
  defp maybe_shuffle(items, true, nil), do: Enum.shuffle(items)
  defp maybe_shuffle(items, true, seed) do
    :rand.seed(:exsplus, {seed, seed, seed})
    Enum.shuffle(items)
  end
end
```

**LOC Estimate:** ~120

---

## File Structure

```
lib/dataset_manager/
├── dataset.ex                         # ENHANCE: Add filter/sort/shuffle_choices
├── memory_dataset.ex                  # NEW: In-memory dataset builder
├── field_mapping.ex                   # NEW: Declarative field specs
├── loader/
│   ├── generic.ex                     # NEW: Generic loader with field mapping
│   ├── mmlu.ex                        # Current (unchanged)
│   ├── gsm8k.ex                       # Current (unchanged)
│   └── human_eval.ex                  # Current (unchanged)
└── (existing modules unchanged)
```

---

## Implementation Roadmap

### Phase 1: Core Additions (1 week)
1. MemoryDataset module
2. Dataset.filter/sort/slice methods
3. Choice shuffling support

### Phase 2: Field Mapping (1 week)
1. FieldMapping specification
2. Generic loader with field mapping
3. Transform functions

### Phase 3: Integration (0.5 week)
1. Update existing loaders to use FieldMapping internally
2. Documentation
3. Examples

---

## Backward Compatibility

- All existing loaders unchanged
- New methods are additive
- MemoryDataset is new module, no conflicts
- Existing Dataset struct fields preserved

---

## Total Effort Estimate

| Component | LOC | Days |
|-----------|-----|------|
| MemoryDataset | 70 | 0.5 |
| Dataset extensions | 120 | 1 |
| FieldMapping | 100 | 1 |
| Generic loader | 120 | 1 |
| Tests | 100 | 1 |
| **Total** | **~510** | **4.5 days** |

---

**Document Status:** Complete
**Last Updated:** 2025-12-23
