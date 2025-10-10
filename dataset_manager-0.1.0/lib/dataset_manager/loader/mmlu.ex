defmodule DatasetManager.Loader.MMLU do
  @moduledoc """
  MMLU (Massive Multitask Language Understanding) dataset loader.

  MMLU contains 57 subjects across STEM, humanities, social sciences, and other domains.
  Each question is multiple choice with 4 options.
  """

  alias DatasetManager.Dataset

  # STEM subjects for mmlu_stem variant
  @stem_subjects [
    "abstract_algebra",
    "anatomy",
    "astronomy",
    "college_biology",
    "college_chemistry",
    "college_computer_science",
    "college_mathematics",
    "college_physics",
    "computer_security",
    "conceptual_physics",
    "electrical_engineering",
    "elementary_mathematics",
    "high_school_biology",
    "high_school_chemistry",
    "high_school_computer_science",
    "high_school_mathematics",
    "high_school_physics",
    "high_school_statistics",
    "machine_learning"
  ]

  @doc """
  Load MMLU dataset.

  For demo purposes, generates synthetic data.
  In production, would fetch from HuggingFace.
  """
  def load(dataset_name, opts \\ []) do
    # In production, this would fetch from HuggingFace:
    # url = "https://huggingface.co/datasets/cais/mmlu"
    # For now, generate synthetic data for testing

    subjects =
      case dataset_name do
        :mmlu_stem -> @stem_subjects
        :mmlu -> @stem_subjects ++ ["history", "philosophy", "law"]
      end

    items = generate_sample_items(subjects, opts)

    dataset =
      Dataset.new(
        to_string(dataset_name),
        "1.0",
        items,
        %{
          source: "huggingface:cais/mmlu",
          license: "MIT",
          domain: if(dataset_name == :mmlu_stem, do: "STEM", else: "general"),
          subjects: subjects
        }
      )

    {:ok, dataset}
  end

  # Generate sample MMLU items for testing
  defp generate_sample_items(subjects, opts) do
    count = Keyword.get(opts, :sample_size, 100)
    items_per_subject = max(1, div(count, length(subjects)))

    # Use a deterministic seed for consistent checksums across loads
    seed = Keyword.get(opts, :seed, 12345)
    :rand.seed(:exsss, {seed, seed, seed})

    all_items =
      subjects
      |> Enum.flat_map(fn subject ->
        Enum.map(1..items_per_subject//1, fn i ->
          choices = ["Option A", "Option B", "Option C", "Option D"]
          correct_answer = rem(i, 4)

          %{
            id: "mmlu_#{subject}_#{i}",
            input: %{
              question: "Sample #{subject} question #{i}?",
              choices: choices
            },
            expected: correct_answer,
            metadata: %{
              subject: subject,
              difficulty: Enum.random(["easy", "medium", "hard"])
            }
          }
        end)
      end)

    # Shuffle with seeded random, then take the requested count
    all_items
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  @doc """
  Parse MMLU CSV format (if loading from file).

  Format: question,A,B,C,D,answer
  """
  def parse_csv(content, subject) do
    content
    |> String.split("\n", trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      parts = String.split(line, ",")

      case parts do
        [question, a, b, c, d, answer] ->
          answer_index = answer_to_index(answer)

          %{
            id: "mmlu_#{subject}_#{idx}",
            input: %{
              question: question,
              choices: [a, b, c, d]
            },
            expected: answer_index,
            metadata: %{
              subject: subject
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp answer_to_index("A"), do: 0
  defp answer_to_index("B"), do: 1
  defp answer_to_index("C"), do: 2
  defp answer_to_index("D"), do: 3
  defp answer_to_index(_), do: 0
end
