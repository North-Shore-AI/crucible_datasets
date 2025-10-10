defmodule DatasetManager.Dataset do
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
          metadata: %{
            source: String.t(),
            license: String.t(),
            domain: String.t(),
            total_items: non_neg_integer(),
            loaded_at: DateTime.t(),
            checksum: String.t()
          }
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
end
