#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "验证单文件 global init 顺序与全局读写..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_globals.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
tail -n 7 "$TMP_STDOUT" | diff -u <(printf 'AB11\n16\n11\n16\n12\n12\n19\n') -
echo "  global init/order ✓"

echo "验证 global init 失败会阻止 main 执行..."
if "$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_global_init_fail.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"; then
    echo "✗ global init failure case should fail under --vm"
    cat "$TMP_STDERR"
    exit 1
fi
grep -q 'exec runtime:' "$TMP_STDERR"
grep -q '除零' "$TMP_STDERR"
if grep -q 'SHOULD_NOT_RUN' "$TMP_STDOUT"; then
    echo "✗ main should not run after global init failure"
    cat "$TMP_STDOUT"
    exit 1
fi
echo "  global init failure ✓"

echo "验证多模块 global init 顺序与 use module.item 全局访问..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_globals_multi.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ multi-module globals unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  multi-module globals ✓"

echo "验证 whole-module import 的导出全局成员访问..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_libc_module_global.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q 'exec backend 构建完成' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ whole-module import globals unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
tail -n 1 "$TMP_STDOUT" | diff -u <(printf 'exec libc module global\n') -
echo "  whole-module globals ✓"

echo "✓ exec vm global checks passed"
