# examples/code/deepcoder_example.exs
# Run with: mix run examples/code/deepcoder_example.exs
#
# This example demonstrates loading code generation datasets like DeepCoder.

alias CrucibleDatasets.Loader.Code

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("DeepCoder Code Dataset Example")
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("")

# Load synthetic data for demo
IO.puts("Loading DeepCoder dataset (synthetic mode)...")
{:ok, dataset} = Code.load(:deepcoder, synthetic: true, sample_size: 10)

IO.puts("Total problems: #{length(dataset.items)}")
IO.puts("Available code datasets: #{inspect(Code.available_datasets())}")
IO.puts("")

# Show sample code problems
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("Sample Code Problems")
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("")

dataset.items
|> Enum.take(5)
|> Enum.each(fn item ->
  IO.puts("ID: #{item.id}")
  IO.puts("Language: #{item.input.language}")
  IO.puts("Problem:")
  IO.puts("  #{item.input.problem}")
  IO.puts("")
  IO.puts("Expected Solution:")
  IO.puts("```#{item.input.language}")
  IO.puts(item.expected)
  IO.puts("```")
  IO.puts("")
  IO.puts("-" <> String.duplicate("-", 40))
  IO.puts("")
end)

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("Example complete!")
IO.puts("=" <> String.duplicate("=", 60))
