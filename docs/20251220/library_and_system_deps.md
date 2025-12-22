# Library and System Dependencies

This document maps Python datasets dependencies to Elixir equivalents and indicates whether
they are needed for tinker-cookbook parity.

Inline tags: [TK]=needed for tinker-cookbook parity, [NP]=not needed for tinker-cookbook parity.

## Architecture: 2-Package System

The Elixir port uses a **2-package architecture**:

1. **hf_hub_ex** - Single shared core package (mirrors Python's huggingface_hub)
2. **crucible_datasets** - Dataset library (depends on hf_hub_ex)

## Dependency Project Mapping

| Python dep / subsystem | Purpose in Python | Elixir package/module | Notes |
| --- | --- | --- | --- |
| huggingface_hub + hub.py | Hub metadata + file listing | hf_hub_ex (HfHub.Api) [TK] | Required for configs/splits/metadata |
| fsspec + filesystems/* | Unified filesystem API | hf_hub_ex (HfHub.FS) [TK] | local + HTTP + hf:// URIs |
| download_manager.py | Download + cache + extract | hf_hub_ex (HfHub.Download + HfHub.Cache) [TK] | Includes cache, checksums, locks; extraction available in v0.1.1 |
| streaming_download_manager.py | Streaming downloads | hf_hub_ex (HfHub.Download) [TK] | Required for IterableDataset |
| utils/file_utils.py | Auth/tokens | hf_hub_ex (HfHub.Auth) [TK] | Token management |
| features/features.py | Schema system | crucible_datasets (Features) [TK] | Value/ClassLabel/Sequence/Image |
| pyarrow + table.py | Arrow tables + IPC | arrow_ex [NP] | Not required for tinker parity |
| pandas | DataFrame ops | Explorer + Dataset.from_dataframe | Use Explorer where possible |
| numpy | array ops | Nx (optional) | Only needed for tensor conversions |
| Pillow | Image decode | crucible_datasets (MediaRef) + Vix [TK] | VLM datasets require image decode |
| torchcodec | Audio/Video decode | (future) [NP] | Audio/video not required for tinker parity |
| nibabel | NIfTI decode | nifti_ex [NP] | Not required for tinker parity |
| pdfplumber | PDF decode | pdf_ex [NP] | Not required for tinker parity |
| zstandard/lz4 | Compression | (can add to hf_hub_ex) [NP] | Only if HF uses these formats |
| pyyaml | Dataset card parsing | hf_hub_ex (optional) | Optional unless dataset cards needed |
| filelock | Cache locking | hf_hub_ex (HfHub.Cache) | Provide simple file lock |
| tqdm | Progress UI | telemetry/logging | Optional |
| xxhash | Fast hashing | :crypto | Use sha256 unless perf requires xxhash |
| multiprocess | Parallel map | BEAM concurrency | Use Task/Flow when needed |

## Dependencies Required for Tinker Parity

### Elixir Packages
- **hf_hub** (hf_hub_ex) - Core HuggingFace hub operations (HfHub.Api, HfHub.FS, HfHub.Download, HfHub.Cache, HfHub.Auth)
- **crucible_datasets** - Dataset types, Features system, format parsers, media wrappers
- Req (HTTP)
- Jason (JSON)
- Explorer (Parquet + DataFrame)
- NimbleCSV (CSV)
- Vix (image decode via libvips)

### Erlang/OTP Built-ins
- :crypto (hashing)
- :zlib, :zip, :erl_tar (extraction)
- :file (file locks)

## Not Needed for Tinker Parity (Full Parity Only)
- arrow_ex (Arrow IPC + memory-mapped tables)
- pdf_ex (PDF parsing)
- nifti_ex (NIfTI parsing)
- compression_ex (zstd/lz4) - can be added to hf_hub_ex extraction if needed
- audio/video decode capabilities

## System-Level Dependencies

### Required for Tinker Parity
- libvips (image decode via Vix)

### Not Needed for Tinker Parity (Full Parity Only)
- ffmpeg (audio/video decode)
- pdfium or poppler (PDF parsing backend)
- zstd/lz4 system libs (compression)

## Risk Notes
- Parquet streaming is the highest-risk component for tinker parity.
- Image decode is required for VLM datasets; keep audio/video optional.
