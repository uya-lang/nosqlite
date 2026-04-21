#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UAPP="$(mktemp /tmp/verify_microapp_loader_unwired.XXXXXX.uapp)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_loader_unwired.XXXXXX.build.log)"
LOADER_LOG="$(mktemp /tmp/verify_microapp_loader_unwired.XXXXXX.loader.log)"

cleanup() {
    rm -f "$UAPP" "$BUILD_LOG" "$LOADER_LOG"
}
trap cleanup EXIT

dump_log_and_fail() {
    local title="$1"
    local path="$2"
    echo "✗ $title"
    if [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

TARGET_GCC=x86_64-linux-gnu-gcc \
    "$ROOT_DIR/bin/uya" build --app microapp \
    --microapp-profile linux_aarch64_hardvm \
    examples/microapp/microcontainer_hello_source.uya \
    -o "$UAPP" >"$BUILD_LOG" 2>&1

if "$ROOT_DIR/bin/uya" run examples/microapp/microcontainer_hello_load.uya -- "$UAPP" >"$LOADER_LOG" 2>&1; then
    dump_log_and_fail "unwired profile 不应静默成功" "$LOADER_LOG"
fi

grep -a -q '\[microapp loader\] no execution path for target_arch=aarch64 bridge=call_gate' "$LOADER_LOG" || dump_log_and_fail "loader 未输出 unwired profile 诊断" "$LOADER_LOG"
grep -a -q '\[microapp loader\] payload result=unwired bridge=call_gate target=aarch64' "$LOADER_LOG" || dump_log_and_fail "loader 未输出统一 unwired result" "$LOADER_LOG"
grep -a -q '\[microapp loader\] pass native payload path as argv\[2\] or add mapped execution support for this profile' "$LOADER_LOG" || dump_log_and_fail "loader 未提示如何处理 unwired profile" "$LOADER_LOG"
if grep -a -q '\[microapp loader\] done' "$LOADER_LOG"; then
    dump_log_and_fail "unwired profile 不应输出 done" "$LOADER_LOG"
fi

echo "microapp loader unwired profile ok"
