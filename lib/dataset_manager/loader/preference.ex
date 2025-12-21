defmodule CrucibleDatasets.Loader.Preference do
  @moduledoc """
  Loader for preference/comparison datasets used in DPO and RLHF.

  Supports:
    - HH-RLHF (Anthropic/hh-rlhf)
    - HelpSteer3 (nvidia/HelpSteer3)
    - HelpSteer2 (nvidia/HelpSteer2)
    - UltraFeedback (openbmb/UltraFeedback)
    - Arena-140K (lmarena-ai/arena-hard-v0.1)
    - Tulu-3-Preference (allenai/tulu-3-preference-mixture)

  ## Examples

      # Load HH-RLHF
      {:ok, dataset} = CrucibleDatasets.Loader.Preference.load(:hh_rlhf)

      # Load HelpSteer3
      {:ok, dataset} = CrucibleDatasets.Loader.Preference.load(:helpsteer3)

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace
  alias CrucibleDatasets.Types.{Comparison, LabeledComparison}

  require Logger

  @datasets %{
    hh_rlhf: %{
      repo_id: "Anthropic/hh-rlhf",
      parser: :hh_rlhf,
      description: "Anthropic's HH-RLHF dataset"
    },
    helpsteer3: %{
      repo_id: "nvidia/HelpSteer3",
      parser: :helpsteer,
      description: "NVIDIA HelpSteer3 dataset"
    },
    helpsteer2: %{
      repo_id: "nvidia/HelpSteer2",
      parser: :helpsteer2,
      description: "NVIDIA HelpSteer2 dataset"
    },
    ultrafeedback: %{
      repo_id: "openbmb/UltraFeedback",
      parser: :ultrafeedback,
      description: "UltraFeedback preference dataset"
    },
    arena_140k: %{
      repo_id: "lmarena-ai/arena-hard-v0.1",
      parser: :arena,
      description: "LMArena Arena Hard dataset"
    },
    tulu3_preference: %{
      repo_id: "allenai/tulu-3-preference-mixture",
      parser: :tulu_preference,
      description: "Tulu 3 Preference Mixture"
    }
  }

  @doc """
  Load a preference/comparison dataset.

  ## Arguments
    * `dataset_name` - One of the supported dataset names (see module docs)
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

    Logger.debug("Loading #{dataset_name} #{split} split from HuggingFace...")

    case HuggingFace.fetch(repo_id, split: split, token: token) do
      {:ok, raw_data} ->
        items = parse_preference_data(raw_data, parser)

        items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            to_string(dataset_name),
            "1.0",
            items,
            %{
              source: "huggingface:#{repo_id}",
              split: split,
              license: "mit",
              domain: "preference"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        Logger.error("Failed to load #{dataset_name} from HuggingFace: #{inspect(reason)}")
        {:error, {:huggingface_fetch_failed, reason}}
    end
  end

  defp parse_preference_data(raw_data, parser) do
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

  defp parse_item(item, :hh_rlhf, idx) do
    with {:ok, comparison} <- Comparison.from_hh_rlhf(item) do
      label = LabeledComparison.from_hh_rlhf()

      {:ok,
       %{
         id: "hh_rlhf_#{idx}",
         input: %{
           comparison: comparison
         },
         expected: label,
         metadata: %{
           source: "hh-rlhf"
         }
       }}
    end
  end

  defp parse_item(item, :helpsteer, idx) do
    with {:ok, comparison} <- Comparison.from_helpsteer(item),
         {:ok, label} <- LabeledComparison.from_label(comparison.metadata[:label] || "A") do
      {:ok,
       %{
         id: "helpsteer_#{idx}",
         input: %{
           comparison: comparison
         },
         expected: label,
         metadata: %{
           source: "helpsteer"
         }
       }}
    end
  end

  defp parse_item(item, :helpsteer2, idx) do
    # HelpSteer2 has a different format - single response with scores
    prompt = item["prompt"]
    response = item["response"]
    score = item["helpfulness"] || item["correctness"] || 3.0

    comparison = Comparison.new(prompt, response, "", %{score: score})

    {:ok,
     %{
       id: "helpsteer2_#{idx}",
       input: %{
         comparison: comparison
       },
       expected: nil,
       metadata: %{
         source: "helpsteer2",
         helpfulness: item["helpfulness"],
         correctness: item["correctness"],
         coherence: item["coherence"],
         complexity: item["complexity"],
         verbosity: item["verbosity"]
       }
     }}
  end

  defp parse_item(item, :ultrafeedback, idx) do
    with {:ok, comparison} <- Comparison.from_ultrafeedback(item) do
      # UltraFeedback: best response is always :a
      label = LabeledComparison.new(:a)

      {:ok,
       %{
         id: "ultrafeedback_#{idx}",
         input: %{
           comparison: comparison
         },
         expected: label,
         metadata: comparison.metadata
       }}
    end
  end

  defp parse_item(item, :arena, idx) do
    # Arena format: has prompt, answer_a, answer_b, winner
    prompt = item["prompt"] || item["question"]
    answer_a = item["answer_a"] || item["response_a"]
    answer_b = item["answer_b"] || item["response_b"]
    winner = item["winner"] || item["label"]

    comparison = Comparison.new(prompt, answer_a, answer_b, %{source: :arena})

    label =
      case winner do
        "model_a" -> LabeledComparison.new(:a)
        "model_b" -> LabeledComparison.new(:b)
        "tie" -> LabeledComparison.new(:tie)
        _ -> nil
      end

    {:ok,
     %{
       id: "arena_#{idx}",
       input: %{
         comparison: comparison
       },
       expected: label,
       metadata: %{
         source: "arena",
         model_a: item["model_a"],
         model_b: item["model_b"]
       }
     }}
  end

  defp parse_item(item, :tulu_preference, idx) do
    # Tulu preference: has chosen and rejected conversations
    chosen = item["chosen"] || []
    rejected = item["rejected"] || []

    # Try to extract prompts
    prompt =
      case chosen do
        [%{"role" => "user", "content" => content} | _] -> content
        _ -> item["prompt"] || ""
      end

    comparison = Comparison.new(prompt, chosen, rejected, %{source: :tulu_preference})
    label = LabeledComparison.new(:a)

    {:ok,
     %{
       id: "tulu_pref_#{idx}",
       input: %{
         comparison: comparison
       },
       expected: label,
       metadata: %{
         source: "tulu_preference"
       }
     }}
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
          license: "mit",
          domain: "preference"
        }
      )

    {:ok, dataset}
  end

  defp generate_synthetic_items(count) do
    prompts = [
      "What is the best programming language?",
      "How do I improve my writing?",
      "Explain machine learning.",
      "What is climate change?",
      "How do computers work?"
    ]

    good_responses = [
      "The best programming language depends on your use case. Python is great for ML, JavaScript for web dev.",
      "To improve writing: read widely, practice daily, seek feedback, and revise your work multiple times.",
      "Machine learning is a branch of AI where computers learn patterns from data to make predictions.",
      "Climate change refers to long-term shifts in temperatures caused primarily by human activities.",
      "Computers process binary data through CPUs, store info in memory, and execute software instructions."
    ]

    bad_responses = [
      "IDK probably Java or something.",
      "Just write more I guess.",
      "It's like robots but smarter.",
      "The weather changes sometimes.",
      "Magic probably."
    ]

    for i <- 0..(count - 1) do
      idx = rem(i, length(prompts))

      comparison =
        Comparison.new(
          Enum.at(prompts, idx),
          Enum.at(good_responses, idx),
          Enum.at(bad_responses, idx)
        )

      %{
        id: "pref_#{i}",
        input: %{
          comparison: comparison
        },
        expected: LabeledComparison.new(:a),
        metadata: %{
          source: "synthetic"
        }
      }
    end
  end

  @doc """
  List available preference datasets.
  """
  @spec available_datasets() :: [atom()]
  def available_datasets, do: Map.keys(@datasets)
end
