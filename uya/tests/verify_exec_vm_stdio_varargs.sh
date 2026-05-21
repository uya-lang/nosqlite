#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
TMP_EXPECTED="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR" "$TMP_EXPECTED"' EXIT

cat >"$TMP_EXPECTED" <<'EOF'
exec vm fprintf 7 body
exec vm printf|  ok|9
snprintf:11:body
EOF

echo "验证 exec vm stdio varargs 直接执行 Uya 函数体..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_stdio_varargs.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
tail -n 3 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
echo "  run --vm stdio varargs body ✓"

echo "验证 run --exec stdio varargs 不发生 fallback..."
"$COMPILER" run --exec "$SCRIPT_DIR/test_exec_vm_stdio_varargs.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ stdio varargs unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
tail -n 3 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
echo "  run --exec stdio varargs body ✓"

echo "✓ exec vm stdio varargs checks passed"
