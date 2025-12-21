defmodule CrucibleDatasets.Format.JSONL do
  @moduledoc """
  JSON Lines format parser.

  Parses files where each line is a valid JSON object.

  ## Example

      {:ok, items} = JSONL.parse("data.jsonl")
      # => [%{"id" => 1, ...}, %{"id" => 2, ...}]

  """

  @behaviour CrucibleDatasets.Format

  @impl true
  def parse(path) do
    items =
      path
      |> File.stream!(:line)
      |> parse_stream()
      |> Enum.to_list()

    {:ok, items}
  rescue
    e -> {:error, {:parse_error, e}}
  end

  @impl true
  def parse_stream(stream) do
    stream
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)
  end

  @impl true
  def handles?(path) do
    ext = Path.extname(path) |> String.downcase()
    ext in [".jsonl", ".jsonlines"]
  end
end
