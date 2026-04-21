#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
OUT_C="$TEST_DIR/build/test_kernel_payload.c"
OUT_BIN="$TEST_DIR/build/test_kernel_payload"

mkdir -p "$TEST_DIR/build"

cd "$TEST_DIR"
"$ROOT_DIR/bin/uya" --c99 --nostdlib test_kernel_payload.uya -o "$OUT_C"
gcc --std=c99 -nostdlib -static -no-pie "$OUT_C" -o "$OUT_BIN" -lgcc
"$OUT_BIN"
