#!/bin/bash
# 验证：切片形参 &[T] 在 C99 中为按值 struct uya_slice_*（含 extern 仅有声明）；
#       调用处对 &expr（expr 为切片值）生成 expr，而非 &expr。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$SCRIPT_DIR/test_slice_param_c99_emit.uya"
OUT="$BUILD_DIR/verify_slice_param_c99_emit.c"

if [ ! -f "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

echo "验证：编译 test_slice_param_c99_emit.uya 并检查 C 输出 ..."
if ! "$COMPILER" --c99 "$SRC" -o "$OUT" >/dev/null 2>&1; then
    echo "✗ 编译 test_slice_param_c99_emit.uya 失败"
    "$COMPILER" --c99 "$SRC" -o "$OUT" 2>&1 || true
    exit 1
fi

if grep -q 'uya_test_slice_param_extern_decl(struct uya_slice_uint8_t \*' "$OUT"; then
    echo "✗ extern 切片形参不应生成 struct uya_slice_uint8_t *"
    exit 1
fi
if ! grep -q 'uya_test_slice_param_extern_decl(struct uya_slice_uint8_t s)' "$OUT"; then
    echo "✗ extern 声明应为 uya_test_slice_param_extern_decl(struct uya_slice_uint8_t s)"
    exit 1
fi
echo "  extern 切片按值 ✓"

if grep -q 'uya_test_slice_param_def(struct uya_slice_uint8_t \*' "$OUT"; then
    echo "✗ 带实现的函数切片形参不应生成 struct uya_slice_uint8_t *"
    exit 1
fi
if ! grep -q 'uya_test_slice_param_def(struct uya_slice_uint8_t s)' "$OUT"; then
    echo "✗ 定义应为 uya_test_slice_param_def(struct uya_slice_uint8_t s)"
    exit 1
fi
echo "  定义切片按值 ✓"

# 调用处：call_inner 内应为 (void)(uya_test_slice_param_def(sl));（源码传 sl，不传 &sl）
if ! grep -q '(void)(uya_test_slice_param_def(sl));' "$OUT"; then
    echo "✗ call_inner 中应为 (void)(uya_test_slice_param_def(sl));"
    exit 1
fi
if ! grep -q 'uya_test_slice_param_def(sl), 8' "$OUT"; then
    echo "✗ 测试中 assert 调用应为 uya_test_slice_param_def(sl), 8"
    exit 1
fi
echo "  调用处按值传递 ✓"

echo "✓ 切片形参 C99 按值与调用约定验证通过"
