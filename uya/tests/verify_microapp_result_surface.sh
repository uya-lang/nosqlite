#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_result_surface.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
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

assert_single_result_surface() {
    local path="$1"
    local expected="$2"
    local count
    grep -a -F -q "$expected" "$path" || dump_log_and_fail "未输出统一 result: $expected" "$path"
    count="$(grep -a -c '^\[microapp loader\] payload result=' "$path" || true)"
    if [ "$count" -ne 1 ]; then
        dump_log_and_fail "payload result 行数量异常: $count" "$path"
    fi
    if grep -a -q '^\[microapp loader\] payload fault class=' "$path"; then
        dump_log_and_fail "不应输出旧 fault 诊断面" "$path"
    fi
}

run_expect_status() {
    local expected_status="$1"
    local log_path="$2"
    shift 2
    local status
    set +e
    "$@" >"$log_path" 2>&1
    status=$?
    set -e
    if [ "$status" -ne "$expected_status" ]; then
        dump_log_and_fail "退出码异常: $status, 期望: $expected_status" "$log_path"
    fi
}

TARGET_GCC_BIN="${TARGET_GCC:-}"
if [ -z "$TARGET_GCC_BIN" ]; then
    TARGET_GCC_BIN="$(pick_first_available x86_64-linux-gnu-gcc gcc cc || true)"
fi
if [ -z "$TARGET_GCC_BIN" ]; then
    echo "✗ microapp result surface 需要 host C compiler"
    exit 1
fi

HOST_CC="${CC:-cc}"
if ! command -v "$HOST_CC" >/dev/null 2>&1; then
    echo "✗ microapp result surface 需要 cc 构建 native fault helper"
    exit 1
fi

AARCH_UAPP="$TMP_DIR/aarch64-unwired.uapp"
AARCH_BUILD_LOG="$TMP_DIR/aarch64-unwired.build.log"
TARGET_GCC="$TARGET_GCC_BIN" \
    "$ROOT_DIR/bin/uya" build --app microapp \
    --microapp-profile linux_aarch64_hardvm \
    "$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya" \
    -o "$AARCH_UAPP" >"$AARCH_BUILD_LOG" 2>&1

UNWIRED_LOG="$TMP_DIR/unwired.log"
run_expect_status 6 "$UNWIRED_LOG" \
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$AARCH_UAPP"
assert_single_result_surface "$UNWIRED_LOG" "[microapp loader] payload result=unwired bridge=call_gate target=aarch64"
grep -a -q '\[microapp loader\] no execution path for target_arch=aarch64 bridge=call_gate' "$UNWIRED_LOG" \
    || dump_log_and_fail "unwired 分支未输出 profile 诊断" "$UNWIRED_LOG"

NATIVE_EXIT="$TMP_DIR/native-exit.sh"
cat >"$NATIVE_EXIT" <<'SH'
#!/usr/bin/env bash
exit 7
SH
chmod +x "$NATIVE_EXIT"

NATIVE_EXIT_LOG="$TMP_DIR/native-exit.log"
run_expect_status 7 "$NATIVE_EXIT_LOG" \
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$AARCH_UAPP" "$NATIVE_EXIT"
grep -a -q '\[microapp loader\] launching native payload' "$NATIVE_EXIT_LOG" \
    || dump_log_and_fail "native fallback exit 未进入 native payload 分支" "$NATIVE_EXIT_LOG"
assert_single_result_surface "$NATIVE_EXIT_LOG" "[microapp loader] payload result=exit code=7"

NATIVE_FAULT_C="$TMP_DIR/native-fault.c"
NATIVE_FAULT="$TMP_DIR/native-fault"
cat >"$NATIVE_FAULT_C" <<'C'
#include <signal.h>
#include <unistd.h>

int main(void) {
    kill(getppid(), SIGSEGV);
    return 0;
}
C
"$HOST_CC" "$NATIVE_FAULT_C" -o "$NATIVE_FAULT" >"$TMP_DIR/native-fault.build.log" 2>&1 \
    || dump_log_and_fail "native fault helper 编译失败" "$TMP_DIR/native-fault.build.log"

NATIVE_FAULT_LOG="$TMP_DIR/native-fault.log"
run_expect_status 139 "$NATIVE_FAULT_LOG" \
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$AARCH_UAPP" "$NATIVE_FAULT"
grep -a -q '\[microapp loader\] launching native payload' "$NATIVE_FAULT_LOG" \
    || dump_log_and_fail "native fallback fault 未进入 native payload 分支" "$NATIVE_FAULT_LOG"
assert_single_result_surface "$NATIVE_FAULT_LOG" "[microapp loader] payload result=fault class=segv code=1 signal=11"

echo "microapp result surface ok"
