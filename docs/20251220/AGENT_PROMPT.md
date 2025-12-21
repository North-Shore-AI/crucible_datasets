# Agent Prompt: Complete crucible_datasets Port for tinkex_cookbook

**Working Directory:** `/home/home/p/g/North-Shore-AI/crucible_datasets`
**Execution Context:** Run from the crucible_datasets root directory

---

## Required Reading (DO THIS FIRST)

Before writing ANY code, you MUST read and understand:

1. **The Porting Plan (PRIMARY REFERENCE)**
   ```
   ./docs/20251220/PORTING_PLAN.md
   ```
   This contains the complete scope, timeline, API design, and file checklist.

2. **Gap Analysis from tinkex_cookbook**
   ```
   ../tinkex_cookbook/docs/20251220/18_DATASETS_GAP_ANALYSIS.md
   ../tinkex_cookbook/docs/20251220/19_CRUCIBLE_DATASETS_DEEP_DIVE.md
   ```
   These explain what's missing and what's already complete.

---

## Your Mission

Complete the `crucible_datasets` library to support ALL datasets required by `tinker-cookbook` for the `tinkex_cookbook` Elixir port.

### Success Criteria

1. **All 14 priority datasets load real data from HuggingFace**
2. **All existing tests pass**
3. **New tests written for every new module (TDD)**
4. **Working examples for each dataset in `examples/` directory**
5. **Documentation with usage examples**

---

## Phase 1: Deep Code Review

### 1.1 Review HuggingFace datasets Library (Python Reference)

Explore `./datasets/src/datasets/` to understand:

```bash
# Key files to read:
./datasets/src/datasets/load.py              # How load_dataset() works
./datasets/src/datasets/arrow_dataset.py     # Dataset class internals
./datasets/src/datasets/download/download_manager.py  # HTTP download patterns
./datasets/src/datasets/io/parquet.py        # Parquet loading
./datasets/src/datasets/io/json.py           # JSONL loading
./datasets/src/datasets/hub.py               # HuggingFace Hub API
```

Document:
- How does `load_dataset("repo/name", split="train")` resolve to actual files?
- What URL patterns does HuggingFace use for parquet/JSONL files?
- How is authentication handled (HF_TOKEN)?
- How are dataset configs/subsets handled?

### 1.2 Review Existing Elixir Code

Read ALL existing modules in `./lib/`:

```bash
# Core modules (COMPLETE - understand the patterns):
./lib/dataset_manager.ex                 # Main API facade
./lib/dataset_manager/dataset.ex         # Dataset struct
./lib/dataset_manager/cache.ex           # Caching system
./lib/dataset_manager/sampler.ex         # Sampling utilities
./lib/dataset_manager/evaluator.ex       # Evaluation orchestration
./lib/dataset_manager/evaluator/*.ex     # Individual evaluators

# Loader modules (INCOMPLETE - these need work):
./lib/dataset_manager/loader.ex          # Loader dispatcher
./lib/dataset_manager/loader/gsm8k.ex    # Parser exists, returns synthetic
./lib/dataset_manager/loader/mmlu.ex     # Parser exists, returns synthetic
./lib/dataset_manager/loader/human_eval.ex  # Parser exists, returns synthetic
```

Document:
- What patterns do existing modules follow?
- How does the Cache module work? (you MUST use it)
- How does the Sampler module work? (you MUST extend it)
- What do the existing parsers expect as input format?

### 1.3 Review Existing Tests

```bash
./test/dataset_manager_test.exs
./test/dataset_manager/*.exs
```

Understand the testing patterns used.

---

## Phase 2: Implementation (TDD Approach)

**CRITICAL: Write tests BEFORE implementation for each module.**

### 2.1 Core Infrastructure

#### Step 1: Update mix.exs

```elixir
# Add these dependencies:
{:req, "~> 0.5"},
{:explorer, "~> 0.10"}
```

#### Step 2: HuggingFace Fetcher (TDD)

**Write test first:** `test/dataset_manager/fetcher/huggingface_test.exs`

```elixir
defmodule CrucibleDatasets.Fetcher.HuggingFaceTest do
  use ExUnit.Case, async: true

  describe "fetch/2" do
    test "fetches GSM8K train split" do
      {:ok, data} = HuggingFace.fetch("openai/gsm8k", split: "train")
      assert is_list(data)
      assert length(data) > 1000  # GSM8K has 7.5K train examples

      first = hd(data)
      assert Map.has_key?(first, "question")
      assert Map.has_key?(first, "answer")
    end

    test "fetches dataset with config" do
      {:ok, data} = HuggingFace.fetch("EleutherAI/hendrycks_math",
                                       config: "algebra",
                                       split: "test")
      assert is_list(data)
      first = hd(data)
      assert Map.has_key?(first, "problem")
    end

    test "returns error for non-existent dataset" do
      {:error, reason} = HuggingFace.fetch("nonexistent/dataset")
      assert is_binary(reason)
    end
  end
end
```

**Then implement:** `lib/dataset_manager/fetcher/huggingface.ex`

#### Step 3: Parsers (TDD)

**Write tests first:**
- `test/dataset_manager/parser/parquet_test.exs`
- `test/dataset_manager/parser/jsonl_test.exs`

**Then implement:**
- `lib/dataset_manager/parser/parquet.ex`
- `lib/dataset_manager/parser/jsonl.ex`

### 2.2 Wire Existing Loaders

#### GSM8K (Template for all loaders)

**Update test:** `test/dataset_manager/loader/gsm8k_test.exs`

```elixir
defmodule CrucibleDatasets.Loader.GSM8KTest do
  use ExUnit.Case, async: false  # Uses network

  describe "load/1 with real data" do
    @tag :integration
    test "loads real GSM8K train data" do
      {:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :train)

      assert dataset.name == "gsm8k"
      assert length(dataset.items) > 7000

      first = hd(dataset.items)
      assert Map.has_key?(first.input, :question)
      assert is_number(first.expected) or is_nil(first.expected)
    end

    @tag :integration
    test "loads real GSM8K test data" do
      {:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :test)

      assert length(dataset.items) > 1000
    end

    test "extracts numerical answer correctly" do
      assert GSM8K.extract_numerical_answer("The answer is #### 42") == 42.0
      assert GSM8K.extract_numerical_answer("#### 1,234.56") == 1234.56
      assert GSM8K.extract_numerical_answer("no answer here") == nil
    end
  end
end
```

**Then update:** `lib/dataset_manager/loader/gsm8k.ex` to use real fetcher

### 2.3 New Dataset Loaders

For EACH dataset, follow this pattern:

1. **Write test file first**
2. **Run test (it will fail)**
3. **Implement loader**
4. **Run test (it should pass)**
5. **Create working example**

#### Required Datasets (14 total)

**Math Datasets (5):**
| Dataset | Test File | Loader File |
|---------|-----------|-------------|
| GSM8K | `test/loader/gsm8k_test.exs` | `lib/loader/gsm8k.ex` (UPDATE) |
| MATH-500 | `test/loader/math_test.exs` | `lib/loader/math.ex` (CREATE) |
| Hendrycks MATH | `test/loader/math_test.exs` | `lib/loader/math.ex` (CREATE) |
| DeepMath-103K | `test/loader/math_test.exs` | `lib/loader/math.ex` (CREATE) |
| POLARIS-53K | `test/loader/math_test.exs` | `lib/loader/math.ex` (CREATE) |

**Chat Datasets (2):**
| Dataset | Test File | Loader File |
|---------|-----------|-------------|
| Tulu-3-SFT | `test/loader/chat_test.exs` | `lib/loader/chat.ex` (CREATE) |
| No Robots | `test/loader/chat_test.exs` | `lib/loader/chat.ex` (CREATE) |

**Preference Datasets (6):**
| Dataset | Test File | Loader File |
|---------|-----------|-------------|
| HH-RLHF | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |
| HelpSteer3 | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |
| HelpSteer2 | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |
| UltraFeedback | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |
| Arena-140K | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |
| Tulu-3-Preference | `test/loader/preference_test.exs` | `lib/loader/preference.ex` (CREATE) |

**Code Datasets (1):**
| Dataset | Test File | Loader File |
|---------|-----------|-------------|
| DeepCoder | `test/loader/code_test.exs` | `lib/loader/code.ex` (CREATE) |

### 2.4 Type Definitions

**Write tests first:**
- `test/types/message_test.exs`
- `test/types/conversation_test.exs`
- `test/types/comparison_test.exs`

**Then implement:**
- `lib/dataset_manager/types/message.ex`
- `lib/dataset_manager/types/conversation.ex`
- `lib/dataset_manager/types/comparison.ex`

### 2.5 Sampler Extensions

**Update test:** `test/dataset_manager/sampler_test.exs`

Add tests for:
- `shuffle/2` with seed
- `take/2`
- `skip/2`

**Then update:** `lib/dataset_manager/sampler.ex`

---

## Phase 3: Working Examples

Create `examples/` directory with runnable examples for EACH dataset:

```
examples/
├── math/
│   ├── gsm8k_example.exs
│   ├── math500_example.exs
│   ├── hendrycks_math_example.exs
│   ├── deepmath_example.exs
│   └── polaris_example.exs
├── chat/
│   ├── tulu3_sft_example.exs
│   └── no_robots_example.exs
├── preference/
│   ├── hh_rlhf_example.exs
│   ├── helpsteer3_example.exs
│   ├── ultrafeedback_example.exs
│   └── arena_example.exs
└── code/
    └── deepcoder_example.exs
```

Each example should:
1. Load the dataset
2. Print sample items
3. Demonstrate common operations (shuffle, take, split)
4. Show how to access structured data (messages, comparisons)

**Example template:**

```elixir
# examples/math/gsm8k_example.exs
# Run with: mix run examples/math/gsm8k_example.exs

alias CrucibleDatasets.{Loader, Sampler}

IO.puts("Loading GSM8K dataset...")
{:ok, dataset} = Loader.GSM8K.load(split: :train)

IO.puts("Total items: #{length(dataset.items)}")
IO.puts("")

# Show first 3 examples
IO.puts("=== Sample Problems ===")
dataset.items
|> Enum.take(3)
|> Enum.each(fn item ->
  IO.puts("Question: #{item.input.question}")
  IO.puts("Answer: #{item.expected}")
  IO.puts("---")
end)

# Demonstrate sampling
IO.puts("\n=== Sampling Demo ===")
shuffled = Sampler.shuffle(dataset, seed: 42)
{train, test} = Sampler.train_test_split(shuffled, test_size: 1000)

IO.puts("Train size: #{length(train.items)}")
IO.puts("Test size: #{length(test.items)}")
```

---

## Phase 4: Integration Tests

Create `test/integration/cookbook_integration_test.exs`:

```elixir
defmodule CrucibleDatasets.CookbookIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: :timer.minutes(10)

  describe "math_rl recipe datasets" do
    test "can load all math datasets needed for math_rl" do
      # GSM8K
      {:ok, gsm8k} = CrucibleDatasets.load(:gsm8k, split: :train)
      assert length(gsm8k.items) > 7000

      # MATH-500
      {:ok, math500} = CrucibleDatasets.load(:math_500)
      assert length(math500.items) == 500

      # Hendrycks MATH (all configs)
      {:ok, hendrycks} = CrucibleDatasets.load(:hendrycks_math, split: :train)
      assert length(hendrycks.items) > 10000
    end
  end

  describe "chat_sl recipe datasets" do
    test "can load all chat datasets needed for chat_sl" do
      {:ok, tulu} = CrucibleDatasets.load(:tulu3_sft)
      assert length(tulu.items) > 100000

      # Verify message structure
      first = hd(tulu.items)
      assert %CrucibleDatasets.Types.Conversation{} = first.input.conversation
    end
  end

  describe "preference/dpo recipe datasets" do
    test "can load all preference datasets needed for DPO" do
      {:ok, hh_rlhf} = CrucibleDatasets.load(:hh_rlhf, split: :train)
      assert length(hh_rlhf.items) > 100000

      # Verify comparison structure
      first = hd(hh_rlhf.items)
      assert %CrucibleDatasets.Types.Comparison{} = first.input.comparison
      assert %CrucibleDatasets.Types.LabeledComparison{} = first.expected
    end
  end
end
```

---

## Validation Checklist

Before considering the port complete, verify:

### Tests
- [ ] `mix test` passes with no failures
- [ ] `mix test --only integration` passes (may be slow)
- [ ] All 14 datasets have loader tests
- [ ] All new modules have unit tests
- [ ] Type modules have property-based tests

### Examples
- [ ] All 12 example files in `examples/` run successfully
- [ ] Examples demonstrate real data loading
- [ ] Examples show common operations

### Documentation
- [ ] All public functions have @doc
- [ ] README updated with new capabilities
- [ ] CHANGELOG updated

### Code Quality
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] No compiler warnings

---

## Reference: HuggingFace URL Patterns

When implementing the fetcher, use these URL patterns:

```
# Dataset file listing API
https://huggingface.co/api/datasets/{repo_id}/tree/main/{config}

# Parquet file download
https://huggingface.co/datasets/{repo_id}/resolve/main/{config}/{split}-00000-of-00001.parquet

# For datasets with multiple shards:
https://huggingface.co/datasets/{repo_id}/resolve/main/data/{split}-00000-of-00005.parquet
https://huggingface.co/datasets/{repo_id}/resolve/main/data/{split}-00001-of-00005.parquet
# ... etc

# Authentication header
Authorization: Bearer {HF_TOKEN}
```

---

## Reference: Dataset Schemas

### GSM8K (JSONL)
```json
{"question": "...", "answer": "... #### 42"}
```

### MATH-500 / Hendrycks MATH (Parquet)
```
problem: string
solution: string (contains \boxed{answer})
level: string
type: string
```

### Tulu-3-SFT / No Robots (Parquet)
```
messages: list of {role: string, content: string}
source: string (optional)
```

### HH-RLHF (Parquet)
```
chosen: string ("Human: ... Assistant: ...")
rejected: string ("Human: ... Assistant: ...")
```

### HelpSteer3 (Parquet)
```
prompt: string
response_a: string
response_b: string
label: string ("A" | "B" | "Tie")
```

---

## Execution Order

1. Read all required documents
2. Explore `./datasets/` Python code to understand HuggingFace patterns
3. Read all existing `./lib/` Elixir code
4. Update `mix.exs` with new dependencies
5. Implement HuggingFace fetcher (TDD)
6. Implement parsers (TDD)
7. Wire GSM8K loader to real data (TDD)
8. Wire MMLU loader to real data (TDD)
9. Wire HumanEval loader to real data (TDD)
10. Implement Math loader (TDD)
11. Implement Chat loader (TDD)
12. Implement Preference loader (TDD)
13. Implement Code loader (TDD)
14. Implement Type modules (TDD)
15. Extend Sampler module (TDD)
16. Create all examples
17. Run full test suite
18. Fix any issues
19. Update documentation

---

**REMEMBER: TDD - Write tests FIRST, then implement. No exceptions.**
