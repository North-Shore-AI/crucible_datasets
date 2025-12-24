defmodule CrucibleDatasets.FieldMapping do
  @moduledoc """
  Declarative field mapping for dataset loading.
  Maps to inspect_ai's FieldSpec pattern.

  ## Examples

      iex> mapping = FieldMapping.new(
      ...>   input: "question",
      ...>   expected: "answer",
      ...>   metadata: ["difficulty", "subject"]
      ...> )
      iex> record = %{"question" => "Q1", "answer" => "A1", "difficulty" => "easy"}
      iex> FieldMapping.apply(mapping, record)
      %{id: nil, input: "Q1", expected: "A1", metadata: %{difficulty: "easy"}}
  """

  @type field_spec :: %{
          source: String.t() | atom(),
          target: :input | :expected | :id | {:metadata, atom()},
          transform: (term() -> term()) | nil
        }

  @type t :: %__MODULE__{
          input: String.t() | atom(),
          expected: String.t() | atom(),
          id: String.t() | atom() | nil,
          choices: String.t() | atom() | nil,
          metadata: [String.t() | atom()] | nil,
          transforms: %{atom() => (term() -> term())}
        }

  defstruct [
    :input,
    :expected,
    :id,
    :choices,
    :metadata,
    :transforms
  ]

  @doc """
  Create a field mapping specification.

  ## Options

  - `:input` - Source field for input (default: `:input`)
  - `:expected` - Source field for expected output (default: `:expected`)
  - `:id` - Source field for item ID (default: `:id`)
  - `:choices` - Source field for multiple choice options (default: `nil`)
  - `:metadata` - List of fields to include in metadata (default: `nil`)
  - `:transforms` - Map of field transforms (default: `%{}`)

  ## Examples

      iex> FieldMapping.new(
      ...>   input: "question",
      ...>   expected: "answer",
      ...>   metadata: ["difficulty", "subject"]
      ...> )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      input: Keyword.get(opts, :input, :input),
      expected: Keyword.get(opts, :expected, :expected),
      id: Keyword.get(opts, :id, :id),
      choices: Keyword.get(opts, :choices),
      metadata: Keyword.get(opts, :metadata),
      transforms: Keyword.get(opts, :transforms, %{})
    }
  end

  @doc """
  Apply field mapping to a raw record.

  ## Examples

      iex> mapping = FieldMapping.new(input: "question", expected: "answer")
      iex> record = %{"question" => "What is 2+2?", "answer" => "4"}
      iex> FieldMapping.apply(mapping, record)
      %{id: nil, input: "What is 2+2?", expected: "4", metadata: %{}}
  """
  @spec apply(t(), map()) :: map()
  def apply(%__MODULE__{} = mapping, record) when is_map(record) do
    base = %{
      id: get_field(record, mapping.id),
      input: build_input(record, mapping),
      expected: get_and_transform(record, mapping.expected, mapping.transforms[:expected])
    }

    metadata =
      if mapping.metadata do
        mapping.metadata
        |> Enum.map(fn field ->
          {to_atom(field), get_field(record, field)}
        end)
        |> Map.new()
      else
        %{}
      end

    Map.put(base, :metadata, metadata)
  end

  defp build_input(record, %{choices: nil} = mapping) do
    get_and_transform(record, mapping.input, mapping.transforms[:input])
  end

  defp build_input(record, mapping) do
    %{
      question: get_and_transform(record, mapping.input, mapping.transforms[:input]),
      choices: get_field(record, mapping.choices) |> List.wrap()
    }
  end

  defp get_field(_record, nil), do: nil

  defp get_field(record, field) when is_atom(field) do
    Map.get(record, field) || Map.get(record, Atom.to_string(field))
  end

  defp get_field(record, field) when is_binary(field) do
    Map.get(record, field) || Map.get(record, String.to_existing_atom(field))
  rescue
    ArgumentError -> Map.get(record, field)
  end

  defp get_and_transform(record, field, nil), do: get_field(record, field)

  defp get_and_transform(record, field, transform) do
    record |> get_field(field) |> transform.()
  end

  defp to_atom(field) when is_atom(field), do: field
  defp to_atom(field) when is_binary(field), do: String.to_atom(field)
end
