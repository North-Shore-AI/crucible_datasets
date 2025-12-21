defmodule CrucibleDatasets.Fetcher.HuggingFace do
  @moduledoc """
  HuggingFace Hub API client for dataset downloads.

  Provides functions to:
  - List files in a HuggingFace dataset repository
  - Download individual files
  - Fetch and parse complete dataset splits

  ## URL Patterns

  - API for file listing: `https://huggingface.co/api/datasets/{repo_id}/tree/{revision}`
  - File download: `https://huggingface.co/datasets/{repo_id}/resolve/{revision}/{path}`

  ## Authentication

  Set the `HF_TOKEN` environment variable for authenticated access to private datasets.

  ## Examples

      # List files in a dataset
      {:ok, files} = HuggingFace.list_files("openai/gsm8k")

      # Download a specific file
      {:ok, data} = HuggingFace.download_file("openai/gsm8k", "data/train.parquet")

      # Fetch and parse a dataset split
      {:ok, rows} = HuggingFace.fetch("openai/gsm8k", split: "train")

  """

  require Logger

  @base_url "https://huggingface.co"
  @api_url "https://huggingface.co/api"
  @default_timeout 60_000

  @doc """
  Build the download URL for a file in a HuggingFace dataset.

  ## Examples

      iex> HuggingFace.build_file_url("openai/gsm8k", "data/train.parquet")
      "https://huggingface.co/datasets/openai/gsm8k/resolve/main/data/train.parquet"

  """
  @spec build_file_url(String.t(), String.t(), keyword()) :: String.t()
  def build_file_url(repo_id, path, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    "#{@base_url}/datasets/#{repo_id}/resolve/#{revision}/#{path}"
  end

  @doc """
  List all files in a HuggingFace dataset repository.

  ## Options
    * `:config` - Dataset configuration/subset (default: root directory)
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token (default: from HF_TOKEN env var)

  ## Returns
    * `{:ok, files}` - List of file metadata maps
    * `{:error, reason}` - Error tuple

  """
  @spec list_files(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_files(repo_id, opts \\ []) do
    config = Keyword.get(opts, :config)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token) || System.get_env("HF_TOKEN")

    path = if config, do: "/#{config}", else: ""
    url = "#{@api_url}/datasets/#{repo_id}/tree/#{revision}#{path}"

    headers = build_headers(token)

    case Req.get(url, headers: headers, receive_timeout: @default_timeout) do
      {:ok, %{status: 200, body: files}} when is_list(files) ->
        {:ok, files}

      {:ok, %{status: 200, body: body}} ->
        # Sometimes the API returns a non-list body - try to handle it
        {:ok, [body]}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Download a file from a HuggingFace dataset repository.

  ## Options
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token (default: from HF_TOKEN env var)

  ## Returns
    * `{:ok, binary}` - File contents as binary
    * `{:error, reason}` - Error tuple

  """
  @spec download_file(String.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def download_file(repo_id, path, opts \\ []) do
    url = build_file_url(repo_id, path, opts)
    token = Keyword.get(opts, :token) || System.get_env("HF_TOKEN")
    headers = build_headers(token)

    # Use Req with redirect following and longer timeout for large files
    req_opts = [
      headers: headers,
      receive_timeout: @default_timeout * 5,
      redirect: true,
      max_redirects: 5,
      raw: true
    ]

    case Req.get(url, req_opts) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: 200, body: body}} ->
        # If body is not binary, try to convert
        {:ok, IO.iodata_to_binary(body)}

      {:ok, %{status: 302, headers: headers}} ->
        # Manual redirect handling if needed
        location = get_header(headers, "location")

        if location do
          Logger.debug("redirecting to #{location}")
          download_url(location, token)
        else
          {:error, {:redirect_without_location, headers}}
        end

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  # Download from a direct URL (for following redirects)
  defp download_url(url, token) do
    headers = build_headers(token)

    req_opts = [
      headers: headers,
      receive_timeout: @default_timeout * 5,
      redirect: true,
      max_redirects: 5,
      raw: true
    ]

    case Req.get(url, req_opts) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: 200, body: body}} ->
        {:ok, IO.iodata_to_binary(body)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp get_header(headers, name) do
    name_lower = String.downcase(name)

    case Enum.find(headers, fn {k, _v} -> String.downcase(k) == name_lower end) do
      {_, value} -> value
      nil -> nil
    end
  end

  @doc """
  Fetch and parse a complete dataset split from HuggingFace.

  This is the main function for loading datasets. It:
  1. Lists files in the repository
  2. Finds parquet/jsonl files matching the requested split
  3. Downloads and parses the files
  4. Returns the data as a list of maps

  ## Options
    * `:split` - Dataset split (default: "train")
    * `:config` - Dataset configuration/subset
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token (default: from HF_TOKEN env var)

  ## Returns
    * `{:ok, data}` - List of row maps
    * `{:error, reason}` - Error tuple

  ## Examples

      {:ok, data} = HuggingFace.fetch("openai/gsm8k", split: "train")
      {:ok, data} = HuggingFace.fetch("cais/mmlu", config: "astronomy", split: "test")

  """
  @spec fetch(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch(repo_id, opts \\ []) do
    split = Keyword.get(opts, :split, "train")
    config = Keyword.get(opts, :config)
    token = Keyword.get(opts, :token) || System.get_env("HF_TOKEN")

    with {:ok, files} <- list_all_files(repo_id, config, token),
         {:ok, data_files} <- find_split_files(files, split, config),
         {:ok, data} <- download_and_parse_files(repo_id, data_files, token) do
      {:ok, data}
    end
  end

  # Private helpers

  defp build_headers(nil), do: []
  defp build_headers(token), do: [{"Authorization", "Bearer #{token}"}]

  defp list_all_files(repo_id, config, token) do
    # Try to list files recursively
    # First try the root, then try with config prefix

    case list_files(repo_id, token: token) do
      {:ok, files} ->
        # If config specified, filter by config path
        files =
          if config do
            Enum.filter(files, fn f ->
              path = f["path"] || ""

              String.starts_with?(path, config) or
                String.starts_with?(path, "data/#{config}") or
                String.contains?(path, "/#{config}/")
            end)
          else
            files
          end

        # Also try to list subdirectories
        {:ok, expand_directories(repo_id, files, token)}

      error ->
        error
    end
  end

  defp expand_directories(repo_id, files, token) do
    # Find directories and expand them
    {dirs, regular_files} =
      Enum.split_with(files, fn f ->
        f["type"] == "directory"
      end)

    expanded =
      Enum.flat_map(dirs, fn dir ->
        path = dir["path"]

        case list_files(repo_id, config: path, token: token) do
          {:ok, sub_files} ->
            # Prefix paths with parent directory
            Enum.map(sub_files, fn f ->
              current_path = f["path"] || ""

              if String.starts_with?(current_path, path) do
                f
              else
                Map.put(f, "path", "#{path}/#{current_path}")
              end
            end)

          _ ->
            []
        end
      end)

    regular_files ++ expanded
  end

  defp find_split_files(files, split, config) do
    # Find parquet or jsonl files for the requested split
    # Common patterns:
    # - data/{split}-XXXXX-of-XXXXX.parquet
    # - {split}/XXXXX.parquet
    # - {config}/{split}.parquet
    # - main/{split}.jsonl

    split_str = to_string(split)

    matching =
      files
      |> Enum.filter(fn f ->
        path = f["path"] || ""
        is_data_file?(path) and matches_split?(path, split_str, config)
      end)
      |> Enum.sort_by(fn f -> f["path"] end)

    case matching do
      [] ->
        # Try looser matching if no exact match
        fallback =
          files
          |> Enum.filter(fn f ->
            path = f["path"] || ""
            is_data_file?(path) and String.contains?(path, split_str)
          end)
          |> Enum.sort_by(fn f -> f["path"] end)

        case fallback do
          [] -> {:error, {:no_files_for_split, split, Enum.map(files, & &1["path"])}}
          found -> {:ok, found}
        end

      found ->
        {:ok, found}
    end
  end

  defp is_data_file?(path) do
    String.ends_with?(path, ".parquet") or
      String.ends_with?(path, ".jsonl") or
      String.ends_with?(path, ".json") or
      String.ends_with?(path, ".csv")
  end

  defp matches_split?(path, split, config) do
    path_lower = String.downcase(path)
    split_lower = String.downcase(split)

    # Common patterns
    String.contains?(path_lower, "/#{split_lower}") or
      String.contains?(path_lower, "/#{split_lower}-") or
      String.contains?(path_lower, "/#{split_lower}.") or
      String.starts_with?(path_lower, "#{split_lower}/") or
      String.starts_with?(path_lower, "#{split_lower}-") or
      (config && String.contains?(path_lower, "#{config}/#{split_lower}"))
  end

  defp download_and_parse_files(repo_id, files, token) do
    # Download and parse all files, concatenating results
    results =
      Enum.map(files, fn file ->
        path = file["path"]
        Logger.debug("Downloading #{path} from #{repo_id}")

        with {:ok, data} <- download_file(repo_id, path, token: token),
             {:ok, rows} <- parse_file(data, path) do
          rows
        else
          {:error, reason} ->
            Logger.warning("Failed to download/parse #{path}: #{inspect(reason)}")
            []
        end
      end)

    all_rows = List.flatten(results)

    if all_rows == [] do
      {:error, :no_data_parsed}
    else
      {:ok, all_rows}
    end
  end

  defp parse_file(data, path) do
    cond do
      String.ends_with?(path, ".parquet") ->
        parse_parquet(data)

      String.ends_with?(path, ".jsonl") ->
        parse_jsonl(data)

      String.ends_with?(path, ".json") ->
        parse_json(data)

      String.ends_with?(path, ".csv") ->
        parse_csv(data)

      true ->
        {:error, {:unsupported_format, path}}
    end
  end

  defp parse_parquet(data) do
    # Write to temp file for Explorer to read
    tmp_path = Path.join(System.tmp_dir!(), "hf_#{:erlang.unique_integer([:positive])}.parquet")

    try do
      :ok = File.write!(tmp_path, data)

      df = Explorer.DataFrame.from_parquet!(tmp_path)
      rows = Explorer.DataFrame.to_rows(df)
      {:ok, rows}
    rescue
      e ->
        {:error, {:parquet_parse_error, Exception.message(e)}}
    after
      File.rm(tmp_path)
    end
  end

  defp parse_jsonl(data) when is_binary(data) do
    rows =
      data
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        case Jason.decode(line) do
          {:ok, row} -> row
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, rows}
  end

  defp parse_json(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, rows} when is_list(rows) -> {:ok, rows}
      {:ok, obj} when is_map(obj) -> {:ok, [obj]}
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  defp parse_csv(data) when is_binary(data) do
    # Simple CSV parsing - for more complex cases, consider using NimbleCSV
    lines = String.split(data, "\n", trim: true)

    case lines do
      [header | rows] ->
        columns = String.split(header, ",") |> Enum.map(&String.trim/1)

        parsed =
          Enum.map(rows, fn row ->
            values = String.split(row, ",") |> Enum.map(&String.trim/1)
            Enum.zip(columns, values) |> Map.new()
          end)

        {:ok, parsed}

      [] ->
        {:ok, []}
    end
  end
end
