defmodule CrucibleDatasets do
  @moduledoc """
  Centralized dataset management library for AI evaluation research.

  DatasetManager provides a unified interface for:
  - Loading standard benchmarks (MMLU, HumanEval, GSM8K)
  - Automatic caching and version tracking
  - Evaluation with multiple metrics
  - Dataset sampling and splitting
  - Custom dataset integration
  - Integration with CrucibleIR.DatasetRef

  ## Quick Start

      # Load a dataset
      {:ok, dataset} = CrucibleDatasets.load(:mmlu_stem, sample_size: 100)

      # Load using DatasetRef (from crucible_ir)
      ref = %CrucibleIR.DatasetRef{name: :mmlu_stem, split: :train, options: [sample_size: 100]}
      {:ok, dataset} = CrucibleDatasets.load(ref)

      # Create predictions
      predictions = [
        %{id: "mmlu_stem_0", predicted: 0, metadata: %{}},
        %{id: "mmlu_stem_1", predicted: 2, metadata: %{}}
      ]

      # Evaluate
      {:ok, results} = CrucibleDatasets.evaluate(predictions,
        dataset: dataset,
        metrics: [:exact_match, :f1],
        model_name: "my_model"
      )

      IO.inspect(results.accuracy)

  ## Supported Datasets

  - `:mmlu` - Massive Multitask Language Understanding (all subjects)
  - `:mmlu_stem` - MMLU STEM subjects only
  - `:humaneval` - Code generation benchmark
  - `:gsm8k` - Grade school math problems

  ## Custom Datasets

  You can load custom datasets from local files:

      {:ok, dataset} = CrucibleDatasets.load("my_dataset",
        source: "path/to/data.jsonl"
      )
  """

  alias CrucibleDatasets.{Loader, Evaluator, Sampler, Cache, Registry, ResultStore, Exporter}

  # Delegates for main API

  @doc """
  Load a dataset by name.

  See `CrucibleDatasets.Loader.load/2` for full documentation.
  """
  defdelegate load(dataset_name, opts \\ []), to: Loader

  @doc """
  Evaluate predictions against a dataset.

  See `CrucibleDatasets.Evaluator.evaluate/2` for full documentation.
  """
  defdelegate evaluate(predictions, opts \\ []), to: Evaluator

  @doc """
  Batch evaluate multiple models.

  See `CrucibleDatasets.Evaluator.evaluate_batch/2` for full documentation.
  """
  defdelegate evaluate_batch(model_predictions, opts \\ []), to: Evaluator

  @doc """
  Create random sample from dataset.

  See `CrucibleDatasets.Sampler.random/2` for full documentation.
  """
  defdelegate random_sample(dataset, opts \\ []), to: Sampler, as: :random

  @doc """
  Create stratified sample from dataset.

  See `CrucibleDatasets.Sampler.stratified/2` for full documentation.
  """
  defdelegate stratified_sample(dataset, opts \\ []), to: Sampler, as: :stratified

  @doc """
  Create k-fold cross-validation splits.

  See `CrucibleDatasets.Sampler.k_fold/2` for full documentation.
  """
  defdelegate k_fold(dataset, opts \\ []), to: Sampler

  @doc """
  Split dataset into train and test sets.

  See `CrucibleDatasets.Sampler.train_test_split/2` for full documentation.
  """
  defdelegate train_test_split(dataset, opts \\ []), to: Sampler

  @doc """
  List all cached datasets.

  See `CrucibleDatasets.Cache.list/0` for full documentation.
  """
  defdelegate list_cached(), to: Cache, as: :list

  @doc """
  Clear all cached datasets.

  See `CrucibleDatasets.Cache.clear_all/0` for full documentation.
  """
  defdelegate clear_cache(), to: Cache, as: :clear_all

  @doc """
  Invalidate cache for specific dataset.

  See `CrucibleDatasets.Loader.invalidate_cache/1` for full documentation.
  """
  defdelegate invalidate_cache(dataset_name), to: Loader

  # Registry delegates

  @doc """
  List all available datasets.

  See `CrucibleDatasets.Registry.list_available/0` for full documentation.
  """
  defdelegate list_available(), to: Registry

  @doc """
  Get metadata for a dataset.

  See `CrucibleDatasets.Registry.get_metadata/1` for full documentation.
  """
  defdelegate get_metadata(dataset_name), to: Registry

  # Result persistence delegates

  @doc """
  Save evaluation result to persistent storage.

  See `CrucibleDatasets.ResultStore.save/2` for full documentation.
  """
  defdelegate save_result(result, opts \\ []), to: ResultStore, as: :save

  @doc """
  Load evaluation result by ID.

  See `CrucibleDatasets.ResultStore.load/1` for full documentation.
  """
  defdelegate load_result(result_id), to: ResultStore, as: :load

  @doc """
  Query evaluation results with filters.

  See `CrucibleDatasets.ResultStore.query/1` for full documentation.
  """
  defdelegate query_results(filters \\ []), to: ResultStore, as: :query

  # Export delegates

  @doc """
  Export results to CSV format.

  See `CrucibleDatasets.Exporter.to_csv/3` for full documentation.
  """
  defdelegate export_csv(results, output_path, opts \\ []), to: Exporter, as: :to_csv

  @doc """
  Export results to JSON Lines format.

  See `CrucibleDatasets.Exporter.to_jsonl/2` for full documentation.
  """
  defdelegate export_jsonl(results, output_path), to: Exporter, as: :to_jsonl

  @doc """
  Generate markdown report from results.

  See `CrucibleDatasets.Exporter.to_markdown/2` for full documentation.
  """
  defdelegate export_markdown(results, opts \\ []), to: Exporter, as: :to_markdown

  @doc """
  Generate HTML report from results.

  See `CrucibleDatasets.Exporter.to_html/2` for full documentation.
  """
  defdelegate export_html(results, opts \\ []), to: Exporter, as: :to_html
end
