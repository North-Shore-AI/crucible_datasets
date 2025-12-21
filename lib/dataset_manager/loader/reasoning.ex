defmodule CrucibleDatasets.Loader.Reasoning do
  @moduledoc """
  Loader for reasoning/chain-of-thought datasets used in distillation.

  Supports:
    - OpenThoughts3 (open-thoughts/OpenThoughts3-1.2M)
    - DeepMath-103K (zwhe99/DeepMath-103K) - reasoning variant

  ## Examples

      # Load OpenThoughts3
      {:ok, dataset} = CrucibleDatasets.Loader.Reasoning.load(:open_thoughts3)

      # Load with sample size
      {:ok, dataset} = CrucibleDatasets.Loader.Reasoning.load(:open_thoughts3, sample_size: 1000)

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace
  alias CrucibleDatasets.Types.Conversation

  require Logger

  @datasets %{
    open_thoughts3: %{
      repo_id: "open-thoughts/OpenThoughts3-1.2M",
      parser: :open_thoughts,
      description: "OpenThoughts3 reasoning traces for distillation (1.2M examples)"
    },
    deepmath_reasoning: %{
      repo_id: "zwhe99/DeepMath-103K",
      parser: :deepmath,
      description: "DeepMath 103K with reasoning traces"
    }
  }

  @doc """
  Load a reasoning/chain-of-thought dataset.

  ## Arguments
    * `dataset_name` - One of `:open_thoughts3`, `:deepmath_reasoning`
    * `opts` - Options (see below)

  ## Options
    * `:split` - Dataset split (default: "train")
    * `:sample_size` - Limit number of items
    * `:synthetic` - Use synthetic data for testing (default: false)
    * `:token` - HuggingFace API token

  """
  @spec load(atom(), keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(dataset_name, opts \\ [])

  def load(dataset_name, opts) when is_atom(dataset_name) do
    case Map.get(@datasets, dataset_name) do
      nil ->
        {:error, {:unknown_dataset, dataset_name, Map.keys(@datasets)}}

      dataset_info ->
        synthetic = Keyword.get(opts, :synthetic, false)

        if synthetic do
          load_synthetic(dataset_name, opts)
        else
          load_from_huggingface(dataset_name, dataset_info, opts)
        end
    end
  end

  defp load_from_huggingface(dataset_name, %{repo_id: repo_id, parser: parser}, opts) do
    split = Keyword.get(opts, :split, "train") |> to_string()
    sample_size = Keyword.get(opts, :sample_size)
    token = Keyword.get(opts, :token)

    case HuggingFace.fetch(repo_id, split: split, token: token) do
      {:ok, raw_data} ->
        items = parse_reasoning_data(raw_data, parser)

        items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            to_string(dataset_name),
            "1.0",
            items,
            %{
              source: "huggingface:#{repo_id}",
              split: split,
              license: "apache-2.0",
              domain: "reasoning"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
          Logger.warning(
            "Failed to load #{dataset_name} from HuggingFace: #{inspect(reason)}, falling back to synthetic"
          )

          load_synthetic(dataset_name, opts)
        else
          {:error, {:huggingface_fetch_failed, reason}}
        end
    end
  end

  defp parse_reasoning_data(raw_data, parser) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      case parse_item(item, parser, idx) do
        {:ok, parsed_item} -> parsed_item
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_item(item, :open_thoughts, idx) do
    # OpenThoughts3 format: conversations with from/value pairs
    conversations = item["conversations"] || []

    messages =
      Enum.map(conversations, fn msg ->
        role =
          case msg["from"] do
            "human" -> :user
            "gpt" -> :assistant
            "system" -> :system
            _ -> :user
          end

        CrucibleDatasets.Types.Message.new(role, msg["value"] || "")
      end)

    case Conversation.new(messages) do
      conversation when is_struct(conversation) ->
        # Extract the user prompt (first user message)
        prompt = extract_first_user_message(conversations)

        # Extract the assistant reasoning (last assistant message)
        reasoning = extract_last_assistant_message(conversations)

        {:ok,
         %{
           id: "open_thoughts_#{idx}",
           input: %{
             prompt: prompt,
             conversation: conversation
           },
           expected: %{
             reasoning: reasoning
           },
           metadata: %{
             source: "open_thoughts3",
             turn_count: length(messages),
             has_reasoning: String.contains?(reasoning || "", ["<think>", "Let me", "First,"])
           }
         }}

      _ ->
        {:error, :invalid_conversation}
    end
  end

  defp parse_item(item, :deepmath, idx) do
    problem = item["problem"] || item["question"] || ""
    solution = item["solution"] || item["answer"] || ""

    {:ok,
     %{
       id: "deepmath_reasoning_#{idx}",
       input: %{
         prompt: problem
       },
       expected: %{
         reasoning: solution,
         answer: extract_final_answer(solution)
       },
       metadata: %{
         source: "deepmath",
         has_reasoning: String.length(solution) > 100
       }
     }}
  end

  defp extract_first_user_message(conversations) do
    conversations
    |> Enum.find(fn msg -> msg["from"] == "human" end)
    |> case do
      nil -> ""
      msg -> msg["value"] || ""
    end
  end

  defp extract_last_assistant_message(conversations) do
    conversations
    |> Enum.filter(fn msg -> msg["from"] == "gpt" end)
    |> List.last()
    |> case do
      nil -> ""
      msg -> msg["value"] || ""
    end
  end

  defp extract_final_answer(solution) when is_binary(solution) do
    # Try common answer patterns
    cond do
      String.contains?(solution, "####") ->
        solution |> String.split("####") |> List.last() |> String.trim()

      String.contains?(solution, "\\boxed{") ->
        case Regex.run(~r/\\boxed\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}/, solution) do
          [_, answer] -> String.trim(answer)
          nil -> nil
        end

      true ->
        nil
    end
  end

  defp extract_final_answer(_), do: nil

  defp load_synthetic(dataset_name, opts) do
    sample_size = Keyword.get(opts, :sample_size, 20)

    items = generate_synthetic_items(sample_size)

    dataset =
      Dataset.new(
        to_string(dataset_name),
        "1.0",
        items,
        %{
          source: "synthetic",
          license: "apache-2.0",
          domain: "reasoning"
        }
      )

    {:ok, dataset}
  end

  defp generate_synthetic_items(count) do
    examples = [
      {"What is 15% of 200?",
       "<think>\nTo find 15% of 200, I need to multiply 200 by 0.15.\n200 × 0.15 = 30\n</think>\n\nThe answer is 30.",
       "30"},
      {"If a train travels 60 miles in 1 hour, how far will it travel in 2.5 hours?",
       "<think>\nThe train travels at 60 miles per hour.\nIn 2.5 hours: 60 × 2.5 = 150 miles\n</think>\n\nThe train will travel 150 miles.",
       "150"},
      {"Solve for x: 3x + 7 = 22",
       "<think>\n3x + 7 = 22\n3x = 22 - 7\n3x = 15\nx = 5\n</think>\n\nx = 5", "5"},
      {"What is the sum of the first 5 prime numbers?",
       "<think>\nThe first 5 prime numbers are: 2, 3, 5, 7, 11\nSum = 2 + 3 + 5 + 7 + 11 = 28\n</think>\n\nThe sum is 28.",
       "28"},
      {"A rectangle has a length of 8 cm and a width of 5 cm. What is its area?",
       "<think>\nArea of rectangle = length × width\nArea = 8 × 5 = 40 cm²\n</think>\n\nThe area is 40 square centimeters.",
       "40"}
    ]

    for i <- 0..(count - 1) do
      {prompt, reasoning, answer} = Enum.at(examples, rem(i, length(examples)))

      %{
        id: "reasoning_#{i}",
        input: %{
          prompt: prompt
        },
        expected: %{
          reasoning: reasoning,
          answer: answer
        },
        metadata: %{
          source: "synthetic",
          has_reasoning: true
        }
      }
    end
  end

  @doc """
  List available reasoning datasets.
  """
  @spec available_datasets() :: [atom()]
  def available_datasets, do: Map.keys(@datasets)
end
