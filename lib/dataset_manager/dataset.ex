defmodule CrucibleDatasets.Dataset do
  @moduledoc """
  Unified dataset representation across all benchmark types.

  All datasets follow this schema regardless of source (MMLU, HumanEval, GSM8K, custom).
  """

  @type item :: %{
          required(:id) => String.t(),
          required(:input) => input_type(),
          required(:expected) => expected_type(),
          optional(:metadata) => map()
        }

  @type input_type ::
          String.t()
          | %{question: String.t(), choices: [String.t()]}
          | %{signature: String.t(), tests: [String.t()]}

  @type expected_type ::
          String.t()
          | integer()
          | %{answer: String.t(), reasoning: String.t()}

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          items: [item()],
          metadata: map()
        }

  @enforce_keys [:name, :version, :items, :metadata]
  defstruct [:name, :version, :items, :metadata]

  @doc """
  Create a new dataset with validation.
  """
  def new(name, version, items, metadata \\ %{}) do
    now = DateTime.utc_now()

    full_metadata =
      Map.merge(
        %{
          source: "unknown",
          license: "unknown",
          domain: "general",
          total_items: length(items),
          loaded_at: now,
          checksum: generate_checksum(items)
        },
        metadata
      )

    %__MODULE__{
      name: name,
      version: version,
      items: items,
      metadata: full_metadata
    }
  end

  @doc """
  Validate dataset schema.
  """
  def validate(%__MODULE__{} = dataset) do
    with :ok <- validate_required_fields(dataset),
         :ok <- validate_items(dataset.items),
         :ok <- validate_metadata(dataset.metadata) do
      {:ok, dataset}
    end
  end

  defp validate_required_fields(dataset) do
    required = [:name, :version, :items, :metadata]
    struct_keys = Map.keys(dataset) |> Enum.filter(&(&1 != :__struct__))
    missing = required -- struct_keys

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_items(items) when is_list(items) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case validate_item(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_items(_), do: {:error, :items_must_be_list}

  defp validate_item(item) when is_map(item) do
    required = [:id, :input, :expected]
    missing = required -- Map.keys(item)

    if missing == [] do
      :ok
    else
      {:error, {:invalid_item, Map.get(item, :id, "unknown"), missing}}
    end
  end

  defp validate_item(_), do: {:error, :item_must_be_map}

  defp validate_metadata(metadata) when is_map(metadata), do: :ok
  defp validate_metadata(_), do: {:error, :metadata_must_be_map}

  defp generate_checksum(items) do
    content = :erlang.term_to_binary(items)
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  @doc """
  Filter dataset items by predicate.

  ## Examples

      iex> dataset |> Dataset.filter(fn item ->
      ...>   item.metadata.difficulty == "hard"
      ...> end)
  """
  @spec filter(t(), (item() -> boolean())) :: t()
  def filter(%__MODULE__{} = dataset, predicate) when is_function(predicate, 1) do
    filtered_items = Enum.filter(dataset.items, predicate)

    %{
      dataset
      | items: filtered_items,
        metadata: Map.put(dataset.metadata, :total_items, length(filtered_items))
    }
  end

  @doc """
  Sort dataset items by key function or atom.

  ## Examples

      iex> dataset |> Dataset.sort(fn item -> item.id end)
      iex> dataset |> Dataset.sort(:id, :desc)
  """
  @spec sort(t(), (item() -> term()) | atom(), :asc | :desc) :: t()
  def sort(%__MODULE__{} = dataset, key_or_fn, order \\ :asc) do
    do_sort(dataset, key_or_fn, order)
  end

  defp do_sort(dataset, key, order) when is_atom(key) do
    do_sort(dataset, fn item -> Map.get(item, key) end, order)
  end

  defp do_sort(dataset, key_fn, order) when is_function(key_fn, 1) do
    sorted_items = Enum.sort_by(dataset.items, key_fn, order)
    %{dataset | items: sorted_items}
  end

  @doc """
  Shuffle multiple-choice options while preserving correct answer mapping.

  ## Options

  - `:seed` - Random seed for reproducible shuffling

  ## Examples

      iex> dataset |> Dataset.shuffle_choices(seed: 42)
  """
  @spec shuffle_choices(t(), keyword()) :: t()
  def shuffle_choices(%__MODULE__{} = dataset, opts \\ []) do
    seed = Keyword.get(opts, :seed)

    if seed do
      :rand.seed(:exsplus, {seed, seed, seed})
    end

    shuffled_items = Enum.map(dataset.items, &shuffle_item_choices/1)
    %{dataset | items: shuffled_items}
  end

  defp shuffle_item_choices(%{input: %{choices: choices}} = item) when is_list(choices) do
    # Get correct answer index
    correct_idx =
      case item.expected do
        idx when is_integer(idx) -> idx
        letter when is_binary(letter) -> letter_to_index(letter)
        _ -> nil
      end

    # Shuffle with position tracking
    indexed_choices = choices |> Enum.with_index()
    shuffled = Enum.shuffle(indexed_choices)

    # Find new position of correct answer
    new_idx =
      if correct_idx do
        Enum.find_index(shuffled, fn {_, orig_idx} -> orig_idx == correct_idx end)
      end

    # Update item
    new_choices = Enum.map(shuffled, fn {choice, _} -> choice end)

    %{
      item
      | input: Map.put(item.input, :choices, new_choices),
        expected: new_idx || item.expected
    }
  end

  defp shuffle_item_choices(item), do: item

  defp letter_to_index(letter) do
    letter
    |> String.upcase()
    |> String.to_charlist()
    |> hd()
    |> Kernel.-(?A)
  end

  @doc """
  Slice dataset by index range or start/count.

  ## Examples

      iex> dataset |> Dataset.slice(0..9)   # First 10 items
      iex> dataset |> Dataset.slice(10, 5)  # 5 items starting at index 10
  """
  @spec slice(t(), Range.t()) :: t()
  def slice(%__MODULE__{} = dataset, range) when is_struct(range, Range) do
    sliced_items = Enum.slice(dataset.items, range)

    %{
      dataset
      | items: sliced_items,
        metadata: Map.put(dataset.metadata, :total_items, length(sliced_items))
    }
  end

  @spec slice(t(), non_neg_integer(), non_neg_integer()) :: t()
  def slice(%__MODULE__{} = dataset, start, count) when is_integer(start) and is_integer(count) do
    sliced_items = Enum.slice(dataset.items, start, count)

    %{
      dataset
      | items: sliced_items,
        metadata: Map.put(dataset.metadata, :total_items, length(sliced_items))
    }
  end
end
