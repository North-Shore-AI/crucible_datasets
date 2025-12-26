defmodule CrucibleDatasets.Exporter do
  @moduledoc """
  Export evaluation results to various formats.

  Supports exporting to CSV, JSON Lines, Markdown, and HTML formats for
  integration with analysis tools, documentation, and reporting systems.

  ## Formats

    * **CSV** - Tabular format for spreadsheet applications
    * **JSON Lines** - One JSON object per line for streaming processing
    * **Markdown** - Human-readable tables for documentation
    * **HTML** - Interactive web-based reports

  ## Examples

      # Export single result to CSV
      :ok = CrucibleDatasets.Exporter.to_csv(result, "results/experiment.csv")

      # Export multiple results to JSON Lines
      :ok = CrucibleDatasets.Exporter.to_jsonl(results, "results/all_experiments.jsonl")

      # Generate markdown report
      markdown = CrucibleDatasets.Exporter.to_markdown(results,
        title: "Model Comparison",
        sort_by: :accuracy,
        include_details: false
      )

      # Generate HTML report
      html = CrucibleDatasets.Exporter.to_html(results,
        title: "Evaluation Results",
        include_charts: true
      )
  """

  alias CrucibleDatasets.EvaluationResult

  @doc """
  Export evaluation result(s) to CSV format.

  Creates a CSV file with one row per result, including key metrics.

  ## Parameters

    * `results` - Single EvaluationResult or list of results
    * `output_path` - Path to output CSV file
    * `opts` - Optional keyword list
      * `:include_item_details` - Include per-item results (default: `false`)

  ## Examples

      :ok = CrucibleDatasets.Exporter.to_csv(result, "results.csv")

      :ok = CrucibleDatasets.Exporter.to_csv(
        [result1, result2, result3],
        "all_results.csv"
      )
  """
  @spec to_csv(EvaluationResult.t() | [EvaluationResult.t()], Path.t(), keyword()) ::
          :ok | {:error, term()}
  def to_csv(results, output_path, opts \\ [])

  def to_csv(%EvaluationResult{} = result, output_path, opts) do
    to_csv([result], output_path, opts)
  end

  def to_csv(results, output_path, opts) when is_list(results) do
    include_item_details = Keyword.get(opts, :include_item_details, false)

    rows =
      if include_item_details do
        generate_csv_rows_with_items(results)
      else
        generate_csv_summary_rows(results)
      end

    with :ok <- ensure_parent_dir(output_path),
         {:ok, file} <- File.open(output_path, [:write, :utf8]) do
      Enum.each(rows, fn row ->
        IO.write(file, row <> "\n")
      end)

      File.close(file)
      :ok
    end
  end

  @doc """
  Export evaluation result(s) to JSON Lines format.

  Each result is written as a single JSON object on one line.

  ## Parameters

    * `results` - Single EvaluationResult or list of results
    * `output_path` - Path to output JSONL file

  ## Examples

      :ok = CrucibleDatasets.Exporter.to_jsonl(results, "results.jsonl")
  """
  @spec to_jsonl(EvaluationResult.t() | [EvaluationResult.t()], Path.t()) ::
          :ok | {:error, term()}
  def to_jsonl(%EvaluationResult{} = result, output_path) do
    to_jsonl([result], output_path)
  end

  def to_jsonl(results, output_path) when is_list(results) do
    with :ok <- ensure_parent_dir(output_path),
         {:ok, file} <- File.open(output_path, [:write, :utf8]) do
      Enum.each(results, fn result ->
        json = EvaluationResult.to_json(result)
        line = Jason.encode!(json)
        IO.write(file, line <> "\n")
      end)

      File.close(file)
      :ok
    end
  end

  @doc """
  Generate markdown report from evaluation results.

  ## Parameters

    * `results` - List of EvaluationResult structs
    * `opts` - Keyword options
      * `:title` - Report title (default: "Evaluation Results")
      * `:sort_by` - Sort criterion (`:accuracy`, `:model`, `:dataset`, `:timestamp`)
      * `:group_by` - Group criterion (`:model`, `:dataset`, `:none`)
      * `:include_details` - Include per-item analysis (default: `false`)
      * `:include_metadata` - Include experiment metadata (default: `true`)

  ## Examples

      markdown = CrucibleDatasets.Exporter.to_markdown(results,
        title: "MMLU Stem Results",
        sort_by: :accuracy,
        group_by: :model
      )

      File.write!("report.md", markdown)
  """
  @spec to_markdown([EvaluationResult.t()], keyword()) :: String.t()
  def to_markdown(results, opts \\ []) do
    title = Keyword.get(opts, :title, "Evaluation Results")
    sort_by = Keyword.get(opts, :sort_by, :accuracy)
    group_by = Keyword.get(opts, :group_by, :none)
    include_details = Keyword.get(opts, :include_details, false)
    include_metadata = Keyword.get(opts, :include_metadata, true)

    sorted_results = sort_results(results, sort_by)
    grouped_results = group_results(sorted_results, group_by)

    header = """
    # #{title}

    Generated: #{DateTime.to_iso8601(DateTime.utc_now())}

    Total Evaluations: #{length(results)}

    """

    metadata_section =
      if include_metadata do
        generate_metadata_section(results)
      else
        ""
      end

    results_section = generate_results_table(grouped_results, group_by)

    details_section =
      if include_details do
        generate_details_section(sorted_results)
      else
        ""
      end

    header <> metadata_section <> results_section <> details_section
  end

  @doc """
  Generate HTML report from evaluation results.

  Creates a standalone HTML document with styling and optional interactive charts.

  ## Parameters

    * `results` - List of EvaluationResult structs
    * `opts` - Keyword options
      * `:title` - Report title
      * `:include_charts` - Include visualization charts (default: `false`)
      * `:theme` - Color theme (`:light`, `:dark`) (default: `:light`)

  ## Examples

      html = CrucibleDatasets.Exporter.to_html(results,
        title: "Model Comparison",
        theme: :light
      )

      File.write!("report.html", html)
  """
  @spec to_html([EvaluationResult.t()], keyword()) :: String.t()
  def to_html(results, opts \\ []) do
    title = Keyword.get(opts, :title, "Evaluation Results")
    theme = Keyword.get(opts, :theme, :light)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title}</title>
        <style>
            #{generate_css(theme)}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>#{title}</h1>
            <p class="timestamp">Generated: #{DateTime.to_iso8601(DateTime.utc_now())}</p>

            #{generate_html_summary(results)}

            #{generate_html_table(results)}

            #{generate_html_footer()}
        </div>
    </body>
    </html>
    """
  end

  ## Private functions - CSV generation

  defp generate_csv_summary_rows(results) do
    header =
      "model,dataset,dataset_version,accuracy,total_items,correct_items,duration_ms,timestamp,metrics"

    data_rows =
      Enum.map(results, fn result ->
        metrics_str = Jason.encode!(result.metrics)

        [
          csv_escape(result.model),
          csv_escape(result.dataset_name),
          csv_escape(result.dataset_version),
          Float.to_string(result.accuracy),
          Integer.to_string(result.total_items),
          Integer.to_string(result.correct_items),
          Integer.to_string(result.duration_ms),
          DateTime.to_iso8601(result.timestamp),
          csv_escape(metrics_str)
        ]
        |> Enum.join(",")
      end)

    [header | data_rows]
  end

  defp generate_csv_rows_with_items(results) do
    header = "model,dataset,item_id,predicted,expected,correct,score,timestamp"

    data_rows =
      Enum.flat_map(results, fn result ->
        Enum.map(result.item_results, fn item ->
          [
            csv_escape(result.model),
            csv_escape(result.dataset_name),
            csv_escape(item.id),
            csv_escape(inspect(item.predicted)),
            csv_escape(inspect(item.expected)),
            to_string(item.correct),
            Float.to_string(item.score),
            DateTime.to_iso8601(result.timestamp)
          ]
          |> Enum.join(",")
        end)
      end)

    [header | data_rows]
  end

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      ~s("#{String.replace(value, "\"", "\"\"")}")
    else
      value
    end
  end

  defp csv_escape(value), do: csv_escape(to_string(value))

  ## Private functions - Markdown generation

  defp sort_results(results, :accuracy) do
    Enum.sort_by(results, & &1.accuracy, :desc)
  end

  defp sort_results(results, :model) do
    Enum.sort_by(results, & &1.model)
  end

  defp sort_results(results, :dataset) do
    Enum.sort_by(results, & &1.dataset_name)
  end

  defp sort_results(results, :timestamp) do
    Enum.sort_by(results, & &1.timestamp, {:desc, DateTime})
  end

  defp sort_results(results, _), do: results

  defp group_results(results, :model) do
    Enum.group_by(results, & &1.model)
  end

  defp group_results(results, :dataset) do
    Enum.group_by(results, & &1.dataset_name)
  end

  defp group_results(results, _), do: %{all: results}

  defp generate_metadata_section(results) do
    models = results |> Enum.map(& &1.model) |> Enum.uniq() |> Enum.sort()
    datasets = results |> Enum.map(& &1.dataset_name) |> Enum.uniq() |> Enum.sort()

    accuracies = Enum.map(results, & &1.accuracy)

    avg_accuracy =
      case accuracies do
        [] -> 0.0
        _ -> accuracies |> Enum.sum() |> Kernel./(length(accuracies)) |> Float.round(4)
      end

    """
    ## Summary

    - **Models:** #{Enum.join(models, ", ")}
    - **Datasets:** #{Enum.join(datasets, ", ")}
    - **Average Accuracy:** #{Float.round(avg_accuracy * 100, 2)}%

    ---

    """
  end

  defp generate_results_table(grouped_results, group_by) do
    if group_by == :none do
      results = Map.get(grouped_results, :all, [])
      generate_single_table(results)
    else
      Enum.map_join(grouped_results, "\n", fn {group_name, group_results} ->
        """
        ### #{group_name}

        #{generate_single_table(group_results)}
        """
      end)
    end
  end

  defp generate_single_table(results) do
    """
    | Rank | Model | Dataset | Accuracy | Correct/Total | Duration | Date |
    |------|-------|---------|----------|---------------|----------|------|
    #{generate_table_rows(results)}
    """
  end

  defp generate_table_rows(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {result, rank} ->
      accuracy_pct = Float.round(result.accuracy * 100, 2)
      date = result.timestamp |> DateTime.to_date() |> Date.to_iso8601()

      "| #{rank} | #{result.model} | #{result.dataset_name} | #{accuracy_pct}% | #{result.correct_items}/#{result.total_items} | #{result.duration_ms}ms | #{date} |"
    end)
  end

  defp generate_details_section(results) do
    """
    ---

    ## Detailed Results

    #{Enum.map_join(results, "\n\n", &generate_result_detail/1)}
    """
  end

  defp generate_result_detail(result) do
    """
    ### #{result.model} on #{result.dataset_name}

    - **Accuracy:** #{Float.round(result.accuracy * 100, 2)}%
    - **Correct:** #{result.correct_items} / #{result.total_items}
    - **Duration:** #{result.duration_ms}ms
    - **Timestamp:** #{DateTime.to_iso8601(result.timestamp)}

    **Metrics:**
    #{Enum.map_join(result.metrics, "\n", fn {metric, value} -> "- #{metric}: #{format_metric_value(value)}" end)}
    """
  end

  defp format_metric_value(value) when is_float(value), do: Float.round(value, 4)
  defp format_metric_value(value), do: inspect(value)

  ## Private functions - HTML generation

  defp generate_css(:light) do
    """
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
    .timestamp { color: #666; font-size: 0.9em; margin-bottom: 30px; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
    th { background: #4CAF50; color: white; font-weight: bold; }
    tr:hover { background: #f5f5f5; }
    .accuracy { font-weight: bold; color: #4CAF50; }
    .summary-box { background: #e8f5e9; padding: 20px; border-radius: 4px; margin: 20px 0; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 0.9em; text-align: center; }
    """
  end

  defp generate_css(:dark) do
    """
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 20px; background: #1a1a1a; color: #e0e0e0; }
    .container { max-width: 1200px; margin: 0 auto; background: #2d2d2d; padding: 40px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.5); }
    h1 { color: #e0e0e0; border-bottom: 3px solid #66bb6a; padding-bottom: 10px; }
    .timestamp { color: #999; font-size: 0.9em; margin-bottom: 30px; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #444; }
    th { background: #66bb6a; color: white; font-weight: bold; }
    tr:hover { background: #333; }
    .accuracy { font-weight: bold; color: #66bb6a; }
    .summary-box { background: #1f3d1f; padding: 20px; border-radius: 4px; margin: 20px 0; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #444; color: #999; font-size: 0.9em; text-align: center; }
    """
  end

  defp generate_html_summary(results) do
    accuracies = Enum.map(results, & &1.accuracy)

    avg_accuracy =
      case accuracies do
        [] ->
          0.0

        _ ->
          accuracies
          |> Enum.sum()
          |> Kernel./(length(accuracies))
          |> Float.round(4)
          |> Kernel.*(100)
          |> Float.round(2)
      end

    """
    <div class="summary-box">
        <h2>Summary</h2>
        <p><strong>Total Evaluations:</strong> #{length(results)}</p>
        <p><strong>Average Accuracy:</strong> <span class="accuracy">#{avg_accuracy}%</span></p>
    </div>
    """
  end

  defp generate_html_table(results) do
    sorted = Enum.sort_by(results, & &1.accuracy, :desc)

    rows =
      sorted
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {result, rank} ->
        accuracy_pct = Float.round(result.accuracy * 100, 2)
        date = result.timestamp |> DateTime.to_date() |> Date.to_iso8601()

        """
        <tr>
            <td>#{rank}</td>
            <td>#{result.model}</td>
            <td>#{result.dataset_name}</td>
            <td class="accuracy">#{accuracy_pct}%</td>
            <td>#{result.correct_items}/#{result.total_items}</td>
            <td>#{result.duration_ms}ms</td>
            <td>#{date}</td>
        </tr>
        """
      end)

    """
    <h2>Results</h2>
    <table>
        <thead>
            <tr>
                <th>Rank</th>
                <th>Model</th>
                <th>Dataset</th>
                <th>Accuracy</th>
                <th>Correct/Total</th>
                <th>Duration</th>
                <th>Date</th>
            </tr>
        </thead>
        <tbody>
            #{rows}
        </tbody>
    </table>
    """
  end

  defp generate_html_footer do
    """
    <div class="footer">
        Generated by CrucibleDatasets
    </div>
    """
  end

  defp ensure_parent_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end
end
