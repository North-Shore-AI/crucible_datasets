defmodule CrucibleDatasets.RegistryTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Registry

  test "lists available datasets" do
    assert Enum.sort(Registry.list_available()) == [
             :gsm8k,
             :humaneval,
             :mmlu,
             :mmlu_stem,
             :no_robots
           ]
  end

  test "gets metadata for known dataset" do
    metadata = Registry.get_metadata(:mmlu)

    assert metadata.name == :mmlu
    assert metadata.domain == "general_knowledge"
    assert metadata.task_type == "multiple_choice_qa"
  end

  test "returns nil for unknown metadata" do
    assert Registry.get_metadata(:unknown) == nil
  end

  describe "filters" do
    test "list_by_domain/1" do
      assert Registry.list_by_domain("math") == [:gsm8k]
      assert Registry.list_by_domain("code") == [:humaneval]
    end

    test "list_by_task_type/1" do
      assert Registry.list_by_task_type("multiple_choice_qa") == [:mmlu, :mmlu_stem]
      assert Registry.list_by_task_type("code_generation") == [:humaneval]
    end

    test "list_by_difficulty/1" do
      assert Registry.list_by_difficulty("challenging") == [:mmlu, :mmlu_stem]
      assert Registry.list_by_difficulty("medium") == [:gsm8k, :humaneval, :no_robots]
    end

    test "list_by_tag/1" do
      assert Registry.list_by_tag("reasoning") == [:gsm8k, :mmlu, :mmlu_stem]
      assert Registry.list_by_tag("code") == [:humaneval]
    end
  end

  test "search is case-insensitive" do
    assert Registry.search("MATH") == [:gsm8k, :mmlu_stem]
    assert Registry.search("nonexistent") == []
  end

  test "stats includes aggregate counts" do
    stats = Registry.stats()

    assert stats.total_datasets == 5

    assert Enum.sort(stats.domains) == [
             "code",
             "general_knowledge",
             "instruction_following",
             "math",
             "stem"
           ]

    assert stats.by_domain["math"] == 1
    assert stats.by_task_type["multiple_choice_qa"] == 2
  end

  test "summary renders readable output" do
    summary = Registry.summary()

    assert summary =~ "Total Datasets: 5"
    assert summary =~ "general_knowledge"
    assert summary =~ "code"
    assert summary =~ "instruction_following"
  end
end
