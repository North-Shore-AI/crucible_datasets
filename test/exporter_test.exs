defmodule CrucibleDatasets.ExporterTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.{EvaluationResult, Exporter}

  test "exports summary CSV rows" do
    tmp_dir = tmp_path()
    result = result_fixture(model: "model-a", dataset: "demo", correct: 2, total: 2)
    path = Path.join(tmp_dir, "summary.csv")

    assert :ok = Exporter.to_csv(result, path)

    lines = File.read!(path) |> String.split("\n", trim: true)
    assert length(lines) == 2
    assert hd(lines) =~ "model,dataset"
    assert Enum.any?(tl(lines), &String.contains?(&1, "model-a"))
  end

  test "exports detailed CSV with item rows" do
    tmp_dir = tmp_path()

    result =
      result_fixture(
        model: "model-b",
        dataset: "demo",
        correct: 1,
        total: 3,
        predicted: "hello, world"
      )

    path = Path.join(tmp_dir, "detailed.csv")

    assert :ok = Exporter.to_csv([result], path, include_item_details: true)

    lines = File.read!(path) |> String.split("\n", trim: true)

    # header + 3 item rows
    assert length(lines) == 4
    assert Enum.any?(lines, &String.contains?(&1, "hello, world"))
  end

  test "exports JSONL with one object per line" do
    tmp_dir = tmp_path()
    result1 = result_fixture(model: "model-a", dataset: "demo", correct: 2, total: 2)
    result2 = result_fixture(model: "model-b", dataset: "demo", correct: 1, total: 2)

    path = Path.join(tmp_dir, "results.jsonl")
    assert :ok = Exporter.to_jsonl([result1, result2], path)

    decoded =
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert Enum.map(decoded, & &1["model"]) == ["model-a", "model-b"]
  end

  test "renders markdown with grouping and handles empty lists" do
    result1 = result_fixture(model: "model-a", dataset: "demo", correct: 2, total: 2)
    result2 = result_fixture(model: "model-b", dataset: "demo", correct: 1, total: 2)

    markdown =
      Exporter.to_markdown([result1, result2],
        title: "Report",
        group_by: :model,
        sort_by: :accuracy,
        include_details: false
      )

    assert markdown =~ "Total Evaluations: 2"
    assert markdown =~ "model-a"
    assert markdown =~ "model-b"

    empty_markdown = Exporter.to_markdown([], title: "Empty")
    assert empty_markdown =~ "Total Evaluations: 0"
  end

  test "generates HTML report sorted by accuracy and handles empty lists" do
    high = result_fixture(model: "model-high", dataset: "demo", correct: 2, total: 2)
    low = result_fixture(model: "model-low", dataset: "demo", correct: 1, total: 3)

    html = Exporter.to_html([high, low], title: "HTML Report", theme: :dark)

    assert html =~ "HTML Report"
    {high_idx, _} = :binary.match(html, "model-high")
    {low_idx, _} = :binary.match(html, "model-low")
    assert high_idx < low_idx

    empty_html = Exporter.to_html([], title: "Empty Report")
    assert empty_html =~ "Total Evaluations"
  end

  defp result_fixture(opts) do
    model = Keyword.fetch!(opts, :model)
    dataset = Keyword.fetch!(opts, :dataset)
    total = Keyword.get(opts, :total, 2)
    correct = Keyword.get(opts, :correct, total)
    predicted_value = Keyword.get(opts, :predicted, "answer")

    item_results =
      Enum.map(1..total, fn idx ->
        correct? = idx <= correct

        %{
          id: Integer.to_string(idx),
          predicted: predicted_value,
          expected: predicted_value,
          correct: correct?,
          score: if(correct?, do: 1.0, else: 0.0),
          metrics: %{exact_match: if(correct?, do: 1.0, else: 0.0)},
          metadata: %{}
        }
      end)

    metrics = %{exact_match: correct / total}

    EvaluationResult.new(dataset, "1.0", model, item_results, metrics, 100)
  end

  defp tmp_path do
    path = Path.join(System.tmp_dir!(), "crucible_export_#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
