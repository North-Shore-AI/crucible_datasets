# examples/chat/tulu3_sft_example.exs
# Run with: mix run examples/chat/tulu3_sft_example.exs
#
# This example demonstrates loading chat datasets like Tulu-3-SFT.

alias CrucibleDatasets.Loader.Chat
alias CrucibleDatasets.Types.Conversation

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("Tulu-3-SFT Chat Dataset Example")
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("")

# Load synthetic data for demo
IO.puts("Loading Tulu-3-SFT dataset (synthetic mode)...")
{:ok, dataset} = Chat.load(:tulu3_sft, synthetic: true, sample_size: 10)

IO.puts("Total conversations: #{length(dataset.items)}")
IO.puts("Available chat datasets: #{inspect(Chat.available_datasets())}")
IO.puts("")

# Show sample conversations
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("Sample Conversations")
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("")

dataset.items
|> Enum.take(3)
|> Enum.each(fn item ->
  conv = item.input.conversation

  IO.puts("ID: #{item.id}")
  IO.puts("Turn count: #{Conversation.turn_count(conv)}")
  IO.puts("")

  Enum.each(conv.messages, fn msg ->
    role_str = String.pad_trailing(to_string(msg.role), 10)
    content = String.slice(msg.content, 0, 60)
    IO.puts("  #{role_str}: #{content}...")
  end)

  IO.puts("")
end)

# Demonstrate conversation utilities
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("Conversation Utilities Demo")
IO.puts("-" <> String.duplicate("-", 60))
IO.puts("")

first_item = hd(dataset.items)
conv = first_item.input.conversation

IO.puts("Last message role: #{Conversation.last_message(conv).role}")
IO.puts("System prompt: #{Conversation.system_prompt(conv) || "(none)"}")
IO.puts("Messages as maps: #{inspect(Conversation.to_maps(conv), limit: 2)}")
IO.puts("")

IO.puts("=" <> String.duplicate("=", 60))
IO.puts("Example complete!")
IO.puts("=" <> String.duplicate("=", 60))
