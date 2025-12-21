# Agent Prompt: CrucibleDatasets Tinker Parity (2025-12-20)

**Working Directory:** /home/home/p/g/North-Shore-AI/crucible_datasets

## Architecture

The port uses a **2-package architecture**:

1. **hf_hub_ex** - Single shared core package (mirrors Python's huggingface_hub)
   - Contains: HfHub.Api, HfHub.FS, HfHub.Download, HfHub.Cache, HfHub.Auth
   - Used by both tinkex (Elixir training SDK) and crucible_datasets
   - Foundation for the broader HF ecosystem in Elixir
   - **This is the critical path** - must be built first

2. **crucible_datasets** - Dataset library (depends on hf_hub_ex)
   - Contains: Dataset/DatasetDict/IterableDataset, Features system, format parsers, media wrappers
   - Uses hf_hub_ex for all hub operations

## Required Reading (short list)
1. `docs/20251220/README.md` - Architecture overview
2. `docs/20251220/dependency_projects.md` - hf_hub_ex detailed scope
3. `docs/20251220/library_and_system_deps.md` - Dependency mapping
4. `docs/20251220/tinker_requirements.md` - Dataset requirements
5. `docs/20251220/PORTING_PLAN.md` - Phase plan
6. `docs/20251220/gap_analysis.md` - Current gaps

## Mission
Deliver tinker-cookbook parity in Elixir: all datasets and operations required to run every
cookbook experiment, including VLM image classification.

## Success Criteria
- hf_hub_ex is built and published as a hex package
- crucible_datasets depends on hf_hub_ex for all hub operations
- All datasets required by the tinker cookbook load real HF data
- DatasetDict semantics work for split indexing
- IterableDataset streaming works for OpenThoughts
- Full dataset operations: map/filter/select/shuffle/take/skip/batch/concat
- Feature system supports Value/ClassLabel/Sequence + image decode

## Constraints
- **Build hf_hub_ex first** - it's the foundation for everything else
- hf_hub_ex must be a single unified package (not split into multiple packages)
- Prefer native Elixir; only introduce Rust NIFs if required for streaming
- Audio/video, PDF, NIfTI, and Arrow IPC are out of scope for tinker parity
- hf_hub_ex should be shared by both tinkex and crucible_datasets

## Implementation Order (high level)
1. **Build hf_hub_ex** (single package containing HfHub.Api, HfHub.FS, HfHub.Download, HfHub.Cache, HfHub.Auth)
2. **Integrate hf_hub_ex into crucible_datasets** (replace Fetcher.HuggingFace)
3. Build Features system + DatasetDict/IterableDataset + dataset ops
4. Implement streaming for JSONL and Parquet (using HfHub.Download)
5. Add image decode support (Vix/libvips) and integrate into Features
6. Complete missing dataset loaders for tinker datasets

## Critical Path
Everything depends on hf_hub_ex. Do not proceed with other work until hf_hub_ex is built and integrated.

