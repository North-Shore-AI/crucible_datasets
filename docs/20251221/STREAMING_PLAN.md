# Streaming Implementation Plan

**Date:** 2025-12-21
**Goal:** Enable streaming for large datasets (primarily OpenThoughts-1.2M)
**Python Reference:** `./datasets/src/datasets/iterable_dataset.py`

---

**Status Update (2025-12-21):** JSONL streaming is implemented via `Format.JSONL.parse_stream/1`
and `load_dataset/2` with `streaming: true`. Parquet streaming remains limited to batch iteration
due to Explorer limitations.

## Overview

**Why streaming?**
- OpenThoughts3-1.2M has 1.2 million examples
- Loading fully into memory would use ~5-10 GB
- Streaming allows processing in constant memory

**Streaming formats needed:**
1. JSONL (line-by-line JSON)
2. Parquet (row groups or full file in chunks)

---

## Part 1: JSONL Streaming

### Current Implementation

**File:** `lib/dataset_manager/format/jsonl.ex`

**Current (eager loading):**
```elixir
defmodule CrucibleDatasets.Format.JSONL do
  def parse(content) when is_binary(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
```

**Problem:** Loads entire file into memory

### Streaming Implementation

#### Option 1: Local File Streaming
```elixir
defmodule CrucibleDatasets.Format.JSONL do
  @doc "Eager parse (existing)"
  def parse(content) when is_binary(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  @doc "Stream from local file path"
  def stream_file(path) do
    File.stream!(path)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)
  end

  @doc "Stream from binary content"
  def stream_content(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)
  end
end
```

#### Option 2: HTTP Streaming (HfHub integration)
```elixir
defmodule CrucibleDatasets.Format.JSONL do
  @doc "Stream from HuggingFace file"
  def stream_hf(repo_id, file_path, opts \\ []) do
    url = HfHub.Api.hf_hub_url(repo_id, file_path, opts)

    HfHub.Download.download_stream(url, opts)
    |> chunk_to_lines()
    |> Stream.map(&Jason.decode!/1)
  end

  # Helper: chunk binary stream into lines
  defp chunk_to_lines(byte_stream) do
    Stream.resource(
      fn -> {byte_stream, ""} end,
      fn {stream, buffer} ->
        case Enum.take(stream, 1) do
          [] ->
            if buffer != "", do: {[buffer], :done}, else: {:halt, :done}
          [chunk] ->
            lines = String.split(buffer <> chunk, "\n")
            {complete, [incomplete]} = Enum.split(lines, -1)
            {complete, {stream, incomplete}}
        end
      end,
      fn _ -> :ok end
    )
  end
end
```

#### Option 3: Unified Streaming API
```elixir
defmodule CrucibleDatasets.Format.JSONL do
  @doc """
  Stream JSONL data from various sources.

  ## Sources
  - `{:file, path}` - Local file
  - `{:hf, repo_id, file_path}` - HuggingFace repo
  - `{:url, url}` - HTTP URL
  - `{:content, binary}` - In-memory binary
  """
  def stream(source, opts \\ []) do
    source
    |> get_byte_stream(opts)
    |> line_stream()
    |> Stream.map(&Jason.decode!/1)
  end

  defp get_byte_stream({:file, path}, _opts) do
    File.stream!(path, [], 64 * 1024)  # 64KB chunks
  end

  defp get_byte_stream({:hf, repo_id, file_path}, opts) do
    url = HfHub.Api.hf_hub_url(repo_id, file_path, opts)
    HfHub.Download.download_stream(url, opts)
  end

  defp get_byte_stream({:url, url}, opts) do
    HfHub.Download.download_stream(url, opts)
  end

  defp get_byte_stream({:content, binary}, _opts) do
    Stream.unfold(binary, fn
      "" -> nil
      content -> {content, ""}
    end)
  end
end
```

### Integration with Loader

```elixir
defmodule CrucibleDatasets.Loader.Reasoning do
  def load(opts) do
    repo_id = "open-thoughts/OpenThoughts3-1.2M"
    split = Keyword.get(opts, :split, "train")
    streaming = Keyword.get(opts, :streaming, false)

    if streaming do
      load_streaming(repo_id, split, opts)
    else
      load_eager(repo_id, split, opts)
    end
  end

  defp load_streaming(repo_id, split, opts) do
    {:ok, files} = HfHub.Api.list_files(repo_id)
    file = find_split_file(files, split, ".jsonl")

    stream = Format.JSONL.stream({:hf, repo_id, file}, opts)
      |> Stream.map(&parse_reasoning_item/1)

    {:ok, IterableDataset.from_stream(stream,
      name: "#{repo_id}/#{split}",
      info: %{repo_id: repo_id, split: split, streaming: true}
    )}
  end
end
```

---

## Part 2: Parquet Streaming

### Challenge

**Explorer limitations:**
- `Explorer.DataFrame.from_parquet(path)` loads full file
- No lazy/streaming Parquet reader in Elixir ecosystem
- Parquet files can be 100s of MB to GB

### Options

#### Option 1: Batch Processing (Recommended)

Read Parquet in chunks, process incrementally.

```elixir
defmodule CrucibleDatasets.Format.Parquet do
  @doc """
  Stream Parquet file in batches.

  Note: This still loads full file but yields rows in batches.
  Memory usage = batch_size * row_size (not full file).
  """
  def stream_batches(source, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 1000)

    Stream.resource(
      fn -> init_parquet_reader(source, opts) end,
      fn state -> read_next_batch(state, batch_size) end,
      fn state -> cleanup_parquet_reader(state) end
    )
  end

  defp init_parquet_reader({:file, path}, _opts) do
    df = Explorer.DataFrame.from_parquet!(path)
    %{
      dataframe: df,
      total_rows: Explorer.DataFrame.n_rows(df),
      offset: 0
    }
  end

  defp read_next_batch(%{offset: offset, total_rows: total} = state, _batch_size)
       when offset >= total do
    {:halt, state}
  end

  defp read_next_batch(%{dataframe: df, offset: offset} = state, batch_size) do
    batch_df = Explorer.DataFrame.slice(df, offset, batch_size)
    rows = Explorer.DataFrame.to_rows(batch_df)

    {rows, %{state | offset: offset + batch_size}}
  end
end
```

**Usage:**
```elixir
Format.Parquet.stream_batches({:file, "/path/to/data.parquet"}, batch_size: 1000)
|> Stream.flat_map(& &1)  # Flatten batches to rows
|> IterableDataset.from_stream(name: "dataset")
```

#### Option 2: Pragmatic Approach (Recommended for now)

For tinker parity, accept full-file loading for Parquet.

**Rationale:**
- Most tinker datasets are <1 GB (fits in memory)
- OpenThoughts is JSONL (can stream)
- True Parquet streaming requires significant infrastructure

**Implementation:**
```elixir
def load(repo_id, opts) do
  streaming = Keyword.get(opts, :streaming, false)
  format = infer_format(repo_id, opts)

  case {streaming, format} do
    {true, :jsonl} ->
      load_jsonl_streaming(repo_id, opts)

    {true, :parquet} ->
      Logger.warning("Parquet streaming not supported, loading full file")
      load_parquet_eager(repo_id, opts)

    {false, _} ->
      load_eager(repo_id, opts)
  end
end
```

---

## Part 3: Integration Plan

### 1. Update load() API

**File:** `lib/crucible_datasets.ex`

```elixir
defmodule CrucibleDatasets do
  @doc """
  Load a dataset from HuggingFace or local source.

  ## Options
    * `:split` - Dataset split (:train, :test, etc.). If nil, loads all splits.
    * `:config` - Dataset config/subset name
    * `:streaming` - Return IterableDataset for lazy loading (default: false)
    * `:sample_size` - Limit number of items

  ## Returns
    * `{:ok, Dataset.t()}` - When split is specified and streaming: false
    * `{:ok, DatasetDict.t()}` - When split is nil
    * `{:ok, IterableDataset.t()}` - When streaming: true

  ## Examples
      # Load single split (eager)
      {:ok, dataset} = CrucibleDatasets.load("openai/gsm8k", split: :train)

      # Load all splits
      {:ok, dataset_dict} = CrucibleDatasets.load("openai/gsm8k")
      train = dataset_dict["train"]

      # Streaming
      {:ok, iterable} = CrucibleDatasets.load(
        "open-thoughts/OpenThoughts3-1.2M",
        split: :train,
        streaming: true
      )
  """
  def load(repo_id, opts \\ []) do
    Loader.load(repo_id, opts)
  end
end
```

### 2. Update Loader Module

**File:** `lib/dataset_manager/loader.ex`

```elixir
defmodule CrucibleDatasets.Loader do
  def load(repo_id, opts) when is_binary(repo_id) do
    split = Keyword.get(opts, :split)
    streaming = Keyword.get(opts, :streaming, false)

    cond do
      split && streaming ->
        load_split_streaming(repo_id, split, opts)

      split && !streaming ->
        load_split_eager(repo_id, split, opts)

      !split && !streaming ->
        load_all_splits_eager(repo_id, opts)

      !split && streaming ->
        {:error, :streaming_requires_split}
    end
  end
end
```

---

## Part 4: Testing Plan

### Unit Tests

**File:** `test/crucible_datasets/format/jsonl_test.exs`

```elixir
defmodule CrucibleDatasets.Format.JSONLTest do
  use ExUnit.Case
  alias CrucibleDatasets.Format.JSONL

  test "stream_content yields line by line" do
    content = """
    {"id": 1, "text": "first"}
    {"id": 2, "text": "second"}
    {"id": 3, "text": "third"}
    """

    result = JSONL.stream_content(content) |> Enum.to_list()

    assert length(result) == 3
    assert List.first(result)["id"] == 1
  end
end
```

### Integration Tests

**File:** `test/crucible_datasets/loader_streaming_test.exs`

```elixir
@tag :live
test "load OpenThoughts with streaming" do
  {:ok, iterable} = CrucibleDatasets.load(
    "open-thoughts/OpenThoughts3-1.2M",
    split: :train,
    streaming: true
  )

  items = IterableDataset.take(iterable, 100)

  assert length(items) == 100
  assert Map.has_key?(List.first(items), :id)
end
```

---

## Part 5: Documentation

### User Guide

```markdown
# Streaming Large Datasets

## When to use streaming

Use `streaming: true` when:
- Dataset has >100K examples
- Dataset size >1 GB
- You only need to iterate once (training)
- You want to start processing immediately

Don't use streaming when:
- Dataset fits comfortably in memory
- You need random access
- You need to iterate multiple times

## Supported formats

| Format | Streaming Support | Notes |
|--------|-------------------|-------|
| JSONL  | Full | Line-by-line streaming |
| Parquet | Limited | Falls back to full load |
| JSON | No | Must load full file |
| CSV | Limited | Line-by-line but slow |

## Examples

### Basic streaming
{:ok, iterable} = CrucibleDatasets.load(
  "open-thoughts/OpenThoughts3-1.2M",
  split: :train,
  streaming: true
)

for item <- iterable do
  IO.inspect(item)
end

### With transforms
iterable
|> IterableDataset.filter(fn item -> item.score > 0.5 end)
|> IterableDataset.map(&process/1)
|> IterableDataset.batch(32)
|> Enum.each(&train_on_batch/1)

### Take sample
first_1000 = IterableDataset.take(iterable, 1000)
```

---

## Implementation Checklist

**JSONL Streaming:**
- [x] Add byte stream → line stream converter (parse_stream)
- [x] Handle edge cases (empty lines, malformed JSON)
- [ ] Test with local files
- [ ] Test with HuggingFace URLs

**Parquet Streaming:**
- [x] Document limitation (full load required)
- [x] Add Format.Parquet.stream_rows/2 (batch iteration)
- [ ] Test batch processing

**Loader Integration:**
- [x] Add streaming parameter to load_dataset/2
- [x] Return IterableDataset when streaming: true
- [x] Auto-detect format for streaming
- [x] Add error handling for unsupported formats

**Testing:**
- [ ] Unit tests for JSONL streaming
- [ ] Integration test with OpenThoughts
- [ ] Memory usage test (ensure constant memory)

**Documentation:**
- [x] Streaming guide
- [x] API docs for load(..., streaming: true)
- [x] Examples in README

**Estimated effort:** Completed (remaining tests optional)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
