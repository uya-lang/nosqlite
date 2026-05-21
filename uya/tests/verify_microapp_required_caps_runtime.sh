#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_required_caps.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

dump_log_and_fail() {
    local title="$1"
    local path="${2:-}"
    echo "✗ $title"
    if [ -n "$path" ] && [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

read_required_caps() {
    local image="$1"
    python3 - "$image" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
if len(data) < 64:
    raise SystemExit("image too small")
print(int.from_bytes(data[60:64], "little"))
PY
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
}

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
export TARGET_GCC
export MICROAPP_TARGET_PROFILE=linux_x86_64_hardvm
export READELF=false
export OBJDUMP=false
export NM=false
export OBJCOPY=false

TIMER_UAPP="$TMP_DIR/sys-io-timer.uapp"
TIMER_BUILD_LOG="$TMP_DIR/sys-io-timer.build.log"
TIMER_RUN_LOG="$TMP_DIR/sys-io-timer.run.log"

if ! "$ROOT_DIR/bin/uya" build --app microapp \
    --microapp-profile linux_x86_64_hardvm \
    "$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_sys_io_timer.uya" \
    -o "$TIMER_UAPP" >"$TIMER_BUILD_LOG" 2>&1; then
    dump_log_and_fail "timer SYS_IO fixture 构建失败" "$TIMER_BUILD_LOG"
fi

grep -q '信息：microapp inferred required_caps=4' "$TIMER_BUILD_LOG" \
    || dump_log_and_fail "timer wrapper 未推导 required_caps=4" "$TIMER_BUILD_LOG"
if [ "$(read_required_caps "$TIMER_UAPP")" -ne 4 ]; then
    dump_log_and_fail "timer .uapp required_caps 不是 4" "$TIMER_BUILD_LOG"
fi

if ! "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$TIMER_UAPP" >"$TIMER_RUN_LOG" 2>&1; then
    dump_log_and_fail "timer SYS_IO fixture 运行失败" "$TIMER_RUN_LOG"
fi
grep -a -q 'io timer ok' "$TIMER_RUN_LOG" || dump_log_and_fail "timer SYS_IO 未成功执行" "$TIMER_RUN_LOG"
grep -a -q '\[microapp loader\] executed mapped payload' "$TIMER_RUN_LOG" \
    || dump_log_and_fail "timer SYS_IO 未命中 mapped payload" "$TIMER_RUN_LOG"
assert_single_result_surface "$TIMER_RUN_LOG" "[microapp loader] payload result=ok"

DENIED_UAPP="$TMP_DIR/sys-io-denied.uapp"
DENIED_BUILD_LOG="$TMP_DIR/sys-io-denied.build.log"
DENIED_RUN_LOG="$TMP_DIR/sys-io-denied.run.log"

if ! "$ROOT_DIR/bin/uya" build --app microapp \
    --microapp-profile linux_x86_64_hardvm \
    "$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_sys_io_denied.uya" \
    -o "$DENIED_UAPP" >"$DENIED_BUILD_LOG" 2>&1; then
    dump_log_and_fail "denied SYS_IO fixture 构建失败" "$DENIED_BUILD_LOG"
fi

if grep -q '信息：microapp inferred required_caps=' "$DENIED_BUILD_LOG"; then
    dump_log_and_fail "direct SYS_IO 不应隐式声明 required_caps" "$DENIED_BUILD_LOG"
fi
if [ "$(read_required_caps "$DENIED_UAPP")" -ne 0 ]; then
    dump_log_and_fail "denied .uapp required_caps 不是 0" "$DENIED_BUILD_LOG"
fi

if ! "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$DENIED_UAPP" >"$DENIED_RUN_LOG" 2>&1; then
    dump_log_and_fail "denied SYS_IO fixture 运行失败" "$DENIED_RUN_LOG"
fi
grep -a -q 'io denied ok' "$DENIED_RUN_LOG" || dump_log_and_fail "未声明 cap 的 SYS_IO 没有按预期拒绝" "$DENIED_RUN_LOG"
assert_single_result_surface "$DENIED_RUN_LOG" "[microapp loader] payload result=ok"

echo "microapp required caps runtime ok"
