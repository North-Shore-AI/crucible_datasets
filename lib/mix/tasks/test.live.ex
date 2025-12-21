defmodule Mix.Tasks.Test.Live do
  @shortdoc "Run tests with live data sources (no synthetic fallback)"
  @moduledoc """
  Runs the test suite against live data sources instead of synthetic data.

  This disables the synthetic fallback and requires real data sources to be available.

  ## Usage

      # Run all tests with live data
      mix test.live

      # Run specific test file with live data
      mix test.live test/dataset_manager/loader/gsm8k_test.exs

      # Pass any mix test options
      mix test.live --only integration --trace

  ## Configuration

  This task sets `fallback_to_synthetic: false` in the application config,
  which means loaders will fail if data sources are unavailable rather than
  silently falling back to synthetic data.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Set the config to disable synthetic fallback
    Application.put_env(:crucible_datasets, :fallback_to_synthetic, false)

    # Also set an application env that tests can check
    Application.put_env(:crucible_datasets, :test_mode, :live)

    # Run the standard test task with all passed arguments
    Mix.Task.run("test", args)
  end
end
