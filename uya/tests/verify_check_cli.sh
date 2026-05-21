#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OK_LOG="$(mktemp /tmp/verify_check_cli_ok.XXXXXX.log)"
BAD_LOG="$(mktemp /tmp/verify_check_cli_bad.XXXXXX.log)"
HELP_LOG="$(mktemp /tmp/verify_check_cli_help.XXXXXX.log)"

cleanup() {
    rm -f "$OK_LOG" "$BAD_LOG" "$HELP_LOG"
}
trap cleanup EXIT

"$ROOT_DIR/bin/uya" check tests/check_cli_no_main.uya >"$OK_LOG" 2>&1
grep -q '类型检查通过' "$OK_LOG"
grep -q '检查完成：checker 通过（未执行代码生成）' "$OK_LOG"
if grep -q '代码生成完成' "$OK_LOG"; then
    echo "✗ check 不应进入代码生成阶段"
    cat "$OK_LOG"
    exit 1
fi

if "$ROOT_DIR/bin/uya" check tests/error_check_missing_brace.uya >"$BAD_LOG" 2>&1; then
    echo "✗ check 对语法错误不应成功"
    cat "$BAD_LOG"
    exit 1
fi
grep -q '语法分析失败' "$BAD_LOG"

"$ROOT_DIR/bin/uya" --help >"$HELP_LOG" 2>&1 || true
grep -q 'check <文件>' "$HELP_LOG"

echo "check cli ok"
