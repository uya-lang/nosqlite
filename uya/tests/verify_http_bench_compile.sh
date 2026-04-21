#!/bin/bash
# 验证 benchmarks/http_bench.uya 可生成并通过 C99 编译（供 wrk 等压测；不运行长驻服务）
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$REPO_ROOT/benchmarks/http_bench.uya"
OUT_C="$BUILD_DIR/verify_http_bench.c"
OUT_O="$BUILD_DIR/verify_http_bench.o"

if [ ! -f "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

echo "验证：编译 benchmarks/http_bench.uya → C99 ..."
if ! "$COMPILER" --c99 --safety-proof "$SRC" -o "$OUT_C" >/dev/null 2>&1; then
    echo "✗ Uya 编译 http_bench 失败"
    "$COMPILER" --c99 --safety-proof "$SRC" -o "$OUT_C" 2>&1 || true
    exit 1
fi

CC_CMD="${CC_DRIVER:-${CC:-cc}}"
# 与 release 构建一致默认 -O2；若遇回归可用 CFLAGS='... -O1' 覆盖
CFLAGS_USE="${CFLAGS:--std=c99 -O2 -fno-builtin -Werror}"
if ! $CC_CMD $CC_TARGET_FLAGS $CFLAGS_USE -std=c99 -no-pie -c "$OUT_C" -o "$OUT_O" 2>&1; then
    echo "✗ cc 编译 http_bench 生成的 C 失败"
    exit 1
fi

echo "✓ http_bench C99 编译通过"
