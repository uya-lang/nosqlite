#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TESTS=(
    "test_main_only.uya"
    "test_exec_vm_if_else.uya"
    "test_exec_vm_loop_control.uya"
    "test_exec_vm_multi_fn.uya"
    "test_exec_vm_short_circuit.uya"
    "test_exec_vm_for_range.uya"
    "test_exec_vm_match_basic.uya"
    "test_exec_vm_error_union.uya"
    "test_exec_vm_error_builtin.uya"
    "test_exec_vm_builtin_bridge.uya"
    "test_exec_vm_aggregates.uya"
    "test_exec_vm_struct_init_zero_fill.uya"
    "test_exec_vm_bitwise.uya"
    "test_exec_vm_scalar_pointer.uya"
    "test_exec_vm_extern_impl.uya"
    "test_exec_vm_interface_dispatch.uya"
    "test_exec_vm_interface_stateful.uya"
)

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
TMP_DUMP1="$(mktemp)"
TMP_DUMP2="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR" "$TMP_DUMP1" "$TMP_DUMP2"' EXIT

run_case() {
    local mode="$1"
    local file="$2"
    set +e
    "$COMPILER" run "$mode" "$SCRIPT_DIR/$file" >"$TMP_STDOUT" 2>"$TMP_STDERR"
    local status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        echo "✗ $mode $file failed with status $status"
        cat "$TMP_STDERR"
        return 1
    fi
    grep -q '后端类型: EXEC' "$TMP_STDERR"
    grep -q 'exec backend 构建完成' "$TMP_STDERR"
    echo "  $mode $file ✓"
}

echo "验证 exec vm smoke..."
for file in "${TESTS[@]}"; do
    run_case "--vm" "$file"
done

echo "对比 --exec 与默认 C99 退出码..."
for file in "${TESTS[@]}"; do
    set +e
    "$COMPILER" run --exec "$SCRIPT_DIR/$file" >"$TMP_STDOUT" 2>"$TMP_STDERR"
    exec_status=$?
    "$COMPILER" run "$SCRIPT_DIR/$file" >"$TMP_STDOUT" 2>"$TMP_DUMP1"
    c99_status=$?
    set -e
    if [ "$exec_status" -ne "$c99_status" ]; then
        echo "✗ exit code mismatch for $file: --exec=$exec_status c99=$c99_status"
        cat "$TMP_STDERR"
        cat "$TMP_DUMP1"
        exit 1
    fi
    grep -q '后端类型: EXEC' "$TMP_STDERR"
    if grep -q '回退 C99' "$TMP_STDERR"; then
        echo "✗ unexpected fallback for supported smoke $file"
        cat "$TMP_STDERR"
        exit 1
    fi
    echo "  exit code match $file ✓"
done

echo "检查 bytecode dump 稳定性..."
"$COMPILER" run --vm --dump-bytecode "$SCRIPT_DIR/test_exec_vm_multi_fn.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q '=== exec bytecode ===' "$TMP_STDERR"
sed -n '/=== exec bytecode ===/,/=== 编译统计 ===/p' "$TMP_STDERR" >"$TMP_DUMP1"
"$COMPILER" run --vm --dump-bytecode "$SCRIPT_DIR/test_exec_vm_multi_fn.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q '=== exec bytecode ===' "$TMP_STDERR"
sed -n '/=== exec bytecode ===/,/=== 编译统计 ===/p' "$TMP_STDERR" >"$TMP_DUMP2"
if ! diff -u "$TMP_DUMP1" "$TMP_DUMP2" >"$TMP_STDERR"; then
    echo "✗ bytecode dump not stable"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  bytecode dump stable ✓"

echo "✓ exec vm smoke passed"
