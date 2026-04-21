#!/bin/bash
# 验证 @syscall 的 C99 输出含 Linux x86_64 / AArch64 / ARM32 分支（交叉编译时不再唯一条 #error）
# 由 make check / make check-hosted 调用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"
OUT_C="$SCRIPT_DIR/build/syscall_c99_cross_verify.c"
ZIG="${ZIG:-/home/winger/zig/zig}"
ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$SCRIPT_DIR/build/.zig-cache-global}"
ZIG_LOCAL_CACHE_DIR="${ZIG_LOCAL_CACHE_DIR:-$SCRIPT_DIR/build/.zig-cache-local}"

mkdir -p "$SCRIPT_DIR/build"
mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"

if [ ! -x "$COMPILER" ]; then
	echo "✗ 未找到 $COMPILER（请先 make uya 或 make from-c）"
	exit 1
fi

echo "验证 @syscall C99：含 x86_64、Linux AArch64、Linux ARM32 分支..."
if ! "$COMPILER" --c99 "$SCRIPT_DIR/syscall_c99_cross.uya" -o "$OUT_C" 2>&1; then
	echo "✗ 编译失败"
	exit 1
fi

if ! grep -q '__aarch64__' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 AArch64 条件分支"
	exit 1
fi
if ! grep -q 'defined(__arm__) && !defined(__aarch64__)' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 Linux ARM32（__arm__ 且非 AArch64）条件分支"
	exit 1
fi
if ! grep -q 'mov r7' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 ARM32 EABI（r7 系统调用号）内联汇编"
	exit 1
fi
if ! grep -q 'svc 0' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 svc 0 系统调用"
	exit 1
fi
if ! grep -q 'uya_syscall0' "$OUT_C"; then
	echo "✗ 生成的 C 中缺少 uya_syscall 辅助函数"
	exit 1
fi

if [ -x "$ZIG" ]; then
	echo "  （可选）zig cc -target aarch64-linux-gnu -c 编译生成的 C..."
	if ! env ZIG_GLOBAL_CACHE_DIR="$ZIG_GLOBAL_CACHE_DIR" ZIG_LOCAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR" "$ZIG" cc -target aarch64-linux-gnu -c -std=c99 -fno-builtin -o "${OUT_C%.c}.aarch64.o" "$OUT_C" 2>&1; then
		echo "✗ zig cc aarch64-linux-gnu 交叉编译失败（检查 ZIG= 路径）"
		exit 1
	fi
	echo "  ✓ AArch64 Linux 交叉编译 C 文件通过"
	# 完整夹具含宿主 typedef（如 ssize_t），与 ARM gnueabihf 头文件可能冲突；仅抽出 ARM 分支做语法/汇编编译检查
	ARM_SNIP="${OUT_C%.c}.arm_syscall_snip.c"
	awk '
/^#elif defined\(__arm__\) && !defined\(__aarch64__\) && defined\(__linux__/ { arm=1 }
arm {
	if (/^#else$/) exit
	print
}
' "$OUT_C" | sed '1s/^#elif /#if /' > "$ARM_SNIP"
	printf '\n#endif\n' >> "$ARM_SNIP"
	echo "  （可选）zig cc -target arm-linux-gnueabihf -c 编译 ARM @syscall 片段..."
	if ! env ZIG_GLOBAL_CACHE_DIR="$ZIG_GLOBAL_CACHE_DIR" ZIG_LOCAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR" "$ZIG" cc -target arm-linux-gnueabihf -c -std=c99 -fno-builtin -o "${OUT_C%.c}.arm.o" "$ARM_SNIP" 2>&1; then
		echo "✗ zig cc arm-linux-gnueabihf 编译 ARM 片段失败（检查 ZIG= 路径）"
		exit 1
	fi
	echo "  ✓ ARM32 Linux (gnueabihf) 交叉编译 syscall 片段通过"
else
	echo "  ⊘ 未找到可执行 zig（$ZIG），跳过交叉编译 C 的步骤"
fi

echo "✓ @syscall C99 交叉目标（AArch64 / ARM32）验证通过"
