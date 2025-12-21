# CrucibleDatasets Examples

This directory contains runnable examples demonstrating how to use CrucibleDatasets with various dataset types.

## Quick Start

Run all examples:

```bash
./examples/run_all.sh
```

Or run individual examples:

```bash
mix run examples/math/gsm8k_example.exs
```

## Examples by Category

### Math Datasets

| Example | Description | Command |
|---------|-------------|---------|
| [gsm8k_example.exs](math/gsm8k_example.exs) | Load GSM8K from HuggingFace, sampling, train/test split | `mix run examples/math/gsm8k_example.exs` |
| [math500_example.exs](math/math500_example.exs) | MATH-500 problems, boxed answer extraction | `mix run examples/math/math500_example.exs` |

### Chat/Instruction Datasets

| Example | Description | Command |
|---------|-------------|---------|
| [tulu3_sft_example.exs](chat/tulu3_sft_example.exs) | Tulu-3-SFT conversations, message handling | `mix run examples/chat/tulu3_sft_example.exs` |

### Preference/DPO Datasets

| Example | Description | Command |
|---------|-------------|---------|
| [hh_rlhf_example.exs](preference/hh_rlhf_example.exs) | HH-RLHF comparisons, preference labels | `mix run examples/preference/hh_rlhf_example.exs` |

### Code Datasets

| Example | Description | Command |
|---------|-------------|---------|
| [deepcoder_example.exs](code/deepcoder_example.exs) | DeepCoder code generation problems | `mix run examples/code/deepcoder_example.exs` |

### Core Functionality

| Example | Description | Command |
|---------|-------------|---------|
| [basic_usage.exs](basic_usage.exs) | Basic loading and evaluation | `mix run examples/basic_usage.exs` |
| [evaluation_workflow.exs](evaluation_workflow.exs) | Complete evaluation pipeline | `mix run examples/evaluation_workflow.exs` |
| [sampling_strategies.exs](sampling_strategies.exs) | Random, stratified, k-fold sampling | `mix run examples/sampling_strategies.exs` |
| [batch_evaluation.exs](batch_evaluation.exs) | Multi-model batch evaluation | `mix run examples/batch_evaluation.exs` |
| [cross_validation.exs](cross_validation.exs) | K-fold cross-validation | `mix run examples/cross_validation.exs` |
| [custom_metrics.exs](custom_metrics.exs) | Implementing custom evaluation metrics | `mix run examples/custom_metrics.exs` |

## Dataset Loaders

### Loading Real Data from HuggingFace

```elixir
# GSM8K - Grade School Math
{:ok, gsm8k} = CrucibleDatasets.Loader.GSM8K.load(split: :train)

# MATH-500 - Competition Math
{:ok, math} = CrucibleDatasets.Loader.Math.load(:math_500)

# Chat datasets
{:ok, tulu} = CrucibleDatasets.Loader.Chat.load(:tulu3_sft)
{:ok, no_robots} = CrucibleDatasets.Loader.Chat.load(:no_robots)

# Preference datasets
{:ok, hh_rlhf} = CrucibleDatasets.Loader.Preference.load(:hh_rlhf)
{:ok, helpsteer} = CrucibleDatasets.Loader.Preference.load(:helpsteer3)

# Code datasets
{:ok, deepcoder} = CrucibleDatasets.Loader.Code.load(:deepcoder)
```

### Using Synthetic Data (for testing)

All loaders support a `synthetic: true` option for offline testing:

```elixir
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(synthetic: true, sample_size: 100)
{:ok, dataset} = CrucibleDatasets.Loader.Chat.load(:tulu3_sft, synthetic: true)
{:ok, dataset} = CrucibleDatasets.Loader.Preference.load(:hh_rlhf, synthetic: true)
```

## Type System

### Conversations (Chat Datasets)

```elixir
alias CrucibleDatasets.Types.{Message, Conversation}

# Access conversation data
first_item = hd(dataset.items)
conv = first_item.input.conversation

# Message operations
Conversation.turn_count(conv)        # Number of turns
Conversation.last_message(conv)      # Last message
Conversation.system_prompt(conv)     # System prompt (if any)
Conversation.to_maps(conv)           # Convert to list of maps
```

### Comparisons (Preference Datasets)

```elixir
alias CrucibleDatasets.Types.{Comparison, LabeledComparison}

# Access comparison data
first_item = hd(dataset.items)
comp = first_item.input.comparison
label = first_item.expected

# Comparison fields
comp.prompt       # The prompt
comp.response_a   # First response
comp.response_b   # Second response

# Label operations
label.preferred                           # :a, :b, or :tie
LabeledComparison.is_preferred?(label, :a)  # true/false
LabeledComparison.to_score(label)           # 1.0, 0.0, or 0.5
```

## Sampling Operations

```elixir
alias CrucibleDatasets.Sampler

# Shuffle with seed
{:ok, shuffled} = Sampler.shuffle(dataset, seed: 42)

# Take first N items
{:ok, subset} = Sampler.take(dataset, 100)

# Skip first N items
{:ok, rest} = Sampler.skip(dataset, 100)

# Filter by predicate
{:ok, hard} = Sampler.filter(dataset, fn item ->
  item.metadata.difficulty == "hard"
end)

# Train/test split
{:ok, {train, test}} = Sampler.train_test_split(dataset, test_size: 0.2)

# K-fold cross-validation
{:ok, folds} = Sampler.k_fold(dataset, k: 5)
```

## Environment Variables

- `HF_TOKEN` - HuggingFace API token for authenticated access to private datasets

## Troubleshooting

### Network Issues

If you get network errors, try using synthetic data:

```elixir
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(synthetic: true)
```

### Large Datasets

Use `sample_size` to limit the number of items loaded:

```elixir
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :train, sample_size: 1000)
```

### Memory Issues

For very large datasets, load and process in chunks:

```elixir
{:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :train)
{:ok, chunk1} = Sampler.take(dataset, 1000)
{:ok, rest} = Sampler.skip(dataset, 1000)
# Process chunk1, then process rest...
```
