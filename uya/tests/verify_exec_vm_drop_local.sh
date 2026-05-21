#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "验证 exec vm local drop 清理顺序..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_drop_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
grep -q '^921$' "$TMP_STDOUT"
echo "  run --vm local drop ✓"

echo "验证 --exec local drop 不发生 fallback..."
"$COMPILER" run --exec "$SCRIPT_DIR/test_exec_vm_drop_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ unexpected fallback for local drop exec path"
    cat "$TMP_STDERR"
    exit 1
fi
grep -q '^921$' "$TMP_STDOUT"
echo "  run --exec local drop ✓"

echo "✓ exec vm local drop checks passed"
