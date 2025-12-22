# Dependency Projects (Must Land First)

Complete tinker-cookbook parity requires prerequisite Elixir packages that replace core
Python dependencies. The foundational package is hf_hub_ex, which serves as the single
shared core for all HuggingFace operations in Elixir.

**Status update (2025-12-21):** hf_hub_ex v0.1.1 is integrated into crucible_datasets for
Hub API, downloads, caching, and extraction.

Inline tags: [TK]=needed for tinker-cookbook parity, [NP]=not needed for tinker-cookbook parity.

## 1) hf_hub_ex [TK] (HuggingFace Hub - Core Foundation Package)

**Python equivalents:** huggingface_hub, fsspec, download_manager.py, streaming_download_manager.py, utils/extract.py

**Purpose:** Single shared core package mirroring Python's huggingface_hub. Used by both tinkex (Elixir training SDK) and crucible_datasets. This is the foundation for the entire HF ecosystem in Elixir.

**Scope (implemented in hf_hub_ex v0.1.1):**
  - **HfHub.Api** - Hub API client
    - dataset list/search
    - config enumeration (get_dataset_config_names)
    - split enumeration (get_dataset_split_names)
    - file listing for repo + config
    - repo tree listing with pagination
    - dataset metadata and info (dataset_info)
  - **HfHub.Download** - File downloads and streaming
    - streaming read interface (IO device/Stream)
    - streaming downloads for IterableDataset
    - parallel/resumable downloads
    - optional archive extraction (zip/tar.gz/tgz/tar.xz/gz)
  - **HfHub.Cache** - Content-addressed caching
    - download caching (content-addressed)
    - checksum hashing and validation
    - file locking for concurrent access
    - cache policy configuration
  - **HfHub.FS** - Unified filesystem abstraction
    - local, HTTP(S), and HuggingFace Hub (hf://) file access
    - uniform open/read/list API
    - integration hooks for caching and extraction
    - optional S3/GCS later
  - **HfHub.Auth** - Token management
    - auth token handling
    - credential storage and retrieval

**Outputs:**
  - Hex package: hf_hub_ex
  - Shared by tinkex and crucible_datasets
  - Foundation for future HF ecosystem ports (transformers, tokenizers, etc.)

## 2) arrow_ex [NP] (Arrow IPC + table semantics)
- Python equivalents: pyarrow, table.py, arrow_reader.py, arrow_writer.py
- Scope:
  - Arrow IPC read/write
  - row group iteration and lazy scanning
  - dataset slicing without full materialization
- Notes:
  - Not needed for tinker parity
  - Explorer/Polars can cover parquet parsing, but Arrow IPC and memory-mapped table semantics
    likely require a Rust NIF or binding to arrow-rs
  - Full parity only

## 3) compression_ex [NP] (Compression)
- Python equivalents: zstandard, lz4
- Scope:
  - zstd/lz4 streaming decode
  - integrate with hf_hub_ex download/extraction paths
- Notes:
  - Not needed for tinker parity unless HF datasets ship data in these formats
  - Can be added to hf_hub_ex extraction pipeline if required

## 4) pdf_ex [NP] (PDF support)
- Python equivalents: pdfplumber, features/pdf.py
- Scope:
  - PDF file parsing (path or bytes)
  - metadata extraction (pages, sizes, etc.)
  - optional text extraction and page iteration
- Notes:
  - Not used in tinker-cookbook today; full parity only
  - Choose a backend (pdfium, poppler, or MuPDF) based on licensing and bindings

## 5) nifti_ex [NP] (NIfTI support)
- Python equivalents: nibabel, features/nifti.py
- Scope:
  - NIfTI file parsing (.nii, .nii.gz)
  - metadata extraction (shape, affine, dtype)
  - optional conversion to tensors
- Notes:
  - Not used in tinker-cookbook today; full parity only

## Integration Order (tinker parity)
1. hf_hub_ex (single unified package - foundation for all HF operations)
2. crucible_datasets (depends on hf_hub_ex for all hub operations)

## Notes on Architecture

The original plan separated hf_hub_ex, hf_fs_ex, and hf_download_ex into three packages. This has been consolidated into a **single hf_hub_ex package** for the following reasons:

- **Mirrors Python ecosystem**: Python's huggingface_hub is a single package containing hub API, filesystem abstraction, caching, and downloads
- **Shared foundation**: Both tinkex (training SDK) and crucible_datasets need all these capabilities
- **Simpler dependency graph**: One core package instead of managing three separate packages with interdependencies
- **Better cohesion**: Hub operations, filesystem access, caching, and downloads are tightly coupled in practice

The internal structure of hf_hub_ex maintains clear module boundaries (HfHub.Api, HfHub.FS, HfHub.Download, HfHub.Cache, HfHub.Auth) while presenting a unified package.

## Deliverables for hf_hub_ex
- Minimal public API spec (all modules)
- Unit tests for each module
- Example usage and integration guide
- System dependency list
- Versioned release (hex package)
- Documentation for tinkex and crucible_datasets integration
