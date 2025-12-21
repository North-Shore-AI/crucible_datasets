defmodule CrucibleDatasets.Loader.GSM8K do
  @moduledoc """
  GSM8K (Grade School Math 8K) dataset loader.

  Contains 8,500 grade school math word problems with natural language solutions.

  ## Examples

      # Load train split from HuggingFace
      {:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :train)

      # Load test split
      {:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(split: :test)

      # Use synthetic data for testing
      {:ok, dataset} = CrucibleDatasets.Loader.GSM8K.load(synthetic: true)

  """

  alias CrucibleDatasets.Dataset
  alias CrucibleDatasets.Fetcher.HuggingFace

  require Logger

  @repo_id "openai/gsm8k"
  @default_config "main"

  @doc """
  Load GSM8K dataset.

  ## Options
    * `:split` - Dataset split (:train or :test, default: :train)
    * `:synthetic` - Use synthetic data instead of HuggingFace (default: false)
    * `:sample_size` - Limit number of items (default: all)
    * `:config` - Dataset config (default: "main", can also be "socratic")
    * `:token` - HuggingFace API token

  """
  def load(opts \\ []) do
    synthetic = Keyword.get(opts, :synthetic, false)

    if synthetic do
      load_synthetic(opts)
    else
      load_from_huggingface(opts)
    end
  end

  defp load_from_huggingface(opts) do
    split = Keyword.get(opts, :split, :train) |> to_string()
    config = Keyword.get(opts, :config, @default_config)
    sample_size = Keyword.get(opts, :sample_size)
    token = Keyword.get(opts, :token)

    Logger.debug("Loading GSM8K #{split} split from HuggingFace...")

    case HuggingFace.fetch(@repo_id, split: split, config: config, token: token) do
      {:ok, raw_data} ->
        items = parse_huggingface_data(raw_data)

        items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            "gsm8k",
            "1.0",
            items,
            %{
              source: "huggingface:#{@repo_id}",
              split: split,
              config: config,
              license: "MIT",
              domain: "math_word_problems"
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        Logger.error("Failed to load GSM8K from HuggingFace: #{inspect(reason)}")
        {:error, {:huggingface_fetch_failed, reason}}
    end
  end

  defp parse_huggingface_data(raw_data) do
    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      answer_text = item["answer"] || ""

      %{
        id: "gsm8k_#{idx}",
        input: %{
          question: item["question"]
        },
        expected: extract_numerical_answer(answer_text),
        metadata: %{
          reasoning: answer_text,
          complexity: count_steps(answer_text),
          difficulty: estimate_difficulty(answer_text)
        }
      }
    end)
  end

  defp load_synthetic(opts) do
    items = generate_sample_items(opts)

    dataset =
      Dataset.new(
        "gsm8k",
        "1.0",
        items,
        %{
          source: "synthetic",
          license: "MIT",
          domain: "math_word_problems"
        }
      )

    {:ok, dataset}
  end

  # Generate sample GSM8K items for testing
  defp generate_sample_items(opts) do
    count = Keyword.get(opts, :sample_size, 20)

    problems = [
      {"Natalie sold clips to 48 of her friends in April, and then she sold half as many clips in May. How many clips did Natalie sell altogether in April and May?",
       72, 2},
      {"Weng earns $12 an hour for babysitting. Yesterday, she just did 50 minutes of babysitting. How much did she earn?",
       10, 2},
      {"Betty is saving money for a new wallet which costs $100. Betty has only half of the money she needs. Her parents decided to give her $15 for that purpose, and her grandparents twice as much as her parents. How much more money does Betty need to buy the wallet?",
       5, 3},
      {"Julie is reading a 120-page book. Yesterday, she was able to read 12 pages and today, she read twice as many pages as yesterday. If she wants to read half of the remaining pages tomorrow, how many pages should she read?",
       42, 3},
      {"James writes a 3-page letter to 2 different friends twice a week. How many pages does he write a year?",
       624, 2},
      {"Mark has a garden with flowers. He planted plants of three different colors in it. Ten of them are yellow, and there are 80% more of those in purple. There are only 25% as many green flowers as there are yellow and purple flowers. How many flowers does Mark have in his garden in total?",
       35, 4},
      {"Albert is wondering how much pizza he can eat in one day. He buys 2 large pizzas and 2 small pizzas. A large pizza has 16 slices and a small pizza has 8 slices. If he eats it all, how many pieces does he eat that day?",
       48, 2},
      {"Ken created a care package to send to his brother, who was away at boarding school. Ken placed a box on a scale, and then he poured into the box enough jelly beans to bring the weight to 2 pounds. Then, he added enough brownies to cause the weight to triple. Next, he added another 2 pounds of jelly beans. And finally, he added enough gummy worms to double the weight once again. What was the final weight of the box of goodies, in pounds?",
       16, 4},
      {"Alexis is applying for a new job and bought a new set of business clothes to wear to the interview. She went to a department store with a budget of $200 and spent $30 on a button-up shirt, $46 on suit pants, $38 on a suit coat, $11 on socks, and $18 on a belt. She also purchased a pair of shoes, but lost the receipt for them. She has $16 left from her budget. How much did Alexis pay for the shoes?",
       41, 3},
      {"Tina makes $18.00 an hour. If she works more than 8 hours per shift, she is eligible for overtime, which is paid by her hourly wage + 1/2 her hourly wage. If she works 10 hours every day for 5 days, how much money does she make?",
       990, 4}
    ]

    problems
    |> Stream.cycle()
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {{question, answer, steps}, idx} ->
      %{
        id: "gsm8k_#{idx}",
        input: question,
        expected: %{
          answer: answer,
          reasoning: generate_reasoning(question, answer, steps)
        },
        metadata: %{
          complexity: steps,
          difficulty: if(steps <= 2, do: "easy", else: if(steps <= 3, do: "medium", else: "hard"))
        }
      }
    end)
  end

  defp generate_reasoning(_question, answer, steps) do
    # Generate a simple reasoning chain
    reasoning_steps =
      Enum.map(1..steps, fn i ->
        "Step #{i}: Calculate intermediate value"
      end)
      |> Enum.join("\n")

    """
    #{reasoning_steps}
    #### #{answer}
    """
  end

  @doc """
  Parse GSM8K JSONL format.
  """
  def parse_jsonl(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      case Jason.decode(line) do
        {:ok, item} ->
          %{
            id: "gsm8k_#{idx}",
            input: item["question"],
            expected: %{
              answer: extract_numerical_answer(item["answer"]),
              reasoning: item["answer"]
            },
            metadata: %{
              complexity: count_steps(item["answer"]),
              difficulty: estimate_difficulty(item["answer"])
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Extract final numerical answer from GSM8K answer format.

  GSM8K answers end with "#### <number>"

  ## Examples

      iex> extract_numerical_answer("The answer is #### 42")
      42.0

      iex> extract_numerical_answer("#### 1,234.56")
      1234.56

      iex> extract_numerical_answer("no answer here")
      nil

  """
  def extract_numerical_answer(nil), do: nil

  def extract_numerical_answer(answer_text) when is_binary(answer_text) do
    case String.split(answer_text, "####") do
      [_] ->
        nil

      parts ->
        parts
        |> List.last()
        |> String.trim()
        |> String.replace(",", "")
        |> String.replace("$", "")
        |> parse_number()
    end
  end

  defp parse_number(str) do
    str = String.trim(str)

    cond do
      String.contains?(str, ".") ->
        case Float.parse(str) do
          {num, _} -> num
          :error -> nil
        end

      true ->
        case Integer.parse(str) do
          {num, _} -> num * 1.0
          :error -> nil
        end
    end
  end

  defp count_steps(answer_text) do
    # Count number of calculation steps (approximation)
    answer_text
    |> String.split("<<")
    |> length()
  end

  defp estimate_difficulty(answer_text) do
    steps = count_steps(answer_text)

    cond do
      steps <= 2 -> "easy"
      steps <= 4 -> "medium"
      true -> "hard"
    end
  end
end
