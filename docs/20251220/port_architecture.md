# CrucibleDatasets Port Architecture

**Date**: 2025-12-20
**Status**: v0.3.0 - Thin Fetch Layer Complete

## Architecture Comparison

### Python `datasets` Library (Full Stack)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        load_dataset("gsm8k")                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  load.py (1,576 lines)                                                  │
│  ├─ Resolve dataset name → HuggingFace Hub or local                     │
│  ├─ Find builder class (Parquet, JSON, CSV, etc.)                       │
│  ├─ Load/create BuilderConfig                                           │
│  └─ Orchestrate download → build → cache pipeline                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  builder.py (1,896 lines)                                               │
│  ├─ DatasetBuilder base class                                           │
│  ├─ GeneratorBasedBuilder (yields examples)                             │
│  ├─ ArrowBasedBuilder (yields Arrow tables)                             │
│  ├─ Split generation and management                                     │
│  └─ Fingerprinting for cache invalidation                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  download/ (650 lines)                                                  │
│  ├─ DownloadManager - coordinate downloads                              │
│  ├─ StreamingDownloadManager - lazy downloads                           │
│  └─ Caching, checksums, extraction                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  packaged_modules/parquet/parquet.py (190 lines)                        │
│  ├─ ParquetConfig (columns, filters, batch_size)                        │
│  ├─ Schema inference from Parquet metadata                              │
│  ├─ Row group iteration with predicate pushdown                         │
│  └─ Batch yielding with PyArrow                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  table.py (2,385 lines)                                                 │
│  ├─ InMemoryTable, MemoryMappedTable, ConcatenationTable                │
│  ├─ PyArrow table wrappers with 283+ pa.* calls                         │
│  ├─ Slice, filter, map, cast operations                                 │
│  └─ Memory-mapped disk access                                           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  arrow_dataset.py (6,836 lines) - THE BEAST                             │
│  ├─ Dataset class - main user-facing API                                │
│  ├─ map(), filter(), select(), shuffle(), etc.                          │
│  ├─ Batched processing with Arrow                                       │
│  ├─ Format conversion (torch, tf, numpy, pandas)                        │
│  └─ Caching and fingerprinting                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  features/features.py (2,330 lines)                                     │
│  ├─ Value, ClassLabel, Sequence, Audio, Image, etc.                     │
│  ├─ Arrow schema ↔ Features conversion                                  │
│  ├─ Type casting and coercion                                           │
│  └─ Nested structure handling                                           │
└─────────────────────────────────────────────────────────────────────────┘

Total: ~26,000+ lines Python + PyArrow C++ (500K+ lines)
```

### Elixir CrucibleDatasets (Thin Fetch Layer)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     CrucibleDatasets.Loader.GSM8K.load()                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Loader.GSM8K (283 lines)                                               │
│  ├─ load(opts) - entry point                                            │
│  ├─ Synthetic fallback for offline testing                              │
│  ├─ HuggingFace.fetch() for real data                                   │
│  └─ parse_huggingface_data() - transform to our format                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Fetcher.HuggingFace (463 lines)                                        │
│  ├─ list_files() - API call to get repo contents                        │
│  ├─ download_file() - HTTP GET with redirects                           │
│  ├─ fetch() - orchestrate file discovery + download                     │
│  ├─ find_split_files() - match train/test patterns                      │
│  └─ parse_file() - Parquet/JSONL/JSON/CSV                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Explorer.DataFrame (Rust/Polars - external)                            │
│  ├─ from_parquet!() - parse Parquet file                                │
│  ├─ to_rows() - convert to list of maps                                 │
│  └─ (We don't use streaming, column projection, etc.)                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Dataset struct (simple)                                                │
│  ├─ name, version, items (list), metadata                               │
│  └─ No Arrow tables, no memory mapping                                  │
└─────────────────────────────────────────────────────────────────────────┘

Total: ~1,500 lines Elixir + Explorer (Rust)
```

## What Each Layer Does

### Python Layer Breakdown

| File | Lines | Key Responsibilities |
|------|-------|---------------------|
| `load.py` | 1,576 | Dataset resolution, config loading, pipeline orchestration |
| `builder.py` | 1,896 | Abstract builders, split generation, fingerprinting |
| `arrow_dataset.py` | 6,836 | Dataset class, all transformations, format conversion |
| `iterable_dataset.py` | 4,714 | Streaming/lazy loading, on-the-fly processing |
| `dataset_dict.py` | 2,852 | Multi-split handling, parallel operations |
| `table.py` | 2,385 | Arrow table wrappers, memory mapping |
| `features/features.py` | 2,330 | Type system, schema conversion |
| `data_files.py` | 814 | File pattern matching, discovery |
| `arrow_reader.py` | 620 | Arrow/Parquet file reading |
| `arrow_writer.py` | 722 | Arrow file writing, caching |
| `download/` | 650 | Download management, caching |
| `packaged_modules/` | 3,407 | Format-specific loaders |

### Elixir Layer Breakdown

| File | Lines | Key Responsibilities |
|------|-------|---------------------|
| `huggingface.ex` | 463 | HTTP fetching, URL patterns, file parsing |
| `gsm8k.ex` | 283 | GSM8K-specific loading, answer extraction |
| `math.ex` | ~200 | MATH-500, DeepMath, POLARIS loaders |
| `chat.ex` | ~200 | Tulu, No Robots loaders |
| `preference.ex` | ~250 | HH-RLHF, HelpSteer, UltraFeedback loaders |
| `code.ex` | ~150 | DeepCoder loader |
| `types/*.ex` | ~300 | Message, Conversation, Comparison types |
| `sampler.ex` | ~150 | shuffle, take, skip, filter, k_fold |
| `dataset.ex` | ~100 | Dataset struct and helpers |

## Feature Comparison Matrix

| Feature | Python `datasets` | Our Elixir Port | Gap |
|---------|------------------|-----------------|-----|
| **Data Loading** |
| Parquet parsing | PyArrow (C++ memory-mapped) | Explorer (Rust Polars) | Comparable |
| JSONL parsing | Built-in | Jason + String.split | Comparable |
| CSV parsing | pandas-style | Basic split | Minor |
| Arrow IPC | Full support | Not supported | Major |
| **Data Access** |
| Row iteration | Lazy, memory-mapped | Eager, in-memory | Major |
| Column projection | Predicate pushdown | Read all columns | Major |
| Row filtering | Pushed to file level | Post-load filter | Major |
| Batching | Configurable batch_size | All at once | Major |
| **Memory Management** |
| Memory mapping | Yes, zero-copy | No | Major |
| Streaming | True lazy iteration | Download all first | Major |
| Out-of-core | Handles TB datasets | Memory-limited | Major |
| **Caching** |
| Disk cache | Arrow format, fingerprinted | None | Major |
| Download cache | With checksums | None (re-downloads) | Major |
| Transform cache | Fingerprinted | None | Major |
| **Type System** |
| Schema inference | From Arrow/Parquet metadata | Read first row | Moderate |
| Type coercion | Complex Features system | Basic Elixir maps | Major |
| Nested types | Audio, Image, Sequence, etc. | Not supported | Major |
| **Transformations** |
| map() | Batched, cached, parallel | Enum.map (eager) | Moderate |
| filter() | Predicate pushdown | Enum.filter (eager) | Moderate |
| shuffle() | Efficient with indices | Full copy | Minor |
| select_columns() | Zero-copy projection | Not implemented | Moderate |
| **Splits** |
| Train/test/val | Full split management | Basic support | Minor |
| K-fold | Not built-in | Implemented | N/A (we have it) |
| Stratified | Not built-in | Implemented | N/A (we have it) |
| **Integration** |
| PyTorch DataLoader | Native | N/A | N/A |
| TensorFlow | Native | N/A | N/A |
| Nx tensors | N/A | Could add | Future |

## What We Actually Need vs. What We Have

### For Research/Evaluation Use Cases

| Need | Status | Notes |
|------|--------|-------|
| Load standard benchmarks | ✅ Done | GSM8K, MATH, Chat, Preference, Code |
| Sample datasets | ✅ Done | shuffle, take, skip, filter |
| Train/test splits | ✅ Done | train_test_split, k_fold |
| Evaluate predictions | ✅ Done | exact_match, F1, BLEU, ROUGE |
| Offline testing | ✅ Done | synthetic: true fallback |
| Basic type safety | 🔄 Designed | Sinter schemas (not yet implemented) |

### For Production/Large-Scale

| Need | Status | Notes |
|------|--------|-------|
| Stream 1M+ rows | ❌ Missing | Would need lazy iteration |
| Cache downloads | ❌ Missing | Re-downloads every time |
| Memory efficiency | ❌ Missing | Loads all into memory |
| Column projection | ❌ Missing | Reads all columns |
| Predicate pushdown | ❌ Missing | Filters after load |

## Code Size Comparison

```
Python datasets library:
├── Core files:         ~26,000 lines
├── Features/types:      ~4,200 lines
├── Packaged modules:    ~3,400 lines
├── Utils:               ~3,000 lines
├── Tests:              ~15,000 lines
└── Total:              ~50,000+ lines Python

Plus PyArrow C++ dependency: ~500,000+ lines

────────────────────────────────────────────

Elixir CrucibleDatasets:
├── Core files:          ~1,500 lines
├── Loaders:              ~800 lines
├── Types:                ~300 lines
├── Examples:             ~500 lines
├── Tests:               ~1,000 lines
└── Total:               ~4,100 lines Elixir

Plus Explorer (Rust/Polars): external dep
```

## Architectural Decisions

### Why Thin Fetch Layer?

1. **Elixir Strengths are Different**
   - Python: Data science, ML pipelines, notebooks
   - Elixir: Concurrent systems, fault tolerance, distributed
   - We don't need Python's data science machinery

2. **Explorer Handles Heavy Lifting**
   - Polars/Rust for Parquet parsing
   - Already optimized, battle-tested
   - No need to reimplement Arrow

3. **Research Focus**
   - Evaluation workflows, not training
   - Reasonable dataset sizes (<1M rows)
   - Emphasis on correctness over throughput

4. **Pragmatic Porting**
   - 1,500 lines vs 50,000 lines
   - 95% of use cases with 5% of code
   - Can extend when needed

### What We Deliberately Skipped

| Python Feature | Why Skipped | Alternative |
|----------------|-------------|-------------|
| Arrow memory mapping | Elixir isn't memory-optimized like Python/C++ | Load smaller samples |
| Streaming iteration | BEAM has different memory model | Use sample_size option |
| Transform caching | Less critical for eval workflows | Re-run transforms |
| Format conversion | Don't need PyTorch/TF tensors | Use Nx directly |
| Dataset builders | Over-engineered for our needs | Simple load functions |
| Fingerprinting | Overkill for research use | Trust user |

## Future Enhancement Paths

### If We Need Streaming (Phase 2)

```elixir
defmodule CrucibleDatasets.Stream do
  @doc "Lazy iteration over large datasets"
  def stream(repo_id, opts \\ []) do
    Stream.resource(
      fn -> init_parquet_reader(repo_id, opts) end,
      fn reader -> read_next_batch(reader) end,
      fn reader -> close_reader(reader) end
    )
  end
end
```

Would require:
- Row group-level reading in Explorer
- Streaming HTTP downloads
- ~500 additional lines

### If We Need Caching (Phase 2)

```elixir
defmodule CrucibleDatasets.Cache do
  @cache_dir "~/.crucible_datasets/cache"

  def cached_fetch(repo_id, opts) do
    cache_key = hash({repo_id, opts})
    cache_path = Path.join(@cache_dir, cache_key)

    if File.exists?(cache_path) do
      load_cached(cache_path)
    else
      data = HuggingFace.fetch(repo_id, opts)
      save_cached(cache_path, data)
      data
    end
  end
end
```

Would require:
- Cache directory management
- Serialization format (ETF or Parquet)
- Cache invalidation strategy
- ~300 additional lines

### If We Need Full Type System (Phase 2)

Already designed in `type_system_design.md`:
- Sinter-based schemas
- HuggingFace format adapters
- Registry pattern
- ~800 additional lines

## Summary

| Aspect | Python | Elixir | Ratio |
|--------|--------|--------|-------|
| Lines of code | 50,000+ | 4,100 | 12x smaller |
| Native deps | PyArrow (500K C++) | Explorer (Rust) | Similar |
| Memory model | Zero-copy, mapped | Eager, in-memory | Different |
| Primary use | Training pipelines | Eval research | Different |
| Complexity | Full ML framework | Thin fetch layer | Intentional |

**Bottom Line**: We built exactly what we need - a thin, working fetch layer that covers 95% of research/evaluation use cases with 5% of the code. The gaps are known and can be filled incrementally if needed.
