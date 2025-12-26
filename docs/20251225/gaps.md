# CrucibleDatasets - Gaps Analysis

**Version:** 0.5.1
**Analysis Date:** 2025-12-25

## Overview

This document identifies gaps, incomplete features, and areas for improvement in CrucibleDatasets.

---

## 1. Real Dataset Loading (CRITICAL)

### Current State
All dataset loaders (MMLU, HumanEval, GSM8K) generate **synthetic data** for demo purposes. They do not actually fetch from HuggingFace or GitHub.

### Evidence
- `lib/dataset_manager/loader/mmlu.ex` (Line 40-42):
  ```elixir
  # In production, this would fetch from HuggingFace:
  # url = "https://huggingface.co/datasets/cais/mmlu"
  # For now, generate synthetic data for testing
  ```
- `lib/dataset_manager/loader/human_eval.ex` (Line 17-19):
  ```elixir
  # In production, would fetch from:
  # https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz
  ```
- `lib/dataset_manager/loader/gsm8k.ex` (Line 16-18):
  ```elixir
  # In production, would fetch from:
  # https://huggingface.co/datasets/gsm8k
  ```

### Impact
- Cannot run real evaluations on actual benchmarks
- Demo data limits research reproducibility
- Tests only validate against synthetic patterns

### Recommendation
1. Implement HTTP download for real datasets
2. Add Parquet support (explore library)
3. Consider `hf_hub` integration (was removed in v0.5.0 due to complexity)
4. Provide offline dataset bundles as alternative

---

## 2. Missing Dataset Loaders

### Datasets Not Yet Implemented
Based on common ML benchmarks and crucible_train/tinkex_cookbook needs:

| Dataset | Domain | Priority | Notes |
|---------|--------|----------|-------|
| TruthfulQA | Truthfulness | High | Common safety benchmark |
| MATH | Math reasoning | High | More complex than GSM8K |
| HellaSwag | Commonsense | Medium | Common LLM benchmark |
| WinoGrande | Commonsense | Medium | Pronoun resolution |
| ARC | Science QA | Medium | Elementary/Challenge splits |
| BIG-Bench | Multi-task | Low | Very large, modular |
| NoRobots | Instruction | High | Used by tinkex_cookbook |
| SciFact | Scientific | Medium | Used by cns_crucible |
| MBPP | Code | Medium | Alternative to HumanEval |

### Integration Gap
- `tinkex_cookbook` uses `NoRobots` dataset but crucible_datasets doesn't provide a loader
- Should align dataset offerings with training recipes

---

## 3. Credo Not in Dependencies

### Current State
Mix.exs does not include Credo in dev dependencies:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.3"},
    {:crucible_ir, "~> 0.1.1"},
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    # Missing: {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  ]
end
```

### Impact
Cannot run `mix credo --strict` for code quality checks.

### Recommendation
Add Credo to dependencies:
```elixir
{:credo, "~> 1.7", only: [:dev, :test], runtime: false}
```

---

## 4. Application Module Issues

### Current State
`lib/dataset_manager/application.ex` starts an empty supervisor:

```elixir
def start(_type, _args) do
  children = [
    # Starts a worker by calling: CrucibleDatasets.Worker.start_link(arg)
    # {CrucibleDatasets.Worker, arg}
  ]
  opts = [strategy: :one_for_one, name: CrucibleDatasets.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Impact
- Application module not referenced in mix.exs (no `mod:` option)
- Unused supervision tree

### Recommendation
Either:
1. Remove Application module entirely (no processes needed)
2. Add to mix.exs if supervision is intended

---

## 5. Cache Eviction Not Implemented

### Current State
`lib/dataset_manager/cache.ex` (Lines 178-181):

```elixir
defp evict_oldest_datasets(_size_to_free) do
  # Simple eviction: remove oldest datasets based on modified time
  # In a real implementation, this would be more sophisticated
  :ok
end
```

### Impact
Cache can grow unbounded up to 10GB limit but actual eviction is a no-op.

### Recommendation
Implement LRU or time-based eviction:
1. Track last access time per dataset
2. Sort by access time
3. Remove oldest until under limit

---

## 6. Missing Telemetry Events

### Current State
Telemetry dependency exists but no events are emitted:

```elixir
{:telemetry, "~> 1.3"}
```

No `:telemetry.execute/3` calls found in any module.

### Impact
Cannot observe dataset loading, evaluation timing, cache hits/misses.

### Recommendation
Add telemetry events for:
- `[:crucible_datasets, :load, :start/:stop/:exception]`
- `[:crucible_datasets, :evaluate, :start/:stop/:exception]`
- `[:crucible_datasets, :cache, :hit/:miss]`
- `[:crucible_datasets, :export, :start/:stop]`

---

## 7. Limited Error Handling

### Current State
Many functions return tuples but don't wrap errors consistently:

Example from `lib/dataset_manager/loader.ex`:
```elixir
defp load_custom(_name, _source, _opts) do
  {:error, :unsupported_source}
end
```

### Issues
- Error atoms lack context (`:unsupported_source` vs `{:unsupported_source, source_type}`)
- No structured error types
- File.read errors not consistently wrapped

### Recommendation
Create structured error module:
```elixir
defmodule CrucibleDatasets.Error do
  defexception [:type, :message, :context]
end
```

---

## 8. No Streaming Support

### Current State
All datasets load completely into memory via `Dataset.items` list.

### Impact
- Cannot handle datasets larger than available memory
- No lazy evaluation for large benchmarks

### Recommendation
Add IterableDataset (was in v0.4.x, removed):
- Stream-based loading
- Lazy transformations
- Batching support

---

## 9. Missing Code Execution for HumanEval

### Current State
HumanEval loader provides test cases but no way to execute them:

```elixir
expected: generate_solution(name)  # Just returns code string
```

### Impact
Cannot actually validate code generation correctness.

### Recommendation
Add code execution adapter:
- Sandboxed Python execution
- Test case runner
- Pass/fail scoring

---

## 10. DatasetRef Split Not Used

### Current State
`CrucibleIR.DatasetRef` has a `:split` field but loader ignores it:

```elixir
def load(%DatasetRef{} = ref, _opts) do
  opts = ref.options || []
  load(ref.name, opts)  # ref.split not passed
end
```

### Impact
Cannot specify train/test/validation split via DatasetRef.

### Recommendation
Pass split to loader:
```elixir
def load(%DatasetRef{} = ref, _opts) do
  opts = Keyword.put(ref.options || [], :split, ref.split)
  load(ref.name, opts)
end
```

---

## 11. No Type Specifications for Item Structure

### Current State
Item structure defined but not enforced:

```elixir
@type item :: %{
  required(:id) => String.t(),
  required(:input) => input_type(),
  required(:expected) => expected_type(),
  optional(:metadata) => map()
}
```

This is a type spec only, not validated at runtime.

### Impact
Invalid items can enter the system.

### Recommendation
Add runtime validation in `Dataset.new/4` or use a struct.

---

## 12. CSV Parsing Limitations

### Current State
`lib/dataset_manager/loader/generic.ex` CSV parsing is naive:

```elixir
defp read_file(path, :csv) do
  [header | rows] = String.split(content, "\n", trim: true)
  keys = String.split(header, ",") |> Enum.map(&String.trim/1)
  records = Enum.map(rows, fn row ->
    values = String.split(row, ",") |> Enum.map(&String.trim/1)
    ...
  end)
end
```

### Issues
- No handling of quoted fields with commas
- No escape character support
- No multiline field support

### Recommendation
Use NimbleCSV or similar robust CSV parser.

---

## 13. Missing Batch Loading

### Current State
No way to load multiple datasets efficiently.

### Recommendation
Add batch operations:
```elixir
def load_all(dataset_names, opts \\ [])
def load_parallel(dataset_names, opts \\ [])
```

---

## 14. Documentation Gaps

### Missing Documentation
1. No hexdocs.pm link validation
2. No usage examples in module docs for some modules
3. CHANGELOG.md mentions features but no migration guides

### Recommendation
1. Add `@doc` examples to all public functions
2. Create migration guide for v0.4.x -> v0.5.x
3. Add architecture diagram to README

---

## 15. Test Coverage Gaps

### Areas Not Tested
1. Cache TTL expiration (hard to test with real time)
2. Large dataset handling (memory limits)
3. Concurrent access to cache
4. Error recovery scenarios
5. Custom metric functions with edge cases

### Recommendation
Add property-based tests for:
- Sampling invariants
- Evaluation metric properties
- Cache consistency

---

## Priority Summary

| Priority | Gap | Effort |
|----------|-----|--------|
| Critical | Real dataset loading | High |
| High | Add Credo dependency | Low |
| High | Telemetry events | Medium |
| High | NoRobots loader | Medium |
| Medium | Cache eviction | Medium |
| Medium | CSV parsing robustness | Low |
| Medium | DatasetRef split handling | Low |
| Low | Streaming support | High |
| Low | Code execution for HumanEval | High |
| Low | Batch loading | Medium |

---

## Compatibility Notes

### Deprecated Versions
- v0.4.0 and v0.4.1 are deprecated (HuggingFace Hub integration)
- v0.5.x reverts to v0.3.x codebase

### Breaking Changes from v0.4.x
- No `load_dataset/2` HuggingFace-style API
- No streaming support
- No DatasetDict
- No Features schema system
- No Parquet support
