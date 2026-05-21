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

printf 'test_exec_vm_builtin_bridge.uya\nNamedFailure\n' >"$TMP_EXPECTED"

echo "验证 exec vm builtin bridge..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_builtin_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
tail -n 2 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
grep -q 'test_exec_vm_builtin_bridge.uya' "$TMP_STDOUT"
echo "  run --vm builtin bridge ✓"

echo "验证 exec builtin bridge 无意外 fallback..."
"$COMPILER" run --exec "$SCRIPT_DIR/test_exec_vm_builtin_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ unexpected fallback for builtin bridge exec path"
    cat "$TMP_STDERR"
    exit 1
fi
tail -n 2 "$TMP_STDOUT" | diff -u "$TMP_EXPECTED" -
grep -q 'test_exec_vm_builtin_bridge.uya' "$TMP_STDOUT"
echo "  run --exec builtin bridge ✓"

echo "验证可折叠 builtin 未落成运行时 opcode..."
"$COMPILER" run --vm --dump-bytecode "$SCRIPT_DIR/test_exec_vm_builtin_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '=== exec bytecode ===' "$TMP_STDERR"
if grep -q 'BC_LOAD_LEN' "$TMP_STDERR"; then
    echo "✗ array @len should fold before VM"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'BC_ERROR_ID' "$TMP_STDERR"; then
    echo "✗ direct @error_id(error.X) should fold before VM"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'BC_ERROR_NAME' "$TMP_STDERR"; then
    echo "✗ direct @error_name(error.X) should fold before VM"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  builtin fold opcode check ✓"

echo "✓ exec vm builtin bridge checks passed"
