#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT_DIR/tests/verify_microapp_inspect_cli.sh"
"$ROOT_DIR/tests/verify_microapp_verify_cli.sh"

echo "microapp uapp compat ok"
