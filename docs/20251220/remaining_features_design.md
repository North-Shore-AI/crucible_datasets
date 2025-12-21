# Remaining Features Design Specification

**Date:** 2025-12-21
**Status:** Design Draft
**Scope:** Features needed for tinker parity

## Overview

This document provides detailed design specifications for the 7 remaining features needed for tinker-cookbook parity:

1. DatasetDict
2. IterableDataset
3. Dataset Operations (map/filter/select/shuffle/batch/concat)
4. Real MMLU Loader
5. Real HumanEval Loader
6. Features Schema System
7. Image Decode Support

---

## 1. DatasetDict

### Purpose
Enable split-based indexing: `dataset["train"]`, `dataset["test"]`, `dataset["validation"]`

### Python Equivalent
```python
from datasets import load_dataset
ds = load_dataset("gsm8k", "main")
train = ds["train"]  # Dataset
test = ds["test"]    # Dataset
```

### Proposed Elixir API
```elixir
# Load returns DatasetDict when multiple splits available
{:ok, dataset_dict} = CrucibleDatasets.load("openai/gsm8k")

# Access splits
train = dataset_dict["train"]  # or dataset_dict[:train]
test = dataset_dict["test"]

# List available splits
DatasetDict.splits(dataset_dict)  # [:train, :test]

# Iterate all splits
DatasetDict.each(dataset_dict, fn {split_name, dataset} ->
  IO.puts("#{split_name}: #{length(dataset.items)} items")
end)
```

### Struct Design
```elixir
defmodule CrucibleDatasets.DatasetDict do
  @type t :: %__MODULE__{
    splits: %{atom() => Dataset.t()},
    metadata: map()
  }

  defstruct splits: %{}, metadata: %{}

  # Access protocol for dataset_dict["train"] syntax
  defimpl Access do
    def fetch(dict, key), do: Map.fetch(dict.splits, normalize_key(key))
    def get_and_update(dict, key, fun), do: ...
    def pop(dict, key), do: ...
  end
end
```

### Loading Behavior
- `load/2` returns `{:ok, Dataset.t()}` when single split requested
- `load/2` returns `{:ok, DatasetDict.t()}` when no split specified and multiple exist
- Option `:split` forces single Dataset return

---

## 2. IterableDataset

### Purpose
Stream large datasets without loading into memory. Critical for OpenThoughts (1.2M examples).

### Python Equivalent
```python
ds = load_dataset("open-thoughts/OpenThoughts3-1.2M", split="train", streaming=True)
for example in ds:
    process(example)
```

### Proposed Elixir API
```elixir
# Streaming load
{:ok, stream} = CrucibleDatasets.load("open-thoughts/OpenThoughts3-1.2M",
  split: "train",
  streaming: true
)

# Lazy enumeration
stream
|> IterableDataset.take(1000)
|> IterableDataset.map(&process/1)
|> Enum.to_list()

# Batched iteration
stream
|> IterableDataset.batch(32)
|> Enum.each(&train_step/1)
```

### Struct Design
```elixir
defmodule CrucibleDatasets.IterableDataset do
  @type t :: %__MODULE__{
    source: source_spec(),
    transform_chain: [transform()],
    metadata: map()
  }

  @type source_spec ::
    {:stream, Stream.t()} |
    {:file, path :: String.t(), format :: atom()} |
    {:remote, repo_id :: String.t(), opts :: keyword()}

  @type transform ::
    {:map, (item -> item)} |
    {:filter, (item -> boolean)} |
    {:batch, size :: pos_integer()} |
    {:shuffle, buffer_size :: pos_integer()}

  defstruct source: nil, transform_chain: [], metadata: %{}

  # Enumerable protocol for Enum compatibility
  defimpl Enumerable do
    def reduce(dataset, acc, fun), do: ...
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}
  end
end
```

### Streaming Sources
1. **JSONL**: Line-by-line streaming via `File.stream!/1`
2. **Parquet**: Chunked reads via Explorer (no true streaming yet)
3. **Remote**: Stream directly from HuggingFace via `HfHub.Download.download_stream/3`

---

## 3. Dataset Operations

### Purpose
Native operations on Dataset struct matching Python datasets API.

### Python Equivalent
```python
ds = ds.map(lambda x: {"text": x["text"].lower()})
ds = ds.filter(lambda x: len(x["text"]) > 10)
ds = ds.shuffle(seed=42)
ds = ds.select(range(100))
```

### Proposed Elixir API
```elixir
dataset
|> Dataset.map(fn item -> %{item | text: String.downcase(item.text)} end)
|> Dataset.filter(fn item -> String.length(item.text) > 10 end)
|> Dataset.shuffle(seed: 42)
|> Dataset.select(0..99)
|> Dataset.batch(32)
```

### Implementation Strategy
Add methods directly to `CrucibleDatasets.Dataset`:

```elixir
defmodule CrucibleDatasets.Dataset do
  # Existing struct...

  @doc "Apply function to each item"
  def map(%__MODULE__{items: items} = dataset, fun) do
    %{dataset | items: Enum.map(items, fun)}
  end

  @doc "Keep items matching predicate"
  def filter(%__MODULE__{items: items} = dataset, fun) do
    %{dataset | items: Enum.filter(items, fun)}
  end

  @doc "Shuffle with optional seed"
  def shuffle(%__MODULE__{items: items} = dataset, opts \\ []) do
    seed = Keyword.get(opts, :seed)
    if seed, do: :rand.seed(:exsss, {seed, seed, seed})
    %{dataset | items: Enum.shuffle(items)}
  end

  @doc "Select items by range or indices"
  def select(%__MODULE__{items: items} = dataset, range) when is_struct(range, Range) do
    %{dataset | items: Enum.slice(items, range)}
  end

  def select(%__MODULE__{items: items} = dataset, indices) when is_list(indices) do
    %{dataset | items: Enum.map(indices, &Enum.at(items, &1))}
  end

  @doc "Take first n items"
  def take(%__MODULE__{items: items} = dataset, n) do
    %{dataset | items: Enum.take(items, n)}
  end

  @doc "Skip first n items"
  def skip(%__MODULE__{items: items} = dataset, n) do
    %{dataset | items: Enum.drop(items, n)}
  end

  @doc "Group items into batches"
  def batch(%__MODULE__{items: items} = dataset, size) do
    %{dataset | items: Enum.chunk_every(items, size)}
  end

  @doc "Concatenate multiple datasets"
  def concat(datasets) when is_list(datasets) do
    items = Enum.flat_map(datasets, & &1.items)
    %__MODULE__{
      name: "concatenated",
      version: "1.0",
      items: items,
      metadata: %{source: "concat", count: length(datasets)}
    }
  end
end
```

### Migration from Sampler
Current `Sampler` module has similar functions. Options:
1. **Deprecate Sampler** - Move all to Dataset, keep Sampler as thin wrapper
2. **Keep Both** - Sampler for standalone use, Dataset methods for chaining
3. **Delegate** - Dataset methods delegate to Sampler

**Recommendation:** Option 1 - consolidate into Dataset for cleaner API.

---

## 4. Real MMLU Loader

### Current State
Synthetic data only. Need real HuggingFace loader.

### Dataset Info
- **Repo:** `cais/mmlu`
- **Configs:** 57 subjects (abstract_algebra, anatomy, astronomy, etc.)
- **Splits:** test, validation, dev
- **Format:** Parquet

### Field Mapping
```
HuggingFace Field -> Elixir Field
question          -> input.question
choices           -> input.choices (list of 4 strings)
answer            -> expected (0-3 index)
subject           -> metadata.subject
```

### Implementation
```elixir
defmodule CrucibleDatasets.Loader.MMLU do
  @repo_id "cais/mmlu"

  @configs ~w(abstract_algebra anatomy astronomy ...)

  def load(opts \\ []) do
    config = Keyword.get(opts, :config, "all")
    split = Keyword.get(opts, :split, "test")

    case HuggingFace.fetch(@repo_id, config: config, split: split) do
      {:ok, raw_data} ->
        items = parse_mmlu_data(raw_data)
        {:ok, Dataset.new("mmlu", "1.0", items, %{config: config})}
      error -> error
    end
  end

  defp parse_mmlu_data(raw_data) do
    Enum.with_index(raw_data, fn item, idx ->
      %{
        id: "mmlu_#{idx}",
        input: %{
          question: item["question"],
          choices: item["choices"]
        },
        expected: item["answer"],
        metadata: %{subject: item["subject"]}
      }
    end)
  end
end
```

---

## 5. Real HumanEval Loader

### Current State
Synthetic data only. Need real loader.

### Dataset Info
- **Repo:** `openai/openai_humaneval`
- **Splits:** test only
- **Format:** Parquet/JSONL

### Field Mapping
```
HuggingFace Field -> Elixir Field
task_id           -> id
prompt            -> input.prompt
canonical_solution -> expected.solution
test              -> expected.test_code
entry_point       -> metadata.entry_point
```

### Implementation
```elixir
defmodule CrucibleDatasets.Loader.HumanEval do
  @repo_id "openai/openai_humaneval"

  def load(opts \\ []) do
    split = Keyword.get(opts, :split, "test")

    case HuggingFace.fetch(@repo_id, split: split) do
      {:ok, raw_data} ->
        items = parse_humaneval_data(raw_data)
        {:ok, Dataset.new("humaneval", "1.0", items, %{})}
      error -> error
    end
  end

  defp parse_humaneval_data(raw_data) do
    Enum.map(raw_data, fn item ->
      %{
        id: item["task_id"],
        input: %{
          prompt: item["prompt"]
        },
        expected: %{
          solution: item["canonical_solution"],
          test_code: item["test"]
        },
        metadata: %{
          entry_point: item["entry_point"]
        }
      }
    end)
  end
end
```

---

## 6. Features Schema System

### Purpose
Type-safe schema for dataset columns. Enables validation, serialization, and media handling.

### Python Equivalent
```python
from datasets import Features, Value, ClassLabel, Sequence, Image

features = Features({
    "text": Value("string"),
    "label": ClassLabel(names=["neg", "pos"]),
    "tokens": Sequence(Value("string")),
    "image": Image()
})
```

### Proposed Elixir API
```elixir
alias CrucibleDatasets.Features.{Value, ClassLabel, Sequence, Image}

features = %{
  text: Value.string(),
  label: ClassLabel.new(["neg", "pos"]),
  tokens: Sequence.new(Value.string()),
  image: Image.new()
}

# Validate item against schema
Features.validate(item, features)

# Decode media fields
Features.decode(item, features)
```

### Type Definitions
```elixir
defmodule CrucibleDatasets.Features do
  @type feature_type ::
    Value.t() |
    ClassLabel.t() |
    Sequence.t() |
    Image.t() |
    Audio.t()

  @type schema :: %{atom() => feature_type()}
end

defmodule CrucibleDatasets.Features.Value do
  @type dtype :: :string | :int32 | :int64 | :float32 | :float64 | :bool
  @type t :: %__MODULE__{dtype: dtype()}

  defstruct [:dtype]

  def string, do: %__MODULE__{dtype: :string}
  def int64, do: %__MODULE__{dtype: :int64}
  def float32, do: %__MODULE__{dtype: :float32}
end

defmodule CrucibleDatasets.Features.ClassLabel do
  @type t :: %__MODULE__{
    names: [String.t()],
    num_classes: non_neg_integer()
  }

  defstruct [:names, :num_classes]

  def new(names) when is_list(names) do
    %__MODULE__{names: names, num_classes: length(names)}
  end

  def int2str(%__MODULE__{names: names}, idx), do: Enum.at(names, idx)
  def str2int(%__MODULE__{names: names}, name), do: Enum.find_index(names, &(&1 == name))
end

defmodule CrucibleDatasets.Features.Sequence do
  @type t :: %__MODULE__{feature: Features.feature_type()}

  defstruct [:feature]

  def new(feature), do: %__MODULE__{feature: feature}
end

defmodule CrucibleDatasets.Features.Image do
  @type t :: %__MODULE__{
    decode: boolean(),
    mode: String.t() | nil
  }

  defstruct decode: true, mode: nil

  def new(opts \\ []) do
    %__MODULE__{
      decode: Keyword.get(opts, :decode, true),
      mode: Keyword.get(opts, :mode)
    }
  end
end
```

---

## 7. Image Decode Support

### Purpose
Decode images for VLM datasets (caltech101, flowers102, etc.).

### Python Equivalent
```python
ds = load_dataset("caltech101", split="train")
image = ds[0]["image"]  # PIL.Image
```

### Proposed Elixir API
```elixir
{:ok, dataset} = CrucibleDatasets.load("caltech101", split: "train")
item = hd(dataset.items)

# Image is decoded automatically if features specify Image type
item.input.image  # => %Vix.Vips.Image{} or %Nx.Tensor{}

# Or lazy decode
item.input.image  # => %MediaRef{path: "...", bytes: nil}
MediaRef.decode(item.input.image)  # => %Vix.Vips.Image{}
```

### MediaRef Struct
```elixir
defmodule CrucibleDatasets.MediaRef do
  @type t :: %__MODULE__{
    path: String.t() | nil,
    bytes: binary() | nil,
    mime: String.t(),
    metadata: map()
  }

  defstruct [:path, :bytes, :mime, metadata: %{}]

  @doc "Decode image to Vix.Vips.Image"
  def decode(%__MODULE__{bytes: bytes}) when is_binary(bytes) do
    Vix.Vips.Image.new_from_buffer(bytes)
  end

  def decode(%__MODULE__{path: path}) when is_binary(path) do
    Vix.Vips.Image.new_from_file(path)
  end

  @doc "Convert to Nx tensor"
  def to_tensor(%__MODULE__{} = ref) do
    {:ok, image} = decode(ref)
    # Convert Vix image to Nx tensor
    image
    |> Vix.Vips.Image.write_to_binary()
    |> Nx.from_binary(:u8)
    |> Nx.reshape({height, width, channels})
  end
end
```

### Dependencies
- `vix` - libvips bindings for image decode
- System: libvips (`apt install libvips-dev`)

---

## Implementation Priority

| Feature | Priority | Effort | Dependencies |
|---------|----------|--------|--------------|
| Dataset Operations | P0 | Low | None |
| DatasetDict | P0 | Low | None |
| Real MMLU Loader | P1 | Low | None |
| Real HumanEval Loader | P1 | Low | None |
| IterableDataset | P1 | Medium | Streaming parsers |
| Features Schema | P2 | Medium | None |
| Image Decode | P2 | Medium | vix, libvips |

---

## Open Questions

1. **Lazy vs Eager Decode**: Should images decode automatically or require explicit `MediaRef.decode/1`?
2. **Tensor Backend**: Return `Vix.Vips.Image` or convert to `Nx.Tensor`? Or support both?
3. **Sampler Deprecation**: Keep both Sampler and Dataset methods, or consolidate?
4. **Streaming Buffer**: What buffer size for shuffle in streaming mode?
