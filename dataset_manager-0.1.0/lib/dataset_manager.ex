defmodule DatasetManager do
  @moduledoc """
  Centralized dataset management library for AI evaluation research.

  DatasetManager provides a unified interface for:
  - Loading standard benchmarks (MMLU, HumanEval, GSM8K)
  - Automatic caching and version tracking
  - Evaluation with multiple metrics
  - Dataset sampling and splitting
  - Custom dataset integration

  ## Quick Start

      # Load a dataset
      {:ok, dataset} = DatasetManager.load(:mmlu_stem, sample_size: 100)

      # Create predictions
      predictions = [
        %{id: "mmlu_stem_0", predicted: 0, metadata: %{}},
        %{id: "mmlu_stem_1", predicted: 2, metadata: %{}}
      ]

      # Evaluate
      {:ok, results} = DatasetManager.evaluate(predictions,
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

      {:ok, dataset} = DatasetManager.load("my_dataset",
        source: "path/to/data.jsonl"
      )
  """

  alias DatasetManager.{Loader, Evaluator, Sampler, Cache}

  # Delegates for main API

  @doc """
  Load a dataset by name.

  See `DatasetManager.Loader.load/2` for full documentation.
  """
  defdelegate load(dataset_name, opts \\ []), to: Loader

  @doc """
  Evaluate predictions against a dataset.

  See `DatasetManager.Evaluator.evaluate/2` for full documentation.
  """
  defdelegate evaluate(predictions, opts \\ []), to: Evaluator

  @doc """
  Batch evaluate multiple models.

  See `DatasetManager.Evaluator.evaluate_batch/2` for full documentation.
  """
  defdelegate evaluate_batch(model_predictions, opts \\ []), to: Evaluator

  @doc """
  Create random sample from dataset.

  See `DatasetManager.Sampler.random/2` for full documentation.
  """
  defdelegate random_sample(dataset, opts \\ []), to: Sampler, as: :random

  @doc """
  Create stratified sample from dataset.

  See `DatasetManager.Sampler.stratified/2` for full documentation.
  """
  defdelegate stratified_sample(dataset, opts \\ []), to: Sampler, as: :stratified

  @doc """
  Create k-fold cross-validation splits.

  See `DatasetManager.Sampler.k_fold/2` for full documentation.
  """
  defdelegate k_fold(dataset, opts \\ []), to: Sampler

  @doc """
  Split dataset into train and test sets.

  See `DatasetManager.Sampler.train_test_split/2` for full documentation.
  """
  defdelegate train_test_split(dataset, opts \\ []), to: Sampler

  @doc """
  List all cached datasets.

  See `DatasetManager.Cache.list/0` for full documentation.
  """
  defdelegate list_cached(), to: Cache, as: :list

  @doc """
  Clear all cached datasets.

  See `DatasetManager.Cache.clear_all/0` for full documentation.
  """
  defdelegate clear_cache(), to: Cache, as: :clear_all

  @doc """
  Invalidate cache for specific dataset.

  See `DatasetManager.Loader.invalidate_cache/1` for full documentation.
  """
  defdelegate invalidate_cache(dataset_name), to: Loader
end
