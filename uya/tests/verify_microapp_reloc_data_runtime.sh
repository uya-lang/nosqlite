#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_reloc_data_source.uya"
RUN_LOG="$(mktemp /tmp/verify_microapp_reloc_data_run.XXXXXX.log)"
LOADER_LOG="$(mktemp /tmp/verify_microapp_reloc_data_loader.XXXXXX.log)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_reloc_data_build.XXXXXX.log)"
INSPECT_LOG="$(mktemp /tmp/verify_microapp_reloc_data_inspect.XXXXXX.log)"
UAPP_PATH="$(mktemp /tmp/verify_microapp_reloc_data.XXXXXX.uapp)"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export TARGET_GCC
export MICROAPP_TARGET_ARCH

cleanup() {
    rm -f "$RUN_LOG" "$LOADER_LOG" "$BUILD_LOG" "$INSPECT_LOG" "$UAPP_PATH"
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
grep -a -q "reloc64 ok" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未输出 reloc64 ok" "$RUN_LOG"
grep -a -q "\[microapp loader\] executed mapped payload" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未命中 mapped payload 执行分支" "$RUN_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$RUN_LOG"; then
    dump_log_and_fail "microapp run 路径意外回退到了 native payload ELF" "$RUN_LOG"
fi

"$ROOT_DIR/bin/uya" build --app microapp "$SOURCE" -o "$UAPP_PATH" >"$BUILD_LOG" 2>&1
"$ROOT_DIR/bin/uya" inspect-image "$UAPP_PATH" >"$INSPECT_LOG" 2>&1
grep -q '^target_arch=x86_64$' "$INSPECT_LOG" || dump_log_and_fail "reloc_data inspect 未命中 x86_64" "$INSPECT_LOG"
grep -Eq '^reloc_count=[2-9][0-9]*$|^reloc_count=[2-9]$' "$INSPECT_LOG" || dump_log_and_fail "reloc_data inspect 未体现扩展后的 reloc_count" "$INSPECT_LOG"

"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$UAPP_PATH" >"$LOADER_LOG" 2>&1
grep -a -q "reloc64 ok" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未输出 reloc64 ok" "$LOADER_LOG"
grep -a -q "\[microapp loader\] executed mapped payload" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未命中 mapped payload 执行分支" "$LOADER_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$LOADER_LOG"; then
    dump_log_and_fail "loader-only 路径意外回退到了 native payload ELF" "$LOADER_LOG"
fi

echo "microapp reloc data runtime ok"
