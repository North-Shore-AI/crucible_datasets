defmodule CrucibleDatasets.ResultStore do
  @moduledoc """
  Persistent storage for evaluation results.

  Stores results in `~/.elixir_ai_research/results/` with indexing for fast
  retrieval and querying. Results are organized by date and include a searchable
  index for filtering by model, dataset, accuracy, and other criteria.

  ## Storage Structure

      ~/.elixir_ai_research/results/
      ├── index.json                # Searchable index of all results
      ├── 2025-11-25/
      │   ├── gpt4_mmlu_stem_abc123.json
      │   ├── claude_gsm8k_def456.json
      │   └── ...
      ├── 2025-11-24/
      │   └── ...

  ## Examples

      # Save a result
      {:ok, result_id} = CrucibleDatasets.ResultStore.save(evaluation_result)

      # Load a result
      {:ok, result} = CrucibleDatasets.ResultStore.load(result_id)

      # Query results
      {:ok, results} = CrucibleDatasets.ResultStore.query(
        model: "gpt-4",
        dataset: :mmlu_stem,
        min_accuracy: 0.8
      )

      # List all result summaries
      {:ok, summaries} = CrucibleDatasets.ResultStore.list_all()

      # Delete a result
      :ok = CrucibleDatasets.ResultStore.delete(result_id)
  """

  alias CrucibleDatasets.EvaluationResult

  @storage_env_var "CRUCIBLE_DATASETS_RESULTS_DIR"

  @type result_id :: String.t()
  @type query_filter ::
          {:model, String.t()}
          | {:dataset, atom() | String.t()}
          | {:min_accuracy, float()}
          | {:max_accuracy, float()}
          | {:date_from, Date.t()}
          | {:date_to, Date.t()}

  @doc """
  Save an evaluation result to persistent storage.

  Generates a unique ID based on model name, dataset, and timestamp.

  ## Parameters

    * `result` - EvaluationResult struct
    * `opts` - Optional keyword list
      * `:id` - Custom result ID (auto-generated if not provided)

  ## Returns

    * `{:ok, result_id}` - Successfully saved
    * `{:error, reason}` - Save failed

  ## Examples

      {:ok, result_id} = CrucibleDatasets.ResultStore.save(result)
      # => {:ok, "2025-11-25/gpt4_mmlu_stem_20251125_143022_abc123"}
  """
  @spec save(EvaluationResult.t(), keyword()) :: {:ok, result_id()} | {:error, term()}
  def save(%EvaluationResult{} = result, opts \\ []) do
    result_id = Keyword.get(opts, :id) || generate_result_id(result)

    with :ok <- ensure_storage_dir(),
         {:ok, result_path} <- build_result_path(result_id),
         :ok <- write_result(result_path, result),
         :ok <- update_index(result_id, result) do
      {:ok, result_id}
    end
  end

  @doc """
  Load an evaluation result by ID.

  ## Parameters

    * `result_id` - Result identifier

  ## Returns

    * `{:ok, result}` - Result loaded successfully
    * `{:error, :not_found}` - Result doesn't exist
    * `{:error, reason}` - Other error

  ## Examples

      {:ok, result} = CrucibleDatasets.ResultStore.load("2025-11-25/gpt4_mmlu_stem_abc123")
  """
  @spec load(result_id()) :: {:ok, EvaluationResult.t()} | {:error, term()}
  def load(result_id) do
    with {:ok, result_path} <- build_result_path(result_id),
         true <- File.exists?(result_path),
         {:ok, content} <- File.read(result_path),
         {:ok, json} <- Jason.decode(content) do
      result = deserialize_result(json)
      {:ok, result}
    else
      false -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Query results with filters.

  ## Parameters

    * `filters` - Keyword list of query filters (see module documentation)

  ## Examples

      # Find all GPT-4 results
      {:ok, results} = CrucibleDatasets.ResultStore.query(model: "gpt-4")

      # Find high-accuracy results from last week
      {:ok, results} = CrucibleDatasets.ResultStore.query(
        min_accuracy: 0.9,
        date_from: Date.add(Date.utc_today(), -7)
      )

      # Find results for specific dataset
      {:ok, results} = CrucibleDatasets.ResultStore.query(dataset: :mmlu_stem)
  """
  @spec query(keyword()) :: {:ok, [EvaluationResult.t()]} | {:error, term()}
  def query(filters \\ []) do
    with {:ok, index} <- load_index() do
      filtered_entries =
        index
        |> Enum.filter(&matches_filters?(&1, filters))

      results =
        filtered_entries
        |> Enum.map(fn entry -> load(entry["id"]) end)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, result} -> result end)

      {:ok, results}
    end
  end

  @doc """
  List all stored results with summary information.

  Returns lightweight summaries without loading full results.

  ## Examples

      {:ok, summaries} = CrucibleDatasets.ResultStore.list_all()
      # => {:ok, [
      #   %{
      #     id: "...",
      #     model: "gpt-4",
      #     dataset: "mmlu_stem",
      #     accuracy: 0.89,
      #     timestamp: ~U[2025-11-25 10:30:00Z]
      #   },
      #   ...
      # ]}
  """
  @spec list_all() :: {:ok, [map()]} | {:error, term()}
  def list_all do
    case load_index() do
      {:ok, index} -> {:ok, index}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a stored result.

  Removes the result file and updates the index.

  ## Parameters

    * `result_id` - Result identifier

  ## Examples

      :ok = CrucibleDatasets.ResultStore.delete("2025-11-25/gpt4_mmlu_stem_abc123")
  """
  @spec delete(result_id()) :: :ok | {:error, term()}
  def delete(result_id) do
    with {:ok, result_path} <- build_result_path(result_id),
         :ok <- File.rm(result_path),
         :ok <- remove_from_index(result_id) do
      :ok
    else
      # Already deleted
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Clear all stored results.

  **Warning:** This deletes all evaluation results permanently.

  ## Examples

      :ok = CrucibleDatasets.ResultStore.clear_all()
  """
  @spec clear_all() :: :ok
  def clear_all do
    storage_dir()
    |> File.rm_rf()

    :ok
  end

  ## Private functions

  defp ensure_storage_dir do
    storage_dir()
    |> File.mkdir_p()
  end

  defp generate_result_id(result) do
    date = DateTime.to_date(result.timestamp)
    date_str = Date.to_iso8601(date)

    model_slug = slugify(result.model)
    dataset_slug = slugify(result.dataset_name)

    timestamp_str =
      result.timestamp
      |> DateTime.to_naive()
      |> NaiveDateTime.to_iso8601()
      |> String.replace(["-", ":", "."], "")
      |> String.slice(0..13)

    random_suffix =
      :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower) |> String.slice(0..5)

    "#{date_str}/#{model_slug}_#{dataset_slug}_#{timestamp_str}_#{random_suffix}"
  end

  defp slugify(str) do
    str
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^\w]+/, "_")
    |> String.trim("_")
  end

  defp build_result_path(result_id) do
    # Extract date directory from result_id if present
    path =
      if String.contains?(result_id, "/") do
        Path.join(storage_dir(), result_id <> ".json")
      else
        # Legacy format without date prefix
        Path.join(storage_dir(), result_id <> ".json")
      end

    # Ensure parent directory exists
    path
    |> Path.dirname()
    |> File.mkdir_p()

    {:ok, path}
  end

  defp write_result(path, result) do
    json = EvaluationResult.to_json(result)
    content = Jason.encode!(json, pretty: true)
    File.write(path, content)
  end

  defp load_index do
    if File.exists?(index_file()) do
      with {:ok, content} <- File.read(index_file()),
           {:ok, data} <- Jason.decode(content) do
        {:ok, Map.get(data, "results", [])}
      end
    else
      {:ok, []}
    end
  end

  defp update_index(result_id, result) do
    {:ok, index} = load_index()

    # Create index entry
    entry = %{
      "id" => result_id,
      "model" => result.model,
      "dataset" => result.dataset_name,
      "dataset_version" => result.dataset_version,
      "accuracy" => result.accuracy,
      "total_items" => result.total_items,
      "timestamp" => DateTime.to_iso8601(result.timestamp),
      "metrics" => result.metrics,
      "duration_ms" => result.duration_ms
    }

    # Remove existing entry with same ID (if updating)
    new_index =
      index
      |> Enum.reject(&(&1["id"] == result_id))
      |> then(&[entry | &1])

    # Write updated index
    index_data = %{
      "results" => new_index,
      "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
    }

    content = Jason.encode!(index_data, pretty: true)

    File.mkdir_p(storage_dir())
    File.write(index_file(), content)
  end

  defp remove_from_index(result_id) do
    {:ok, index} = load_index()

    new_index = Enum.reject(index, &(&1["id"] == result_id))

    index_data = %{
      "results" => new_index,
      "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
    }

    content = Jason.encode!(index_data, pretty: true)

    File.write(index_file(), content)
  end

  defp matches_filters?(entry, filters) do
    Enum.all?(filters, fn filter -> matches_filter?(entry, filter) end)
  end

  defp matches_filter?(entry, {:model, model}) do
    entry["model"] == model
  end

  defp matches_filter?(entry, {:dataset, dataset}) do
    entry["dataset"] == to_string(dataset)
  end

  defp matches_filter?(entry, {:min_accuracy, min_acc}) do
    entry["accuracy"] >= min_acc
  end

  defp matches_filter?(entry, {:max_accuracy, max_acc}) do
    entry["accuracy"] <= max_acc
  end

  defp matches_filter?(entry, {:date_from, date_from}) do
    case DateTime.from_iso8601(entry["timestamp"]) do
      {:ok, dt, _} -> Date.compare(DateTime.to_date(dt), date_from) != :lt
      _ -> false
    end
  end

  defp matches_filter?(entry, {:date_to, date_to}) do
    case DateTime.from_iso8601(entry["timestamp"]) do
      {:ok, dt, _} -> Date.compare(DateTime.to_date(dt), date_to) != :gt
      _ -> false
    end
  end

  defp matches_filter?(_entry, _unknown_filter), do: true

  defp deserialize_result(json) do
    timestamp =
      case DateTime.from_iso8601(json["timestamp"]) do
        {:ok, dt, _} -> dt
        _ -> DateTime.utc_now()
      end

    %EvaluationResult{
      dataset_name: json["dataset_name"],
      dataset_version: json["dataset_version"],
      model: json["model"],
      total_items: json["total_items"],
      correct_items: json["correct_items"],
      accuracy: json["accuracy"],
      metrics: atomize_keys(json["metrics"]),
      item_results: json["item_results"],
      timestamp: timestamp,
      duration_ms: json["duration_ms"]
    }
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_atom(k), else: k
      {key, v}
    end)
  end

  defp storage_dir do
    System.get_env(@storage_env_var)
    |> case do
      nil -> Path.expand("~/.elixir_ai_research/results")
      dir -> Path.expand(dir)
    end
  end

  defp index_file do
    Path.join(storage_dir(), "index.json")
  end
end
