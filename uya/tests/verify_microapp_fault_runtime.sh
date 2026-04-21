#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_fault_segv.uya"
RUN_LOG="$(mktemp /tmp/verify_microapp_fault_run.XXXXXX.log)"
LOADER_LOG="$(mktemp /tmp/verify_microapp_fault_loader.XXXXXX.log)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_fault_build.XXXXXX.log)"
UAPP_PATH="$(mktemp /tmp/verify_microapp_fault.XXXXXX.uapp)"

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

set +e
"$ROOT_DIR/bin/uya" run --app microapp "$SOURCE" >"$RUN_LOG" 2>&1
run_status=$?
set -e
if [ "$run_status" -ne 139 ]; then
    dump_log_and_fail "microapp run 路径崩溃退出码异常: $run_status" "$RUN_LOG"
fi
grep -a -q "\[microapp loader\] payload fault class=segv code=1 signal=11" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未报告 SEGV fault class" "$RUN_LOG"
grep -a -q "\[microapp loader\] payload result=fault class=segv code=1 signal=11" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未输出统一 fault class result" "$RUN_LOG"
grep -a -q "\[microapp loader\] image loaded, ticking" "$RUN_LOG" || dump_log_and_fail "microapp run 路径未进入 tick" "$RUN_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$RUN_LOG"; then
    dump_log_and_fail "microapp run 路径意外回退到了 native payload ELF" "$RUN_LOG"
fi

"$ROOT_DIR/bin/uya" build --app microapp "$SOURCE" -o "$UAPP_PATH" >"$BUILD_LOG" 2>&1
set +e
"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$UAPP_PATH" >"$LOADER_LOG" 2>&1
loader_status=$?
set -e
if [ "$loader_status" -ne 139 ]; then
    dump_log_and_fail "loader-only 路径崩溃退出码异常: $loader_status" "$LOADER_LOG"
fi
grep -a -q "\[microapp loader\] payload fault class=segv code=1 signal=11" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未报告 SEGV fault class" "$LOADER_LOG"
grep -a -q "\[microapp loader\] payload result=fault class=segv code=1 signal=11" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未输出统一 fault class result" "$LOADER_LOG"
grep -a -q "\[microapp loader\] image loaded, ticking" "$LOADER_LOG" || dump_log_and_fail "loader-only 路径未进入 tick" "$LOADER_LOG"
if grep -a -q "\[microapp loader\] launching native payload" "$LOADER_LOG"; then
    dump_log_and_fail "loader-only 路径意外回退到了 native payload ELF" "$LOADER_LOG"
fi

echo "microapp fault runtime ok"
