#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${UYA_COMPILER:-}" ]; then
    COMPILER="$UYA_COMPILER"
elif [ -x "$REPO_ROOT/bin/uya-hosted" ]; then
    COMPILER="$REPO_ROOT/bin/uya-hosted"
else
    COMPILER="$REPO_ROOT/bin/uya"
fi

OUT_BIN="$(mktemp /tmp/uya-split-build-out.XXXXXX)"
BUILD_LOG="$(mktemp /tmp/uya-split-build-out.XXXXXX.log)"

cleanup() {
    rm -f "$OUT_BIN" "$BUILD_LOG"
}
trap cleanup EXIT

"$COMPILER" build "$REPO_ROOT/src/main.uya" -o "$OUT_BIN" >"$BUILD_LOG" 2>&1
test -x "$OUT_BIN"

echo "split build output materialized ok"
