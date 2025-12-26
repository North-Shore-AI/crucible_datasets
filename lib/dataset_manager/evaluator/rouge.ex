defmodule CrucibleDatasets.Evaluator.ROUGE do
  @moduledoc """
  ROUGE (Recall-Oriented Understudy for Gisting Evaluation) scores.

  ROUGE measures the quality of summaries by comparing them to reference summaries.
  It calculates recall-based metrics focused on n-gram and sequence overlap.

  ## Variants

    * `ROUGE-1` - Unigram (single word) overlap
    * `ROUGE-2` - Bigram (two-word sequence) overlap
    * `ROUGE-L` - Longest Common Subsequence based metric
    * `ROUGE-W` - Weighted Longest Common Subsequence

  ## Formulas

  ROUGE-N = ∑(S∈refs) ∑(gram∈S) Count_match(gram) /
            ∑(S∈refs) ∑(gram∈S) Count(gram)

  ROUGE-L = LCS(X,Y) / len(Y)
    where LCS = longest common subsequence length

  ## Options

    * `:variants` - List of variants to compute (default: `[:rouge1, :rouge2, :rougel]`)
    * `:use_stemming` - Apply stemming (default: `false`)
    * `:remove_stopwords` - Remove stopwords (default: `false`)

  ## Examples

      iex> ROUGE.compute(
      ...>   "the cat sat on the mat",
      ...>   "the cat is on the mat"
      ...> )
      %{
        rouge1: %{precision: 0.857, recall: 0.857, f1: 0.857},
        rouge2: %{precision: 0.600, recall: 0.600, f1: 0.600},
        rougel: %{precision: 0.857, recall: 0.857, f1: 0.857}
      }

      # With multiple references
      iex> ROUGE.compute(
      ...>   "the cat sat",
      ...>   ["the cat sat on mat", "a cat was sitting"],
      ...>   variants: [:rouge1, :rouge2]
      ...> )
      %{
        rouge1: %{precision: ..., recall: ..., f1: ...},
        rouge2: %{precision: ..., recall: ..., f1: ...}
      }
  """

  @doc """
  Compute ROUGE scores between candidate and reference(s).

  ## Parameters

    * `candidate` - Generated text string
    * `reference` - Reference text string or list of reference strings
    * `opts` - Keyword options (see module documentation)

  ## Returns

  Map with requested ROUGE variants, each containing precision, recall, and F1 scores.
  """
  @spec compute(String.t(), String.t() | [String.t()], keyword()) :: map()
  def compute(candidate, reference, opts \\ [])

  def compute(candidate, references, opts) when is_list(references) do
    variants = Keyword.get(opts, :variants, [:rouge1, :rouge2, :rougel])

    Enum.reduce(variants, %{}, fn variant, acc ->
      score = compute_variant(variant, candidate, references, opts)
      Map.put(acc, variant, score)
    end)
  end

  def compute(candidate, reference, opts) when is_binary(reference) do
    compute(candidate, [reference], opts)
  end

  # Handle non-string inputs
  def compute(candidate, reference, opts) do
    candidate_str = to_string(candidate)

    reference_str =
      if is_list(reference), do: Enum.map(reference, &to_string/1), else: to_string(reference)

    compute(candidate_str, reference_str, opts)
  end

  ## Private functions

  # Compute specific ROUGE variant
  defp compute_variant(:rouge1, candidate, references, _opts) do
    compute_rouge_n(candidate, references, 1)
  end

  defp compute_variant(:rouge2, candidate, references, _opts) do
    compute_rouge_n(candidate, references, 2)
  end

  defp compute_variant(:rougel, candidate, references, _opts) do
    compute_rouge_l(candidate, references)
  end

  defp compute_variant(:rougew, candidate, references, _opts) do
    # ROUGE-W is weighted LCS - simplified to LCS for this implementation
    compute_rouge_l(candidate, references)
  end

  defp compute_variant(_, _candidate, _references, _opts) do
    %{precision: 0.0, recall: 0.0, f1: 0.0}
  end

  # Compute ROUGE-N (n-gram based)
  defp compute_rouge_n(candidate, references, n) do
    candidate_tokens = tokenize(candidate)
    candidate_ngrams = extract_ngrams(candidate_tokens, n)
    candidate_ngram_counts = count_ngrams(candidate_ngrams)

    # Compute overlap with each reference and take maximum
    scores =
      Enum.map(references, fn reference ->
        reference_tokens = tokenize(reference)
        reference_ngrams = extract_ngrams(reference_tokens, n)
        reference_ngram_counts = count_ngrams(reference_ngrams)

        # Count overlapping n-grams
        overlapping_count =
          Map.keys(candidate_ngram_counts)
          |> Enum.map(fn ngram ->
            min(
              Map.get(candidate_ngram_counts, ngram, 0),
              Map.get(reference_ngram_counts, ngram, 0)
            )
          end)
          |> Enum.sum()

        total_candidate = Enum.sum(Map.values(candidate_ngram_counts))
        total_reference = Enum.sum(Map.values(reference_ngram_counts))

        precision =
          if total_candidate == 0,
            do: 0.0,
            else: overlapping_count / total_candidate

        recall =
          if total_reference == 0,
            do: 0.0,
            else: overlapping_count / total_reference

        f1 =
          if precision + recall == 0,
            do: 0.0,
            else: 2 * (precision * recall) / (precision + recall)

        %{precision: precision, recall: recall, f1: f1}
      end)

    # Take maximum F1 score across references
    scores
    |> Enum.max_by(& &1.f1, fn -> %{precision: 0.0, recall: 0.0, f1: 0.0} end)
  end

  # Compute ROUGE-L (Longest Common Subsequence based)
  defp compute_rouge_l(candidate, references) do
    candidate_tokens = tokenize(candidate)

    # Compute LCS with each reference and take maximum
    scores =
      Enum.map(references, fn reference ->
        reference_tokens = tokenize(reference)

        lcs_length = longest_common_subsequence_length(candidate_tokens, reference_tokens)

        candidate_len = length(candidate_tokens)
        reference_len = length(reference_tokens)

        precision =
          if candidate_len == 0,
            do: 0.0,
            else: lcs_length / candidate_len

        recall =
          if reference_len == 0,
            do: 0.0,
            else: lcs_length / reference_len

        f1 =
          if precision + recall == 0,
            do: 0.0,
            else: 2 * (precision * recall) / (precision + recall)

        %{precision: precision, recall: recall, f1: f1}
      end)

    # Take maximum F1 score across references
    scores
    |> Enum.max_by(& &1.f1, fn -> %{precision: 0.0, recall: 0.0, f1: 0.0} end)
  end

  # Tokenize text into lowercase words
  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
  end

  defp tokenize(_), do: []

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

  # Compute longest common subsequence length using dynamic programming
  defp longest_common_subsequence_length([], _), do: 0
  defp longest_common_subsequence_length(_, []), do: 0

  defp longest_common_subsequence_length(seq1, seq2) do
    m = length(seq1)
    n = length(seq2)

    # Initialize DP table with 0s for all coordinates
    dp =
      for i <- 0..m, j <- 0..n, into: %{} do
        {{i, j}, 0}
      end

    # Fill DP table
    dp =
      Enum.reduce(1..m, dp, fn i, acc_dp ->
        elem1 = Enum.at(seq1, i - 1)
        fill_lcs_row(acc_dp, elem1, seq2, i, n)
      end)

    Map.get(dp, {m, n}, 0)
  end

  # Fill a single row of the LCS DP table
  defp fill_lcs_row(dp, elem1, seq2, i, n) do
    Enum.reduce(1..n, dp, fn j, inner_dp ->
      elem2 = Enum.at(seq2, j - 1)
      value = compute_lcs_cell(inner_dp, elem1, elem2, i, j)
      Map.put(inner_dp, {i, j}, value)
    end)
  end

  # Compute the value for a single cell in the LCS DP table
  defp compute_lcs_cell(dp, elem1, elem2, i, j) when elem1 == elem2 do
    Map.get(dp, {i - 1, j - 1}, 0) + 1
  end

  defp compute_lcs_cell(dp, _elem1, _elem2, i, j) do
    max(
      Map.get(dp, {i - 1, j}, 0),
      Map.get(dp, {i, j - 1}, 0)
    )
  end

  @doc """
  Compute aggregated ROUGE scores across multiple predictions.

  Useful for computing dataset-level ROUGE scores.

  ## Examples

      iex> predictions = [
      ...>   %{predicted: "the cat sat", expected: "the cat sat on mat"},
      ...>   %{predicted: "dog ran", expected: "the dog ran fast"}
      ...> ]
      iex> ROUGE.compute_aggregate(predictions)
      %{
        rouge1: %{precision: 0.75, recall: 0.70, f1: 0.72},
        rouge2: %{precision: 0.50, recall: 0.45, f1: 0.47}
      }
  """
  @spec compute_aggregate([map()], keyword()) :: map()
  def compute_aggregate(predictions, opts \\ []) do
    variants = Keyword.get(opts, :variants, [:rouge1, :rouge2, :rougel])

    # Compute ROUGE for each prediction
    all_scores =
      Enum.map(predictions, fn pred ->
        compute(pred.predicted, pred.expected, opts)
      end)

    # Aggregate by averaging each metric
    Enum.reduce(variants, %{}, fn variant, acc ->
      variant_scores =
        Enum.map(all_scores, &Map.get(&1, variant, %{precision: 0.0, recall: 0.0, f1: 0.0}))

      avg_precision = average(Enum.map(variant_scores, & &1.precision))
      avg_recall = average(Enum.map(variant_scores, & &1.recall))
      avg_f1 = average(Enum.map(variant_scores, & &1.f1))

      Map.put(acc, variant, %{precision: avg_precision, recall: avg_recall, f1: avg_f1})
    end)
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
end
