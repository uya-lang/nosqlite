#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

if [ "$HOST_ARCH" != "aarch64" ] && [ "$HOST_ARCH" != "arm64" ]; then
    echo "microapp aarch64 hosted runtime skipped (host_arch=$HOST_ARCH)"
    exit 0
fi

RUN_LOG="$(mktemp /tmp/verify_microapp_aarch64_run.XXXXXX.log)"
EXIT_LOG="$(mktemp /tmp/verify_microapp_aarch64_exit.XXXXXX.log)"

cleanup() {
    rm -f "$RUN_LOG" "$EXIT_LOG"
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

pick_first_available() {
    local cmd
    for cmd in "$@"; do
        if [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done
    return 1
}

TARGET_GCC_BIN="${TARGET_GCC:-}"
if [ -z "$TARGET_GCC_BIN" ]; then
    if [ "$HOST_OS" = "Darwin" ] && command -v xcrun >/dev/null 2>&1; then
        TARGET_GCC_BIN="$(xcrun --find clang 2>/dev/null || true)"
    fi
fi
if [ -z "$TARGET_GCC_BIN" ]; then
    TARGET_GCC_BIN="$(pick_first_available aarch64-linux-gnu-gcc clang gcc cc || true)"
fi

if [ -z "$TARGET_GCC_BIN" ]; then
    echo "microapp aarch64 hosted runtime skipped (missing compiler)"
    exit 0
fi

OBJCOPY_BIN="${OBJCOPY:-}"
if [ -z "$OBJCOPY_BIN" ]; then
    if [ "$HOST_OS" = "Darwin" ] && command -v xcrun >/dev/null 2>&1; then
        OBJCOPY_BIN="$(xcrun --find llvm-objcopy 2>/dev/null || true)"
    fi
fi
if [ -z "$OBJCOPY_BIN" ]; then
    OBJCOPY_BIN="$(pick_first_available llvm-objcopy gobjcopy objcopy || true)"
fi

if [ -z "$OBJCOPY_BIN" ]; then
    echo "microapp aarch64 hosted runtime skipped (missing objcopy)"
    exit 0
fi

export TARGET_GCC="$TARGET_GCC_BIN"
export OBJCOPY="$OBJCOPY_BIN"

"$ROOT_DIR/bin/uya" run --app microapp --microapp-profile linux_aarch64_hardvm \
    examples/microapp/microcontainer_hello_source.uya >"$RUN_LOG" 2>&1
grep -a -q "hello microapp" "$RUN_LOG" || dump_log_and_fail "aarch64 run 路径未输出 hello microapp" "$RUN_LOG"
grep -a -q "\[microapp loader\] executed mapped payload" "$RUN_LOG" || dump_log_and_fail "aarch64 run 路径未命中 mapped payload 执行分支" "$RUN_LOG"
grep -a -q "\[microapp loader\] payload result=ok" "$RUN_LOG" || dump_log_and_fail "aarch64 run 路径未输出统一 ok result" "$RUN_LOG"

"$ROOT_DIR/bin/uya" run --app microapp --microapp-profile linux_aarch64_hardvm \
    tests/fixtures/microapp/test_std_microapp_exit_nonzero.uya >"$EXIT_LOG" 2>&1 || status=$?
status="${status:-0}"
if [ "$status" -ne 7 ]; then
    dump_log_and_fail "aarch64 non-zero exit 退出码异常: $status" "$EXIT_LOG"
fi
grep -a -q "\[microapp loader\] executed mapped payload" "$EXIT_LOG" || dump_log_and_fail "aarch64 non-zero exit 未命中 mapped payload 执行分支" "$EXIT_LOG"
grep -a -q "\[microapp loader\] payload result=exit code=7" "$EXIT_LOG" || dump_log_and_fail "aarch64 non-zero exit 未输出统一 exit result" "$EXIT_LOG"

echo "microapp aarch64 hosted runtime ok"
