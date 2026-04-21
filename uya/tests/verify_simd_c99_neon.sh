#!/bin/bash
# 验证含 @vector/@mask 的 C99 输出在 ARM NEON 目标可编译（zig cc 交叉）
# 由 make check / make check-hosted 调用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"
OUT_C="$SCRIPT_DIR/build/simd_c99_neon_verify.c"
ZIG="${ZIG:-/home/winger/zig/zig}"
ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$SCRIPT_DIR/build/.zig-cache-global}"
ZIG_LOCAL_CACHE_DIR="${ZIG_LOCAL_CACHE_DIR:-$SCRIPT_DIR/build/.zig-cache-local}"

mkdir -p "$SCRIPT_DIR/build"
mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"

if [ ! -x "$COMPILER" ]; then
	echo "✗ 未找到 $COMPILER（请先 make uya 或 make from-c）"
	exit 1
fi

echo "验证 SIMD C99：UYA_HAVE_SIMD_ARM_NEON 分支与 AArch64 交叉编译..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/simd_c99_neon.uya" -o "$OUT_C" 2>&1; then
	echo "✗ 编译 simd_c99_neon.uya 失败"
	exit 1
fi

if ! grep -q 'UYA_HAVE_SIMD_ARM_NEON' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 UYA_HAVE_SIMD_ARM_NEON 宏"
	exit 1
fi
if ! grep -q 'arm_neon.h' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 arm_neon.h 包含（NEON 分支）"
	exit 1
fi
if ! grep -q 'uya_simd_sse_add_i32x4' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 uya_simd_sse_* 助手"
	exit 1
fi

if [ -x "$ZIG" ]; then
	# 完整生成 C 含宿主 typedef，与 AArch64 工具链 stdint 可能冲突；仅抽出 NEON 分支做交叉 -c（同 syscall ARM 片段思路）
	SNIP_A64="${OUT_C%.c}.neon_snip_a64.c"
	SNIP_ARM="${OUT_C%.c}.neon_snip_arm.c"
	{
		echo "#include <stdint.h>"
		echo "#include <stdbool.h>"
		awk '/^#elif UYA_HAVE_SIMD_ARM_NEON$/ { sub(/^#elif/, "#if"); print; next } /^#else$/ { exit } { print }' "$OUT_C"
		echo "#endif"
	} > "$SNIP_A64"
	echo "  （可选）zig cc -target aarch64-linux-gnu -c 编译 NEON 片段..."
	if ! env ZIG_GLOBAL_CACHE_DIR="$ZIG_GLOBAL_CACHE_DIR" ZIG_LOCAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR" "$ZIG" cc -target aarch64-linux-gnu -c -std=c99 -fno-builtin -o "${SNIP_A64%.c}.o" "$SNIP_A64" 2>&1; then
		echo "✗ zig cc aarch64-linux-gnu 编译 NEON 片段失败（检查 ZIG= 路径）"
		exit 1
	fi
	echo "  ✓ AArch64 Linux 交叉编译 NEON 助手片段通过"
	cp "$SNIP_A64" "$SNIP_ARM"
	echo "  （可选）zig cc -target arm-linux-gnueabihf -mfpu=neon -c..."
	if ! env ZIG_GLOBAL_CACHE_DIR="$ZIG_GLOBAL_CACHE_DIR" ZIG_LOCAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR" "$ZIG" cc -target arm-linux-gnueabihf -mfpu=neon -c -std=c99 -fno-builtin -o "${SNIP_ARM%.c}.o" "$SNIP_ARM" 2>&1; then
		echo "✗ zig cc arm-linux-gnueabihf (NEON) 编译 NEON 片段失败"
		exit 1
	fi
	echo "  ✓ ARM32 Linux (gnueabihf + NEON) 交叉编译 NEON 助手片段通过"
else
	echo "  ⊘ 未找到可执行 zig（$ZIG），跳过交叉编译 C 的步骤"
fi

echo "✓ SIMD C99 NEON / AArch64 / ARM32 验证通过"
