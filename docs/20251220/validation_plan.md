# Validation Plan

This plan defines how to validate tinker-cookbook parity. Optional full-parity checks are listed
separately.

## Unit Tests (offline)
- DataFiles
  - split matching for train/test/validation
  - config enumeration and file pattern matching
- DownloadManager
  - caching behavior (hit/miss)
  - extraction (zip/tar/gz)
  - checksum/hash behavior
- IO readers
  - JSONL streaming parser
  - CSV parsing (NimbleCSV)
  - Parquet parse via Explorer
- Dataset operations
  - map/filter/select/shuffle/take/skip/concat/batch
- Type adapters
  - Message/Conversation/Comparison/LabeledComparison normalization
  - MediaRef (image) adapters
- DatasetDict/IterableDataset operations

## Integration Tests (network)
- HuggingFace API
  - list files for each required dataset
  - download and parse a small split sample
- Dataset-specific loaders
  - GSM8K, MATH-500, Hendrycks, DeepMath, Polaris
  - Tulu-3-SFT, No Robots
  - HH-RLHF, HelpSteer2/3, UltraFeedback, Arena, Tulu-Preference
  - DeepCoder configs
- Vision datasets (caltech101, flowers102, oxford_iiit_pet, stanford_cars)
- Streaming datasets
  - OpenThoughts streaming iterator (first N records)

Integration tests are tagged with `@tag :live` and excluded by default.

## Performance Checks (non-blocking)
- Parquet load time for 10k rows
- JSONL streaming throughput
- Memory usage for full vs streaming loads

## Acceptance Criteria (tinker parity)
- All required datasets load real data and parse into expected shapes.
- DatasetDict semantics work for split indexing.
- Operations used by tinker (shuffle/filter/select/take/skip/map/batch/concat) pass tests.
- Streaming works for OpenThoughts.
- Image decode works for VLM datasets.

## Optional Full-Parity Checks (later)
- Arrow IPC and memory-mapped semantics
- PDF and NIfTI feature support
- Audio/video decoding
