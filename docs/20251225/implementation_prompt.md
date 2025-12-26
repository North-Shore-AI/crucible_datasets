# CrucibleDatasets Implementation Prompt

**Target:** Fresh agent implementing crucible_datasets improvements
**Date:** 2025-12-25
**Version:** 0.5.1

---

## Mission

You are implementing improvements to CrucibleDatasets, a dataset management library for AI evaluation research in Elixir. Your work enables ML training pipelines and evaluation workflows across the Crucible framework.

---

## Required Reading

Read these files completely before making any changes:

### Core Files (Read First)
```
/home/home/p/g/North-Shore-AI/crucible_datasets/mix.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/dataset.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader.ex
```

### Existing Loaders (Understand the Pattern)
```
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/mmlu.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/human_eval.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/gsm8k.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/generic.ex
```

### Evaluation System
```
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluator.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluator/exact_match.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluator/f1.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluator/bleu.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluator/rouge.ex
```

### Supporting Modules
```
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/cache.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/sampler.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/registry.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/result_store.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/exporter.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/memory_dataset.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/field_mapping.ex
/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/evaluation_result.ex
```

### Tests (Understand Testing Patterns)
```
/home/home/p/g/North-Shore-AI/crucible_datasets/test/dataset_manager_test.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/test/loader_generic_test.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/test/field_mapping_test.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/test/memory_dataset_test.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/test/evaluator_bleu_test.exs
/home/home/p/g/North-Shore-AI/crucible_datasets/test/evaluator_rouge_test.exs
```

### Documentation
```
/home/home/p/g/North-Shore-AI/crucible_datasets/README.md
/home/home/p/g/North-Shore-AI/crucible_datasets/CHANGELOG.md
/home/home/p/g/North-Shore-AI/crucible_datasets/docs/20251225/current_state.md
/home/home/p/g/North-Shore-AI/crucible_datasets/docs/20251225/gaps.md
```

### Integration Context (Understand How Datasets Are Used)
```
/home/home/p/g/North-Shore-AI/crucible_train/README.md
/home/home/p/g/North-Shore-AI/crucible_train/mix.exs
/home/home/p/g/North-Shore-AI/tinkex_cookbook/README.md
```

---

## Current Module Structure

### Main API (`lib/dataset_manager.ex`)
- Lines 1-195
- Entry point with delegates to submodules
- Key function: `load/2` (Line 62)

### Dataset Struct (`lib/dataset_manager/dataset.ex`)
- Lines 1-250
- `new/4` at Line 38
- `filter/2` at Line 127
- `sort/2,3` at Line 146
- `shuffle_choices/2` at Line 171
- `slice/2,3` at Lines 230, 241

### Loader (`lib/dataset_manager/loader.ex`)
- Lines 1-179
- `@dataset_sources` map at Lines 17-22
- `load/2` at Lines 51-87
- `fetch_and_parse/3` at Lines 124-138

### MMLU Loader (`lib/dataset_manager/loader/mmlu.ex`)
- Lines 1-146
- `@stem_subjects` at Lines 12-32
- `load/2` at Line 40 (generates synthetic data)
- `parse_csv/2` at Line 111

### Evaluator (`lib/dataset_manager/evaluator.ex`)
- Lines 1-223
- `evaluate/2` at Line 46
- `compute_metric/4` at Lines 158-209 (metric dispatch)

### Registry (`lib/dataset_manager/registry.ex`)
- Lines 1-375
- `@datasets` map at Lines 46-114
- Metadata for: `:mmlu`, `:mmlu_stem`, `:humaneval`, `:gsm8k`

---

## Integration with crucible_train

CrucibleTrain provides training infrastructure and expects datasets in this format:

### Required Dataset Structure
```elixir
%CrucibleDatasets.Dataset{
  name: "dataset_name",
  version: "1.0",
  items: [
    %{
      id: "unique_id",
      input: ...,       # String or structured (question + choices)
      expected: ...,    # String, integer, or map with :answer/:reasoning
      metadata: %{}
    }
  ],
  metadata: %{...}
}
```

### Training Loop Integration
- `CrucibleTrain.Supervised.Train` consumes datasets for supervised learning
- `CrucibleTrain.RL.Train` uses datasets for RL environments
- `CrucibleTrain.Renderers` transform dataset items into model inputs

### tinkex_cookbook Integration
- Uses `crucible_datasets` v0.5.1 for dataset operations
- References NoRobots dataset (not yet implemented in crucible_datasets)
- Relies on evaluation metrics for training validation

---

## New Dataset Loaders Needed

### Priority 1: NoRobots (Required by tinkex_cookbook)

Create `/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/no_robots.ex`:

```elixir
defmodule CrucibleDatasets.Loader.NoRobots do
  @moduledoc """
  NoRobots instruction-following dataset loader.

  NoRobots contains human-written instruction-response pairs
  for training instruction-following models.

  Source: https://huggingface.co/datasets/HuggingFaceH4/no_robots
  """

  alias CrucibleDatasets.Dataset

  @doc """
  Load NoRobots dataset.

  ## Options
    * `:split` - Dataset split (:train, :test) default: :train
    * `:sample_size` - Limit items (default: all)
  """
  def load(opts \\ []) do
    # Implementation needed:
    # 1. Download from HuggingFace (or use local cache)
    # 2. Parse JSONL format
    # 3. Map to Dataset struct with:
    #    - input: instruction text
    #    - expected: response text
    #    - metadata: category, source info
  end
end
```

Update `lib/dataset_manager/loader.ex` Lines 17-22:
```elixir
@dataset_sources %{
  mmlu: {:huggingface, "cais/mmlu", "all"},
  mmlu_stem: {:huggingface, "cais/mmlu", "stem"},
  humaneval: {:github, "openai/human-eval", "data/HumanEval.jsonl.gz"},
  gsm8k: {:huggingface, "gsm8k", "main"},
  no_robots: {:huggingface, "HuggingFaceH4/no_robots", "main"}  # ADD THIS
}
```

Update `lib/dataset_manager/loader.ex` `fetch_and_parse/3` (around Line 124):
```elixir
:no_robots ->
  NoRobots.load(opts)
```

Update `lib/dataset_manager/registry.ex` `@datasets` map (around Line 114):
```elixir
no_robots: %{
  name: :no_robots,
  loader: NoRobots,
  domain: "instruction_following",
  task_type: "text_generation",
  description: "Human-written instruction-response pairs for training instruction-following models",
  num_items: 9500,
  license: "Apache-2.0",
  source_url: "https://huggingface.co/datasets/HuggingFaceH4/no_robots",
  citation: "HuggingFace H4, 2023",
  languages: ["en"],
  difficulty: "medium",
  tags: ["instruction", "generation", "chat", "assistant"]
}
```

### Priority 2: TruthfulQA

Create `/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/truthful_qa.ex`:

```elixir
defmodule CrucibleDatasets.Loader.TruthfulQA do
  @moduledoc """
  TruthfulQA benchmark loader.

  Tests model truthfulness across 817 questions spanning 38 categories.
  """
end
```

### Priority 3: MATH

Create `/home/home/p/g/North-Shore-AI/crucible_datasets/lib/dataset_manager/loader/math.ex`:

```elixir
defmodule CrucibleDatasets.Loader.MATH do
  @moduledoc """
  MATH dataset loader.

  Competition-level mathematics problems with step-by-step solutions.
  """
end
```

---

## TDD Approach

### Step 1: Write Tests First

Before implementing any loader, create tests:

```elixir
# test/loader_no_robots_test.exs
defmodule CrucibleDatasets.Loader.NoRobotsTest do
  use ExUnit.Case

  alias CrucibleDatasets.Loader.NoRobots
  alias CrucibleDatasets.Dataset

  describe "load/1" do
    test "loads NoRobots dataset with defaults" do
      {:ok, dataset} = NoRobots.load()

      assert %Dataset{} = dataset
      assert dataset.name == "no_robots"
      assert is_list(dataset.items)
      assert length(dataset.items) > 0
    end

    test "respects sample_size option" do
      {:ok, dataset} = NoRobots.load(sample_size: 10)

      assert length(dataset.items) <= 10
    end

    test "items have required fields" do
      {:ok, dataset} = NoRobots.load(sample_size: 5)

      Enum.each(dataset.items, fn item ->
        assert Map.has_key?(item, :id)
        assert Map.has_key?(item, :input)
        assert Map.has_key?(item, :expected)
        assert is_binary(item.input)
        assert is_binary(item.expected)
      end)
    end

    test "items have metadata" do
      {:ok, dataset} = NoRobots.load(sample_size: 5)

      Enum.each(dataset.items, fn item ->
        assert Map.has_key?(item, :metadata)
        assert is_map(item.metadata)
      end)
    end
  end
end
```

### Step 2: Run Tests (Should Fail)

```bash
cd /home/home/p/g/North-Shore-AI/crucible_datasets
mix test test/loader_no_robots_test.exs
```

### Step 3: Implement to Pass Tests

### Step 4: Verify All Tests Pass

```bash
mix test
```

---

## Quality Requirements

### Before Committing, Ensure:

1. **No Compiler Warnings**
   ```bash
   mix compile --warnings-as-errors
   ```

2. **Dialyzer Clean**
   ```bash
   mix dialyzer
   ```
   Expected output: `done (passed successfully)`

3. **Credo Strict** (after adding dependency)
   ```bash
   mix credo --strict
   ```

   First, add to mix.exs deps:
   ```elixir
   {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
   ```

   Then:
   ```bash
   mix deps.get
   mix credo --strict
   ```

4. **All Tests Passing**
   ```bash
   mix test
   ```
   Expected: 142+ tests, 0 failures

5. **Update README.md** if adding new features

6. **Update CHANGELOG.md** with changes

---

## Additional Improvements

### Add Telemetry Events

In `lib/dataset_manager/loader.ex`, around Line 51:

```elixir
def load(dataset_or_ref, opts \\ [])

def load(%DatasetRef{} = ref, _opts) do
  :telemetry.span(
    [:crucible_datasets, :load],
    %{dataset: ref.name, source: :dataset_ref},
    fn ->
      opts = ref.options || []
      result = load(ref.name, opts)
      {result, %{}}
    end
  )
end
```

### Fix Cache Eviction

In `lib/dataset_manager/cache.ex`, replace Lines 178-182:

```elixir
defp evict_oldest_datasets(size_to_free) do
  case File.ls(@cache_dir) do
    {:ok, dirs} ->
      dirs
      |> Enum.map(fn dir ->
        path = Path.join(@cache_dir, dir)
        stat = File.stat!(path)
        {path, stat.mtime, get_dir_size(path)}
      end)
      |> Enum.sort_by(fn {_, mtime, _} -> mtime end)
      |> Enum.reduce_while(0, fn {path, _, size}, freed ->
        if freed >= size_to_free do
          {:halt, freed}
        else
          File.rm_rf(path)
          {:cont, freed + size}
        end
      end)
      :ok
    _ ->
      :ok
  end
end
```

### Add Credo to Dependencies

In `mix.exs`, update deps function (around Line 30):

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.3"},
    {:crucible_ir, "~> 0.1.1"},
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},  # ADD THIS
    {:ex_doc, "~> 0.38", only: :dev, runtime: false}
  ]
end
```

---

## Commit Message Template

When committing changes, use this format:

```
feat(datasets): Add NoRobots loader for instruction-following

- Implement NoRobots dataset loader for HuggingFace dataset
- Add to registry with metadata
- Update Loader dispatch
- Add comprehensive tests

Quality gates:
- 150 tests passing
- Zero compiler warnings
- Dialyzer clean
- Credo strict clean

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## File Checklist

When implementing a new dataset loader, modify these files:

| File | Change |
|------|--------|
| `lib/dataset_manager/loader/NEW_LOADER.ex` | Create new loader module |
| `lib/dataset_manager/loader.ex` | Add to `@dataset_sources`, update `fetch_and_parse/3` |
| `lib/dataset_manager/registry.ex` | Add metadata to `@datasets` |
| `test/loader_NEW_LOADER_test.exs` | Create test file |
| `README.md` | Document new dataset in Supported Datasets |
| `CHANGELOG.md` | Add to Unreleased section |

---

## Verification Commands

Run these after every change:

```bash
cd /home/home/p/g/North-Shore-AI/crucible_datasets

# Compile check
mix compile --warnings-as-errors

# Type check
mix dialyzer

# Tests
mix test

# Code style (after adding Credo)
mix credo --strict

# Documentation
mix docs
```

All must pass before committing.

---

## Questions to Clarify Before Implementation

1. Should NoRobots loader download real data or generate synthetic for now?
2. What HTTP client should be used? (req, finch, httpoison)
3. Should we add streaming support for large datasets?
4. Is Parquet support needed (requires explorer dependency)?

---

## Success Criteria

Implementation is complete when:

1. New loader(s) implemented and tested
2. Registry updated with metadata
3. All 142+ tests passing
4. Zero warnings, dialyzer clean
5. README.md updated
6. CHANGELOG.md updated
7. Credo dependency added and passing
