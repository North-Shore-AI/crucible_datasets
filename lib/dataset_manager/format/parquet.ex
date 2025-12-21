defmodule CrucibleDatasets.Format.Parquet do
  @moduledoc """
  Parquet format parser using Explorer.

  Parses Apache Parquet files into list of maps.

  ## Example

      {:ok, items} = Parquet.parse("data.parquet")
      # => [%{"id" => 1, "text" => "hello"}, ...]

  ## Dependencies

  Requires `explorer` package for Parquet support.
  """

  @behaviour CrucibleDatasets.Format

  @impl true
  def parse(path) do
    case Explorer.DataFrame.from_parquet(path) do
      {:ok, df} ->
        items = Explorer.DataFrame.to_rows(df)
        {:ok, items}

      {:error, reason} ->
        {:error, {:parquet_error, reason}}
    end
  rescue
    e -> {:error, {:parse_error, e}}
  end

  @impl true
  def parse_stream(_stream) do
    # Parquet doesn't support true streaming
    # Would need chunked reads via Explorer
    raise "Parquet format does not support streaming. Use parse/1 instead."
  end

  @impl true
  def handles?(path) do
    ext = Path.extname(path) |> String.downcase()
    ext == ".parquet"
  end
end
