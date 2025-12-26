defmodule CrucibleDatasets.Loader.NoRobots do
  @moduledoc """
  NoRobots instruction-following dataset loader.

  NoRobots contains human-written instruction-response pairs
  for training instruction-following models. The dataset includes
  high-quality examples across various categories like coding,
  summarization, creative writing, and more.

  Source: https://huggingface.co/datasets/HuggingFaceH4/no_robots

  ## Categories

  The dataset covers these instruction categories:
  - Open QA: General question answering
  - Generation: Text generation tasks
  - Brainstorm: Creative ideation
  - Rewrite: Text transformation
  - Summarize: Summarization tasks
  - Classify: Classification tasks
  - Closed QA: Factual question answering
  - Extract: Information extraction
  - Chat: Conversational responses

  ## Examples

      # Load with defaults
      {:ok, dataset} = NoRobots.load()

      # Load with sample size
      {:ok, dataset} = NoRobots.load(sample_size: 100)

      # Load specific split
      {:ok, dataset} = NoRobots.load(split: :train)
  """

  alias CrucibleDatasets.Dataset

  @categories [
    "Open QA",
    "Generation",
    "Brainstorm",
    "Rewrite",
    "Summarize",
    "Classify",
    "Closed QA",
    "Extract",
    "Chat"
  ]

  @doc """
  Load NoRobots dataset.

  For demo purposes, generates synthetic data.
  In production, would fetch from HuggingFace.

  ## Options

    * `:split` - Dataset split (:train, :test) default: :train
    * `:sample_size` - Limit items (default: 50)
    * `:seed` - Random seed for reproducibility
  """
  @spec load(keyword()) :: {:ok, Dataset.t()}
  def load(opts \\ []) do
    # In production, this would fetch from HuggingFace:
    # https://huggingface.co/datasets/HuggingFaceH4/no_robots
    # For now, generate synthetic data for testing

    items = generate_sample_items(opts)

    dataset =
      Dataset.new(
        "no_robots",
        "1.0",
        items,
        %{
          source: "huggingface:HuggingFaceH4/no_robots",
          license: "Apache-2.0",
          domain: "instruction_following"
        }
      )

    {:ok, dataset}
  end

  # Generate sample NoRobots items for testing
  defp generate_sample_items(opts) do
    count = Keyword.get(opts, :sample_size, 50)

    # Use a deterministic seed for consistent checksums across loads
    seed = Keyword.get(opts, :seed, 12_345)
    :rand.seed(:exsss, {seed, seed, seed})

    instruction_templates = [
      {"Write a short poem about %topic%.", "Here is a short poem about %topic%:\n\n%content%"},
      {"Summarize the following text: %topic%",
       "Here is a summary:\n\n%topic% can be condensed to its key points which are %content%."},
      {"Explain %topic% in simple terms.",
       "Let me explain %topic% simply:\n\n%content% This makes it easier to understand."},
      {"What are the main benefits of %topic%?",
       "The main benefits of %topic% include:\n\n1. %content%\n2. Improved efficiency\n3. Better outcomes"},
      {"Generate a list of ideas for %topic%.",
       "Here are some ideas for %topic%:\n\n- %content%\n- Try a new approach\n- Consider alternatives"},
      {"Rewrite this in a more formal tone: %topic%",
       "In a more formal register:\n\n%content% This represents the key aspects of %topic%."},
      {"What is %topic%?", "%topic% is %content%. It is commonly used in various applications."},
      {"Create a brief outline for %topic%.",
       "Outline for %topic%:\n\nI. Introduction\nII. %content%\nIII. Conclusion"},
      {"How can I improve my %topic%?",
       "To improve your %topic%, consider:\n\n1. %content%\n2. Practice regularly\n3. Seek feedback"},
      {"Classify the following: %topic%",
       "Classification: %topic% belongs to the category of %content%."}
    ]

    topics = [
      "machine learning",
      "climate change",
      "healthy eating",
      "time management",
      "software development",
      "creative writing",
      "public speaking",
      "financial planning",
      "meditation",
      "team collaboration"
    ]

    content_snippets = [
      "effective strategies and techniques",
      "fundamental concepts and principles",
      "best practices for success",
      "key considerations and factors",
      "important aspects to consider"
    ]

    all_items =
      Enum.map(1..count, fn i ->
        {instruction_template, response_template} = Enum.random(instruction_templates)
        topic = Enum.random(topics)
        content = Enum.random(content_snippets)
        category = Enum.random(@categories)

        instruction =
          instruction_template
          |> String.replace("%topic%", topic)

        response =
          response_template
          |> String.replace("%topic%", topic)
          |> String.replace("%content%", content)

        %{
          id: "no_robots_#{i}",
          input: instruction,
          expected: response,
          metadata: %{
            category: category,
            topic: topic
          }
        }
      end)

    # Shuffle with seeded random, then take the requested count
    all_items
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  @doc """
  Parse NoRobots JSONL format (if loading from file).

  Expected format:
  {"prompt": "...", "completion": "...", "category": "..."}
  """
  @spec parse_jsonl(String.t()) :: [map()]
  def parse_jsonl(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      case Jason.decode(line) do
        {:ok, item} ->
          %{
            id: "no_robots_#{idx}",
            input: item["prompt"] || item["instruction"] || "",
            expected: item["completion"] || item["response"] || item["output"] || "",
            metadata: %{
              category: item["category"] || "unknown"
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
