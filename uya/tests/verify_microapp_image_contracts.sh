#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp /tmp/verify_microapp_image_contracts.XXXXXX.log)"

cleanup() {
    rm -f "$LOG"
}
trap cleanup EXIT

dump_and_fail() {
    local title="$1"
    echo "✗ $title"
    if [ -f "$LOG" ]; then
        echo "--- $LOG ---"
        cat "$LOG"
    fi
    exit 1
}

if ! "$ROOT_DIR/tests/run_programs_parallel.sh" --uya tests/test_kernel_payload.uya >"$LOG" 2>&1; then
    dump_and_fail "kernel payload 契约回归失败"
fi

grep -q "test_kernel_payload:测试通过" "$LOG" || dump_and_fail "kernel payload 契约回归未命中通过标记"

echo "microapp image contracts ok"
