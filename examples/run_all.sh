#!/bin/bash
# Run all CrucibleDatasets examples
# Usage: ./examples/run_all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "============================================================"
echo "CrucibleDatasets Examples"
echo "============================================================"
echo ""

# Core functionality examples
CORE_EXAMPLES=(
  "examples/basic_usage.exs"
  "examples/evaluation_workflow.exs"
  "examples/sampling_strategies.exs"
  "examples/batch_evaluation.exs"
  "examples/cross_validation.exs"
  "examples/custom_metrics.exs"
)

# Dataset-specific examples
DATASET_EXAMPLES=(
  "examples/math/gsm8k_example.exs"
  "examples/math/math500_example.exs"
  "examples/chat/tulu3_sft_example.exs"
  "examples/preference/hh_rlhf_example.exs"
  "examples/code/deepcoder_example.exs"
)

run_example() {
  local example=$1
  echo ""
  echo "------------------------------------------------------------"
  echo "Running: $example"
  echo "------------------------------------------------------------"
  mix run "$example"
  echo ""
}

echo "=== Core Functionality Examples ==="
for example in "${CORE_EXAMPLES[@]}"; do
  if [ -f "$example" ]; then
    run_example "$example"
  else
    echo "Skipping $example (not found)"
  fi
done

echo "=== Dataset-Specific Examples ==="
for example in "${DATASET_EXAMPLES[@]}"; do
  if [ -f "$example" ]; then
    run_example "$example"
  else
    echo "Skipping $example (not found)"
  fi
done

echo "============================================================"
echo "All examples completed!"
echo "============================================================"
