defmodule CrucibleDatasets.Fetcher.HuggingFace do
  @moduledoc """
  HuggingFace Hub API client for dataset downloads.

  This module provides a high-level interface for fetching datasets from HuggingFace Hub,
  built on top of the `HfHub` library which handles API access, downloads, and caching.

  ## Features

  - List files in a HuggingFace dataset repository
  - Download individual files with automatic caching
  - Fetch and parse complete dataset splits (parquet, jsonl, json, csv)
  - Resume interrupted downloads
  - Smart caching with LRU eviction

  ## Authentication

  Set the `HF_TOKEN` environment variable for authenticated access to private datasets,
  or configure via:

      config :hf_hub, token: "hf_..."

  ## Examples

      # List files in a dataset
      {:ok, files} = HuggingFace.list_files("openai/gsm8k")

      # Download a specific file
      {:ok, path} = HuggingFace.download_file("openai/gsm8k", "data/train.parquet")

      # Fetch and parse a dataset split
      {:ok, rows} = HuggingFace.fetch("openai/gsm8k", split: "train")

      # Get dataset configurations
      {:ok, configs} = HuggingFace.dataset_configs("openai/gsm8k")

  """

  require Logger

  @doc """
  Build the download URL for a file in a HuggingFace dataset.

  ## Examples

      iex> HuggingFace.build_file_url("openai/gsm8k", "data/train.parquet")
      "https://huggingface.co/datasets/openai/gsm8k/resolve/main/data/train.parquet"

  """
  @spec build_file_url(String.t(), String.t(), keyword()) :: String.t()
  def build_file_url(repo_id, path, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    endpoint = HfHub.Config.endpoint()
    "#{endpoint}/datasets/#{repo_id}/resolve/#{revision}/#{path}"
  end

  @doc """
  List all files in a HuggingFace dataset repository.

  ## Options
    * `:config` - Dataset configuration/subset (filters by path prefix)
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token (default: from HF_TOKEN env var or hf_hub config)

  ## Returns
    * `{:ok, files}` - List of file metadata maps with "path", "size", "type" keys
    * `{:error, reason}` - Error tuple

  """
  @spec list_files(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_files(repo_id, opts \\ []) do
    config = Keyword.get(opts, :config)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)

    case HfHub.Api.list_files(repo_id, repo_type: :dataset, revision: revision, token: token) do
      {:ok, files} ->
        # Convert HfHub file_info format to our expected format
        formatted_files =
          files
          |> Enum.map(fn file ->
            %{
              "path" => file.rfilename,
              "size" => file.size,
              "type" => if(String.contains?(file.rfilename || "", "/"), do: "file", else: "file"),
              "lfs" => file.lfs
            }
          end)
          |> maybe_filter_by_config(config)

        {:ok, formatted_files}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_filter_by_config(files, nil), do: files

  defp maybe_filter_by_config(files, config) do
    Enum.filter(files, fn f ->
      path = f["path"] || ""

      String.starts_with?(path, config) or
        String.starts_with?(path, "data/#{config}") or
        String.contains?(path, "/#{config}/")
    end)
  end

  @doc """
  Download a file from a HuggingFace dataset repository.

  Downloads to the HfHub cache and returns the file contents. Uses caching by default,
  so repeated downloads of the same file are served from cache.

  ## Options
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token (default: from hf_hub config)
    * `:force_download` - Force re-download even if cached (default: false)

  ## Returns
    * `{:ok, binary}` - File contents as binary
    * `{:error, reason}` - Error tuple

  """
  @spec download_file(String.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def download_file(repo_id, path, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)
    force_download = Keyword.get(opts, :force_download, false)

    download_opts = [
      repo_id: repo_id,
      filename: path,
      repo_type: :dataset,
      revision: revision,
      force_download: force_download
    ]

    download_opts = if token, do: Keyword.put(download_opts, :token, token), else: download_opts

    case HfHub.Download.hf_hub_download(download_opts) do
      {:ok, cache_path} ->
        # Read the file contents from cache
        case File.read(cache_path) do
          {:ok, ""} ->
            # Empty file likely means download failed (404 created empty file)
            {:error, :empty_file}

          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Download a file and return the local cache path instead of contents.

  Useful for large files where you don't want to load the entire file into memory.

  ## Options
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token
    * `:force_download` - Force re-download even if cached (default: false)

  ## Returns
    * `{:ok, path}` - Local path to the cached file
    * `{:error, reason}` - Error tuple

  """
  @spec download_file_to_cache(String.t(), String.t(), keyword()) ::
          {:ok, Path.t()} | {:error, term()}
  def download_file_to_cache(repo_id, path, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)
    force_download = Keyword.get(opts, :force_download, false)

    download_opts = [
      repo_id: repo_id,
      filename: path,
      repo_type: :dataset,
      revision: revision,
      force_download: force_download
    ]

    download_opts = if token, do: Keyword.put(download_opts, :token, token), else: download_opts

    HfHub.Download.hf_hub_download(download_opts)
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
    * `:max_files` - Maximum number of files to download for sharded datasets (default: 3)

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
    token = Keyword.get(opts, :token)
    # Limit files for large sharded datasets (default: 3 files max)
    max_files = Keyword.get(opts, :max_files, 3)

    with {:ok, files} <- list_all_files(repo_id, config, token),
         {:ok, data_files} <- find_split_files(files, split, config),
         limited_files = Enum.take(data_files, max_files),
         {:ok, data} <- download_and_parse_files(repo_id, limited_files, token) do
      {:ok, data}
    end
  end

  @doc """
  Get dataset information from HuggingFace Hub.

  ## Options
    * `:revision` - Git revision/branch (default: "main")
    * `:token` - HuggingFace API token

  ## Returns
    * `{:ok, info}` - Dataset metadata map
    * `{:error, reason}` - Error tuple

  """
  @spec dataset_info(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def dataset_info(repo_id, opts \\ []) do
    HfHub.Api.dataset_info(repo_id, opts)
  end

  @doc """
  Get available configuration names for a dataset.

  Configurations (also called subsets) represent different versions of a dataset.
  For example, `openai/gsm8k` has "main" and "socratic" configs.

  ## Options
    * `:token` - HuggingFace API token

  ## Returns
    * `{:ok, configs}` - List of configuration names
    * `{:error, reason}` - Error tuple

  ## Examples

      {:ok, configs} = HuggingFace.dataset_configs("openai/gsm8k")
      # => {:ok, ["main", "socratic"]}

  """
  @spec dataset_configs(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def dataset_configs(repo_id, opts \\ []) do
    HfHub.Api.dataset_configs(repo_id, opts)
  end

  @doc """
  Check if a dataset file is cached locally.

  ## Options
    * `:revision` - Git revision/branch (default: "main")

  ## Returns
    * `true` if the file is cached, `false` otherwise

  """
  @spec cached?(String.t(), String.t(), keyword()) :: boolean()
  def cached?(repo_id, filename, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")

    HfHub.Cache.cached?(
      repo_id: repo_id,
      filename: filename,
      repo_type: :dataset,
      revision: revision
    )
  end

  @doc """
  Get the local cache path for a dataset file.

  ## Options
    * `:revision` - Git revision/branch (default: "main")

  ## Returns
    * `{:ok, path}` - Local path to the cached file
    * `{:error, :not_cached}` - File is not cached

  """
  @spec cache_path(String.t(), String.t(), keyword()) :: {:ok, Path.t()} | {:error, :not_cached}
  def cache_path(repo_id, filename, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")

    HfHub.Cache.cache_path(
      repo_id: repo_id,
      filename: filename,
      repo_type: :dataset,
      revision: revision
    )
  end

  # Private helpers

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
      String.ends_with?(path, ".jsonl.gz") or
      String.ends_with?(path, ".json") or
      String.ends_with?(path, ".json.gz") or
      String.ends_with?(path, ".csv") or
      String.ends_with?(path, ".csv.gz")
  end

  defp matches_split?(path, split, config) do
    path_lower = String.downcase(path)
    split_lower = String.downcase(split)
    filename = Path.basename(path_lower)

    # Common patterns:
    # - data/train-00000-of-00001.parquet
    # - train/00000.parquet
    # - config/train.jsonl
    # - harmless-base/train.jsonl.gz (filename starts with split)
    String.contains?(path_lower, "/#{split_lower}") or
      String.contains?(path_lower, "/#{split_lower}-") or
      String.contains?(path_lower, "/#{split_lower}.") or
      String.starts_with?(path_lower, "#{split_lower}/") or
      String.starts_with?(path_lower, "#{split_lower}-") or
      String.starts_with?(filename, "#{split_lower}.") or
      String.starts_with?(filename, "#{split_lower}-") or
      (config && String.contains?(path_lower, "#{config}/#{split_lower}"))
  end

  defp download_and_parse_files(repo_id, files, token) do
    # Download and parse all files, concatenating results
    results =
      Enum.map(files, fn file ->
        path = file["path"]
        download_opts = if token, do: [token: token], else: []

        # For parquet files, use cached path directly (more efficient)
        # For other formats, read contents
        result =
          if String.ends_with?(path, ".parquet") do
            with {:ok, cache_path} <- download_file_to_cache(repo_id, path, download_opts),
                 {:ok, rows} <- parse_parquet_file(cache_path) do
              rows
            end
          else
            with {:ok, data} <- download_file(repo_id, path, download_opts),
                 {:ok, rows} <- parse_file(data, path) do
              rows
            end
          end

        case result do
          {:error, reason} ->
            Logger.warning("Failed to download/parse #{path}: #{inspect(reason)}")
            []

          rows when is_list(rows) ->
            rows
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
    # Decompress if gzipped
    {data, path} = maybe_decompress(data, path)

    cond do
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

  defp maybe_decompress(data, path) do
    if String.ends_with?(path, ".gz") do
      {:zlib.gunzip(data), String.replace_suffix(path, ".gz", "")}
    else
      {data, path}
    end
  rescue
    _ -> {data, path}
  end

  defp parse_parquet_file(file_path) do
    # First validate the parquet file has correct magic bytes
    case validate_parquet_file(file_path) do
      :ok ->
        try do
          df = Explorer.DataFrame.from_parquet!(file_path)
          rows = Explorer.DataFrame.to_rows(df)
          {:ok, rows}
        rescue
          e ->
            # Delete corrupted file so it gets re-downloaded next time
            File.rm(file_path)
            {:error, {:parquet_parse_error, Exception.message(e)}}
        end

      {:error, reason} ->
        # Delete corrupted file so it gets re-downloaded next time
        File.rm(file_path)
        {:error, {:parquet_validation_failed, reason}}
    end
  end

  defp validate_parquet_file(file_path) do
    # Parquet files must start with "PAR1" and end with "PAR1"
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          header = IO.binread(file, 4)
          :file.position(file, {:eof, -4})
          footer = IO.binread(file, 4)
          File.close(file)

          cond do
            not is_binary(header) or byte_size(header) < 4 -> {:error, :invalid_header}
            not is_binary(footer) or byte_size(footer) < 4 -> {:error, :invalid_footer}
            header != "PAR1" -> {:error, :invalid_header}
            footer != "PAR1" -> {:error, :invalid_footer}
            true -> :ok
          end
        rescue
          _ ->
            File.close(file)
            {:error, :file_read_error}
        end

      {:error, reason} ->
        {:error, {:file_open_error, reason}}
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
