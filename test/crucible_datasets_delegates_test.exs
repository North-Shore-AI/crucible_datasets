defmodule CrucibleDatasets.DelegatesTest do
  use ExUnit.Case

  alias CrucibleDatasets.EvaluationResult

  @env_key "CRUCIBLE_DATASETS_RESULTS_DIR"

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "crucible_delegate_#{System.unique_integer([:positive])}")

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    original_env = System.get_env(@env_key)
    System.put_env(@env_key, tmp_dir)

    on_exit(fn ->
      restore_env(original_env)
      File.rm_rf(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "delegates to registry" do
    assert Enum.sort(CrucibleDatasets.list_available()) == [:gsm8k, :humaneval, :mmlu, :mmlu_stem]

    metadata = CrucibleDatasets.get_metadata(:mmlu)
    assert metadata.name == :mmlu
  end

  test "delegates to result store", %{tmp_dir: tmp_dir} do
    result = result_fixture()

    {:ok, id} = CrucibleDatasets.save_result(result)
    {:ok, loaded} = CrucibleDatasets.load_result(id)

    assert loaded.dataset_name == result.dataset_name
    assert File.exists?(Path.join(tmp_dir, "#{id}.json"))

    {:ok, queried} = CrucibleDatasets.query_results(model: result.model)
    assert Enum.map(queried, & &1.model) == [result.model]
  end

  test "delegates to exporter", %{tmp_dir: tmp_dir} do
    result1 = result_fixture(model: "model-a")
    result2 = result_fixture(model: "model-b")

    csv_path = Path.join(tmp_dir, "out.csv")
    jsonl_path = Path.join(tmp_dir, "out.jsonl")

    assert :ok = CrucibleDatasets.export_csv([result1, result2], csv_path)
    assert :ok = CrucibleDatasets.export_jsonl([result1, result2], jsonl_path)

    markdown = CrucibleDatasets.export_markdown([result1, result2], title: "Delegates")
    html = CrucibleDatasets.export_html([result1, result2], title: "Delegates")

    assert File.exists?(csv_path)
    assert File.exists?(jsonl_path)
    assert markdown =~ "Delegates"
    assert html =~ "Delegates"
  end

  defp result_fixture(opts \\ []) do
    model = Keyword.get(opts, :model, "model-a")
    dataset = Keyword.get(opts, :dataset, "demo")
    total = Keyword.get(opts, :total, 2)
    correct = Keyword.get(opts, :correct, total)

    item_results =
      Enum.map(1..total, fn idx ->
        correct? = idx <= correct

        %{
          id: Integer.to_string(idx),
          predicted: "p#{idx}",
          expected: "p#{idx}",
          correct: correct?,
          score: if(correct?, do: 1.0, else: 0.0),
          metrics: %{exact_match: if(correct?, do: 1.0, else: 0.0)},
          metadata: %{}
        }
      end)

    metrics = %{exact_match: correct / total}

    EvaluationResult.new(dataset, "1.0", model, item_results, metrics, 50)
  end

  defp restore_env(nil), do: System.delete_env(@env_key)
  defp restore_env(value), do: System.put_env(@env_key, value)
end
