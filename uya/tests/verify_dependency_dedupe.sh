#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${UYA_COMPILER:-}" ]; then
    COMPILER="$UYA_COMPILER"
elif [ -x "$ROOT/bin/uya-hosted" ]; then
    COMPILER="$ROOT/bin/uya-hosted"
else
    COMPILER="$ROOT/bin/uya"
fi

TMP="$(mktemp -d)"
OUT_BIN="$TMP/dep-dedupe.out"
BUILD_LOG="$TMP/build.log"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT

"$COMPILER" build "$ROOT/tests/fixtures/dep_dedupe/main.uya" -o "$OUT_BIN" >"$BUILD_LOG" 2>&1
test -x "$OUT_BIN"
"$OUT_BIN"

TARGET_PATH="$ROOT/tests/fixtures/dep_dedupe/lib/storage/wal_header.uya"
COUNT="$(awk -v path="$TARGET_PATH" '$0 ~ /^  [0-9]+: / && index($0, path) != 0 { c++ } END { print c + 0 }' "$BUILD_LOG")"

if [ "$COUNT" -ne 1 ]; then
    echo "verify_dependency_dedupe: expected exactly one wal_header input entry, got $COUNT" >&2
    awk '/^输入文件数量:/{flag=1} flag{print} /^输出文件:/{exit}' "$BUILD_LOG" >&2
    exit 1
fi

echo "verify_dependency_dedupe: ok"
