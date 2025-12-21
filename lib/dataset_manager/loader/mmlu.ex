defmodule CrucibleDatasets.Loader.MMLU do
  @moduledoc """
  MMLU (Massive Multitask Language Understanding) dataset loader.

  MMLU contains 57 subjects across STEM, humanities, social sciences, and other domains.
  Each question is multiple choice with 4 options.

  ## HuggingFace Dataset

  The official MMLU dataset is hosted at `cais/mmlu` on HuggingFace.

  ## Example

      {:ok, dataset} = CrucibleDatasets.Loader.MMLU.load(:mmlu_stem)
      {:ok, dataset} = CrucibleDatasets.Loader.MMLU.load(:mmlu, split: "test")

  """

  alias CrucibleDatasets.{Dataset, DatasetDict, Source, Format}

  @repo_id "cais/mmlu"

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

  @all_subjects @stem_subjects ++
                  [
                    "business_ethics",
                    "clinical_knowledge",
                    "college_medicine",
                    "formal_logic",
                    "global_facts",
                    "high_school_european_history",
                    "high_school_geography",
                    "high_school_government_and_politics",
                    "high_school_macroeconomics",
                    "high_school_microeconomics",
                    "high_school_psychology",
                    "high_school_us_history",
                    "high_school_world_history",
                    "human_aging",
                    "human_sexuality",
                    "international_law",
                    "jurisprudence",
                    "logical_fallacies",
                    "management",
                    "marketing",
                    "medical_genetics",
                    "miscellaneous",
                    "moral_disputes",
                    "moral_scenarios",
                    "nutrition",
                    "philosophy",
                    "prehistory",
                    "professional_accounting",
                    "professional_law",
                    "professional_medicine",
                    "professional_psychology",
                    "public_relations",
                    "security_studies",
                    "sociology",
                    "us_foreign_policy",
                    "virology",
                    "world_religions"
                  ]

  @doc """
  Load MMLU dataset from HuggingFace.

  ## Options

    * `:split` - Split to load ("train", "test", "validation", "dev"). Default: "test"
    * `:subjects` - List of subjects to include. Default: all for mmlu, STEM for mmlu_stem
    * `:sample_size` - Limit number of items. Default: all
    * `:offline` - If true, use synthetic data for testing. Default: false

  ## Examples

      {:ok, dataset} = MMLU.load(:mmlu_stem)
      {:ok, dataset} = MMLU.load(:mmlu, split: "validation", sample_size: 100)

  """
  @spec load(atom(), keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(dataset_name, opts \\ []) do
    # Support both :synthetic and legacy :offline option
    synthetic = Keyword.get(opts, :synthetic, Keyword.get(opts, :offline, false))

    if synthetic do
      load_synthetic(dataset_name, opts)
    else
      load_from_huggingface(dataset_name, opts)
    end
  end

  @doc """
  Load all splits as a DatasetDict.

  ## Example

      {:ok, dd} = MMLU.load_dataset_dict(:mmlu_stem)
      train = dd["train"]
      test = dd["test"]

  """
  @spec load_dataset_dict(atom(), keyword()) :: {:ok, DatasetDict.t()} | {:error, term()}
  def load_dataset_dict(dataset_name, opts \\ []) do
    splits = ["train", "validation", "test"]

    # Load always succeeds now (with synthetic fallback)
    datasets =
      splits
      |> Enum.map(fn split ->
        {:ok, dataset} = load(dataset_name, Keyword.put(opts, :split, split))
        {split, dataset}
      end)
      |> Map.new()

    {:ok, DatasetDict.new(datasets)}
  end

  # Load from HuggingFace
  defp load_from_huggingface(dataset_name, opts) do
    split = Keyword.get(opts, :split, "test")
    sample_size = Keyword.get(opts, :sample_size)

    subjects =
      case dataset_name do
        :mmlu_stem -> Keyword.get(opts, :subjects, @stem_subjects)
        :mmlu -> Keyword.get(opts, :subjects, @all_subjects)
        _ -> Keyword.get(opts, :subjects, @all_subjects)
      end

    # MMLU on HuggingFace has files per subject and an "all" directory with all subjects
    # The structure is: {subject}/{split}-00000-of-00001.parquet
    # We use the "all" directory to get all subjects in one file

    file_path = "all/#{split}-00000-of-00001.parquet"

    case Source.HuggingFace.download(@repo_id, file_path, []) do
      {:ok, local_path} ->
        case parse_mmlu_parquet(local_path, dataset_name, split, subjects, sample_size) do
          {:ok, _} = success ->
            success

          {:error, reason} ->
            if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
              load_synthetic(dataset_name, opts)
            else
              {:error, {:parse_failed, reason}}
            end
        end

      {:error, reason} ->
        if Application.get_env(:crucible_datasets, :fallback_to_synthetic, false) do
          load_synthetic(dataset_name, opts)
        else
          {:error, {:huggingface_download_failed, reason}}
        end
    end
  end

  defp parse_mmlu_parquet(path, dataset_name, split, subjects, sample_size) do
    case Format.Parquet.parse(path) do
      {:ok, rows} ->
        items =
          rows
          |> Enum.filter(fn row ->
            subject = row["subject"] || row[:subject]
            subject in subjects
          end)
          |> Enum.with_index()
          |> Enum.map(fn {row, idx} ->
            subject = row["subject"] || row[:subject]
            question = row["question"] || row[:question]
            choices = row["choices"] || row[:choices] || build_choices(row)
            answer = row["answer"] || row[:answer]

            %{
              id: "mmlu_#{subject}_#{split}_#{idx}",
              input: %{
                question: question,
                choices: if(is_list(choices), do: choices, else: [])
              },
              expected: normalize_answer(answer),
              metadata: %{
                subject: subject,
                split: split
              }
            }
          end)

        final_items = if sample_size, do: Enum.take(items, sample_size), else: items

        dataset =
          Dataset.new(
            to_string(dataset_name),
            "1.0",
            final_items,
            %{
              source: "huggingface:#{@repo_id}",
              license: "MIT",
              domain: if(dataset_name == :mmlu_stem, do: "STEM", else: "general"),
              subjects: subjects,
              split: split
            }
          )

        {:ok, dataset}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp build_choices(row) do
    # Some formats have A, B, C, D columns
    [
      row["A"] || row[:A],
      row["B"] || row[:B],
      row["C"] || row[:C],
      row["D"] || row[:D]
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_answer(answer) when is_integer(answer), do: answer

  defp normalize_answer(answer) when is_binary(answer) do
    case answer do
      "A" -> 0
      "B" -> 1
      "C" -> 2
      "D" -> 3
      _ -> String.to_integer(answer)
    end
  rescue
    _ -> 0
  end

  defp normalize_answer(_), do: 0

  # Generate synthetic data for offline testing
  defp load_synthetic(dataset_name, opts) do
    subjects =
      case dataset_name do
        :mmlu_stem -> @stem_subjects
        :mmlu -> @stem_subjects ++ ["history", "philosophy", "law"]
        _ -> @stem_subjects
      end

    items = generate_sample_items(subjects, opts)

    dataset =
      Dataset.new(
        to_string(dataset_name),
        "1.0",
        items,
        %{
          source: "synthetic",
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

  @doc """
  Get list of available subjects.
  """
  @spec subjects(atom()) :: [String.t()]
  def subjects(:mmlu_stem), do: @stem_subjects
  def subjects(:mmlu), do: @all_subjects
  def subjects(_), do: @all_subjects

  defp answer_to_index("A"), do: 0
  defp answer_to_index("B"), do: 1
  defp answer_to_index("C"), do: 2
  defp answer_to_index("D"), do: 3
  defp answer_to_index(_), do: 0
end
