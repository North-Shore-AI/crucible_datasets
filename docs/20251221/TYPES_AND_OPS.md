# Types and Operations Gaps

**Date:** 2025-12-21
**Scope:** Dataset types and operations needed for tinker parity
**Python Reference:** `./datasets/src/datasets/` (HuggingFace datasets Python library)

---

## Part 1: DatasetDict

### Python Implementation

**Reference:** `datasets/src/datasets/dataset_dict.py`

```python
class DatasetDict(dict[Union[str, NamedSplit], Dataset]):
    """A dictionary (dict of str: datasets.Dataset) with dataset transforms"""

    @property
    def num_rows(self) -> dict[str, int]:
        return {k: dataset.num_rows for k, dataset in self.items()}

    @property
    def column_names(self) -> dict[str, list[str]]:
        return {k: dataset.column_names for k, dataset in self.items()}

    def map(self, function, **kwargs) -> DatasetDict:
        return DatasetDict({k: dataset.map(function, **kwargs)
                           for k, dataset in self.items()})
```

### Elixir Implementation

**File:** `lib/dataset_manager/dataset_dict.ex`
**Status:** FULLY IMPLEMENTED + WIRED

**Structure:**
```elixir
defmodule CrucibleDatasets.DatasetDict do
  @enforce_keys [:splits, :datasets]
  defstruct [:splits, :datasets]

  # splits: MapSet of split names
  # datasets: Map of %{split_name => Dataset}
end
```

**Features implemented:**
- Access protocol for `dataset["train"]` syntax
- Enumerable protocol for iteration
- Split management (add, remove, rename)
- Transform methods (map, filter, select, shuffle)
- Info and statistics methods
- Flatten (concatenate all splits)

**What's missing:**
- None for tinker parity (num_rows/column_names implemented)

**Action needed:**
```elixir
def num_rows(%__MODULE__{datasets: datasets}) do
  Map.new(datasets, fn {k, ds} -> {k, Dataset.num_items(ds)} end)
end

def column_names(%__MODULE__{datasets: datasets}) do
  Map.new(datasets, fn {k, ds} -> {k, Dataset.column_names(ds)} end)
end
```

---

## Part 2: IterableDataset

### Python Implementation

**Reference:** `datasets/src/datasets/iterable_dataset.py`

```python
class IterableDataset:
    """Lazy dataset for streaming large files"""

    def map(self, function):
        ex_iterable = self._ex_iterable.map(function)
        return IterableDataset(ex_iterable, self._info)

    def filter(self, function):
        ex_iterable = self._ex_iterable.filter(function)
        return IterableDataset(ex_iterable, self._info)

    def shuffle(self, buffer_size, seed=None):
        ex_iterable = self._ex_iterable.shuffle(buffer_size, seed)
        return IterableDataset(ex_iterable, self._info)

    def __iter__(self):
        for key, example in self._ex_iterable:
            yield example
```

### Elixir Implementation

**File:** `lib/dataset_manager/iterable_dataset.ex`
**Status:** FULLY IMPLEMENTED + WIRED

**Structure:**
```elixir
defmodule CrucibleDatasets.IterableDataset do
  @enforce_keys [:stream, :name]
  defstruct [:stream, :name, info: %{}]

  # stream: Enumerable.t() (Elixir Stream)
  # name: String.t()
  # info: map()
end
```

**Features implemented:**
- Lazy transforms (map, filter, batch, shuffle with buffer)
- take/skip operations
- Enumerable protocol for Enum/Stream compatibility
- Conversion to/from Dataset
- Streaming from file/HTTP via Stream

**What's missing:**
- Parquet streaming is batch-based due to Explorer limitations

---

## Part 3: Dataset Operations

### Python Dataset Operations

**Reference:** `datasets/src/datasets/arrow_dataset.py`

```python
class Dataset:
    # Transforms
    def map(self, function, **kwargs) -> Dataset
    def filter(self, function, **kwargs) -> Dataset
    def select(self, indices) -> Dataset  # by index list/range
    def sort(self, column_names) -> Dataset
    def shuffle(self, seed=None) -> Dataset
    def train_test_split(self, test_size=None) -> DatasetDict
    def shard(self, num_shards, index) -> Dataset

    # Column operations
    def rename_column(self, original, new) -> Dataset
    def remove_columns(self, column_names) -> Dataset
    def cast_column(self, column, feature) -> Dataset

    # Slicing
    def __getitem__(self, key):
        if isinstance(key, int): return self._getitem_one(key)
        if isinstance(key, slice): return self.select(range(*key.indices(len(self))))
        if isinstance(key, str): return self._getitem_column(key)

    # Conversion
    @classmethod
    def from_list(cls, mapping: List[dict]) -> Dataset

    @classmethod
    def from_pandas(cls, df) -> Dataset
```

### Elixir Implementation

**File:** `lib/dataset_manager/dataset.ex`
**Status:** COMPLETE

**What exists:**
- map, filter, shuffle, select (columns)
- take, skip, slice, batch
- concat, split (train/test)
- shard (multi-shard splitting)
- rename_column, add_column, remove_columns
- unique, sort, flatten
- Access protocol for indexing: `dataset[0]`
- Enumerable protocol for iteration

**What's missing:**
- cast_column (full feature casting is still minimal)

**Action needed:**

#### Add select by indices
```elixir
@spec select(t(), [non_neg_integer()]) :: t()
def select(%__MODULE__{} = dataset, indices) when is_list(indices) do
  case List.first(indices) do
    idx when is_integer(idx) ->
      new_items = indices
        |> Enum.map(&Enum.at(dataset.items, &1))
        |> Enum.reject(&is_nil/1)
      update_items(dataset, new_items)

    col when is_atom(col) or is_binary(col) ->
      select_columns(dataset, indices)
  end
end
```

#### Add Dataset.from_list
```elixir
@spec from_list([map()], keyword()) :: t()
def from_list(items, opts \\ []) do
  name = Keyword.get(opts, :name, "dataset")
  version = Keyword.get(opts, :version, "1.0")
  metadata = Keyword.get(opts, :metadata, %{})

  new(name, version, items, metadata)
end
```

#### Add Dataset.from_dataframe
```elixir
@spec from_dataframe(Explorer.DataFrame.t(), keyword()) :: t()
def from_dataframe(%Explorer.DataFrame{} = df, opts \\ []) do
  items = Explorer.DataFrame.to_rows(df)
    |> Enum.map(&to_string_keys/1)

  from_list(items, opts)
end
```

---

## Part 4: Features System

### Python Implementation

**Reference:** `datasets/src/datasets/features/features.py`

**Type hierarchy:**
```python
# Base types
Value(dtype='string')  # scalar
Value(dtype='int64')
Value(dtype='float32')
Value(dtype='bool')

# Structured types
ClassLabel(names=['cat', 'dog'])  # categorical
Sequence(feature=Value('int32'))  # list
Image(decode=True)  # image bytes/path
Audio(sampling_rate=16000)  # audio bytes/path
```

### Elixir Implementation

**File:** `lib/dataset_manager/features.ex`
**Status:** COMPLETE (tinker scope)

**What exists:**
- Features struct with schema map
- Value, ClassLabel, Sequence, Image, Audio types
- validate_value, validate_item
- cast_value for type conversion
- infer features from dataset

**Feature type files:**
- `lib/dataset_manager/features/value.ex`
- `lib/dataset_manager/features/class_label.ex`
- `lib/dataset_manager/features/sequence.ex`
- `lib/dataset_manager/features/image.ex`
- `lib/dataset_manager/features/audio.ex`

**What's missing:**
- Audio decode not implemented (out of scope)
- encode_example for Arrow compatibility (full parity)

**Action needed:**

#### Add features to Dataset struct
```elixir
defmodule CrucibleDatasets.Dataset do
  @type t :: %__MODULE__{
    name: String.t(),
    version: String.t(),
    items: [item()],
    metadata: map(),
    features: Features.t() | nil  # ADD THIS
  }

  @enforce_keys [:name, :version, :items, :metadata]
  defstruct [:name, :version, :items, :metadata, features: nil]

  def new(name, version, items, metadata \\ %{}, features \\ nil) do
    features = features || Features.infer_from_items(items)

    %__MODULE__{
      name: name,
      version: version,
      items: items,
      metadata: metadata,
      features: features
    }
  end
end
```

---

## Part 5: Concatenate Datasets

### Python Implementation

```python
def concatenate_datasets(dsets: List[Dataset], **kwargs) -> Dataset:
    """Concatenate multiple datasets"""
    features = _check_if_features_can_be_aligned([ds.features for ds in dsets])
    dsets = [ds.cast(features) for ds in dsets]
    table = concat_tables([ds._data for ds in dsets])
    return Dataset(table, info=dsets[0].info, split=dsets[0].split)
```

### Elixir Implementation

**Status:** COMPLETE (basic version)

```elixir
@spec concat([t()]) :: t()
def concat([single]), do: single

def concat([first | rest]) do
  Enum.reduce(rest, first, &concat(&2, &1))
end
```

**What's missing:**
- No feature alignment check
- No automatic casting to common features

---

## Summary: Missing Operations

### High Priority
1. **All tinker operations complete**

### Medium Priority
2. **Feature alignment in concat** (optional)
3. **cast_column** (optional)

### Low Priority
4. **Audio decode** - Not needed for tinker

---

## Implementation Checklist

**DatasetDict:**
- [x] Basic structure
- [x] Access protocol
- [x] Enumerable protocol
- [x] Transform methods
- [x] Return from load()
- [x] Convenience properties
- [ ] Feature validation

**IterableDataset:**
- [x] Basic structure
- [x] Lazy transforms
- [x] Enumerable protocol
- [x] Buffer shuffle
- [x] Return from load(..., streaming: true)
- [x] JSONL streaming integration
- [x] Parquet streaming (documented limitation)

**Dataset:**
- [x] Core operations (map, filter, etc.)
- [x] Slicing and indexing
- [x] Column operations
- [x] select by indices
- [x] from_list
- [x] from_dataframe
- [ ] cast_column
- [x] features field

**Features:**
- [x] Basic types (Value, ClassLabel, Sequence, Image, Audio)
- [x] Validation
- [x] Type inference
- [x] Integration with Dataset
- [x] Image decode
- [ ] encode_example for Arrow

**Total:** 23/26 complete (88%)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
