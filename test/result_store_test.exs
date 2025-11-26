defmodule CrucibleDatasets.ResultStoreTest do
  use ExUnit.Case

  alias CrucibleDatasets.{EvaluationResult, ResultStore}

  @env_key "CRUCIBLE_DATASETS_RESULTS_DIR"

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "crucible_results_#{System.unique_integer([:positive])}")

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

  test "save and load round-trips results", %{tmp_dir: tmp_dir} do
    result = result_fixture(model: "model-a", dataset: :demo, correct: 2, total: 2)

    {:ok, result_id} = ResultStore.save(result)
    result_path = Path.join(tmp_dir, "#{result_id}.json")

    assert File.exists?(result_path)

    {:ok, loaded} = ResultStore.load(result_id)

    assert loaded.dataset_name == result.dataset_name
    assert loaded.model == result.model
    assert_in_delta loaded.accuracy, result.accuracy, 0.0001
    assert DateTime.to_iso8601(loaded.timestamp) == DateTime.to_iso8601(result.timestamp)
  end

  test "query filters by model, dataset, and accuracy", %{tmp_dir: tmp_dir} do
    {:ok, id1} =
      result_fixture(model: "model-a", dataset: :ds1, correct: 2, total: 2) |> ResultStore.save()

    {:ok, id2} =
      result_fixture(model: "model-b", dataset: :ds2, correct: 1, total: 2) |> ResultStore.save()

    {:ok, results_model} = ResultStore.query(model: "model-a")
    assert Enum.map(results_model, & &1.model) == ["model-a"]

    {:ok, results_dataset} = ResultStore.query(dataset: :ds2)
    assert Enum.map(results_dataset, & &1.dataset_name) == ["ds2"]

    {:ok, high_accuracy} = ResultStore.query(min_accuracy: 0.75)
    assert Enum.map(high_accuracy, & &1.dataset_name) == ["ds1"]

    tomorrow = Date.add(Date.utc_today(), 1)
    {:ok, future_results} = ResultStore.query(date_from: tomorrow)
    assert future_results == []

    # Ensure index was written to the configured directory
    assert File.exists?(Path.join(tmp_dir, "index.json"))

    # Clean up files for this test to avoid leftovers in later assertions
    File.rm(Path.join(tmp_dir, "#{id1}.json"))
    File.rm(Path.join(tmp_dir, "#{id2}.json"))
  end

  test "skips missing result files when querying", %{tmp_dir: tmp_dir} do
    {:ok, result_id} = result_fixture() |> ResultStore.save()

    # Delete the underlying file to simulate missing result
    result_path = Path.join(tmp_dir, "#{result_id}.json")
    File.rm!(result_path)

    {:ok, results} = ResultStore.query(model: "model-a")
    assert results == []
  end

  test "delete removes file and index entry idempotently", %{tmp_dir: tmp_dir} do
    {:ok, result_id} = result_fixture() |> ResultStore.save()
    result_path = Path.join(tmp_dir, "#{result_id}.json")

    assert File.exists?(result_path)

    assert :ok = ResultStore.delete(result_id)
    refute File.exists?(result_path)

    # Second delete should still succeed
    assert :ok = ResultStore.delete(result_id)

    {:ok, summaries} = ResultStore.list_all()
    refute Enum.any?(summaries, &(&1["id"] == result_id))
  end

  test "clear_all wipes storage directory", %{tmp_dir: tmp_dir} do
    {:ok, _result_id} = result_fixture() |> ResultStore.save()

    assert :ok = ResultStore.clear_all()
    refute File.exists?(tmp_dir)
  end

  test "generates slugged ids with date prefix" do
    result = result_fixture(model: "Model X", dataset: :DataSet1)
    {:ok, result_id} = ResultStore.save(result)

    today = Date.utc_today() |> Date.to_iso8601()
    assert String.starts_with?(result_id, today <> "/")
    assert result_id =~ "model_x_dataset1_"
  end

  test "list_all returns stored summaries" do
    {:ok, id1} = result_fixture(model: "model-a") |> ResultStore.save()
    {:ok, id2} = result_fixture(model: "model-b") |> ResultStore.save()

    {:ok, summaries} = ResultStore.list_all()
    ids = Enum.map(summaries, & &1["id"])

    assert Enum.sort(ids) == Enum.sort([id1, id2])
  end

  defp result_fixture(opts \\ []) do
    model = Keyword.get(opts, :model, "model-a")
    dataset = Keyword.get(opts, :dataset, :demo)
    total = Keyword.get(opts, :total, 2)
    correct = Keyword.get(opts, :correct, total)

    item_results =
      Enum.map(1..total, fn idx ->
        correct? = idx <= correct

        %{
          id: Integer.to_string(idx),
          predicted: "p#{idx}",
          expected: "e#{idx}",
          correct: correct?,
          score: if(correct?, do: 1.0, else: 0.0),
          metrics: %{exact_match: if(correct?, do: 1.0, else: 0.0)},
          metadata: %{}
        }
      end)

    metrics = %{exact_match: correct / total}

    EvaluationResult.new(to_string(dataset), "1.0", model, item_results, metrics, 10)
  end

  defp restore_env(nil), do: System.delete_env(@env_key)
  defp restore_env(value), do: System.put_env(@env_key, value)
end
