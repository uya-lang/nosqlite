#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
OUT_C="$TEST_DIR/build/test_capability_runtime_compat.c"
OUT_BIN="$TEST_DIR/build/test_capability_runtime_compat"

mkdir -p "$TEST_DIR/build"

cd "$TEST_DIR"
"$ROOT_DIR/bin/uya" --c99 --nostdlib test_capability_runtime_compat.uya -o "$OUT_C"
gcc --std=c99 -nostdlib -static -no-pie "$OUT_C" -o "$OUT_BIN" -lgcc
"$OUT_BIN"
