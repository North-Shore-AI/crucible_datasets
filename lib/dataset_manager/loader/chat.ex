defmodule CrucibleDatasets.Loader.Chat do
  @moduledoc """
  Loader for chat/instruction-following datasets.

  Supports:
    - Tulu-3-SFT (allenai/tulu-3-sft-mixture)
    - No Robots (HuggingFaceH4/no_robots)

  ## Examples

      # Load Tulu-3-SFT
      {:ok, dataset} = CrucibleDatasets.Loader.Chat.load(:tulu3_sft)

      # Load No Robots
      {:ok, dataset} = CrucibleDatasets.Loader.Chat.load(:no_robots)

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace
  alias CrucibleDatasets.Types.Conversation

  require Logger

  @datasets %{
    tulu3_sft: %{
      repo_id: "allenai/tulu-3-sft-mixture",
      description: "Tulu 3 SFT Mixture - instruction-following dataset"
    },
    no_robots: %{
      repo_id: "HuggingFaceH4/no_robots",
      description: "No Robots - high-quality human demonstrations"
    }
  }

  @doc """
  Load a chat/instruction-following dataset.

  ## Arguments
    * `dataset_name` - Either `:tulu3_sft` or `:no_robots`
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

  defp load_from_huggingface(dataset_name, %{repo_id: repo_id}, opts) do
    split = Keyword.get(opts, :split, "train") |> to_string()
    sample_size = Keyword.get(opts, :sample_size)
    token = Keyword.get(opts, :token)

    Logger.debug("Loading #{dataset_name} #{split} split from HuggingFace...")

    case HuggingFace.fetch(repo_id, split: split, token: token) do
      {:ok, raw_data} ->
        items = parse_chat_data(raw_data, dataset_name)

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
              domain: "chat"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        Logger.error("Failed to load #{dataset_name} from HuggingFace: #{inspect(reason)}")
        {:error, {:huggingface_fetch_failed, reason}}
    end
  end

  defp parse_chat_data(raw_data, _dataset_name) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      messages = item["messages"] || item["conversations"] || []

      case Conversation.from_hf_data(messages, %{source: item["source"]}) do
        {:ok, conversation} ->
          %{
            id: "chat_#{idx}",
            input: %{
              conversation: conversation
            },
            expected: nil,
            metadata: %{
              source: item["source"] || "unknown",
              turn_count: Conversation.turn_count(conversation)
            }
          }

        {:error, _} ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

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
          domain: "chat"
        }
      )

    {:ok, dataset}
  end

  defp generate_synthetic_items(count) do
    prompts = [
      "What is machine learning?",
      "Explain quantum computing in simple terms.",
      "How do I make pasta?",
      "What are the benefits of exercise?",
      "Can you help me write a poem about nature?",
      "What is the capital of France?",
      "How does photosynthesis work?",
      "What are some good study habits?",
      "Can you explain the theory of relativity?",
      "What is the meaning of life?"
    ]

    responses = [
      "Machine learning is a subset of AI that enables computers to learn from data.",
      "Quantum computing uses quantum bits (qubits) to process information differently than classical computers.",
      "To make pasta, boil water, add pasta, cook for 8-10 minutes, drain, and add sauce.",
      "Exercise improves cardiovascular health, mental well-being, and overall fitness.",
      "Here's a poem: The trees sway gently in the breeze...",
      "The capital of France is Paris.",
      "Photosynthesis is the process by which plants convert sunlight into energy.",
      "Good study habits include regular breaks, active recall, and spaced repetition.",
      "Einstein's theory describes how space and time are interconnected.",
      "The meaning of life is subjective and personal to each individual."
    ]

    for i <- 0..(count - 1) do
      prompt_idx = rem(i, length(prompts))

      messages = [
        CrucibleDatasets.Types.Message.new(:user, Enum.at(prompts, prompt_idx)),
        CrucibleDatasets.Types.Message.new(:assistant, Enum.at(responses, prompt_idx))
      ]

      conversation = Conversation.new(messages)

      %{
        id: "chat_#{i}",
        input: %{
          conversation: conversation
        },
        expected: nil,
        metadata: %{
          source: "synthetic",
          turn_count: 1
        }
      }
    end
  end

  @doc """
  List available chat datasets.
  """
  @spec available_datasets() :: [atom()]
  def available_datasets, do: Map.keys(@datasets)
end
