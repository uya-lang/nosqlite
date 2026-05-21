#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya_verify_async_nested_split.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
SRC="$ROOT/tests/test_async_nested_http1_await_codegen.uya"
OUT_BIN="$TMP_DIR/async_nested_split.out"
SPLIT_DIR="$TMP_DIR/split"

mkdir -p "$SPLIT_DIR"

"$COMPILER" build "$SRC" --split-c-dir "$SPLIT_DIR" -o "$OUT_BIN" --c99
"$OUT_BIN" >/dev/null

echo "verify_async_nested_split_codegen: ok"
