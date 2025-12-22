# CrucibleDatasets Tinker Parity Docs (2025-12-20)

This directory is the authoritative plan for a complete port of the subset of HuggingFace datasets
needed to run all tinker cookbook experiments.

## Architecture Overview

The port is structured as a 2-package architecture:

1. **hf_hub_ex** - Single shared core package (mirrors Python's huggingface_hub)
   - Hub API client, caching, downloads, auth, filesystem abstraction
   - Used by both tinkex (Elixir training SDK) and crucible_datasets
   - Foundation for the broader HF ecosystem in Elixir

2. **crucible_datasets** - Dataset library (depends on hf_hub_ex)
   - Dataset/DatasetDict/IterableDataset types
   - Features system (ClassLabel, Value, Image, etc.)
   - Format parsers (parquet, jsonl, csv)
   - Media wrappers (uses Vix for images)

## Scope Policy
- Primary target: tinker-cookbook parity (all recipes, including VLM image classification).
- Full parity with Python datasets is optional and not required for this milestone.
- hf_hub_ex is built as the foundational package (like Python's huggingface_hub).
- crucible_datasets depends on hf_hub_ex for all hub operations.

## Status Snapshot (facts)
- Fetcher.HuggingFace uses hf_hub for file listing, downloads, caching, and extraction.
- Loaders cover all tinker datasets (MMLU, HumanEval, Reasoning, Rubric, Vision included).
- Core API wires all loaders; `load_dataset/2` supports repo_id/config/split/streaming with DataFiles resolution.
- DatasetDict and IterableDataset implemented; JSONL streaming is supported; Parquet streaming is limited (batch-based).
- Features system integrated with Image decode via Vix/libvips.
- Sampler, evaluator, exporter, and result_store remain solid and tested.

## How To Use These Docs
1. Read `docs/20251220/dependency_projects.md` to see prerequisite Elixir projects.
2. Read `docs/20251220/python_module_inventory.md` for a full Python module map.
3. Read `docs/20251220/feature_matrix.md` for the full feature set and coverage matrix.
4. Read `docs/20251220/library_and_system_deps.md` for dependency mapping and system requirements.
5. Read `docs/20251220/PORTING_PLAN.md` for the phased tinker-parity plan.
6. Use `docs/20251220/validation_plan.md` for verification criteria.

## Document Index
| Document | Purpose |
| --- | --- |
| `dependency_projects.md` | Dependency projects required before CrucibleDatasets integration |
| `python_module_inventory.md` | Python module inventory and Elixir mapping |
| `feature_matrix.md` | Formats/operations/features matrix |
| `library_and_system_deps.md` | Python-to-Elixir dependency mapping and system deps |
| `PORTING_PLAN.md` | Phased plan with dependency-first sequencing (tinker parity) |
| `gap_analysis.md` | Gaps vs Python datasets and tinker cookbook |
| `implementation_status.md` | Current code status and mismatches |
| `port_architecture.md` | Current vs target architecture |
| `type_system_design.md` | Full type and features system design |
| `tinker_requirements.md` | Cookbook dataset and API requirements |
| `validation_plan.md` | Validation and testing plan |
| `AGENT_PROMPT.md` | Updated execution prompt for implementation |
| `remaining_features_design.md` | **NEW** Detailed design for remaining 7 features |
| `architecture_review.md` | **NEW** Source abstraction and reusability design |
