#!/bin/bash
# 验证证明优化是否生效：编译后检查生成的 C 代码
# 运行方式: ./tests/verify_proof_optimization.sh
# 或在 make check 中自动运行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"
OUT_C="$SCRIPT_DIR/build/proof_opt_verify.c"

mkdir -p "$SCRIPT_DIR/build"

echo "验证证明优化：编译 test_proof_optimization.uya (-O2)..."
COMPILE_OUT=$("$COMPILER" --c99 -O2 "$SCRIPT_DIR/test_proof_optimization.uya" -o "$OUT_C" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "✗ 编译失败"
    echo "$COMPILE_OUT"
    exit 1
fi

# 检查证明优化次数
PROOF_COUNT=$(echo "$COMPILE_OUT" | grep '证明优化:' | sed 's/.*证明优化: *\([0-9]*\).*/\1/' || echo "0")
if [ -z "$PROOF_COUNT" ] || [ "$PROOF_COUNT" -lt 6 ]; then
    echo "✗ 证明优化次数不足: 期望 >= 6, 实际: $PROOF_COUNT"
    exit 1
fi
echo "  证明优化次数: $PROOF_COUNT ✓"

# 检查各用例的优化结果：优化后不应保留对应 if 包装

# constant_index: 不应有 if (((i >= 0) && (i < 5)))
if grep -q 'if (((i >= 0) && (i < 5)))' "$OUT_C"; then
    echo "✗ constant_index: 应移除的 if 仍存在"
    exit 1
fi
echo "  constant_index: if 已移除 ✓"

# array_size (@len): 不应有 if ((size == 100))
if grep -q 'if ((size == 100))' "$OUT_C"; then
    echo "✗ array_size: 应移除的 if (size == 100) 仍存在"
    exit 1
fi
echo "  array_size: if 已移除 ✓"

# expr_boundary: 不应有 if (((index >= 0) && (index < 20)))
if grep -q 'if (((index >= 0) && (index < 20)))' "$OUT_C"; then
    echo "✗ expr_boundary: 应移除的 if 仍存在"
    exit 1
fi
echo "  expr_boundary: if 已移除 ✓"

# combined_conditions: 不应有 if (((a >= 0) && (a < 10) && ...
if grep -qE 'if \(\(\(\(a >= 0\) && \(a < 10\)' "$OUT_C"; then
    echo "✗ combined_conditions: 应移除的 if 仍存在"
    exit 1
fi
echo "  combined_conditions: if 已移除 ✓"

# size_of_condition: 优化后不应有 if (((int32_t)sizeof... == 4))
if grep -q 'if (((int32_t)sizeof' "$OUT_C"; then
    echo "✗ size_of_condition: 应移除的 if 仍存在"
    exit 1
fi
echo "  size_of_condition: if 已移除 ✓"

echo ""
echo "✓ 证明优化验证通过"
