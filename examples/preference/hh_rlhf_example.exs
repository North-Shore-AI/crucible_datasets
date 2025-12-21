# examples/preference/hh_rlhf_example.exs
# Run with: mix run examples/preference/hh_rlhf_example.exs
#
# This example demonstrates loading preference/comparison datasets
# like HH-RLHF for DPO training.

alias CrucibleDatasets.Loader.Preference
alias CrucibleDatasets.Types.{Comparison, LabeledComparison}

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("HH-RLHF Preference Dataset Example")
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("")

# Load synthetic data for demo
IO.puts("Loading HH-RLHF dataset (synthetic mode)...")
{:ok, dataset} = Preference.load(:hh_rlhf, synthetic: true, sample_size: 10)

IO.puts("Total comparisons: #{length(dataset.items)}")
IO.puts("Available preference datasets: #{inspect(Preference.available_datasets())}")
IO.puts("")

# Show sample comparisons
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("Sample Comparisons")
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("")

dataset.items
|> Enum.take(3)
|> Enum.each(fn item ->
  comp = item.input.comparison
  label = item.expected

  IO.puts("ID: #{item.id}")
  IO.puts("Prompt: #{String.slice(comp.prompt, 0, 50)}...")
  IO.puts("")
  IO.puts("Response A (#{if label.preferred == :a, do: "PREFERRED", else: "rejected"}):")
  IO.puts("  #{String.slice(comp.response_a, 0, 60)}...")
  IO.puts("")
  IO.puts("Response B (#{if label.preferred == :b, do: "PREFERRED", else: "rejected"}):")
  IO.puts("  #{String.slice(comp.response_b, 0, 60)}...")
  IO.puts("")
  IO.puts("Label: #{label.preferred}")
  IO.puts("Score for loss: #{LabeledComparison.to_score(label)}")
  IO.puts("")
  IO.puts("-" <> String.duplicate("-", 40))
  IO.puts("")
end)

# Demonstrate label utilities
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("Label Utilities Demo")
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("")

Enum.each(["A", "B", "tie", "chosen"], fn label_str ->
  {:ok, label} = LabeledComparison.from_label(label_str)

  IO.puts(
    "Label '#{label_str}' -> preferred: #{label.preferred}, score: #{LabeledComparison.to_score(label)}"
  )
end)

IO.puts("")

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("Example complete!")
IO.puts("=" <> String.duplicate("=", 60))
