# PORTING PLAN: crucible_datasets for tinkex_cookbook

**Date:** 2025-12-20
**Status:** PLANNING COMPLETE
**Timeline:** 3-4 weeks
**Approach:** Complete crucible_datasets native implementation, not Python wrapper

---

## 1. Executive Summary

### Scope

Build a production-ready dataset loading and processing library in Elixir that:
- Fetches real data from HuggingFace Hub (20+ datasets)
- Supports all data formats used by tinker-cookbook (JSONL, Parquet, conversations, preferences)
- Integrates with existing crucible_datasets infrastructure (caching, sampling, evaluation)
- Provides native Elixir types for Messages, Conversations, and Comparisons

### Timeline: 3-4 Weeks

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Core Infrastructure | Week 1 | HTTP client, HuggingFace API, basic formats |
| Phase 2: Wire Existing Loaders | Week 1 | GSM8K, MMLU, HumanEval with real data |
| Phase 3: Cookbook Datasets | Weeks 2-3 | Math (5), Chat (2), Preference (6), Code (1) |
| Phase 4: Data Types | Week 3-4 | Message, Conversation, Comparison types, streaming |

### Approach: Complete Native Elixir (Not Python Wrapper)

**Why Native:**
- crucible_datasets is already 70% complete - caching, sampling, evaluation all work
- Parsers for GSM8K, MMLU, HumanEval exist but are never called (synthetic data returned)
- Only missing piece is HTTP fetching (Req was removed from dependencies)
- 3-4 weeks vs. permanent Python dependency

**What's Already Done:**
- `CrucibleDatasets.Cache` - TTL caching, versioning, manifests
- `CrucibleDatasets.Sampler` - random, stratified, k-fold, train/test split
- `CrucibleDatasets.Evaluator` - ExactMatch, F1, BLEU, ROUGE
- `CrucibleDatasets.ResultStore` - persistent result storage with querying
- `CrucibleDatasets.Exporter` - CSV, JSONL, Markdown, HTML output

---

## 2. HuggingFace datasets Library Analysis

### Key Modules (Reference: datasets/ subdirectory)

| Python Module | Purpose | Elixir Equivalent |
|---------------|---------|-------------------|
| `load.py` | Main `load_dataset()` function | `CrucibleDatasets.HuggingFace.load/2` |
| `arrow_dataset.py` | Dataset class with operations | `CrucibleDatasets.Dataset` (exists) |
| `io/parquet.py` | Parquet file reading | `Explorer.DataFrame.from_parquet/1` |
| `io/json.py` | JSONL file reading | `CrucibleDatasets.Fetcher.parse_jsonl/1` |
| `download/download_manager.py` | HTTP downloads with caching | `CrucibleDatasets.Fetcher.HuggingFace` |
| `hub.py` | HuggingFace Hub API client | `CrucibleDatasets.HuggingFace.API` |

### API Patterns to Mirror

```python
# Python HuggingFace patterns
dataset = load_dataset("openai/gsm8k", split="train")
dataset = load_dataset("EleutherAI/hendrycks_math", name="algebra", split="test")
dataset = load_dataset("Anthropic/hh-rlhf")  # Returns DatasetDict with multiple splits

# Operations used in tinker-cookbook
dataset.shuffle(seed=0)
dataset.take(1024)
dataset.skip(1024)
dataset.select(range(start, end))
dataset.filter(lambda x: condition)
concatenate_datasets([ds1, ds2, ds3])
```

### Data Formats

| Format | HuggingFace Handling | Elixir Strategy |
|--------|---------------------|-----------------|
| Parquet | Native via pyarrow | Explorer.DataFrame |
| JSONL | Native | Jason + Stream |
| Arrow | Native | Not needed (convert to maps) |
| Nested JSON | Automatic schema detection | Manual parsing per dataset |

---

## 3. Current crucible_datasets State

### What's Complete (Production-Ready)

```
lib/dataset_manager/
├── cache.ex                # TTL caching (200+ lines) - COMPLETE
├── dataset.ex              # Dataset struct (100+ lines) - COMPLETE
├── evaluator.ex            # Evaluation orchestration - COMPLETE
├── evaluator/
│   ├── exact_match.ex      # Multi-type comparison - COMPLETE
│   ├── f1.ex               # Token-level F1 - COMPLETE
│   ├── bleu.ex             # Full BLEU with smoothing - COMPLETE
│   └── rouge.ex            # ROUGE-1, ROUGE-2, ROUGE-L - COMPLETE
├── exporter.ex             # CSV, JSONL, MD, HTML (535 lines) - COMPLETE
├── registry.ex             # Dataset metadata - COMPLETE
├── result_store.ex         # Persistent storage (421 lines) - COMPLETE
└── sampler.ex              # Random, stratified, k-fold - COMPLETE
```

### What's Placeholder (Needs Implementation)

```
lib/dataset_manager/
├── loader.ex               # Unified loader - INCOMPLETE (dispatches to synthetic)
└── loader/
    ├── gsm8k.ex            # Parser EXISTS, returns SYNTHETIC - NEEDS WIRING
    ├── mmlu.ex             # Parser EXISTS, returns SYNTHETIC - NEEDS WIRING
    └── human_eval.ex       # Parser EXISTS, returns SYNTHETIC - NEEDS WIRING
```

### Example: GSM8K Loader (Current State)

```elixir
# CURRENT: Returns 10 hardcoded synthetic problems
def load(opts \\ []) do
  items = generate_sample_items(opts)  # <-- SYNTHETIC DATA
  # ...
end

# Parser EXISTS but is NEVER CALLED:
def parse_jsonl(content) do
  content
  |> String.split("\n", trim: true)
  |> Enum.map(&Jason.decode!/1)
  |> Enum.map(fn data ->
    %{
      id: "gsm8k_#{idx}",
      input: %{question: data["question"]},
      expected: extract_numerical_answer(data["answer"]),
      metadata: %{raw_answer: data["answer"]}
    }
  end)
end
```

### Dependencies (Current vs. Needed)

**Current mix.exs:**
```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.3"},
    {:crucible_ir, "~> 0.1.1"}
  ]
end
```

**Needs Adding:**
```elixir
{:req, "~> 0.5"},           # HTTP client (WAS REMOVED)
{:explorer, "~> 0.10"}      # DataFrames + Parquet
```

---

## 4. Datasets Required for tinker-cookbook

### Complete Dataset Inventory (20+ datasets)

#### Math Datasets (5) - HIGH PRIORITY

| Dataset | HuggingFace Repo ID | Format | Size | Splits |
|---------|---------------------|--------|------|--------|
| GSM8K | `openai/gsm8k` | JSONL | 8.5K | train, test |
| MATH-500 | `HuggingFaceH4/MATH-500` | Parquet | 500 | test |
| Hendrycks MATH | `EleutherAI/hendrycks_math` | Parquet | 12.5K | train, test (8 configs) |
| DeepMath-103K | `zwhe99/DeepMath-103K` | Parquet | 103K | train |
| POLARIS-53K | `POLARIS-Project/Polaris-Dataset-53K` | Parquet | 53K | train |

#### Chat/SFT Datasets (2) - HIGH PRIORITY

| Dataset | HuggingFace Repo ID | Format | Size | Splits |
|---------|---------------------|--------|------|--------|
| Tulu-3-SFT | `allenai/tulu-3-sft-mixture` | Parquet | 326K | train |
| No Robots | `HuggingFaceH4/no_robots` | Parquet | 10K | train, test |

#### Preference Datasets (6) - HIGH PRIORITY

| Dataset | HuggingFace Repo ID | Format | Size | Splits |
|---------|---------------------|--------|------|--------|
| HH-RLHF | `Anthropic/hh-rlhf` | Parquet | 170K | train, test |
| HelpSteer3 | `nvidia/HelpSteer3` | Parquet | 40K | train, validation |
| HelpSteer2 | `nvidia/HelpSteer2` | Parquet | 37K | train |
| UltraFeedback | `argilla/ultrafeedback-binarized-preferences` | Parquet | 61K | train |
| Arena-140K | `lmarena-ai/arena-human-preference-140k` | Parquet | 140K | train |
| Tulu-3-Preference | `allenai/llama-3.1-tulu-3-8b-preference-mixture` | Parquet | Large | train |

#### Code Datasets (1) - MEDIUM PRIORITY

| Dataset | HuggingFace Repo ID | Format | Configs |
|---------|---------------------|--------|---------|
| DeepCoder | `agentica-org/DeepCoder-Preview-Dataset` | Parquet | primeintellect, taco, lcbv5, codeforces |

#### Vision Datasets (4) - LOW PRIORITY (Optional)

| Dataset | HuggingFace Repo ID | Format | Size |
|---------|---------------------|--------|------|
| Caltech-101 | `dpdl-benchmark/caltech101` | Parquet+Images | 9K |
| Flowers-102 | `dpdl-benchmark/oxford_flowers102` | Parquet+Images | 8K |
| Oxford Pets | `dpdl-benchmark/oxford_iiit_pet` | Parquet+Images | 7K |
| Stanford Cars | `tanganke/stanford_cars` | Parquet+Images | 16K |

---

## 5. Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

#### 5.1.1 Add Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:req, "~> 0.5"},              # HTTP client
    {:explorer, "~> 0.10"},        # DataFrames + Parquet
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.3"},
    {:crucible_ir, "~> 0.1.1"}
  ]
end
```

#### 5.1.2 Create HuggingFace API Client

**New file:** `lib/dataset_manager/fetcher/huggingface.ex`

```elixir
defmodule CrucibleDatasets.Fetcher.HuggingFace do
  @moduledoc """
  HuggingFace Hub API client for dataset downloads.
  """

  @base_url "https://huggingface.co"
  @api_url "https://huggingface.co/api"

  def fetch(repo_id, opts \\ []) do
    split = Keyword.get(opts, :split, "train")
    config = Keyword.get(opts, :config, "default")
    token = Keyword.get(opts, :token) || System.get_env("HF_TOKEN")

    with {:ok, file_info} <- get_dataset_files(repo_id, config, split, token),
         {:ok, data} <- download_and_parse(file_info, token) do
      {:ok, data}
    end
  end

  defp get_dataset_files(repo_id, config, split, token) do
    url = "#{@api_url}/datasets/#{repo_id}/tree/main/#{config}"
    headers = if token, do: [{"Authorization", "Bearer #{token}"}], else: []

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: files}} ->
        matching = Enum.filter(files, &file_matches_split?(&1, split))
        {:ok, matching}
      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp download_and_parse(file_info, token) do
    # Download and parse based on file type
    # Parquet -> Explorer.DataFrame
    # JSONL -> Stream parse with Jason
  end
end
```

#### 5.1.3 Parquet and JSONL Parsers

**New file:** `lib/dataset_manager/parser/parquet.ex`

```elixir
defmodule CrucibleDatasets.Parser.Parquet do
  def parse(binary_data) do
    tmp_path = Path.join(System.tmp_dir!(), "hf_#{:erlang.unique_integer()}.parquet")
    File.write!(tmp_path, binary_data)

    df = Explorer.DataFrame.from_parquet!(tmp_path)
    File.rm!(tmp_path)

    Explorer.DataFrame.to_rows(df)
  end
end
```

**New file:** `lib/dataset_manager/parser/jsonl.ex`

```elixir
defmodule CrucibleDatasets.Parser.JSONL do
  def parse(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  def parse_stream(stream) do
    stream
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)
  end
end
```

### Phase 2: Wire Existing Loaders (Week 1)

#### 5.2.1 GSM8K - Template for All Loaders

```elixir
defmodule CrucibleDatasets.Loader.GSM8K do
  alias CrucibleDatasets.{Cache, Dataset, Fetcher.HuggingFace}

  @repo_id "openai/gsm8k"

  def load(opts \\ []) do
    split = Keyword.get(opts, :split, :train)
    cache_key = "gsm8k_#{split}"

    case Cache.get(cache_key) do
      {:ok, cached} ->
        {:ok, cached}
      {:error, :not_found} ->
        with {:ok, raw_data} <- HuggingFace.fetch(@repo_id, split: to_string(split)),
             items <- parse_items(raw_data) do
          dataset = Dataset.new("gsm8k", "1.0", items, metadata())
          Cache.put(cache_key, dataset)
          {:ok, dataset}
        end
    end
  end

  # Existing parser - NOW GETS CALLED
  defp parse_items(raw_data) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {row, idx} ->
      %{
        id: "gsm8k_#{idx}",
        input: %{question: row["question"]},
        expected: extract_numerical_answer(row["answer"]),
        metadata: %{raw_answer: row["answer"]}
      }
    end)
  end

  def extract_numerical_answer(answer_text) do
    case Regex.run(~r/####\s*([0-9,]+(?:\.[0-9]+)?)/, answer_text || "") do
      [_, number_str] ->
        number_str |> String.replace(",", "") |> String.to_float()
      _ ->
        nil
    end
  end
end
```

### Phase 3: Cookbook Datasets (Weeks 2-3)

#### New Loader Files

| File | Datasets | Priority |
|------|----------|----------|
| `lib/dataset_manager/loader/math.ex` | MATH-500, Hendrycks, DeepMath, POLARIS | HIGH |
| `lib/dataset_manager/loader/chat.ex` | Tulu-3-SFT, No Robots | HIGH |
| `lib/dataset_manager/loader/preference.ex` | HH-RLHF, HelpSteer2/3, UltraFeedback | HIGH |
| `lib/dataset_manager/loader/code.ex` | DeepCoder | MEDIUM |

### Phase 4: Data Types (Weeks 3-4)

#### Message and Conversation Types

**New file:** `lib/dataset_manager/types/message.ex`

```elixir
defmodule CrucibleDatasets.Types.Message do
  @type role :: :user | :assistant | :system
  @type t :: %__MODULE__{role: role(), content: String.t()}

  defstruct [:role, :content]

  def new(role, content) when is_atom(role) do
    %__MODULE__{role: role, content: content}
  end

  def new(role, content) when is_binary(role) do
    new(String.to_atom(role), content)
  end
end
```

**New file:** `lib/dataset_manager/types/conversation.ex`

```elixir
defmodule CrucibleDatasets.Types.Conversation do
  alias CrucibleDatasets.Types.Message

  @type t :: %__MODULE__{messages: [Message.t()]}

  defstruct messages: []

  def new(messages) when is_list(messages) do
    %__MODULE__{messages: messages}
  end
end
```

#### Comparison Types for Preference Data

**New file:** `lib/dataset_manager/types/comparison.ex`

```elixir
defmodule CrucibleDatasets.Types.Comparison do
  alias CrucibleDatasets.Types.Message

  @type t :: %__MODULE__{
    prompt_conversation: [Message.t()],
    completion_A: [Message.t()],
    completion_B: [Message.t()]
  }

  defstruct [:prompt_conversation, :completion_A, :completion_B]

  def new(prompt_conversation, completion_A, completion_B) do
    %__MODULE__{
      prompt_conversation: prompt_conversation,
      completion_A: completion_A,
      completion_B: completion_B
    }
  end
end

defmodule CrucibleDatasets.Types.LabeledComparison do
  alias CrucibleDatasets.Types.Comparison

  @type label :: :A | :B | :Tie
  @type t :: %__MODULE__{comparison: Comparison.t(), label: label()}

  defstruct [:comparison, :label]

  def new(%Comparison{} = comparison, label) when label in [:A, :B, :Tie] do
    %__MODULE__{comparison: comparison, label: label}
  end
end
```

---

## 6. API Design

### Proposed Elixir API

```elixir
# Main entry point - mirrors HuggingFace load_dataset()
CrucibleDatasets.load("openai/gsm8k", split: :train)
CrucibleDatasets.load("EleutherAI/hendrycks_math", config: "algebra", split: :test)

# Named loaders for cookbook datasets
CrucibleDatasets.load(:gsm8k, split: :train)
CrucibleDatasets.load(:math_500)
CrucibleDatasets.load(:tulu3_sft)
CrucibleDatasets.load(:hh_rlhf, split: :train)

# Dataset operations
dataset
|> CrucibleDatasets.shuffle(seed: 42)
|> CrucibleDatasets.take(1024)
|> CrucibleDatasets.skip(100)

# Train/test split (existing)
{train, test} = CrucibleDatasets.Sampler.train_test_split(dataset, test_size: 0.1)

# Streaming for large datasets
CrucibleDatasets.stream("open-thoughts/OpenThoughts3-1.2M")
|> Stream.map(&process_item/1)
|> Enum.take(10_000)

# Evaluation (existing)
CrucibleDatasets.Evaluator.evaluate(predictions, dataset, evaluator: :exact_match)
```

---

## 7. Integration with Existing Infrastructure

### Leverage Cache Module

```elixir
def load_gsm8k(opts) do
  cache_key = "gsm8k_#{opts[:split]}"

  case Cache.get(cache_key) do
    {:ok, cached} -> {:ok, cached}
    {:error, :not_found} ->
      {:ok, data} = fetch_from_huggingface(...)
      Cache.put(cache_key, data, ttl: :timer.hours(24))
      {:ok, data}
  end
end
```

### Leverage Sampler Module

| Python (datasets) | Elixir (Sampler) | Status |
|-------------------|------------------|--------|
| `dataset.shuffle(seed=0)` | `Sampler.shuffle(dataset, seed: 0)` | Needs wrapper |
| `dataset.take(N)` | `Sampler.take(dataset, N)` | Needs adding |
| `dataset.skip(N)` | `Sampler.skip(dataset, N)` | Needs adding |
| `train_test_split` | `Sampler.train_test_split/2` | EXISTS |
| `stratified_sample` | `Sampler.stratified/2` | EXISTS |
| `k_fold` | `Sampler.k_fold/2` | EXISTS |

### Leverage Evaluators

```elixir
# Exact match for math answers
CrucibleDatasets.Evaluator.evaluate(predictions, dataset,
  evaluator: CrucibleDatasets.Evaluator.ExactMatch)

# F1 for text generation
CrucibleDatasets.Evaluator.evaluate(predictions, dataset,
  evaluator: CrucibleDatasets.Evaluator.F1)
```

---

## 8. File-by-File Implementation Checklist

### Files to Modify

| File | Change | Effort | Priority |
|------|--------|--------|----------|
| `mix.exs` | Add {:req}, {:explorer} | 5 min | **HIGH** |
| `lib/dataset_manager.ex` | Add unified `load/2` function | 2 hrs | **HIGH** |
| `lib/dataset_manager/loader.ex` | Wire to HuggingFace fetcher | 2 hrs | **HIGH** |
| `lib/dataset_manager/loader/gsm8k.ex` | Connect parser to real fetch | 2 hrs | **HIGH** |
| `lib/dataset_manager/loader/mmlu.ex` | Connect parser to real fetch | 2 hrs | **HIGH** |
| `lib/dataset_manager/loader/human_eval.ex` | Connect parser to real fetch | 2 hrs | **HIGH** |
| `lib/dataset_manager/sampler.ex` | Add `take/2`, `skip/2`, `shuffle/2` | 1 hr | **HIGH** |

### Files to Create

| File | Purpose | Effort | Priority |
|------|---------|--------|----------|
| `lib/dataset_manager/fetcher/huggingface.ex` | HuggingFace API client | 1 day | **HIGH** |
| `lib/dataset_manager/parser/parquet.ex` | Parquet via Explorer | 4 hrs | **HIGH** |
| `lib/dataset_manager/parser/jsonl.ex` | JSONL streaming parser | 2 hrs | **HIGH** |
| `lib/dataset_manager/loader/math.ex` | Math datasets | 1 day | **HIGH** |
| `lib/dataset_manager/loader/chat.ex` | Chat datasets | 4 hrs | **HIGH** |
| `lib/dataset_manager/loader/preference.ex` | Preference datasets | 1 day | **HIGH** |
| `lib/dataset_manager/loader/code.ex` | DeepCoder | 4 hrs | MEDIUM |
| `lib/dataset_manager/types/message.ex` | Message struct | 2 hrs | **HIGH** |
| `lib/dataset_manager/types/conversation.ex` | Conversation struct | 2 hrs | **HIGH** |
| `lib/dataset_manager/types/comparison.ex` | Comparison types | 3 hrs | **HIGH** |
| `lib/dataset_manager/streaming.ex` | Large dataset streaming | 4 hrs | MEDIUM |

### Total Effort Estimate

| Category | Effort |
|----------|--------|
| Core Infrastructure (Req, HF API, parsers) | 3 days |
| Wire Existing Loaders | 1 day |
| New Dataset Loaders (14 datasets) | 5 days |
| Type Definitions | 1 day |
| Streaming Support | 0.5 days |
| Testing | 3 days |
| Documentation | 1 day |
| **Total** | **~15 working days (3 weeks)** |

---

## 9. Critical Path

```
Week 1:
├── Day 1-2: Add Req + Explorer, implement HuggingFace fetcher
├── Day 3: Implement Parquet + JSONL parsers
├── Day 4: Wire GSM8K, MMLU, HumanEval to real fetch
└── Day 5: Add take/skip/shuffle to Sampler

Week 2:
├── Day 1-2: Implement Math loader (5 datasets)
├── Day 3: Implement Chat loader (2 datasets)
├── Day 4-5: Implement Preference loader (6 datasets)
└── Buffer for issues

Week 3:
├── Day 1: Implement Code loader
├── Day 2: Implement Message/Conversation/Comparison types
├── Day 3: Streaming support
├── Day 4-5: Testing + documentation
└── Buffer for issues
```

---

**Document Status:** Complete
**Last Updated:** 2025-12-20
**Reference:** HuggingFace datasets library cloned at `datasets/`
