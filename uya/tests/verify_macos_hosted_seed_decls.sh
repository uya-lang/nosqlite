#!/bin/bash
# 验证 macOS hosted 单文件 seed 输出保留 read/write 的 C99 extern 声明。
# 由 make check / make check-hosted 调用。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/build/macos_hosted_seed_decl_verify"
OUT_C="$OUT_DIR/uya-hosted.c"

mkdir -p "$OUT_DIR"

if [ -x "$REPO_ROOT/bin/uya" ]; then
    COMPILER="$REPO_ROOT/bin/uya"
elif [ -x "$REPO_ROOT/bin/uya-hosted" ]; then
    COMPILER="$REPO_ROOT/bin/uya-hosted"
else
    echo "✗ 未找到可用编译器（请先 make uya 或 make uya-hosted）"
    exit 1
fi

echo "验证 macOS hosted 单文件 seed extern 声明..."
HOST_OS=macos HOST_ARCH=x86_64 TARGET_OS=macos TARGET_ARCH=x86_64 TARGET_TRIPLE= \
TOOLCHAIN="${TOOLCHAIN:-system}" ZIG="${ZIG:-}" RUNTIME_MODE=hosted LINK_MODE="${LINK_MODE:-dynamic}" \
UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= \
UYA_BOOTSTRAP_PROFILE=darwin-hosted UYA_NATIVE_BOOTSTRAP=0 \
"$COMPILER" --c99 "$REPO_ROOT/src/main.uya" -o "$OUT_C" >/dev/null 2>&1

if ! grep -Fqx 'extern ssize_t read(int, void *, size_t);' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 缺少 read extern 声明"
    exit 1
fi

if ! grep -Fqx 'extern ssize_t write(int, const void *, size_t);' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 缺少 write extern 声明"
    exit 1
fi

echo "✓ macOS hosted 单文件 seed extern 声明通过"
