#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_reloc_source.uya"
RUN_LOG="$(mktemp /tmp/verify_microapp_reloc_run.XXXXXX.log)"
LOADER_LOG="$(mktemp /tmp/verify_microapp_reloc_loader.XXXXXX.log)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_reloc_build.XXXXXX.log)"
UAPP_PATH="$(mktemp /tmp/verify_microapp_reloc.XXXXXX.uapp)"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export TARGET_GCC
export MICROAPP_TARGET_ARCH

cleanup() {
    rm -f "$RUN_LOG" "$LOADER_LOG" "$BUILD_LOG" "$UAPP_PATH"
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

"$ROOT_DIR/bin/uya" run --app microapp "$SOURCE" >"$RUN_LOG" 2>&1
grep -a -q "reloc ok" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未输出 reloc ok" "$RUN_LOG"
grep -a -q "\[microapp loader\] executed mapped payload" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未命中 mapped payload 执行分支" "$RUN_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$RUN_LOG"; then
    dump_log_and_fail "microapp run 路径意外回退到了 native payload ELF" "$RUN_LOG"
fi

"$ROOT_DIR/bin/uya" build --app microapp "$SOURCE" -o "$UAPP_PATH" >"$BUILD_LOG" 2>&1
"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$UAPP_PATH" >"$LOADER_LOG" 2>&1
grep -a -q "reloc ok" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未输出 reloc ok" "$LOADER_LOG"
grep -a -q "\[microapp loader\] executed mapped payload" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未命中 mapped payload 执行分支" "$LOADER_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$LOADER_LOG"; then
    dump_log_and_fail "loader-only 路径意外回退到了 native payload ELF" "$LOADER_LOG"
fi

echo "microapp reloc runtime ok"
