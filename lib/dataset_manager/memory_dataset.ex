defmodule CrucibleDatasets.MemoryDataset do
  @moduledoc """
  Lightweight in-memory dataset construction.
  Maps to inspect_ai's MemoryDataset.

  ## Examples

      iex> CrucibleDatasets.MemoryDataset.from_list([
      ...>   %{input: "What is 2+2?", expected: "4"},
      ...>   %{input: "What is 3+3?", expected: "6"}
      ...> ])
      %CrucibleDatasets.Dataset{name: "memory_...", items: [...]}

      iex> CrucibleDatasets.MemoryDataset.from_list([
      ...>   %{input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}}
      ...> ], name: "my_dataset")
      %CrucibleDatasets.Dataset{name: "my_dataset", items: [...]}
  """

  alias CrucibleDatasets.Dataset

  @doc """
  Create a dataset from a list of items.

  ## Options

  - `:name` - Dataset name (default: auto-generated "memory_<unique_id>")
  - `:version` - Dataset version (default: "1.0.0")
  - `:auto_id` - Auto-generate IDs for items without them (default: true)

  ## Examples

      iex> items = [
      ...>   %{input: "What is 2+2?", expected: "4"},
      ...>   %{input: "What is 3+3?", expected: "6"}
      ...> ]
      iex> dataset = CrucibleDatasets.MemoryDataset.from_list(items)
      iex> length(dataset.items)
      2

      iex> items = [
      ...>   %{input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}}
      ...> ]
      iex> dataset = CrucibleDatasets.MemoryDataset.from_list(items, name: "my_dataset")
      iex> dataset.name
      "my_dataset"
  """
  @spec from_list([map()], keyword()) :: Dataset.t()
  def from_list(items, opts \\ []) when is_list(items) do
    name = Keyword.get(opts, :name, generate_name())
    version = Keyword.get(opts, :version, "1.0.0")
    auto_id = Keyword.get(opts, :auto_id, true)

    normalized_items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, idx} ->
        normalize_item(item, idx, auto_id)
      end)

    Dataset.new(name, version, normalized_items, %{
      source: :memory,
      total_items: length(normalized_items)
    })
  end

  @doc """
  Create a dataset from a list of samples.

  This is an alias for `from_list/2` for clarity when using Sample structs.

  ## Examples

      iex> samples = [
      ...>   %{input: "What is 2+2?", expected: "4"},
      ...>   %{input: "What is 3+3?", expected: "6"}
      ...> ]
      iex> dataset = CrucibleDatasets.MemoryDataset.from_samples(samples)
      iex> length(dataset.items)
      2
  """
  @spec from_samples([map()], keyword()) :: Dataset.t()
  def from_samples(samples, opts \\ []) do
    from_list(samples, opts)
  end

  defp normalize_item(item, idx, auto_id) do
    id =
      if auto_id and not Map.has_key?(item, :id) do
        "item_#{idx}"
      else
        Map.get(item, :id)
      end

    %{
      id: id,
      input: Map.fetch!(item, :input),
      expected: Map.get(item, :expected, ""),
      metadata: Map.get(item, :metadata, %{})
    }
  end

  defp generate_name do
    "memory_#{:erlang.unique_integer([:positive])}"
  end
end
