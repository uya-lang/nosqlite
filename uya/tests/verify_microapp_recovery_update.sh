#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_LOG="$(mktemp /tmp/verify_microapp_recovery_update_kernel_update.XXXXXX.log)"
SIM_LOG="$(mktemp /tmp/verify_microapp_recovery_update_kernel_sim.XXXXXX.log)"

cleanup() {
    rm -f "$UPDATE_LOG" "$SIM_LOG"
}
trap cleanup EXIT

dump_and_fail() {
    local title="$1"
    local path="$2"
    echo "✗ $title"
    if [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

if ! "$ROOT_DIR/tests/run_programs_parallel.sh" --uya tests/test_kernel_update.uya >"$UPDATE_LOG" 2>&1; then
    dump_and_fail "kernel update 回归失败" "$UPDATE_LOG"
fi
grep -q "test_kernel_update:测试通过" "$UPDATE_LOG" || dump_and_fail "kernel update 回归未命中通过标记" "$UPDATE_LOG"

if ! "$ROOT_DIR/tests/run_programs_parallel.sh" --uya tests/test_kernel_sim.uya >"$SIM_LOG" 2>&1; then
    dump_and_fail "kernel sim recovery 回归失败" "$SIM_LOG"
fi
grep -q "test_kernel_sim:测试通过" "$SIM_LOG" || dump_and_fail "kernel sim recovery 回归未命中通过标记" "$SIM_LOG"

echo "microapp recovery/update ok"
