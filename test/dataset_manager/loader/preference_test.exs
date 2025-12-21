defmodule CrucibleDatasets.Loader.PreferenceTest do
  use ExUnit.Case, async: false

  alias CrucibleDatasets.Loader.Preference
  alias CrucibleDatasets.Types.{Comparison, LabeledComparison}

  describe "available_datasets/0" do
    test "returns list of available datasets" do
      datasets = Preference.available_datasets()

      assert :hh_rlhf in datasets
      assert :helpsteer3 in datasets
      assert :ultrafeedback in datasets
    end
  end

  describe "load/2 with synthetic data" do
    test "loads synthetic preference data" do
      {:ok, dataset} = Preference.load(:hh_rlhf, synthetic: true)

      assert dataset.name == "hh_rlhf"
      assert length(dataset.items) > 0
      assert dataset.metadata.source == "synthetic"
    end

    test "respects sample_size option" do
      {:ok, dataset} = Preference.load(:helpsteer3, synthetic: true, sample_size: 5)

      assert length(dataset.items) == 5
    end

    test "synthetic items have correct structure" do
      {:ok, dataset} = Preference.load(:ultrafeedback, synthetic: true, sample_size: 1)

      first = hd(dataset.items)
      assert is_binary(first.id)
      assert is_map(first.input)
      assert Map.has_key?(first.input, :comparison)
      assert is_struct(first.input.comparison, Comparison)
      assert is_struct(first.expected, LabeledComparison)
    end
  end

  describe "load/2 with unknown dataset" do
    test "returns error for unknown dataset" do
      {:error, {:unknown_dataset, :unknown, available}} = Preference.load(:unknown)

      assert is_list(available)
    end
  end
end
