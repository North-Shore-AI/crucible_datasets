defmodule CrucibleDatasets.Evaluator.BLEU do
  @moduledoc """
  BLEU (Bilingual Evaluation Understudy) score computation.

  BLEU measures the quality of machine-translated or generated text by comparing
  n-gram overlap with reference texts. It includes a brevity penalty to discourage
  overly short translations.

  ## Formula

  BLEU = BP × exp(∑(wₙ × log(pₙ)))

  where:
    - BP = brevity penalty = min(1, exp(1 - r/c))
    - r = reference length
    - c = candidate length
    - pₙ = modified n-gram precision for n-grams of length n
    - wₙ = uniform weight = 1/N (typically N=4)

  ## Options

    * `:max_n` - Maximum n-gram length to consider (default: 4)
    * `:smoothing` - Smoothing method for zero counts (default: :none)
      - `:none` - No smoothing
      - `:add_epsilon` - Add small constant (0.1)
      - `:add_k` - Add k=1 to all counts

  ## Examples

      iex> BLEU.compute("the cat sat on the mat", "the cat sat on the mat")
      1.0

      iex> BLEU.compute("the cat", "the cat sat on the mat")
      # Lower score due to brevity penalty

      iex> BLEU.compute("cat sat mat", "the cat sat on the mat")
      # Lower score due to missing words

      # With multiple references
      iex> BLEU.compute("the cat sat", ["the cat sat on mat", "a cat was sitting"])
      0.7...

      # With options
      iex> BLEU.compute("the cat", "the cat sat on mat", max_n: 2, smoothing: :add_epsilon)
      0.5...
  """

  @default_max_n 4
  @epsilon 0.1

  @doc """
  Compute BLEU score between candidate and reference(s).

  ## Parameters

    * `candidate` - Generated text string
    * `reference` - Reference text string or list of reference strings
    * `opts` - Keyword options (see module documentation)

  ## Returns

  Float between 0.0 and 1.0, where 1.0 is a perfect match.
  """
  @spec compute(String.t(), String.t() | [String.t()], keyword()) :: float()
  def compute(candidate, reference, opts \\ [])

  def compute(candidate, references, opts) when is_list(references) do
    max_n = Keyword.get(opts, :max_n, @default_max_n)
    smoothing = Keyword.get(opts, :smoothing, :none)

    candidate_tokens = tokenize(candidate)
    reference_tokens_list = Enum.map(references, &tokenize/1)

    # Compute n-gram precisions
    precisions =
      1..max_n
      |> Enum.map(fn n ->
        compute_ngram_precision(candidate_tokens, reference_tokens_list, n, smoothing)
      end)

    # If any precision is 0 and no smoothing, BLEU is 0
    if Enum.any?(precisions, &(&1 == 0.0)) and smoothing == :none do
      0.0
    else
      # Compute geometric mean of precisions
      log_precisions =
        precisions
        |> Enum.map(&safe_log/1)
        |> Enum.sum()

      geometric_mean = :math.exp(log_precisions / max_n)

      # Compute brevity penalty
      c = length(candidate_tokens)
      r = closest_reference_length(c, reference_tokens_list)
      bp = brevity_penalty(c, r)

      # BLEU score
      bp * geometric_mean
    end
  end

  def compute(candidate, reference, opts) when is_binary(reference) do
    compute(candidate, [reference], opts)
  end

  # Handle non-string inputs by converting to string
  def compute(candidate, reference, opts) do
    candidate_str = to_string(candidate)

    reference_str =
      if is_list(reference), do: Enum.map(reference, &to_string/1), else: to_string(reference)

    compute(candidate_str, reference_str, opts)
  end

  ## Private functions

  # Tokenize text into lowercase words
  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
  end

  defp tokenize(_), do: []

  # Compute modified n-gram precision
  defp compute_ngram_precision(candidate_tokens, reference_tokens_list, n, smoothing) do
    candidate_ngrams = extract_ngrams(candidate_tokens, n)

    # Count candidate n-grams
    candidate_counts = count_ngrams(candidate_ngrams)

    # For each n-gram in candidate, find max count in any reference
    reference_max_counts =
      reference_tokens_list
      |> Enum.map(fn ref_tokens ->
        ref_ngrams = extract_ngrams(ref_tokens, n)
        count_ngrams(ref_ngrams)
      end)

    # Modified precision: clip counts by maximum reference count
    {clipped_count, total_count} =
      Enum.reduce(candidate_counts, {0, 0}, fn {ngram, count}, {clipped, total} ->
        max_ref_count =
          reference_max_counts
          |> Enum.map(&Map.get(&1, ngram, 0))
          |> Enum.max(fn -> 0 end)

        clipped_ngram = min(count, max_ref_count)
        {clipped + clipped_ngram, total + count}
      end)

    # Apply smoothing if requested
    {numerator, denominator} =
      case smoothing do
        :add_epsilon when total_count == 0 ->
          {@epsilon, @epsilon}

        :add_epsilon ->
          {clipped_count + @epsilon, total_count + @epsilon}

        :add_k ->
          {clipped_count + 1, total_count + 1}

        _ ->
          {clipped_count, total_count}
      end

    if denominator == 0 do
      0.0
    else
      numerator / denominator
    end
  end

  # Extract n-grams from token list
  defp extract_ngrams(tokens, n) when length(tokens) < n, do: []

  defp extract_ngrams(tokens, n) do
    tokens
    |> Enum.chunk_every(n, 1, :discard)
    |> Enum.map(&List.to_tuple/1)
  end

  # Count occurrences of each n-gram
  defp count_ngrams(ngrams) do
    Enum.frequencies(ngrams)
  end

  # Find closest reference length to candidate length
  defp closest_reference_length(candidate_length, reference_tokens_list) do
    reference_lengths = Enum.map(reference_tokens_list, &length/1)

    reference_lengths
    |> Enum.min_by(
      fn ref_len ->
        abs(ref_len - candidate_length)
      end,
      fn -> candidate_length end
    )
  end

  # Compute brevity penalty
  defp brevity_penalty(c, r) when c >= r, do: 1.0
  defp brevity_penalty(0, _r), do: 0.0
  defp brevity_penalty(c, r), do: :math.exp(1 - r / c)

  # Safe logarithm that handles edge cases
  defp safe_log(x) when x > 0, do: :math.log(x)
  # Very negative for 0 precision
  defp safe_log(_), do: -1000.0
end
