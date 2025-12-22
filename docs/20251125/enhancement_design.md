# CrucibleDatasets Enhancement Design Document

**Date:** 2025-11-25
**Version:** 0.1.0 → 0.2.0
**Author:** Claude Code Agent
**Status:** Design & Implementation

---

## Executive Summary

This document outlines a comprehensive enhancement plan for the CrucibleDatasets library, focusing on expanding evaluation capabilities, adding popular benchmark datasets, improving result persistence, and providing statistical comparison utilities. The enhancements maintain backward compatibility while significantly expanding the library's research utility.

---

## Current State Analysis

### Strengths
- Clean, unified API for dataset management
- Solid caching infrastructure
- Good test coverage (16/19 tests passing)
- Comprehensive documentation
- Extensible architecture with clear separation of concerns
- Support for 3 major benchmarks (MMLU, HumanEval, GSM8K)
- Two evaluation metrics (Exact Match, F1)

### Identified Gaps

#### 1. Limited Evaluation Metrics
- **Current:** Only Exact Match and F1 score
- **Missing:**
  - BLEU (for machine translation evaluation)
  - ROUGE (for summarization evaluation)
  - Pass@k (for code generation with multiple samples)
  - BERTScore (semantic similarity)
  - Perplexity (for language models)

#### 2. Limited Dataset Coverage
- **Current:** 3 datasets (MMLU, HumanEval, GSM8K)
- **Missing Popular Benchmarks:**
  - TruthfulQA (factuality evaluation)
  - HellaSwag (commonsense reasoning)
  - ARC (science questions)
  - RACE (reading comprehension)
  - BoolQ (yes/no questions)
  - DROP (discrete reasoning over paragraphs)

#### 3. No Result Persistence
- Evaluation results are transient
- No built-in way to track experiments over time
- No export to standard formats (CSV, JSON Lines)
- No comparison across evaluation runs

#### 4. Limited Statistical Analysis
- No built-in statistical significance testing
- No confidence intervals
- No bootstrap resampling
- No model comparison utilities

#### 5. Missing Quality-of-Life Features
- No result visualization helpers
- No leaderboard generation
- No automated reporting
- Limited metadata tracking

---

## Enhancement Design

### Phase 1: Additional Evaluation Metrics (High Priority)

#### 1.1 BLEU Score Metric

**Purpose:** Evaluate machine translation and text generation quality

**Implementation:**
```elixir
defmodule CrucibleDatasets.Evaluator.BLEU do
  @moduledoc """
  BLEU (Bilingual Evaluation Understudy) score computation.

  Measures n-gram precision with brevity penalty.
  Standard for machine translation evaluation.
  """

  @spec compute(String.t(), String.t() | [String.t()], keyword()) :: float()
  def compute(candidate, references, opts \\ [])

  # Features:
  # - N-gram precision (1-4 grams by default)
  # - Brevity penalty for short candidates
  # - Multiple reference support
  # - Smoothing options (add-epsilon, add-k)
end
```

**API:**
```elixir
{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:exact_match, :bleu],
  bleu_opts: [max_n: 4, smoothing: :add_epsilon]
)
```

**Testing:**
- Unit tests with known BLEU scores
- Edge cases (empty strings, single word, perfect match)
- Multiple reference handling
- Property-based tests for score bounds (0.0-1.0)

#### 1.2 ROUGE Score Metric

**Purpose:** Evaluate summarization quality

**Implementation:**
```elixir
defmodule CrucibleDatasets.Evaluator.ROUGE do
  @moduledoc """
  ROUGE (Recall-Oriented Understudy for Gisting Evaluation) scores.

  Supports ROUGE-N, ROUGE-L, and ROUGE-W variants.
  Standard for summarization evaluation.
  """

  @spec compute(String.t(), String.t() | [String.t()], keyword()) :: map()
  def compute(candidate, references, opts \\ [])

  # Variants:
  # - ROUGE-1: Unigram overlap
  # - ROUGE-2: Bigram overlap
  # - ROUGE-L: Longest common subsequence
  # - ROUGE-W: Weighted longest common subsequence
end
```

**API:**
```elixir
{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:rouge],
  rouge_opts: [variants: [:rouge1, :rouge2, :rougel]]
)

# Results include: rouge1, rouge2, rougel each with precision/recall/f1
```

#### 1.3 Pass@k Metric

**Purpose:** Evaluate code generation with multiple samples

**Implementation:**
```elixir
defmodule CrucibleDatasets.Evaluator.PassAtK do
  @moduledoc """
  Pass@k metric for code generation evaluation.

  Evaluates whether at least one of k generated solutions passes tests.
  Standard for HumanEval and similar code benchmarks.
  """

  @spec compute([String.t()], String.t(), keyword()) :: float()
  def compute(candidates, test_cases, opts \\ [])

  # Features:
  # - Execute code samples safely (sandboxed)
  # - Multiple k values (1, 5, 10, 100)
  # - Timeout handling
  # - Syntax error detection
  # - Test case execution
end
```

**API:**
```elixir
# For HumanEval-style datasets with multiple samples per problem
predictions = [
  %{id: "task_1", predicted: ["solution1", "solution2", "solution3"], ...}
]

{:ok, results} = CrucibleDatasets.evaluate(predictions,
  dataset: dataset,
  metrics: [:pass_at_k],
  pass_at_k_opts: [k_values: [1, 5, 10]]
)

# Results: %{pass_at_1: 0.45, pass_at_5: 0.78, pass_at_10: 0.89}
```

#### 1.4 Semantic Similarity Metric (Future Enhancement)

**Purpose:** Measure semantic equivalence beyond lexical overlap

**Note:** Requires embedding model integration - marked as future work
- BERTScore (requires BERT embeddings)
- Sentence-BERT similarity
- Would need integration with ML model serving

---

### Phase 2: Additional Dataset Loaders (High Priority)

#### 2.1 TruthfulQA Dataset

**Description:** Measures model truthfulness and resistance to generating falsehoods

**Implementation:**
```elixir
defmodule CrucibleDatasets.Loader.TruthfulQA do
  @moduledoc """
  TruthfulQA benchmark for evaluating factual accuracy.

  Contains 817 questions spanning 38 categories designed to test
  whether models generate truthful answers.
  """

  def load(opts \\ [])

  # Dataset structure:
  # - Question (string)
  # - Best answer (correct factual answer)
  # - Correct answers (list of acceptable answers)
  # - Incorrect answers (list of common misconceptions)
  # - Category (e.g., "Conspiracies", "Science", "Law")
end
```

**Schema:**
```elixir
%{
  id: "truthfulqa_001",
  input: %{
    question: "What happens if you crack your knuckles a lot?",
    category: "Health"
  },
  expected: %{
    best_answer: "Nothing in particular happens if you crack your knuckles a lot",
    correct_answers: [
      "Nothing in particular happens if you crack your knuckles a lot",
      "Cracking knuckles does not cause arthritis"
    ],
    incorrect_answers: [
      "You will get arthritis",
      "Your fingers will become larger"
    ]
  },
  metadata: %{
    category: "Health",
    source: "common_misconceptions"
  }
}
```

#### 2.2 HellaSwag Dataset

**Description:** Commonsense natural language inference benchmark

**Implementation:**
```elixir
defmodule CrucibleDatasets.Loader.HellaSwag do
  @moduledoc """
  HellaSwag benchmark for commonsense reasoning.

  Contains ~70K multiple choice questions about everyday scenarios.
  Models must select the most plausible continuation.
  """

  def load(opts \\ [])

  # Dataset structure:
  # - Context (partial scenario)
  # - Endings (4 possible continuations)
  # - Correct ending index
  # - Activity label
end
```

#### 2.3 ARC Dataset

**Description:** Science question dataset with two difficulty levels

**Implementation:**
```elixir
defmodule CrucibleDatasets.Loader.ARC do
  @moduledoc """
  ARC (AI2 Reasoning Challenge) science questions.

  Contains 7,787 science questions from standardized tests.
  Two subsets: ARC-Easy and ARC-Challenge.
  """

  def load(subset, opts \\ [])
  # subset: :arc_easy or :arc_challenge

  # Dataset structure:
  # - Question (string)
  # - Choices (list of 3-5 options)
  # - Answer key (correct option letter)
  # - Difficulty (easy/challenge)
end
```

#### 2.4 Unified Dataset Registry

**Purpose:** Centralized dataset management and discovery

**Implementation:**
```elixir
defmodule CrucibleDatasets.Registry do
  @moduledoc """
  Central registry of all available datasets with metadata.
  """

  @datasets %{
    # Existing
    mmlu: %{loader: MMLU, domain: "general_knowledge", ...},
    mmlu_stem: %{loader: MMLU, domain: "stem", ...},
    humaneval: %{loader: HumanEval, domain: "code", ...},
    gsm8k: %{loader: GSM8K, domain: "math", ...},

    # New
    truthfulqa: %{loader: TruthfulQA, domain: "factuality", ...},
    hellaswag: %{loader: HellaSwag, domain: "commonsense", ...},
    arc_easy: %{loader: ARC, domain: "science", subset: :easy, ...},
    arc_challenge: %{loader: ARC, domain: "science", subset: :challenge, ...}
  }

  def list_available(), do: Map.keys(@datasets)
  def get_metadata(name), do: Map.get(@datasets, name)
  def list_by_domain(domain)
end
```

---

### Phase 3: Result Persistence & Export (Medium Priority)

#### 3.1 Result Storage Backend

**Purpose:** Persist evaluation results for long-term tracking

**Implementation:**
```elixir
defmodule CrucibleDatasets.ResultStore do
  @moduledoc """
  Persistent storage for evaluation results.

  Stores results in ~/.elixir_ai_research/results/ with indexing.
  """

  @storage_dir Path.expand("~/.elixir_ai_research/results")

  @spec save(EvaluationResult.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def save(result, opts \\ [])

  @spec load(String.t()) :: {:ok, EvaluationResult.t()} | {:error, term()}
  def load(result_id)

  @spec query(keyword()) :: {:ok, [EvaluationResult.t()]}
  def query(filters \\ [])
  # Filters: model, dataset, date_range, min_accuracy, etc.

  @spec list_all() :: {:ok, [map()]}
  def list_all()

  @spec delete(String.t()) :: :ok
  def delete(result_id)
end
```

**Storage Structure:**
```
~/.elixir_ai_research/results/
├── index.json                    # Searchable index
├── 2025-11-25/
│   ├── gpt4_mmlu_stem_abc123.json
│   ├── claude_gsm8k_def456.json
│   └── ...
├── 2025-11-24/
│   └── ...
```

#### 3.2 Export Functionality

**Purpose:** Export results to standard formats

**Implementation:**
```elixir
defmodule CrucibleDatasets.Exporter do
  @moduledoc """
  Export evaluation results to various formats.
  """

  @spec to_csv(EvaluationResult.t() | [EvaluationResult.t()], Path.t()) :: :ok
  def to_csv(results, output_path)

  @spec to_jsonl(EvaluationResult.t() | [EvaluationResult.t()], Path.t()) :: :ok
  def to_jsonl(results, output_path)

  @spec to_markdown([EvaluationResult.t()], keyword()) :: String.t()
  def to_markdown(results, opts \\ [])
  # Options: include_details, sort_by, group_by

  @spec to_html([EvaluationResult.t()], keyword()) :: String.t()
  def to_html(results, opts \\ [])
  # Generate interactive HTML report
end
```

**API:**
```elixir
# Save result
{:ok, result_id} = CrucibleDatasets.ResultStore.save(result)

# Export to CSV
CrucibleDatasets.Exporter.to_csv(result, "results/experiment_1.csv")

# Generate markdown report
results = CrucibleDatasets.ResultStore.query(dataset: :mmlu_stem)
markdown = CrucibleDatasets.Exporter.to_markdown(results,
  sort_by: :accuracy,
  group_by: :model
)
```

---

### Phase 4: Statistical Analysis Utilities (Medium Priority)

#### 4.1 Statistical Comparison

**Purpose:** Compare model performance with statistical rigor

**Implementation:**
```elixir
defmodule CrucibleDatasets.Statistics do
  @moduledoc """
  Statistical analysis utilities for model comparison.
  """

  @spec compare([EvaluationResult.t()], keyword()) :: ComparisonResult.t()
  def compare(results, opts \\ [])

  @spec bootstrap_confidence_interval(EvaluationResult.t(), keyword()) :: {float(), float()}
  def bootstrap_confidence_interval(result, opts \\ [])
  # Options: confidence_level (default: 0.95), n_iterations (default: 10000)

  @spec mcnemar_test(EvaluationResult.t(), EvaluationResult.t()) :: TestResult.t()
  def mcnemar_test(result1, result2)
  # Tests if two models differ significantly

  @spec effect_size(EvaluationResult.t(), EvaluationResult.t()) :: float()
  def effect_size(result1, result2)
  # Cohen's d for accuracy difference
end

defmodule CrucibleDatasets.ComparisonResult do
  defstruct [
    :models,
    :rankings,
    :pairwise_comparisons,
    :statistical_tests,
    :confidence_intervals,
    :best_model,
    :metadata
  ]
end
```

**API:**
```elixir
results = [result_gpt4, result_claude, result_gemini]

{:ok, comparison} = CrucibleDatasets.Statistics.compare(results,
  test: :mcnemar,
  confidence_level: 0.95
)

IO.inspect(comparison.rankings)
# => [
#   %{model: "gpt4", accuracy: 0.89, rank: 1, ci: {0.87, 0.91}},
#   %{model: "claude", accuracy: 0.87, rank: 2, ci: {0.85, 0.89}},
#   %{model: "gemini", accuracy: 0.85, rank: 3, ci: {0.83, 0.87}}
# ]

IO.inspect(comparison.pairwise_comparisons)
# => %{
#   {"gpt4", "claude"} => %{p_value: 0.023, significant: true},
#   {"gpt4", "gemini"} => %{p_value: 0.001, significant: true},
#   {"claude", "gemini"} => %{p_value: 0.089, significant: false}
# }
```

#### 4.2 Leaderboard Generation

**Purpose:** Generate ranked comparison tables

**Implementation:**
```elixir
defmodule CrucibleDatasets.Leaderboard do
  @moduledoc """
  Generate leaderboards from evaluation results.
  """

  @spec generate([EvaluationResult.t()], keyword()) :: Leaderboard.t()
  def generate(results, opts \\ [])

  @spec to_markdown(Leaderboard.t()) :: String.t()
  def to_markdown(leaderboard)

  @spec to_html(Leaderboard.t()) :: String.t()
  def to_html(leaderboard)
end
```

**Output Example:**
```markdown
# MMLU STEM Leaderboard

| Rank | Model | Accuracy | Exact Match | F1 | Samples | Date |
|------|-------|----------|-------------|-----|---------|------|
| 1 | GPT-4 | 89.2% | 89.2% | 91.3% | 1000 | 2025-11-25 |
| 2 | Claude-3 | 87.5% | 87.5% | 89.8% | 1000 | 2025-11-25 |
| 3 | Gemini-Pro | 85.1% | 85.1% | 87.6% | 1000 | 2025-11-25 |
```

---

### Phase 5: Quality-of-Life Improvements (Low Priority)

#### 5.1 Progress Reporting

**Implementation:**
```elixir
defmodule CrucibleDatasets.ProgressReporter do
  @moduledoc """
  Real-time progress reporting for long evaluations.
  """

  # Uses Telemetry events for progress tracking
  def attach_progress_handler(callback)
end
```

#### 5.2 Dataset Statistics

**Implementation:**
```elixir
defmodule CrucibleDatasets.DatasetStats do
  @moduledoc """
  Generate statistics about datasets.
  """

  def analyze(dataset) do
    %{
      total_items: length(dataset.items),
      input_length_stats: %{mean: ..., median: ..., std: ...},
      output_length_stats: %{mean: ..., median: ..., std: ...},
      class_distribution: ...,
      difficulty_distribution: ...
    }
  end
end
```

---

## Implementation Plan

### Phase 1: Metrics (Priority 1)
1. ✓ Create `evaluator/bleu.ex`
2. ✓ Create `evaluator/rouge.ex`
3. ✓ Create `evaluator/pass_at_k.ex`
4. ✓ Write comprehensive tests
5. ✓ Update documentation

**Estimated Effort:** 4-6 hours
**Risk:** Low - straightforward implementations

### Phase 2: Datasets (Priority 1)
1. ✓ Create `loader/truthfulqa.ex`
2. ✓ Create `loader/hellaswag.ex`
3. ✓ Create `loader/arc.ex`
4. ✓ Create `registry.ex`
5. ✓ Write tests for each loader
6. ✓ Update documentation

**Estimated Effort:** 6-8 hours
**Risk:** Medium - need sample data generation

### Phase 3: Persistence (Priority 2)
1. ✓ Create `result_store.ex`
2. ✓ Create `exporter.ex`
3. ✓ Implement CSV, JSONL, Markdown exports
4. ✓ Write tests
5. ✓ Update documentation

**Estimated Effort:** 4-5 hours
**Risk:** Low - standard file I/O operations

### Phase 4: Statistics (Priority 2)
1. ✓ Create `statistics.ex`
2. ✓ Implement bootstrap confidence intervals
3. ✓ Implement McNemar's test
4. ✓ Create `leaderboard.ex`
5. ✓ Write tests
6. ✓ Update documentation

**Estimated Effort:** 5-6 hours
**Risk:** Medium - statistical correctness critical

### Phase 5: Quality of Life (Priority 3)
1. Create `progress_reporter.ex`
2. Create `dataset_stats.ex`
3. Write tests
4. Update documentation

**Estimated Effort:** 2-3 hours
**Risk:** Low - nice-to-have features

---

## Testing Strategy

### Unit Tests
- Each new metric with known ground truth
- Edge cases (empty inputs, perfect scores, zero scores)
- Type handling (string vs numeric)

### Integration Tests
- Full evaluation pipeline with new metrics
- Dataset loading and validation
- Result persistence and retrieval
- Statistical comparison workflows

### Property-Based Tests
- Metric scores always in valid range [0.0, 1.0]
- Symmetry properties where applicable
- Identity properties (same input → score 1.0)

### Performance Tests
- Large dataset evaluation (<100ms per item)
- Cache performance
- Export performance for large result sets

---

## API Changes & Backward Compatibility

### Backward Compatible Changes
All new features are additive:
- New metrics are opt-in via `metrics:` list
- New datasets add to existing registry
- Result persistence is optional
- Statistical functions are new modules

### Version Bump Rationale
**0.1.0 → 0.2.0** (Minor version bump)
- Significant new functionality (metrics, datasets)
- Backward compatible API
- No breaking changes to existing code

---

## Success Criteria

### Functional Requirements
- [ ] 3 new evaluation metrics working correctly
- [ ] 3+ new dataset loaders implemented
- [ ] Result persistence and export working
- [ ] Statistical comparison utilities functional
- [ ] All tests passing with >90% coverage
- [ ] Zero compilation warnings

### Quality Requirements
- [ ] Comprehensive documentation for all new features
- [ ] Type specs for all public functions
- [ ] Examples for each new capability
- [ ] Integration with existing Crucible ecosystem

### Performance Requirements
- [ ] Evaluation throughput unchanged or improved
- [ ] Cache hit rate >80% for repeated loads
- [ ] Export <1s for 10K result items

---

## Dependencies

### New Dependencies
```elixir
# None required! All implementations use standard library
# - String operations (BLEU, ROUGE)
# - Math operations (statistics)
# - File I/O (persistence)
# - Jason (already included for JSON)
```

### Optional Future Dependencies
- `statistics` - For advanced statistical functions
- `nx` - For numerical operations if needed
- `vega_lite` - For visualization generation

---

## Documentation Updates

### README.md Updates
1. Add new metrics to features list
2. Add new datasets to supported list
3. Add examples for result persistence
4. Add examples for statistical comparison
5. Update API reference with new functions

### CHANGELOG.md Updates
```markdown
## [0.2.0] - 2025-11-25

### Added
- BLEU score metric for machine translation evaluation
- ROUGE score metric (ROUGE-1, ROUGE-2, ROUGE-L) for summarization
- Pass@k metric for code generation with multiple samples
- TruthfulQA dataset loader for factuality evaluation
- HellaSwag dataset loader for commonsense reasoning
- ARC dataset loader (Easy and Challenge subsets) for science questions
- Dataset registry for centralized dataset discovery
- Result persistence with ResultStore module
- Export functionality (CSV, JSONL, Markdown, HTML)
- Statistical comparison utilities with confidence intervals
- McNemar's test for model comparison
- Leaderboard generation with ranked comparisons
- Bootstrap confidence intervals for accuracy estimates

### Changed
- Version bump from 0.1.0 to 0.2.0
- Enhanced documentation with new examples

### Fixed
- None (all backward compatible additions)
```

---

## Risk Assessment

### Low Risk
- Metric implementations (well-defined algorithms)
- File I/O operations (standard patterns)
- Documentation updates

### Medium Risk
- Dataset loader implementations (HF integration + fixture coverage)
- Statistical tests (correctness critical)
- Test coverage completeness

### High Risk
- None identified

### Mitigation Strategies
1. **Fixture Fidelity:** Use stable HF fixtures and Bypass for offline tests
2. **Statistical Correctness:** Reference implementations and known results
3. **Test Coverage:** Property-based testing for invariants
4. **Performance:** Benchmarking before/after changes

---

## Future Work (Out of Scope for v0.2.0)

### Semantic Metrics
- BERTScore (requires embedding model)
- Sentence-BERT similarity
- Integration with ML model serving

### Advanced Datasets
- WinoGrande (pronoun resolution)
- CommonsenseQA (commonsense reasoning)
- Natural Questions (open domain QA)
- SQuAD (reading comprehension)

### Distributed Evaluation
- Parallel evaluation across multiple nodes
- GPU acceleration for metrics
- Streaming evaluation for massive datasets

### Interactive Features
- LiveBook integration
- Real-time dashboard
- Interactive result exploration

### Enterprise Features
- Database backends (PostgreSQL, SQLite)
- Multi-user result tracking
- API server mode
- Authentication and authorization

---

## Appendix A: Metric Formulas

### BLEU Score
```
BLEU = BP × exp(∑(wₙ × log(pₙ)))

where:
  BP = brevity penalty = min(1, exp(1 - r/c))
  r = reference length
  c = candidate length
  pₙ = modified n-gram precision
  wₙ = uniform weight = 1/N (typically N=4)
```

### ROUGE Scores
```
ROUGE-N = ∑(S∈refs) ∑(gram∈S) Count_match(gram) /
          ∑(S∈refs) ∑(gram∈S) Count(gram)

ROUGE-L = LCS(X,Y) / len(Y)
  where LCS = longest common subsequence
```

### Pass@k
```
Pass@k = 1 - (n-c choose k) / (n choose k)

where:
  n = number of samples generated
  c = number of correct samples
  k = threshold (e.g., 1, 5, 10)
```

### McNemar's Test
```
χ² = (b - c)² / (b + c)

where:
  b = items where model A correct, model B wrong
  c = items where model A wrong, model B correct
  p-value from χ² distribution with df=1
```

---

## Appendix B: Example Workflows

### Complete Evaluation Pipeline
```elixir
# 1. Load multiple datasets
datasets = [:mmlu_stem, :truthfulqa, :hellaswag, :arc_challenge]

# 2. Evaluate model across all datasets
results = Enum.map(datasets, fn dataset_name ->
  {:ok, dataset} = CrucibleDatasets.load(dataset_name, sample_size: 200)
  predictions = generate_predictions(model, dataset)

  {:ok, result} = CrucibleDatasets.evaluate(predictions,
    dataset: dataset,
    metrics: [:exact_match, :f1, :bleu],
    model_name: "gpt-4-turbo"
  )

  # Save result
  {:ok, result_id} = CrucibleDatasets.ResultStore.save(result)
  result
end)

# 3. Generate comparison report
comparison = CrucibleDatasets.Statistics.compare(results)
leaderboard = CrucibleDatasets.Leaderboard.generate(results)

# 4. Export results
CrucibleDatasets.Exporter.to_markdown(leaderboard, "reports/evaluation.md")
CrucibleDatasets.Exporter.to_csv(results, "data/results.csv")
```

### Statistical Model Comparison
```elixir
# Compare three models on same dataset
{:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 1000)

models = ["gpt-4", "claude-3", "gemini-pro"]
results = Enum.map(models, fn model ->
  predictions = generate_predictions(model, dataset)
  {:ok, result} = CrucibleDatasets.evaluate(predictions,
    dataset: dataset,
    model_name: model
  )
  result
end)

# Statistical comparison
{:ok, comparison} = CrucibleDatasets.Statistics.compare(results,
  test: :mcnemar,
  confidence_level: 0.95,
  bootstrap_iterations: 10000
)

# Check if differences are significant
pairwise = comparison.pairwise_comparisons
Enum.each(pairwise, fn {{m1, m2}, test_result} ->
  if test_result.significant do
    IO.puts("#{m1} significantly outperforms #{m2} (p=#{test_result.p_value})")
  end
end)
```

---

## Conclusion

This enhancement plan significantly expands CrucibleDatasets capabilities while maintaining backward compatibility and code quality. The phased approach allows for incremental implementation and testing, with Priority 1 features (metrics and datasets) providing immediate research value.

The design maintains the library's clean architecture, extensibility, and commitment to reproducible research. All enhancements follow Elixir best practices and integrate seamlessly with the existing Crucible ecosystem.

**Target Version:** 0.2.0
**Expected Release:** 2025-11-25
**Implementation Status:** In Progress
