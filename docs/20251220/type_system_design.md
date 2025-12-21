# CrucibleDatasets Type System Design

**Date**: 2025-12-20
**Library**: Sinter (chosen for clean, minimal, runtime-first design)
**Status**: Design Document

## Why Sinter?

| Criteria | Sinter | Exdantic |
|----------|--------|----------|
| API Surface | ~5 functions | ~50+ functions |
| Runtime-first | Yes (core design) | Bolted on |
| Schema definition | `Sinter.Schema.define(fields)` | Multiple approaches |
| Validation | Single pipeline | 4 different modules |
| JSON Schema | One generator | 3 modules |
| Dependencies | Minimal | Heavy |

For dataset type definitions, we need:
- Simple struct-like validation
- Runtime schema creation (dataset schemas vary)
- Optional coercion (string → int from JSON)
- No LLM/DSPy complexity

Sinter's "One True Way" philosophy matches our needs perfectly.

---

## Type Hierarchy

```
                    ┌──────────────────┐
                    │   DatasetItem    │
                    │  (base schema)   │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   MathItem    │   │   ChatItem    │   │PreferenceItem │
│               │   │               │   │               │
│ - problem     │   │ - conversation│   │ - comparison  │
│ - answer      │   │ - system_msg  │   │ - label       │
│ - type/level  │   │               │   │               │
└───────────────┘   └───────┬───────┘   └───────┬───────┘
                            │                   │
                            ▼                   ▼
                    ┌───────────────┐   ┌───────────────┐
                    │  Conversation │   │  Comparison   │
                    │               │   │               │
                    │ - messages[]  │   │ - prompt      │
                    └───────┬───────┘   │ - response_a  │
                            │           │ - response_b  │
                            ▼           └───────────────┘
                    ┌───────────────┐
                    │    Message    │
                    │               │
                    │ - role        │
                    │ - content     │
                    └───────────────┘
```

---

## Schema Definitions

### 1. Message Schema

The atomic unit for chat data.

```elixir
defmodule CrucibleDatasets.Schema.Message do
  @moduledoc """
  Schema for a single chat message.

  Maps to HuggingFace conversation formats:
  - OpenAI: {"role": "user", "content": "..."}
  - ShareGPT: {"from": "human", "value": "..."}
  """

  @roles [:system, :user, :assistant, :human, :gpt, :tool]

  def schema do
    Sinter.Schema.define([
      {:role, :atom, [
        required: true,
        choices: @roles,
        description: "Message author role"
      ]},
      {:content, :string, [
        required: true,
        min_length: 0,
        description: "Message text content"
      ]},
      {:name, :string, [
        optional: true,
        description: "Optional speaker name"
      ]},
      {:tool_calls, {:array, :map}, [
        optional: true,
        description: "Tool/function calls (for assistant messages)"
      ]},
      {:tool_call_id, :string, [
        optional: true,
        description: "ID of tool call being responded to"
      ]}
    ], title: "Message")
  end

  @doc "Normalize role from various HuggingFace formats"
  def normalize_role("human"), do: :user
  def normalize_role("gpt"), do: :assistant
  def normalize_role("from_human"), do: :user
  def normalize_role("from_gpt"), do: :assistant
  def normalize_role(role) when is_binary(role), do: String.to_atom(role)
  def normalize_role(role) when is_atom(role), do: role
end
```

### 2. Conversation Schema

Multi-turn dialogue container.

```elixir
defmodule CrucibleDatasets.Schema.Conversation do
  @moduledoc """
  Schema for a multi-turn conversation.

  Supports formats:
  - messages: [%{role, content}, ...]
  - ShareGPT: {"conversations": [{"from": "human", "value": "..."}]}
  - Tulu: {"messages": [...]}
  """

  alias CrucibleDatasets.Schema.Message

  def schema do
    Sinter.Schema.define([
      {:messages, {:array, Message}, [
        required: true,
        min_items: 1,
        description: "Ordered list of messages"
      ]},
      {:id, :string, [
        optional: true,
        description: "Conversation identifier"
      ]},
      {:metadata, :map, [
        optional: true,
        description: "Additional conversation metadata"
      ]}
    ],
    title: "Conversation",
    post_validate: &__MODULE__.validate_turn_order/1
    )
  end

  @doc "Ensure conversation has valid turn structure"
  def validate_turn_order(%{messages: messages} = conv) do
    # Check for valid alternation (user/assistant)
    # Allow system message at start
    case messages do
      [%{role: :system} | rest] -> validate_alternation(rest, conv)
      _ -> validate_alternation(messages, conv)
    end
  end

  defp validate_alternation([], conv), do: {:ok, conv}
  defp validate_alternation([_], conv), do: {:ok, conv}
  defp validate_alternation([a, b | rest], conv) do
    if alternates?(a.role, b.role) do
      validate_alternation([b | rest], conv)
    else
      {:ok, conv}  # Allow non-strict for some datasets
    end
  end

  defp alternates?(:user, :assistant), do: true
  defp alternates?(:assistant, :user), do: true
  defp alternates?(:human, :gpt), do: true
  defp alternates?(:gpt, :human), do: true
  defp alternates?(_, _), do: false

  # Computed fields
  def turn_count(%{messages: msgs}), do: length(msgs)

  def system_prompt(%{messages: [%{role: :system, content: c} | _]}), do: c
  def system_prompt(_), do: nil

  def last_message(%{messages: msgs}), do: List.last(msgs)

  def user_messages(%{messages: msgs}) do
    Enum.filter(msgs, &(&1.role in [:user, :human]))
  end

  def assistant_messages(%{messages: msgs}) do
    Enum.filter(msgs, &(&1.role in [:assistant, :gpt]))
  end
end
```

### 3. Comparison Schema

For preference/DPO datasets.

```elixir
defmodule CrucibleDatasets.Schema.Comparison do
  @moduledoc """
  Schema for preference comparison data.

  Used by: HH-RLHF, HelpSteer, UltraFeedback, Arena
  """

  def schema do
    Sinter.Schema.define([
      {:prompt, :string, [
        required: true,
        min_length: 1,
        description: "The input prompt/question"
      ]},
      {:response_a, :string, [
        required: true,
        description: "First response option"
      ]},
      {:response_b, :string, [
        required: true,
        description: "Second response option"
      ]},
      {:context, :string, [
        optional: true,
        description: "Additional context for comparison"
      ]},
      {:category, :string, [
        optional: true,
        description: "Task category (harmlessness, helpfulness, etc.)"
      ]}
    ], title: "Comparison")
  end
end
```

### 4. LabeledComparison Schema

Comparison with preference annotation.

```elixir
defmodule CrucibleDatasets.Schema.LabeledComparison do
  @moduledoc """
  Schema for labeled preference comparisons.

  Extends Comparison with preference annotation.
  """

  @preferences [:a, :b, :tie, :both_bad, :both_good]

  def schema do
    Sinter.Schema.define([
      {:comparison, CrucibleDatasets.Schema.Comparison, [
        required: true,
        description: "The comparison being labeled"
      ]},
      {:preferred, :atom, [
        required: true,
        choices: @preferences,
        description: "Which response is preferred"
      ]},
      {:margin, :float, [
        optional: true,
        gteq: 0.0,
        lteq: 1.0,
        description: "Confidence/margin of preference (0-1)"
      ]},
      {:rationale, :string, [
        optional: true,
        description: "Explanation for preference"
      ]},
      {:ratings, :map, [
        optional: true,
        description: "Per-dimension ratings (helpfulness, harmlessness, etc.)"
      ]}
    ], title: "LabeledComparison")
  end

  # Utility functions
  def to_score(%{preferred: :a}), do: 1.0
  def to_score(%{preferred: :b}), do: 0.0
  def to_score(%{preferred: :tie}), do: 0.5
  def to_score(%{preferred: :both_bad}), do: 0.5
  def to_score(%{preferred: :both_good}), do: 0.5

  def is_preferred?(%{preferred: pref}, which), do: pref == which

  def chosen_response(%{comparison: c, preferred: :a}), do: c.response_a
  def chosen_response(%{comparison: c, preferred: :b}), do: c.response_b
  def chosen_response(_), do: nil

  def rejected_response(%{comparison: c, preferred: :a}), do: c.response_b
  def rejected_response(%{comparison: c, preferred: :b}), do: c.response_a
  def rejected_response(_), do: nil
end
```

### 5. MathProblem Schema

For GSM8K, MATH-500, etc.

```elixir
defmodule CrucibleDatasets.Schema.MathProblem do
  @moduledoc """
  Schema for math word problems.

  Used by: GSM8K, MATH-500, Hendrycks MATH, DeepMath
  """

  @types [:algebra, :geometry, :number_theory, :counting_probability,
          :precalculus, :intermediate_algebra, :prealgebra, :word_problem]

  @levels [:easy, :medium, :hard, :competition]

  def schema do
    Sinter.Schema.define([
      {:problem, :string, [
        required: true,
        min_length: 10,
        description: "The math problem statement"
      ]},
      {:solution, :string, [
        optional: true,
        description: "Step-by-step solution/reasoning"
      ]},
      {:answer, {:union, [:string, :float, :integer]}, [
        required: true,
        description: "Final answer (numeric or LaTeX)"
      ]},
      {:type, :atom, [
        optional: true,
        choices: @types,
        description: "Problem category"
      ]},
      {:level, :atom, [
        optional: true,
        choices: @levels,
        description: "Difficulty level"
      ]},
      {:steps, :integer, [
        optional: true,
        gt: 0,
        description: "Number of reasoning steps"
      ]}
    ], title: "MathProblem")
  end

  @doc "Extract boxed answer from LaTeX solution"
  def extract_boxed_answer(text) when is_binary(text) do
    case Regex.run(~r/\\boxed\{([^}]+)\}/, text) do
      [_, answer] -> {:ok, answer}
      nil -> {:error, :no_boxed_answer}
    end
  end

  @doc "Extract numerical answer from GSM8K format (#### N)"
  def extract_gsm8k_answer(text) when is_binary(text) do
    case String.split(text, "####") do
      [_, answer_part] ->
        answer_part
        |> String.trim()
        |> String.replace(~r/[,$]/, "")
        |> parse_number()
      _ ->
        {:error, :no_answer_marker}
    end
  end

  defp parse_number(str) do
    cond do
      String.contains?(str, ".") ->
        case Float.parse(str) do
          {n, _} -> {:ok, n}
          :error -> {:error, :invalid_number}
        end
      true ->
        case Integer.parse(str) do
          {n, _} -> {:ok, n * 1.0}
          :error -> {:error, :invalid_number}
        end
    end
  end
end
```

### 6. CodeProblem Schema

For code generation datasets.

```elixir
defmodule CrucibleDatasets.Schema.CodeProblem do
  @moduledoc """
  Schema for code generation problems.

  Used by: HumanEval, DeepCoder, MBPP
  """

  @languages [:python, :javascript, :elixir, :rust, :go, :java, :cpp]

  def schema do
    Sinter.Schema.define([
      {:task_id, :string, [
        required: true,
        description: "Unique problem identifier"
      ]},
      {:prompt, :string, [
        required: true,
        description: "Problem description and function signature"
      ]},
      {:canonical_solution, :string, [
        optional: true,
        description: "Reference solution"
      ]},
      {:test_cases, {:array, :map}, [
        optional: true,
        description: "Input/output test cases"
      ]},
      {:entry_point, :string, [
        optional: true,
        description: "Function name to call"
      ]},
      {:language, :atom, [
        optional: true,
        choices: @languages,
        default: :python,
        description: "Programming language"
      ]},
      {:difficulty, :atom, [
        optional: true,
        choices: [:easy, :medium, :hard],
        description: "Problem difficulty"
      ]}
    ], title: "CodeProblem")
  end

  @doc "Extract function signature from prompt"
  def extract_signature(prompt) do
    case Regex.run(~r/def\s+(\w+)\s*\(([^)]*)\)/, prompt) do
      [_, name, args] -> {:ok, %{name: name, args: args}}
      nil -> {:error, :no_signature}
    end
  end
end
```

---

## Dataset Item Schemas

### Generic DatasetItem

Base schema all items share.

```elixir
defmodule CrucibleDatasets.Schema.DatasetItem do
  @moduledoc """
  Base schema for all dataset items.
  """

  def schema do
    Sinter.Schema.define([
      {:id, :string, [
        required: true,
        description: "Unique item identifier"
      ]},
      {:input, :any, [
        required: true,
        description: "Item input (varies by dataset type)"
      ]},
      {:expected, :any, [
        required: true,
        description: "Expected output/answer"
      ]},
      {:metadata, :map, [
        optional: true,
        default: %{},
        description: "Additional item metadata"
      ]}
    ], title: "DatasetItem")
  end
end
```

### Specialized Item Schemas

```elixir
defmodule CrucibleDatasets.Schema.Items do
  @moduledoc """
  Specialized dataset item schemas.
  """

  alias CrucibleDatasets.Schema.{
    Message, Conversation, Comparison,
    LabeledComparison, MathProblem, CodeProblem
  }

  def math_item do
    Sinter.Schema.define([
      {:id, :string, [required: true]},
      {:input, MathProblem, [required: true]},
      {:expected, {:union, [:string, :float]}, [required: true]},
      {:metadata, :map, [optional: true, default: %{}]}
    ], title: "MathItem")
  end

  def chat_item do
    Sinter.Schema.define([
      {:id, :string, [required: true]},
      {:input, Conversation, [required: true]},
      {:expected, Message, [optional: true]},  # Target response
      {:metadata, :map, [optional: true, default: %{}]}
    ], title: "ChatItem")
  end

  def preference_item do
    Sinter.Schema.define([
      {:id, :string, [required: true]},
      {:input, LabeledComparison, [required: true]},
      {:expected, :atom, [required: true, choices: [:a, :b, :tie]]},
      {:metadata, :map, [optional: true, default: %{}]}
    ], title: "PreferenceItem")
  end

  def code_item do
    Sinter.Schema.define([
      {:id, :string, [required: true]},
      {:input, CodeProblem, [required: true]},
      {:expected, :string, [required: true]},  # Solution code
      {:metadata, :map, [optional: true, default: %{}]}
    ], title: "CodeItem")
  end
end
```

---

## HuggingFace Format Adapters

Functions to convert HuggingFace data to our schemas.

```elixir
defmodule CrucibleDatasets.Schema.Adapters do
  @moduledoc """
  Adapters for converting HuggingFace dataset formats to our schemas.
  """

  alias CrucibleDatasets.Schema.{Message, Conversation, Comparison, LabeledComparison}

  # ─────────────────────────────────────────────────────────────
  # Conversation Adapters
  # ─────────────────────────────────────────────────────────────

  @doc """
  Convert ShareGPT format to Conversation.

  ShareGPT: {"conversations": [{"from": "human", "value": "..."}, ...]}
  """
  def from_sharegpt(%{"conversations" => convs}) do
    messages = Enum.map(convs, fn msg ->
      %{
        role: normalize_role(msg["from"]),
        content: msg["value"]
      }
    end)

    validate_conversation(%{messages: messages})
  end

  @doc """
  Convert OpenAI messages format to Conversation.

  OpenAI: {"messages": [{"role": "user", "content": "..."}, ...]}
  """
  def from_openai_messages(%{"messages" => msgs}) do
    messages = Enum.map(msgs, fn msg ->
      %{
        role: normalize_role(msg["role"]),
        content: msg["content"]
      }
    end)

    validate_conversation(%{messages: messages})
  end

  @doc """
  Convert Tulu format to Conversation.
  """
  def from_tulu(data) do
    from_openai_messages(data)  # Same format
  end

  # ─────────────────────────────────────────────────────────────
  # Preference Adapters
  # ─────────────────────────────────────────────────────────────

  @doc """
  Convert HH-RLHF format to LabeledComparison.

  HH-RLHF: {"chosen": "...", "rejected": "..."}
  """
  def from_hh_rlhf(data) do
    chosen = data["chosen"] || ""
    rejected = data["rejected"] || ""

    # Extract last exchange from chosen/rejected
    {prompt, response_a} = extract_last_exchange(chosen)
    {_, response_b} = extract_last_exchange(rejected)

    %{
      comparison: %{
        prompt: prompt,
        response_a: response_a,
        response_b: response_b,
        category: "helpfulness"
      },
      preferred: :a,  # chosen is always A in our format
      margin: nil
    }
  end

  @doc """
  Convert HelpSteer format to LabeledComparison.

  HelpSteer: {"prompt": "...", "response": "...", "helpfulness": N, ...}
  """
  def from_helpsteer(data) do
    ratings = %{
      helpfulness: data["helpfulness"],
      correctness: data["correctness"],
      coherence: data["coherence"],
      complexity: data["complexity"],
      verbosity: data["verbosity"]
    }

    # HelpSteer has single responses with ratings, not comparisons
    # We convert to pseudo-comparison format
    %{
      comparison: %{
        prompt: data["prompt"],
        response_a: data["response"],
        response_b: "",  # No comparison in this format
        category: "quality_rating"
      },
      preferred: :a,
      margin: normalize_helpsteer_score(ratings),
      ratings: ratings
    }
  end

  @doc """
  Convert UltraFeedback format to LabeledComparison.
  """
  def from_ultrafeedback(data) do
    prompt = data["instruction"] || data["prompt"]
    completions = data["completions"] || []

    case completions do
      [a, b | _] ->
        %{
          comparison: %{
            prompt: prompt,
            response_a: a["response"],
            response_b: b["response"],
            category: data["source"] || "general"
          },
          preferred: compare_ratings(a["overall_score"], b["overall_score"]),
          margin: abs((a["overall_score"] || 0) - (b["overall_score"] || 0)) / 5.0
        }
      _ ->
        {:error, :insufficient_completions}
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Math Adapters
  # ─────────────────────────────────────────────────────────────

  @doc """
  Convert GSM8K format to MathProblem.
  """
  def from_gsm8k(data) do
    answer_text = data["answer"] || ""

    %{
      problem: data["question"],
      solution: answer_text,
      answer: extract_gsm8k_answer(answer_text),
      type: :word_problem,
      level: estimate_difficulty(answer_text),
      steps: count_steps(answer_text)
    }
  end

  @doc """
  Convert MATH/Hendrycks format to MathProblem.
  """
  def from_math(data) do
    %{
      problem: data["problem"],
      solution: data["solution"],
      answer: extract_boxed_answer(data["solution"]),
      type: normalize_math_type(data["type"]),
      level: normalize_math_level(data["level"]),
      steps: nil
    }
  end

  # ─────────────────────────────────────────────────────────────
  # Helper Functions
  # ─────────────────────────────────────────────────────────────

  defp normalize_role("human"), do: :user
  defp normalize_role("gpt"), do: :assistant
  defp normalize_role("user"), do: :user
  defp normalize_role("assistant"), do: :assistant
  defp normalize_role("system"), do: :system
  defp normalize_role(other), do: String.to_atom(other)

  defp validate_conversation(conv) do
    Sinter.Validator.validate(Conversation.schema(), conv)
  end

  defp extract_last_exchange(text) do
    # HH-RLHF format: "Human: ...\n\nAssistant: ..."
    parts = String.split(text, ~r/\n\n(?=Human:|Assistant:)/)

    case Enum.reverse(parts) do
      [last, second_last | _] ->
        assistant = String.replace(last, ~r/^Assistant:\s*/, "")
        human = String.replace(second_last, ~r/^Human:\s*/, "")
        {human, assistant}
      [only] ->
        {"", String.replace(only, ~r/^(Human|Assistant):\s*/, "")}
      [] ->
        {"", ""}
    end
  end

  defp normalize_helpsteer_score(ratings) do
    avg = (ratings.helpfulness + ratings.correctness + ratings.coherence) / 3.0
    avg / 5.0  # Normalize to 0-1
  end

  defp compare_ratings(a, b) when is_number(a) and is_number(b) do
    cond do
      a > b -> :a
      b > a -> :b
      true -> :tie
    end
  end
  defp compare_ratings(_, _), do: :tie

  defp extract_gsm8k_answer(text) do
    case String.split(text, "####") do
      [_, answer] ->
        answer
        |> String.trim()
        |> String.replace(~r/[,$]/, "")
        |> parse_number()
      _ -> nil
    end
  end

  defp extract_boxed_answer(text) do
    case Regex.run(~r/\\boxed\{([^}]+)\}/, text || "") do
      [_, answer] -> answer
      nil -> nil
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {n, _} -> n
      :error ->
        case Integer.parse(str) do
          {n, _} -> n * 1.0
          :error -> nil
        end
    end
  end

  defp count_steps(text) do
    text
    |> String.split("<<")
    |> length()
  end

  defp estimate_difficulty(text) do
    steps = count_steps(text)
    cond do
      steps <= 2 -> :easy
      steps <= 4 -> :medium
      true -> :hard
    end
  end

  defp normalize_math_type(nil), do: nil
  defp normalize_math_type(type) do
    type
    |> String.downcase()
    |> String.replace(" ", "_")
    |> String.to_atom()
  end

  defp normalize_math_level(nil), do: nil
  defp normalize_math_level("Level " <> n) do
    case Integer.parse(n) do
      {1, _} -> :easy
      {2, _} -> :easy
      {3, _} -> :medium
      {4, _} -> :hard
      {5, _} -> :competition
      _ -> :medium
    end
  end
  defp normalize_math_level(_), do: nil
end
```

---

## Schema Registry

Central registry for all schemas.

```elixir
defmodule CrucibleDatasets.Schema.Registry do
  @moduledoc """
  Registry of all available schemas.

  Provides lookup and introspection capabilities.
  """

  alias CrucibleDatasets.Schema.{
    Message, Conversation, Comparison, LabeledComparison,
    MathProblem, CodeProblem, DatasetItem, Items
  }

  @schemas %{
    # Core types
    message: Message,
    conversation: Conversation,
    comparison: Comparison,
    labeled_comparison: LabeledComparison,
    math_problem: MathProblem,
    code_problem: CodeProblem,
    dataset_item: DatasetItem,

    # Item types
    math_item: {:items, :math_item},
    chat_item: {:items, :chat_item},
    preference_item: {:items, :preference_item},
    code_item: {:items, :code_item}
  }

  @doc "Get schema by name"
  def get(name) when is_atom(name) do
    case Map.get(@schemas, name) do
      nil -> {:error, :unknown_schema}
      {:items, type} -> {:ok, apply(Items, type, [])}
      module -> {:ok, module.schema()}
    end
  end

  @doc "List all registered schema names"
  def list, do: Map.keys(@schemas)

  @doc "Get schema for a dataset type"
  def for_dataset_type(:math), do: get(:math_item)
  def for_dataset_type(:chat), do: get(:chat_item)
  def for_dataset_type(:preference), do: get(:preference_item)
  def for_dataset_type(:code), do: get(:code_item)
  def for_dataset_type(_), do: get(:dataset_item)

  @doc "Validate data against a named schema"
  def validate(schema_name, data) do
    with {:ok, schema} <- get(schema_name) do
      Sinter.Validator.validate(schema, data)
    end
  end

  @doc "Generate JSON Schema for a named schema"
  def json_schema(schema_name) do
    with {:ok, schema} <- get(schema_name) do
      {:ok, Sinter.JsonSchema.generate(schema)}
    end
  end
end
```

---

## Integration with Loaders

How loaders use the type system.

```elixir
defmodule CrucibleDatasets.Loader.GSM8K do
  alias CrucibleDatasets.Schema.{Adapters, Registry}

  def parse_huggingface_data(raw_data) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      # Convert to our schema format
      math_problem = Adapters.from_gsm8k(item)

      # Build dataset item
      %{
        id: "gsm8k_#{idx}",
        input: %{
          problem: math_problem.problem
        },
        expected: math_problem.answer,
        metadata: %{
          reasoning: math_problem.solution,
          complexity: math_problem.steps,
          difficulty: math_problem.level
        }
      }
    end)
  end

  def validate_item(item) do
    Registry.validate(:math_item, item)
  end
end
```

---

## JSON Schema Generation

For API documentation and LLM structured output.

```elixir
# Generate JSON Schema for any of our types
{:ok, message_schema} = CrucibleDatasets.Schema.Registry.json_schema(:message)

# Output:
%{
  "type" => "object",
  "title" => "Message",
  "required" => ["role", "content"],
  "properties" => %{
    "role" => %{
      "type" => "string",
      "enum" => ["system", "user", "assistant", "human", "gpt", "tool"],
      "description" => "Message author role"
    },
    "content" => %{
      "type" => "string",
      "minLength" => 0,
      "description" => "Message text content"
    },
    "name" => %{
      "type" => "string",
      "description" => "Optional speaker name"
    }
  }
}
```

---

## Implementation Roadmap

### Phase 1: Core Schemas (Week 1)
- [ ] Message schema + tests
- [ ] Conversation schema + tests
- [ ] Comparison schema + tests
- [ ] LabeledComparison schema + tests

### Phase 2: Domain Schemas (Week 1-2)
- [ ] MathProblem schema + tests
- [ ] CodeProblem schema + tests
- [ ] DatasetItem base schema

### Phase 3: Adapters (Week 2)
- [ ] ShareGPT adapter
- [ ] OpenAI messages adapter
- [ ] HH-RLHF adapter
- [ ] HelpSteer adapter
- [ ] UltraFeedback adapter
- [ ] GSM8K adapter
- [ ] MATH adapter

### Phase 4: Integration (Week 2-3)
- [ ] Registry implementation
- [ ] Loader integration
- [ ] JSON Schema generation
- [ ] Documentation

---

## Testing Strategy

```elixir
defmodule CrucibleDatasets.Schema.MessageTest do
  use ExUnit.Case

  alias CrucibleDatasets.Schema.Message

  describe "schema/0" do
    test "validates valid message" do
      data = %{role: :user, content: "Hello"}
      assert {:ok, _} = Sinter.Validator.validate(Message.schema(), data)
    end

    test "rejects missing role" do
      data = %{content: "Hello"}
      assert {:error, _} = Sinter.Validator.validate(Message.schema(), data)
    end

    test "rejects invalid role" do
      data = %{role: :invalid, content: "Hello"}
      assert {:error, _} = Sinter.Validator.validate(Message.schema(), data)
    end
  end

  describe "normalize_role/1" do
    test "normalizes ShareGPT roles" do
      assert Message.normalize_role("human") == :user
      assert Message.normalize_role("gpt") == :assistant
    end

    test "passes through standard roles" do
      assert Message.normalize_role(:user) == :user
      assert Message.normalize_role("assistant") == :assistant
    end
  end
end
```

---

## Summary

This type system design:

1. **Uses Sinter** for clean, runtime-first schema validation
2. **Covers all dataset types**: Math, Chat, Preference, Code
3. **Provides adapters** for common HuggingFace formats
4. **Generates JSON Schema** for API documentation
5. **Integrates with loaders** via the Registry pattern
6. **Is extensible** for new dataset formats

The schemas are intentionally simple - just enough structure to validate and transform data, without the complexity of Exdantic's full feature set.
