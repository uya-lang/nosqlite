#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SCRIPTS=(
    "tests/verify_microapp_mode_gate.sh"
    "tests/verify_microapp_profile_default_resolution.sh"
    "tests/verify_microapp_profile_example_matrix.sh"
    "tests/verify_microapp_portable_sources.sh"
    "tests/verify_microapp_example_codegen.sh"
    "tests/verify_microapp_host_api_diagnostics.sh"
    "tests/verify_microapp_aarch64_hosted_runtime.sh"
)

for rel in "${SCRIPTS[@]}"; do
    echo "==> $(basename "$rel")"
    "$ROOT_DIR/$rel"
done

echo "microapp hosted smoke ok"
