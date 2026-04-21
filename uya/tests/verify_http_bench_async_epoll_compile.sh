#!/bin/bash
# 验证 benchmarks/http_bench_async_epoll.uya 可生成并通过 C99 编译（不运行长驻服务）
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$REPO_ROOT/benchmarks/http_bench_async_epoll.uya"
OUT_C="$BUILD_DIR/verify_http_bench_async_epoll.c"
OUT_O="$BUILD_DIR/verify_http_bench_async_epoll.o"

if [ ! -f "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

# 未加 --safety-proof：@async_fn 状态机拆分后，数组索引的支配边界对证明器不可见（见 handle_bench_client 内 g_cli_*[slot]）。
echo "验证：编译 benchmarks/http_bench_async_epoll.uya → C99 ..."
if ! "$COMPILER" --c99 "$SRC" -o "$OUT_C" >/dev/null 2>&1; then
    echo "✗ Uya 编译 http_bench_async_epoll 失败"
    "$COMPILER" --c99 "$SRC" -o "$OUT_C" 2>&1 || true
    exit 1
fi

CC_CMD="${CC_DRIVER:-${CC:-cc}}"
ASYNC_BENCH_CFLAGS="${ASYNC_BENCH_CFLAGS:-${CFLAGS:--std=c99 -O3 -g -fno-builtin -fno-inline-small-functions -I${REPO_ROOT}}}"
if ! $CC_CMD $CC_TARGET_FLAGS $ASYNC_BENCH_CFLAGS -no-pie -c "$OUT_C" -o "$OUT_O" 2>&1; then
    echo "✗ cc 编译 http_bench_async_epoll 生成的 C 失败"
    exit 1
fi

echo "✓ http_bench_async_epoll C99 编译通过"
