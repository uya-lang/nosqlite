#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "验证 exec HIR 显式 scope enter/exit..."
"$COMPILER" run --vm --dump-exec-hir "$SCRIPT_DIR/test_exec_vm_hir_scope.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '后端类型: EXEC' "$TMP_STDERR"
grep -q '=== exec hir ===' "$TMP_STDERR"
grep -q 'scope enter #' "$TMP_STDERR"
grep -q 'scope exit #' "$TMP_STDERR"
if grep -q 'if const true' "$TMP_STDERR"; then
    echo "✗ nested block should not be lowered as synthetic if const true"
    cat "$TMP_STDERR"
    exit 1
fi
grep -q '^ACBD$' "$TMP_STDOUT"
echo "✓ exec HIR scope markers passed"
