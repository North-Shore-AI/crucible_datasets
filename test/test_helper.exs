# Exclude integration and slow tests by default
# Run with: mix test --include integration --include slow
#
# To run tests with live data sources:
#   mix test.live
ExUnit.start(exclude: [:integration, :slow])

defmodule TestHelper do
  @moduledoc "Test utilities for data source control"

  def live_mode?, do: Application.get_env(:crucible_datasets, :test_mode) == :live

  def data_opts(extra \\ []) do
    base = if live_mode?(), do: [], else: [synthetic: true]
    Keyword.merge(base, extra)
  end
end
