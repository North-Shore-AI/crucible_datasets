# Image Support Implementation Plan

**Date:** 2025-12-21
**Goal:** Enable vision dataset loading for VLM training
**Python Reference:** `./datasets/src/datasets/features/image.py`

---

## Overview

**Required for:**
- caltech101 (102 categories)
- oxford_flowers102 (102 flower species)
- oxford_iiit_pet (37 pet breeds)
- stanford_cars (196 car models)

**Image formats in HF datasets:**
1. Embedded bytes in Parquet (most common for vision datasets)
2. File paths to images in repo
3. URLs to external images

**Status Update (2025-12-21):** Image features and vision loaders are implemented. Image decode
uses Vix/libvips and returns `Vix.Vips.Image` when decode is enabled.
Resize and Nx tensor conversion examples below remain future work.

---

## Part 1: Image Feature Type

### Current Implementation

**File:** `lib/dataset_manager/features/image.ex`
**Status:** Implemented (tinker scope)

```elixir
defmodule CrucibleDatasets.Features.Image do
  defstruct mode: nil, decode: true

  def new(opts \\ []) do
    %__MODULE__{
      mode: Keyword.get(opts, :mode),
      decode: Keyword.get(opts, :decode, true)
    }
  end

  def rgb, do: new(mode: "RGB")
  def grayscale, do: new(mode: "L")
  def rgba, do: new(mode: "RGBA")
end
```

**What's missing:**
- encode/decode helpers (optional)
- Extended validation + tensor conversion (full parity)

### Enhanced Implementation

**Note:** The current implementation decodes to `Vix.Vips.Image`. Nx tensor conversion is deferred.

```elixir
defmodule CrucibleDatasets.Features.Image do
  @moduledoc """
  Image feature type for vision datasets.

  Images are stored as %{"bytes" => binary(), "path" => string() | nil}.

  When decode: true, images are decoded to Vix.Vips.Image values.
  When decode: false, raw bytes/path dict is returned.
  """

  @type mode :: :rgb | :grayscale | :rgba | nil
  @type t :: %__MODULE__{mode: mode(), decode: boolean()}

  defstruct mode: nil, decode: true

  @doc "Create image feature"
  def new(opts \\ []) do
    %__MODULE__{
      mode: normalize_mode(Keyword.get(opts, :mode)),
      decode: Keyword.get(opts, :decode, true)
    }
  end

  @doc """
  Encode various image inputs to standard format.

  Accepts:
  - Binary (raw image bytes)
  - %{"bytes" => binary(), "path" => string()}
  - %{"path" => string()} (will read file)
  - File path string
  """
  def encode_example(value) when is_binary(value) do
    %{"bytes" => value, "path" => nil}
  end

  def encode_example(%{"bytes" => bytes, "path" => path}) do
    %{"bytes" => bytes, "path" => path}
  end

  def encode_example(%{"path" => path}) when is_binary(path) do
    bytes = if File.exists?(path), do: File.read!(path), else: nil
    %{"bytes" => bytes, "path" => path}
  end

  @doc """
  Decode image to Nx tensor (requires Vix).

  Returns {:ok, tensor} or {:error, reason}.
  """
  def decode_example(value, %__MODULE__{decode: false}) do
    {:ok, value}
  end

  def decode_example(%{"bytes" => bytes}, %__MODULE__{mode: mode})
      when is_binary(bytes) do
    CrucibleDatasets.Media.Image.decode(bytes, mode: mode)
  end
end
```

---

## Part 2: ClassLabel Feature Type

### Current Implementation

**File:** `lib/dataset_manager/features/class_label.ex`
**Status:** COMPLETE

Already has:
- names/num_classes
- int2str/str2int
- encode/decode

**No changes needed.**

---

## Part 3: Image Decode Module

### Dependencies

**Required:**
- `vix` - Elixir wrapper for libvips (image processing)
- System: `libvips` (brew install vips / apt-get install libvips-dev)

**Add to mix.exs:**
```elixir
defp deps do
  [
    {:vix, "~> 0.35"},  # Image processing via libvips
    # ... other deps
  ]
end
```

### Implementation

**File:** `lib/dataset_manager/media/image.ex`

```elixir
defmodule CrucibleDatasets.Media.Image do
  @moduledoc """
  Image decoding and processing.

  Wraps Vix (libvips) for high-performance image operations.
  """

  require Logger

  @doc """
  Decode image bytes to Nx tensor.

  ## Options
    * `:mode` - Color mode (:rgb, :grayscale, :rgba)
    * `:resize` - Resize to {width, height}

  ## Examples
      {:ok, tensor} = Image.decode(jpeg_bytes, mode: :rgb)
      # tensor shape: {height, width, 3}
  """
  def decode(bytes, opts \\ []) when is_binary(bytes) do
    mode = Keyword.get(opts, :mode, :rgb)
    resize = Keyword.get(opts, :resize)

    with {:ok, vips_image} <- load_from_bytes(bytes),
         {:ok, vips_image} <- convert_mode(vips_image, mode),
         {:ok, vips_image} <- maybe_resize(vips_image, resize),
         {:ok, tensor} <- to_nx_tensor(vips_image) do
      {:ok, tensor}
    end
  end

  @doc "Decode image from file path."
  def decode_file(path, opts \\ []) when is_binary(path) do
    case File.read(path) do
      {:ok, bytes} -> decode(bytes, opts)
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  # Private helpers

  defp load_from_bytes(bytes) do
    case Vix.Vips.Image.new_from_buffer(bytes) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, {:vix_load_error, reason}}
    end
  end

  defp convert_mode(image, nil), do: {:ok, image}

  defp convert_mode(image, :rgb) do
    case Vix.Vips.Operation.colourspace(image, :VIPS_INTERPRETATION_RGB) do
      {:ok, rgb_image} -> {:ok, rgb_image}
      {:error, reason} -> {:error, {:convert_mode_error, reason}}
    end
  end

  defp convert_mode(image, :grayscale) do
    case Vix.Vips.Operation.colourspace(image, :VIPS_INTERPRETATION_B_W) do
      {:ok, gray_image} -> {:ok, gray_image}
      {:error, reason} -> {:error, {:convert_mode_error, reason}}
    end
  end

  defp maybe_resize(image, nil), do: {:ok, image}

  defp maybe_resize(image, {width, height}) do
    current_width = Vix.Vips.Image.width(image)
    current_height = Vix.Vips.Image.height(image)

    hscale = width / current_width
    vscale = height / current_height

    case Vix.Vips.Operation.resize(image, hscale, vscale: vscale) do
      {:ok, resized} -> {:ok, resized}
      {:error, reason} -> {:error, {:resize_error, reason}}
    end
  end

  defp to_nx_tensor(vips_image) do
    case Vix.Vips.Image.write_to_binary(vips_image) do
      {:ok, binary} ->
        height = Vix.Vips.Image.height(vips_image)
        width = Vix.Vips.Image.width(vips_image)
        bands = Vix.Vips.Image.bands(vips_image)

        tensor = Nx.from_binary(binary, :u8)
          |> Nx.reshape({height, width, bands})

        {:ok, tensor}

      {:error, reason} ->
        {:error, {:tensor_conversion_error, reason}}
    end
  end

  @doc """
  Encode Nx tensor back to image bytes.

  ## Options
    * `:format` - Output format (:jpeg, :png, :webp)
    * `:quality` - JPEG quality (1-100)
  """
  def encode(tensor, opts \\ []) do
    format = Keyword.get(opts, :format, :jpeg)
    quality = Keyword.get(opts, :quality, 90)

    with {:ok, vips_image} <- from_nx_tensor(tensor),
         {:ok, bytes} <- write_to_bytes(vips_image, format, quality) do
      {:ok, bytes}
    end
  end
end
```

---

## Part 4: Vision Dataset Loader

### Generic Vision Loader

**File:** `lib/dataset_manager/loader/vision.ex`

```elixir
defmodule CrucibleDatasets.Loader.Vision do
  @moduledoc """
  Generic loader for vision datasets (image classification).

  Supports:
  - caltech101
  - oxford_flowers102
  - oxford_iiit_pet
  - stanford_cars
  """

  alias CrucibleDatasets.{Dataset, Features}
  alias CrucibleDatasets.Features.{Image, ClassLabel}
  alias CrucibleDatasets.Fetcher.HuggingFace

  require Logger

  # Dataset configurations
  @datasets %{
    caltech101: %{
      repo_id: "dpdl-benchmark/caltech101",
      num_classes: 102,
      has_species: false
    },
    flowers102: %{
      repo_id: "dpdl-benchmark/oxford_flowers102",
      num_classes: 102,
      has_species: false
    },
    oxford_iiit_pet: %{
      repo_id: "dpdl-benchmark/oxford_iiit_pet",
      num_classes: 37,
      has_species: true
    },
    stanford_cars: %{
      repo_id: "tanganke/stanford_cars",
      num_classes: 196,
      has_species: false
    }
  }

  @doc """
  Load a vision dataset.

  ## Options
    * `:split` - Dataset split (:train, :test, :validation)
    * `:decode_images` - Decode images to tensors (default: false)
    * `:resize` - Resize images to {width, height}
    * `:sample_size` - Limit number of items
  """
  def load(dataset_name, opts \\ []) when is_atom(dataset_name) do
    case Map.get(@datasets, dataset_name) do
      nil -> {:error, {:unknown_vision_dataset, dataset_name}}
      config -> load_dataset(dataset_name, config, opts)
    end
  end

  defp load_dataset(dataset_name, config, opts) do
    split = Keyword.get(opts, :split, :train) |> to_string()
    decode_images = Keyword.get(opts, :decode_images, false)
    sample_size = Keyword.get(opts, :sample_size)

    case HuggingFace.fetch(config.repo_id, split: split, token: opts[:token]) do
      {:ok, raw_data} ->
        items = parse_vision_data(raw_data, dataset_name, decode_images, opts)
        items = if sample_size, do: Enum.take(items, sample_size), else: items

        features = build_features(config, decode_images)

        dataset = Dataset.new(
          to_string(dataset_name),
          "1.0",
          items,
          %{
            source: "huggingface:#{config.repo_id}",
            split: split,
            domain: "vision",
            task_type: "image_classification",
            num_classes: config.num_classes
          },
          features
        )

        {:ok, dataset}

      {:error, reason} ->
        {:error, {:huggingface_fetch_failed, reason}}
    end
  end

  defp parse_vision_data(raw_data, dataset_name, decode_images, opts) do
    resize = Keyword.get(opts, :resize)

    raw_data
    |> Enum.with_index()
    |> Enum.map(fn {row, idx} ->
      image_value = parse_image(row["image"], decode_images, resize)
      label = parse_label(row["label"])

      item = %{
        id: "#{dataset_name}_#{idx}",
        input: %{image: image_value},
        expected: label,
        metadata: %{dataset: dataset_name}
      }

      if Map.has_key?(row, "species") do
        put_in(item, [:metadata, :species], row["species"])
      else
        item
      end
    end)
  end

  defp parse_image(image_data, false, _resize) do
    case image_data do
      %{"bytes" => bytes, "path" => path} ->
        %{"bytes" => bytes, "path" => path}
      %{"bytes" => bytes} ->
        %{"bytes" => bytes, "path" => nil}
      bytes when is_binary(bytes) ->
        %{"bytes" => bytes, "path" => nil}
    end
  end

  defp parse_image(image_data, true, resize) do
    bytes = case image_data do
      %{"bytes" => b} when is_binary(b) -> b
      %{"path" => p} -> File.read!(p)
      b when is_binary(b) -> b
    end

    opts = if resize, do: [mode: :rgb, resize: resize], else: [mode: :rgb]

    case CrucibleDatasets.Media.Image.decode(bytes, opts) do
      {:ok, tensor} -> tensor
      {:error, reason} ->
        Logger.warning("Failed to decode image: #{inspect(reason)}")
        %{"bytes" => bytes, "path" => nil}
    end
  end

  defp parse_label(label) when is_integer(label), do: label
  defp parse_label(label) when is_binary(label) do
    case Integer.parse(label) do
      {int, ""} -> int
      _ -> label
    end
  end

  defp build_features(config, decode_images) do
    image_feature = Image.new(decode: decode_images)
    label_feature = ClassLabel.new(num_classes: config.num_classes)

    schema = %{
      "image" => image_feature,
      "label" => label_feature
    }

    schema = if config.has_species do
      Map.put(schema, "species", ClassLabel.new(names: ["cat", "dog"]))
    else
      schema
    end

    Features.new(schema)
  end

  @doc "Get list of supported vision datasets"
  def list_datasets do
    Map.keys(@datasets)
  end
end
```

---

## Part 5: Testing

### Unit Tests

**File:** `test/crucible_datasets/media/image_test.exs`

```elixir
defmodule CrucibleDatasets.Media.ImageTest do
  use ExUnit.Case
  alias CrucibleDatasets.Media.Image

  @tag :vix_required
  test "decode JPEG bytes to tensor" do
    jpeg_bytes = File.read!("test/fixtures/sample.jpg")

    {:ok, tensor} = Image.decode(jpeg_bytes, mode: :rgb)

    assert {_h, _w, 3} = Nx.shape(tensor)
    assert Nx.type(tensor) == {:u, 8}
  end

  @tag :vix_required
  test "resize image" do
    jpeg_bytes = File.read!("test/fixtures/sample.jpg")

    {:ok, tensor} = Image.decode(jpeg_bytes, mode: :rgb, resize: {224, 224})

    assert {224, 224, 3} = Nx.shape(tensor)
  end

  @tag :vix_required
  test "convert to grayscale" do
    jpeg_bytes = File.read!("test/fixtures/sample.jpg")

    {:ok, tensor} = Image.decode(jpeg_bytes, mode: :grayscale)

    assert {_h, _w, 1} = Nx.shape(tensor)
  end
end
```

### Integration Tests

**File:** `test/crucible_datasets/loader/vision_test.exs`

```elixir
@tag :live
test "load caltech101 without decode" do
  {:ok, dataset} = Vision.load(:caltech101,
    split: :train,
    decode_images: false,
    sample_size: 10
  )

  assert dataset.metadata.num_classes == 102
  assert length(dataset.items) == 10

  first = List.first(dataset.items)
  assert %{"bytes" => bytes, "path" => _} = first.input.image
  assert is_binary(bytes)
end

@tag :live
@tag :vix_required
test "load caltech101 with decode" do
  {:ok, dataset} = Vision.load(:caltech101,
    split: :train,
    decode_images: true,
    resize: {224, 224},
    sample_size: 5
  )

  first = List.first(dataset.items)
  tensor = first.input.image

  assert {224, 224, 3} = Nx.shape(tensor)
end
```

---

## Part 6: Documentation

### User Guide

```markdown
# Vision Dataset Support

CrucibleDatasets supports loading vision datasets for VLM training.

## Supported Datasets

- **caltech101**: 102 object categories, ~9K images
- **oxford_flowers102**: 102 flower species, ~8K images
- **oxford_iiit_pet**: 37 pet breeds, ~7K images
- **stanford_cars**: 196 car models, ~16K images

## Loading Without Decode (Fast)

{:ok, dataset} = CrucibleDatasets.load(:caltech101,
  split: :train,
  decode_images: false
)

# Images are stored as %{"bytes" => ..., "path" => ...}

## Loading With Decode (For Training)

Requires `vix` dependency and libvips system library.

{:ok, dataset} = CrucibleDatasets.load(:caltech101,
  split: :train,
  decode_images: true
)

# Images are Vix.Vips.Image values (decoded with libvips)

## Setup

Add to mix.exs:
{:vix, "~> 0.35"}

Install system library:
# macOS
brew install vips

# Ubuntu/Debian
apt-get install libvips-dev
```

---

## Implementation Checklist

**Image Feature:**
- [x] Basic Image struct (exists)
- [ ] Add encode_example (optional)
- [ ] Add decode_example (optional)
- [x] Basic validation for bytes/path

**Media Module:**
- [x] Create Media.Image module
- [x] Add Vix dependency
- [x] Implement decode/2
- [ ] Implement encode/2 (optional)
- [x] Add mode conversion
- [ ] Add resize support (optional)

**Vision Loader:**
- [x] Create Vision loader module
- [x] Add dataset configurations
- [x] Parse image bytes from Parquet
- [x] Integrate with Image.decode
- [x] Handle decode: true/false modes
- [x] Add features to dataset

**Testing:**
- [ ] Unit tests for Media.Image
- [ ] Unit tests for Image feature
- [x] Integration test for vision loader (HF stub)
- [ ] Test with/without decode
- [ ] Test with resize (optional)

**Documentation:**
- [x] Vision datasets guide
- [x] API docs for Media.Image
- [x] Setup instructions for Vix/libvips

**Registry:**
- [x] Add all 4 vision datasets to registry
- [x] Update loader dispatcher

**Estimated effort:** Completed (remaining items optional)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
