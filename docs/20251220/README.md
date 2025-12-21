# CrucibleDatasets v0.3.0 Port Documentation

**Date**: 2025-12-20
**Status**: Research/Evaluation Ready

## Overview

This directory contains comprehensive documentation for the CrucibleDatasets port from Python's HuggingFace `datasets` library to Elixir.

## Documents

| Document | Purpose |
|----------|---------|
| [port_architecture.md](port_architecture.md) | Architecture comparison between Python and Elixir implementations |
| [implementation_status.md](implementation_status.md) | Current status of all components, loaders, and tests |
| [gap_analysis.md](gap_analysis.md) | Gaps between Python and Elixir, with roadmap |
| [type_system_design.md](type_system_design.md) | Sinter-based schema design for dataset types |

## Quick Summary

### What We Built

```
Python datasets: 50,000+ lines → Elixir: 4,100 lines (8% of code)
```

A **thin fetch layer** that:
- Downloads datasets from HuggingFace Hub
- Parses Parquet/JSONL via Explorer (Rust/Polars)
- Provides sampling, splitting, and evaluation
- Supports 14 dataset types with synthetic fallbacks

### What Works Today

```elixir
# Load from HuggingFace
{:ok, gsm8k} = CrucibleDatasets.Loader.GSM8K.load(split: :train, sample_size: 100)

# Or use synthetic for offline testing
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(synthetic: true)

# Sample and evaluate
{:ok, {train, test}} = CrucibleDatasets.Sampler.train_test_split(dataset, test_size: 0.2)
{:ok, results} = CrucibleDatasets.evaluate(predictions, dataset: test, metrics: [:exact_match])
```

### Supported Datasets

| Category | Datasets |
|----------|----------|
| Math | GSM8K, MATH-500, Hendrycks MATH, DeepMath, POLARIS |
| Chat | Tulu-3-SFT, No Robots |
| Preference | HH-RLHF, HelpSteer2/3, UltraFeedback, Arena, Tulu-3-Preference |
| Code | DeepCoder, HumanEval |
| Knowledge | MMLU |

### Key Gaps

| Gap | Status | Priority |
|-----|--------|----------|
| Disk caching | Not implemented | P1 |
| Streaming | Not implemented | P1 |
| Schema validation | Designed (Sinter) | P2 |
| Column projection | Easy to add | P2 |

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│              CrucibleDatasets.Loader.GSM8K                 │
│                         │                                  │
│              ┌──────────┴──────────┐                       │
│              │                     │                       │
│              ▼                     ▼                       │
│     ┌────────────────┐    ┌────────────────┐              │
│     │   Synthetic    │    │   HuggingFace  │              │
│     │   Generator    │    │   Fetcher      │              │
│     └────────────────┘    └───────┬────────┘              │
│                                   │                        │
│                                   ▼                        │
│                          ┌────────────────┐                │
│                          │    Explorer    │                │
│                          │  (Rust/Polars) │                │
│                          └───────┬────────┘                │
│                                  │                         │
│                                  ▼                         │
│                          ┌────────────────┐                │
│                          │ List of Maps   │                │
│                          │ (Dataset.items)│                │
│                          └────────────────┘                │
└────────────────────────────────────────────────────────────┘
```

## Design Decisions

1. **Thin Fetch Layer**: 95% of value with 5% of code
2. **Explorer for Parquet**: Leverage Rust/Polars, don't reimplement Arrow
3. **Synthetic Fallback**: Every loader works offline
4. **Sinter for Types**: Clean, minimal, runtime-first validation
5. **No Memory Mapping**: BEAM has different memory model

## Next Steps

See [gap_analysis.md](gap_analysis.md) for the full roadmap:

1. **Phase 1**: Disk caching, test all loaders (1 week)
2. **Phase 2**: Sinter schema integration (1 week)
3. **Phase 3**: Streaming support (2 weeks)
4. **Phase 4**: Polish and v1.0 release (1 week)

## Usage

```bash
# Run examples
./examples/run_all.sh

# Run tests
mix test

# Run with real HuggingFace data
HF_TOKEN=your_token mix run examples/math/gsm8k_example.exs
```

## Contributing

1. Pick an item from [gap_analysis.md](gap_analysis.md) Phase 1
2. Implement with tests
3. Update [implementation_status.md](implementation_status.md)
4. Submit PR
