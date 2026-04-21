#!/bin/bash
# TDD：SIMD @vector.select 助手按需写入 C（无 select 则无定义；单型/宽窄混合均不得拖带无关 select 助手）
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

no_sel_c="$BUILD_DIR/simd_emit_no_select.c"
i32_only_c="$BUILD_DIR/simd_emit_select_i32_only.c"
u32_only_c="$BUILD_DIR/simd_emit_select_u32_only.c"
f32_only_c="$BUILD_DIR/simd_emit_select_f32_only.c"
i32x2_only_c="$BUILD_DIR/simd_emit_select_i32x2_only.c"
u32x2_only_c="$BUILD_DIR/simd_emit_select_u32x2_only.c"
f32x2_only_c="$BUILD_DIR/simd_emit_select_f32x2_only.c"
i32x2x4_c="$BUILD_DIR/simd_emit_select_i32x2_i32x4.c"
f32x2x4_c="$BUILD_DIR/simd_emit_select_f32x2_f32x4.c"
u32x2x4_c="$BUILD_DIR/simd_emit_select_u32x2_u32x4.c"
i32u32x4_c="$BUILD_DIR/simd_emit_select_i32x4_u32x4.c"
i32f32x4_c="$BUILD_DIR/simd_emit_select_i32x4_f32x4.c"
i32x2u32x4_c="$BUILD_DIR/simd_emit_select_i32x2_u32x4.c"
i32x2f32x4_c="$BUILD_DIR/simd_emit_select_i32x2_f32x4.c"

echo "验证：无 @vector.select 的 SIMD 程序不应输出 select 助手定义 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_sse_lower_i32x4.uya" -o "$no_sel_c" 2>&1; then
    echo "✗ 编译 test_simd_sse_lower_i32x4.uya 失败"
    exit 1
fi
if grep -q 'static inline void uya_simd_sse_select_' "$no_sel_c"; then
    echo "✗ 未使用 select 时仍生成了 uya_simd_sse_select_* 定义"
    exit 1
fi
echo "  无 select 时无助手定义 ✓"

echo "验证：仅 i32×4 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32_only.uya" -o "$i32_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x4' "$i32_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32_only_c" | grep -v select_i32x4; then
    echo "✗ i32×4 专用程序只应含 select_i32x4 的 static inline 定义"
    exit 1
fi
echo "  仅 i32×4 select 助手隔离 ✓"

echo "验证：仅 u32×4 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_u32_only.uya" -o "$u32_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_u32_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x4' "$u32_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$u32_only_c" | grep -v select_u32x4; then
    echo "✗ u32×4 专用程序只应含 select_u32x4 的 static inline 定义"
    exit 1
fi
echo "  仅 u32×4 select 助手隔离 ✓"

echo "验证：仅 f32×4 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_f32_only.uya" -o "$f32_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_f32_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x4' "$f32_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$f32_only_c" | grep -v select_f32x4; then
    echo "✗ f32×4 专用程序只应含 select_f32x4 的 static inline 定义"
    exit 1
fi
echo "  仅 f32×4 select 助手隔离 ✓"

echo "验证：i32×2 + i32×4 同程序仅生成二者、无 u32/f32 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x2_and_i32x4.uya" -o "$i32x2x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x2_and_i32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x2' "$i32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x2 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x4' "$i32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32x2x4_c" | grep -Ev 'select_i32x2|select_i32x4'; then
    echo "✗ i32×2+×4 程序只应含 select_i32x2 / select_i32x4 的 static inline 定义"
    exit 1
fi
echo "  i32×2 + i32×4 select 助手按需 ✓"

echo "验证：f32×2 + f32×4 同程序仅生成二者、无 i32/u32 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_f32x2_and_f32x4.uya" -o "$f32x2x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_f32x2_and_f32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x2' "$f32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x2 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x4' "$f32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$f32x2x4_c" | grep -Ev 'select_f32x2|select_f32x4'; then
    echo "✗ f32×2+×4 程序只应含 select_f32x2 / select_f32x4 的 static inline 定义"
    exit 1
fi
echo "  f32×2 + f32×4 select 助手按需 ✓"

echo "验证：u32×2 + u32×4 同程序仅生成二者、无 i32/f32 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_u32x2_and_u32x4.uya" -o "$u32x2x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_u32x2_and_u32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x2' "$u32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x2 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x4' "$u32x2x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$u32x2x4_c" | grep -Ev 'select_u32x2|select_u32x4'; then
    echo "✗ u32×2+×4 程序只应含 select_u32x2 / select_u32x4 的 static inline 定义"
    exit 1
fi
echo "  u32×2 + u32×4 select 助手按需 ✓"

echo "验证：i32×4 + u32×4 同程序仅生成二者、无 f32/×2 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x4_and_u32x4.uya" -o "$i32u32x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x4_and_u32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x4' "$i32u32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x4 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x4' "$i32u32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32u32x4_c" | grep -Ev 'select_i32x4|select_u32x4'; then
    echo "✗ i32×4+u32×4 程序只应含 select_i32x4 / select_u32x4 的 static inline 定义"
    exit 1
fi
echo "  i32×4 + u32×4 select 助手按需 ✓"

echo "验证：i32×4 + f32×4 同程序仅生成二者、无 u32/×2 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x4_and_f32x4.uya" -o "$i32f32x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x4_and_f32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x4' "$i32f32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x4 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x4' "$i32f32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32f32x4_c" | grep -Ev 'select_i32x4|select_f32x4'; then
    echo "✗ i32×4+f32×4 程序只应含 select_i32x4 / select_f32x4 的 static inline 定义"
    exit 1
fi
echo "  i32×4 + f32×4 select 助手按需 ✓"

echo "验证：i32×2 + u32×4 同程序仅生成二者、无 f32/其它宽度 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x2_and_u32x4.uya" -o "$i32x2u32x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x2_and_u32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x2' "$i32x2u32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x2 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x4' "$i32x2u32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32x2u32x4_c" | grep -Ev 'select_i32x2|select_u32x4'; then
    echo "✗ i32×2+u32×4 程序只应含 select_i32x2 / select_u32x4 的 static inline 定义"
    exit 1
fi
echo "  i32×2 + u32×4 select 助手按需 ✓"

echo "验证：i32×2 + f32×4 同程序仅生成二者、无 u32/其它宽度 select ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x2_and_f32x4.uya" -o "$i32x2f32x4_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x2_and_f32x4.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x2' "$i32x2f32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x2 定义"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x4' "$i32x2f32x4_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x4 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32x2f32x4_c" | grep -Ev 'select_i32x2|select_f32x4'; then
    echo "✗ i32×2+f32×4 程序只应含 select_i32x2 / select_f32x4 的 static inline 定义"
    exit 1
fi
echo "  i32×2 + f32×4 select 助手按需 ✓"

echo "验证：仅 i32×2 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_i32x2_only.uya" -o "$i32x2_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_i32x2_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_i32x2' "$i32x2_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_i32x2 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$i32x2_only_c" | grep -v select_i32x2; then
    echo "✗ i32×2 专用程序只应含 select_i32x2 的 static inline 定义"
    exit 1
fi
echo "  仅 i32×2 select 助手隔离 ✓"

echo "验证：仅 u32×2 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_u32x2_only.uya" -o "$u32x2_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_u32x2_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_u32x2' "$u32x2_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_u32x2 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$u32x2_only_c" | grep -v select_u32x2; then
    echo "✗ u32×2 专用程序只应含 select_u32x2 的 static inline 定义"
    exit 1
fi
echo "  仅 u32×2 select 助手隔离 ✓"

echo "验证：仅 f32×2 select 助手隔离 ..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/test_simd_c99_select_emit_f32x2_only.uya" -o "$f32x2_only_c" 2>&1; then
    echo "✗ 编译 test_simd_c99_select_emit_f32x2_only.uya 失败"
    exit 1
fi
if ! grep -q 'static inline void uya_simd_sse_select_f32x2' "$f32x2_only_c"; then
    echo "✗ 缺少 uya_simd_sse_select_f32x2 定义"
    exit 1
fi
if grep 'static inline void uya_simd_sse_select_' "$f32x2_only_c" | grep -v select_f32x2; then
    echo "✗ f32×2 专用程序只应含 select_f32x2 的 static inline 定义"
    exit 1
fi
echo "  仅 f32×2 select 助手隔离 ✓"

echo ""
echo "✓ SIMD select C 按需生成验证通过"
