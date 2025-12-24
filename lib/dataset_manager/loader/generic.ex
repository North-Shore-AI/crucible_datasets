defmodule CrucibleDatasets.Loader.Generic do
  @moduledoc """
  Generic dataset loader with field mapping support.
  Load CSV, JSON, JSONL with declarative field specs.

  ## Examples

      iex> mapping = FieldMapping.new(
      ...>   input: "question",
      ...>   expected: "answer",
      ...>   metadata: ["difficulty"]
      ...> )
      iex> {:ok, dataset} = Loader.Generic.load("data.jsonl", fields: mapping)
  """

  alias CrucibleDatasets.{Dataset, FieldMapping}

  @doc """
  Load a dataset from a file with field mapping.

  ## Options

  - `:name` - Dataset name (default: filename without extension)
  - `:version` - Dataset version (default: "1.0.0")
  - `:format` - File format (`:jsonl`, `:json`, `:csv`, or auto-detect)
  - `:fields` - FieldMapping specification (default: FieldMapping.new())
  - `:auto_id` - Auto-generate IDs for items (default: true)
  - `:limit` - Maximum number of items to load
  - `:shuffle` - Shuffle items after loading (default: false)
  - `:seed` - Random seed for shuffling

  ## Examples

      iex> mapping = FieldMapping.new(input: "question", expected: "answer")
      iex> {:ok, dataset} = Loader.Generic.load("data.jsonl", fields: mapping)

      iex> {:ok, dataset} = Loader.Generic.load("data.csv",
      ...>   name: "my_dataset",
      ...>   format: :csv,
      ...>   fields: FieldMapping.new(
      ...>     input: "question",
      ...>     expected: "answer",
      ...>     metadata: ["difficulty"]
      ...>   ),
      ...>   limit: 100
      ...> )
  """
  @spec load(String.t(), keyword()) :: {:ok, Dataset.t()} | {:error, term()}
  def load(path, opts \\ []) do
    name = Keyword.get(opts, :name, Path.basename(path, Path.extname(path)))
    version = Keyword.get(opts, :version, "1.0.0")
    format = Keyword.get(opts, :format) || detect_format(path)
    fields = Keyword.get(opts, :fields, FieldMapping.new())
    auto_id = Keyword.get(opts, :auto_id, true)
    limit = Keyword.get(opts, :limit)
    shuffle = Keyword.get(opts, :shuffle, false)
    seed = Keyword.get(opts, :seed)

    with {:ok, records} <- read_file(path, format),
         items <- process_records(records, fields, auto_id),
         items <- maybe_limit(items, limit),
         items <- maybe_shuffle(items, shuffle, seed) do
      {:ok,
       Dataset.new(name, version, items, %{
         source: path,
         format: format,
         total_items: length(items)
       })}
    end
  end

  defp detect_format(path) do
    case Path.extname(path) do
      ".json" -> :json
      ".jsonl" -> :jsonl
      ".csv" -> :csv
      _ -> :unknown
    end
  end

  defp read_file(path, :jsonl) do
    case File.read(path) do
      {:ok, content} ->
        records =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&Jason.decode!/1)

        {:ok, records}

      error ->
        error
    end
  end

  defp read_file(path, :json) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, records} when is_list(records) -> {:ok, records}
          {:ok, record} -> {:ok, [record]}
          error -> error
        end

      error ->
        error
    end
  end

  defp read_file(path, :csv) do
    case File.read(path) do
      {:ok, content} ->
        [header | rows] = String.split(content, "\n", trim: true)
        keys = String.split(header, ",") |> Enum.map(&String.trim/1)

        records =
          Enum.map(rows, fn row ->
            values = String.split(row, ",") |> Enum.map(&String.trim/1)
            Enum.zip(keys, values) |> Map.new()
          end)

        {:ok, records}

      error ->
        error
    end
  end

  defp process_records(records, fields, auto_id) do
    records
    |> Enum.with_index(1)
    |> Enum.map(fn {record, idx} ->
      item = FieldMapping.apply(fields, record)

      if auto_id and (is_nil(item.id) or item.id == "") do
        Map.put(item, :id, "item_#{idx}")
      else
        item
      end
    end)
  end

  defp maybe_limit(items, nil), do: items
  defp maybe_limit(items, limit), do: Enum.take(items, limit)

  defp maybe_shuffle(items, false, _), do: items

  defp maybe_shuffle(items, true, nil), do: Enum.shuffle(items)

  defp maybe_shuffle(items, true, seed) do
    :rand.seed(:exsplus, {seed, seed, seed})
    Enum.shuffle(items)
  end
end
