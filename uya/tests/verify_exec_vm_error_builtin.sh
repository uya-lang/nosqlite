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

printf 'NamedFailure\nOtherFailure\n' >"$TMP_EXPECTED"

echo "验证 exec vm error builtin..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_error_builtin.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
tail -n 2 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
echo "  run --vm error builtin ✓"

echo "验证 exec error builtin 无意外 fallback..."
"$COMPILER" run --exec "$SCRIPT_DIR/test_exec_vm_error_builtin.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ unexpected fallback for error builtin exec path"
    cat "$TMP_STDERR"
    exit 1
fi
tail -n 2 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
echo "  run --exec error builtin ✓"

echo "✓ exec vm error builtin checks passed"
