# Synthetic Removal Plan

## Goal
Remove all synthetic-data paths and fallback behavior from the Elixir codebase and tests. Replace them with explicit HTTP mocks/fixtures (Bypass + local files), and align behavior with the Python `datasets/` repository where tests simulate network/filesystem conditions without synthetic datasets.

## Status Update (2025-12-22)
- Phase 1 complete: synthetic APIs/fallback removed from lib and configs.
- Phase 2 complete: tests use `TestSupport.HfStub` + `TestSupport.HfCase` fixtures.
- Phase 3 complete: examples/docs no longer promote synthetic usage; `CRUCIBLE_DATASETS_LIVE_EXAMPLES` remains as the `run_all.sh` live gate.
- Phase 4 complete: Parquet `rechunk: true` workaround applied.

## External Baseline (Python `datasets/`)
Findings from `./datasets`:
- No synthetic-data feature in source or tests (`rg -n "synthetic" datasets/src datasets/tests datasets/docs` returns no matches).
- Tests use mocks/fixtures and offline simulation instead of synthetic data:
  - Offline simulation utilities in `datasets/tests/utils.py` (context manager patches HTTP clients).
  - Extensive `unittest.mock` usage in tests like `datasets/tests/test_search.py`, `datasets/tests/test_hub.py`.
  - Mock filesystems via fsspec in `datasets/tests/test_file_utils.py` and related fixtures.
  - Offline mode is an environment/config concept (`datasets/src/datasets/config.py`, `HF_HUB_OFFLINE`).

Conclusion: Python tests rely on mocks/fixtures and offline simulation, not synthetic datasets or fallback behavior. This is the model to align with.

## Current Elixir State (Historical Inventory, pre-removal)
Synthetic-related behavior exists across:
- Loader APIs and implementations:
  - `lib/dataset_manager/loader/*.ex` includes `:synthetic` (and `:offline`) options, `load_synthetic` functions, and `fallback_to_synthetic` branches.
  - `lib/dataset_manager/loader/mmlu.ex`, `lib/dataset_manager/loader/human_eval.ex` accept `:offline` aliases for synthetic.
- Global fallback config:
  - `fallback_to_synthetic` read in many loaders.
  - `lib/mix/tasks/test.live.ex` references `fallback_to_synthetic`.
  - `examples/support/example_helpers.exs` toggles fallback (to be removed).
- Tests:
  - `test/test_helper.exs` injects `synthetic: true` by default.
  - Several tests assert synthetic shapes (e.g. `test/dataset_manager/loader/gsm8k_test.exs`, `test/dataset_manager/loader/rubric_test.exs`).
- Examples/docs:
  - Example helper uses `synthetic` and a live/non-live mode.
  - `examples/README.md` advertises synthetic usage.
  - Various docs reference synthetic support.

## Target Behavior
- No `synthetic` or `offline` options in public APIs.
- No `fallback_to_synthetic` config anywhere.
- Unit tests use HTTP mocks/fixtures for HuggingFace and local fixtures for dataset files.
- Live tests remain tagged `:live` and use real HF when explicitly requested.
- Examples run against real data only and fail loudly when HF data is unavailable.

## Remediation Plan (Phased)
### Phase 1: Remove Synthetic APIs and Fallbacks
- Delete `:synthetic`/`:offline` options from loader docs and code.
- Remove `load_synthetic/…` helpers and synthetic branches in all loaders.
- Remove `fallback_to_synthetic` checks and config usage (including `lib/mix/tasks/test.live.ex` and docs).
- Update `lib/dataset_manager/registry.ex` to remove `:synthetic` from metadata types.

### Phase 2: Replace Tests with HTTP Mocks + Fixtures
- Replace `TestHelper.data_opts/1` with a mock-oriented helper (e.g., `TestHelper.hf_opts/1`).
- Use Bypass to stub HF endpoints in loader tests (pattern from `test/dataset_manager/load_dataset_test.exs`).
- Add deterministic fixtures under `test/support/fixtures/`:
  - JSONL for text-based loaders (GSM8K, Chat, Preference, Reasoning, Rubric).
  - Parquet fixtures for MMLU/HumanEval/Vision (small files matching expected schema).
  - Image bytes fixtures for vision datasets (or use fixed binary content in JSON/Parquet).
- Update assertions to match fixture content instead of synthetic shapes.
- Remove fallback-specific test expectations (e.g., rubric tests).

### Phase 3: Examples and Docs Cleanup
- Remove ExampleHelpers `synthetic` logic and live-skip guards.
- Update examples to always run live and fail on HF errors.
- Keep `CRUCIBLE_DATASETS_LIVE_EXAMPLES` as a `run_all.sh` live gate; remove synthetic guidance in `examples/README.md` and `examples/run_all.sh`.
- Update README and docs to remove synthetic mentions and align with mock-based testing.

### Phase 4: Parquet Reader Workaround
- Apply `rechunk: true` in `Explorer.DataFrame.from_parquet/2` calls:
  - `lib/dataset_manager/format/parquet.ex` `parse/1`
  - `lib/dataset_manager/format/parquet.ex` `stream_rows/2`
- Rationale: mitigates Polars NIF panic when materializing struct columns (see `temp/repro_explorer_parquet.exs`).

## Validation Plan
- `mix test` (no live network; all HF calls via Bypass + fixtures)
- `mix test.live` (real HF; no fallback)
- `mix dialyzer`
- `./examples/run_all.sh` (live-only behavior)

## Risks / Mitigations
- **Risk:** Loss of fast offline tests without synthetic data.
  - **Mitigation:** Use small local fixtures and Bypass to keep tests deterministic and fast.
- **Risk:** Parquet instability in Explorer/Polars.
  - **Mitigation:** Apply `rechunk: true` workaround and keep repro script in `temp/`.

## Scope Notes
This plan intentionally removes all synthetic behavior and fallback logic. Any remaining offline support should be based on caching or explicit mocks, not generated data.
