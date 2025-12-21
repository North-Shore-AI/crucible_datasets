# CrucibleDatasets Gap Analysis & Roadmap

**Date**: 2025-12-20
**Version**: 0.3.0

## Executive Summary

CrucibleDatasets v0.3.0 is a **thin fetch layer** that provides 95% of research/evaluation functionality with 5% of the code compared to Python's `datasets` library. This document analyzes the gaps between our implementation and the full Python library, and provides a roadmap for addressing critical gaps.

## Gap Categories

### Category A: Intentionally Not Ported (Different Philosophy)

These features exist in Python but are **intentionally excluded** because:
- They solve problems we don't have in Elixir
- They add complexity without value for our use case
- Alternative solutions exist in the Elixir ecosystem

| Feature | Python Implementation | Why Not Ported |
|---------|----------------------|----------------|
| PyTorch DataLoader | `dataset.with_format("torch")` | Use Nx directly |
| TensorFlow conversion | `dataset.to_tf_dataset()` | Use Nx directly |
| Pandas conversion | `dataset.to_pandas()` | Use Explorer directly |
| Hub uploads | `dataset.push_to_hub()` | Not needed for eval |
| Dataset cards | `DatasetCard` class | Not needed for eval |
| Custom builders | `DatasetBuilder` subclassing | Simple load functions suffice |
| Fingerprinting | Cache invalidation hashes | Over-engineering for research |
| Multi-process map | `dataset.map(num_proc=4)` | BEAM handles concurrency |

### Category B: Missing but Low Priority

These would be nice to have but aren't blocking:

| Feature | Python Implementation | Impact | Effort |
|---------|----------------------|--------|--------|
| Arrow IPC format | `save_to_disk()` | Medium | High |
| Interleaved datasets | `interleave_datasets()` | Low | Medium |
| Dataset concatenation | `concatenate_datasets()` | Low | Low |
| Rename columns | `dataset.rename_column()` | Low | Low |
| Flatten nested | `dataset.flatten()` | Low | Medium |
| Dataset info | `dataset.info` | Low | Low |

### Category C: Missing and Important

These gaps affect production use and should be addressed:

| Gap | Python Lines | Impact | Effort | Priority |
|-----|--------------|--------|--------|----------|
| **Streaming** | 4,714 | Critical for large datasets | High | P1 |
| **Disk Caching** | ~1,000 | Critical for repeated use | Medium | P1 |
| **Schema Validation** | 2,330 | Important for data quality | Medium | P2 |
| **Column Projection** | ~500 | Important for wide datasets | Medium | P2 |
| **Filter Pushdown** | ~300 | Important for large datasets | Medium | P3 |
| **Error Recovery** | ~300 | Important for reliability | Low | P3 |

---

## Detailed Gap Analysis

### Gap 1: Streaming / Lazy Loading

**Python Behavior:**
```python
# Python: True lazy iteration - only loads what's needed
dataset = load_dataset("gsm8k", streaming=True)
for item in dataset:  # Loads one batch at a time
    process(item)
```

**Current Elixir Behavior:**
```elixir
# Elixir: Eager loading - downloads entire dataset
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load()
# All 8,500 items now in memory
```

**Impact:**
- Cannot handle datasets larger than available memory
- Slow startup for large datasets
- Wastes bandwidth if only need subset

**Proposed Solution:**
```elixir
defmodule CrucibleDatasets.Stream do
  @moduledoc "Lazy streaming for large datasets"

  def stream(loader, opts \\ []) do
    Stream.resource(
      fn -> init_stream(loader, opts) end,
      fn state -> fetch_next_batch(state) end,
      fn state -> cleanup(state) end
    )
  end

  defp init_stream(loader, opts) do
    # Get file list without downloading
    {:ok, files} = HuggingFace.list_files(loader.repo_id())
    %{files: files, current_file: 0, current_row: 0, opts: opts}
  end

  defp fetch_next_batch(%{files: files, current_file: idx} = state) do
    # Download and parse one file at a time
    file = Enum.at(files, idx)
    {:ok, rows} = HuggingFace.download_and_parse(file)
    batch = Enum.take(rows, state.opts[:batch_size] || 1000)
    {batch, %{state | current_file: idx + 1}}
  end
end

# Usage:
CrucibleDatasets.Stream.stream(:gsm8k)
|> Stream.take(100)
|> Enum.each(&process/1)
```

**Effort Estimate:** ~500 lines, 1-2 days

---

### Gap 2: Disk Caching

**Python Behavior:**
```python
# Python: Automatic caching with fingerprinting
dataset = load_dataset("gsm8k")  # Downloads first time
dataset = load_dataset("gsm8k")  # Loads from ~/.cache/huggingface
```

**Current Elixir Behavior:**
```elixir
# Elixir: Re-downloads every time
{:ok, dataset} = GSM8K.load()  # Downloads
{:ok, dataset} = GSM8K.load()  # Downloads again!
```

**Impact:**
- Slow repeated loads
- Wastes bandwidth
- Fails if network unavailable

**Proposed Solution:**
```elixir
defmodule CrucibleDatasets.DiskCache do
  @cache_dir Path.expand("~/.crucible_datasets/cache")

  def cached_load(loader, opts \\ []) do
    cache_key = compute_key(loader, opts)
    cache_path = Path.join(@cache_dir, cache_key)

    cond do
      File.exists?(cache_path) and not opts[:force_refresh] ->
        load_from_cache(cache_path)

      true ->
        {:ok, dataset} = loader.load(opts)
        save_to_cache(cache_path, dataset)
        {:ok, dataset}
    end
  end

  defp compute_key(loader, opts) do
    data = {loader, opts[:split], opts[:config]}
    :crypto.hash(:sha256, :erlang.term_to_binary(data))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp save_to_cache(path, dataset) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(dataset))
  end

  defp load_from_cache(path) do
    data = File.read!(path)
    {:ok, :erlang.binary_to_term(data)}
  end
end
```

**Effort Estimate:** ~200 lines, 0.5 days

---

### Gap 3: Schema Validation (Sinter Integration)

**Python Behavior:**
```python
# Python: Automatic schema from Arrow
dataset.features
# {'question': Value(dtype='string'),
#  'answer': Value(dtype='string')}

# Enforced on access
dataset[0]['question']  # Guaranteed to be string
```

**Current Elixir Behavior:**
```elixir
# Elixir: Raw maps, no validation
item = hd(dataset.items)
item.input.question  # Could be anything
```

**Impact:**
- No type safety
- Silent data corruption
- Harder debugging

**Proposed Solution:**

See `type_system_design.md` for full design. Key integration:

```elixir
defmodule CrucibleDatasets.Loader.GSM8K do
  alias CrucibleDatasets.Schema.{Registry, Adapters}

  def load(opts \\ []) do
    validate = Keyword.get(opts, :validate, false)

    {:ok, raw_items} = fetch_data(opts)

    items = Enum.map(raw_items, fn raw ->
      item = Adapters.from_gsm8k(raw)

      if validate do
        {:ok, validated} = Registry.validate(:math_item, item)
        validated
      else
        item
      end
    end)

    {:ok, %Dataset{items: items, ...}}
  end
end

# Usage:
{:ok, dataset} = GSM8K.load(validate: true)  # Schema-validated
{:ok, dataset} = GSM8K.load()                 # Raw maps (faster)
```

**Effort Estimate:** ~800 lines, 2-3 days (schemas already designed)

---

### Gap 4: Column Projection

**Python Behavior:**
```python
# Python: Only reads requested columns from Parquet
dataset = load_dataset("gsm8k", columns=["question"])
# answer column never loaded from disk
```

**Current Elixir Behavior:**
```elixir
# Elixir: Reads all columns, discards unwanted
{:ok, dataset} = GSM8K.load()
# Both question and answer loaded
```

**Impact:**
- Slower for wide datasets
- More memory usage
- More network transfer

**Proposed Solution:**
```elixir
defmodule CrucibleDatasets.Fetcher.HuggingFace do
  def fetch(repo_id, opts \\ []) do
    columns = Keyword.get(opts, :columns)

    # ... download parquet file ...

    df = if columns do
      Explorer.DataFrame.from_parquet!(path, columns: columns)
    else
      Explorer.DataFrame.from_parquet!(path)
    end

    Explorer.DataFrame.to_rows(df)
  end
end

# Usage:
{:ok, dataset} = GSM8K.load(columns: ["question"])
```

**Effort Estimate:** ~50 lines, 0.5 days (Explorer already supports this)

---

### Gap 5: Filter Pushdown

**Python Behavior:**
```python
# Python: Filter pushed to Parquet row group level
dataset = load_dataset("gsm8k", filters=[("level", "=", "hard")])
# Only hard problems loaded from disk
```

**Current Elixir Behavior:**
```elixir
# Elixir: Load all, then filter
{:ok, dataset} = GSM8K.load()
{:ok, hard} = Sampler.filter(dataset, fn i -> i.metadata.level == "hard" end)
# All problems loaded, then filtered
```

**Impact:**
- Slower for selective queries
- More memory for filtered results

**Proposed Solution:**
```elixir
defmodule CrucibleDatasets.Fetcher.HuggingFace do
  def fetch(repo_id, opts \\ []) do
    filters = Keyword.get(opts, :filters)

    # Explorer/Polars supports predicate pushdown
    df = Explorer.DataFrame.from_parquet!(path)

    df = if filters do
      apply_filters(df, filters)
    else
      df
    end

    Explorer.DataFrame.to_rows(df)
  end

  defp apply_filters(df, filters) do
    Enum.reduce(filters, df, fn {col, op, val}, df ->
      case op do
        "=" -> Explorer.DataFrame.filter(df, col == ^val)
        ">" -> Explorer.DataFrame.filter(df, col > ^val)
        # etc.
      end
    end)
  end
end
```

**Effort Estimate:** ~100 lines, 0.5 days

---

## Roadmap

### Phase 1: Production Essentials (1 week)

| Task | Priority | Effort | Owner |
|------|----------|--------|-------|
| Disk caching | P1 | 0.5 days | |
| Column projection | P2 | 0.5 days | |
| Test all loaders with real HF data | P1 | 1 day | |
| Integration test suite | P1 | 1 day | |

**Deliverable:** v0.3.1 - Production-ready for moderate datasets

### Phase 2: Type Safety (1 week)

| Task | Priority | Effort | Owner |
|------|----------|--------|-------|
| Implement Sinter schemas | P2 | 2 days | |
| HuggingFace format adapters | P2 | 1 day | |
| Schema registry | P2 | 0.5 days | |
| Validation integration | P2 | 0.5 days | |

**Deliverable:** v0.4.0 - Type-safe dataset loading

### Phase 3: Scale (2 weeks)

| Task | Priority | Effort | Owner |
|------|----------|--------|-------|
| Streaming implementation | P1 | 2 days | |
| Filter pushdown | P3 | 0.5 days | |
| Memory optimization | P3 | 1 day | |
| Large dataset testing | P2 | 1 day | |

**Deliverable:** v0.5.0 - Large dataset support

### Phase 4: Polish (1 week)

| Task | Priority | Effort | Owner |
|------|----------|--------|-------|
| Error recovery | P3 | 1 day | |
| Progress reporting | P3 | 0.5 days | |
| Documentation | P2 | 1 day | |
| Performance benchmarks | P3 | 0.5 days | |

**Deliverable:** v1.0.0 - Production release

---

## Comparison Summary

| Metric | Python `datasets` | Elixir v0.3.0 | Elixir v1.0 (target) |
|--------|------------------|---------------|----------------------|
| Lines of code | 50,000+ | 4,100 | ~6,000 |
| Datasets supported | 100,000+ | 14 + synthetic | 14 + extensible |
| Max dataset size | TB+ | ~100K rows | 1M+ rows |
| Memory efficiency | Excellent | Poor | Good |
| Cache support | Full | None | Disk cache |
| Type safety | Full | None | Sinter schemas |
| Streaming | Full | None | Basic |
| Primary use case | Training | Eval/Research | Eval/Research |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-20 | Thin fetch layer approach | 95% value with 5% code |
| 2025-12-20 | Skip Arrow memory mapping | Different BEAM memory model |
| 2025-12-20 | Skip format conversions | Use Nx/Explorer directly |
| 2025-12-20 | Choose Sinter over Exdantic | Minimal, runtime-first design |
| 2025-12-20 | Synthetic fallback for all loaders | Enables offline testing |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| HuggingFace API changes | Medium | High | Version lock, fallback patterns |
| Explorer Parquet bugs | Low | Medium | Test with real data |
| Memory issues with large datasets | High | Medium | Add streaming, document limits |
| Sinter integration complexity | Low | Low | Design already done |

---

## Success Criteria for v1.0

1. ✅ All 14 loaders work with real HuggingFace data
2. ⏳ Disk caching reduces repeated load time by 90%
3. ⏳ Sinter schemas validate all dataset types
4. ⏳ Can stream datasets up to 1M rows
5. ⏳ Full test coverage including integration tests
6. ⏳ Documentation covers all features
7. ⏳ Performance benchmarks published
