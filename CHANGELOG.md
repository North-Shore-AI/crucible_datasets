# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-11-25

### Added
- **New Evaluation Metrics:**
  - BLEU score metric for machine translation and text generation evaluation
  - ROUGE score metrics (ROUGE-1, ROUGE-2, ROUGE-L) for summarization evaluation
  - Support for multiple ROUGE variants with precision, recall, and F1 scores
- **Dataset Registry:**
  - Centralized dataset registry with comprehensive metadata
  - Dataset discovery by domain, task type, difficulty, and tags
  - Search functionality for finding datasets by keyword
  - Dataset statistics and summary generation
- **Result Persistence:**
  - ResultStore module for persistent storage of evaluation results
  - Organized storage by date with searchable index
  - Query interface with filters (model, dataset, accuracy, date range)
  - Result management (save, load, delete, clear)
- **Export Functionality:**
  - CSV export for spreadsheet applications and data analysis
  - JSON Lines export for streaming processing
  - Markdown report generation with customizable formatting
  - HTML report generation with styling and theming options
  - Flexible export options (sorting, grouping, detail levels)
- **Enhanced API:**
  - Convenience delegates in main CrucibleDatasets module
  - `list_available()` - List all available datasets
  - `get_metadata/1` - Get dataset metadata
  - `save_result/2` - Save evaluation results
  - `load_result/1` - Load saved results
  - `query_results/1` - Query results with filters
  - `export_csv/3`, `export_jsonl/2`, `export_markdown/2`, `export_html/2`

### Changed
- Version bump from 0.1.0 to 0.2.0
- Enhanced Evaluator to support new metrics (`:bleu`, `:rouge`, `:rouge1`, `:rouge2`, `:rougel`)
- Expanded documentation with new features and examples
- Updated README with version 0.2.0

### Documentation
- Comprehensive design document at `docs/20251125/enhancement_design.md`
- Detailed architecture and implementation plans
- Enhanced examples for new features
- API documentation for all new modules

## [0.1.0] - 2025-10-07

### Added
- Initial release
- Centralized dataset management for AI evaluation research
- Unified interface for benchmark datasets (MMLU, HumanEval, GSM8K)
- Automatic caching with version tracking for fast access
- Comprehensive evaluation metrics (exact match, F1 score, custom metrics)
- Dataset sampling strategies (random, stratified, k-fold cross-validation)
- Support for custom datasets from local JSONL files
- Reproducibility features with deterministic sampling and version control

### Documentation
- Comprehensive README with examples
- API documentation for dataset loading and evaluation
- Usage examples for common research workflows
- Integration guide for research infrastructure libraries
