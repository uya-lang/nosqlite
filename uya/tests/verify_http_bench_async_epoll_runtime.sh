#!/bin/bash
# 运行时验证 benchmarks/http_bench_async_epoll.uya：启动服务并校验 / 与 /json 响应
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$REPO_ROOT/benchmarks/http_bench_async_epoll.uya"
OUT_C="$BUILD_DIR/verify_http_bench_async_epoll_runtime.c"
OUT_BIN="$BUILD_DIR/verify_http_bench_async_epoll_runtime"
PORT=8876
HOST="127.0.0.1"
BASE_URL="http://$HOST:$PORT"

if [ ! -f "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

CC_CMD="${CC_DRIVER:-${CC:-cc}}"
ASYNC_BENCH_CFLAGS="${ASYNC_BENCH_CFLAGS:-${CFLAGS:--std=c99 -O3 -g -fno-builtin -fno-inline-small-functions -I${REPO_ROOT}}}"
CC_TARGET_FLAGS_USE="${CC_TARGET_FLAGS:-}"

echo "验证：构建 http_bench_async_epoll 运行时二进制 ..."
"$COMPILER" --c99 "$SRC" -o "$OUT_C" >/dev/null
$CC_CMD $CC_TARGET_FLAGS_USE $ASYNC_BENCH_CFLAGS -no-pie "$OUT_C" -o "$OUT_BIN" -lm

server_pid=""
cleanup() {
    if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "验证：启动服务并检查 HTTP 响应 ..."
"$OUT_BIN" >"$BUILD_DIR/http_bench_async_epoll_runtime.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 100); do
    if curl -sS --max-time 1 "$BASE_URL/" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

root_headers="$BUILD_DIR/http_root_headers.txt"
root_body="$BUILD_DIR/http_root_body.txt"
json_headers="$BUILD_DIR/http_json_headers.txt"
json_body="$BUILD_DIR/http_json_body.txt"

if ! curl -sS --max-time 3 -D "$root_headers" "$BASE_URL/" -o "$root_body"; then
    echo "✗ 请求 / 失败（可能出现 Empty reply）"
    exit 1
fi
if ! curl -sS --max-time 3 -D "$json_headers" "$BASE_URL/json" -o "$json_body"; then
    echo "✗ 请求 /json 失败（可能出现 Empty reply）"
    exit 1
fi

if ! grep -q "HTTP/1.1 200 OK" "$root_headers"; then
    echo "✗ / 未返回 HTTP/1.1 200 OK"
    exit 1
fi
if ! grep -q "HTTP/1.1 200 OK" "$json_headers"; then
    echo "✗ /json 未返回 HTTP/1.1 200 OK"
    exit 1
fi
if ! grep -q "^hello$" "$root_body"; then
    echo "✗ / body 非 hello"
    exit 1
fi
if ! grep -q "^\{\"ok\":true\}$" "$json_body"; then
    echo "✗ /json body 非 {\"ok\":true}"
    exit 1
fi

echo "✓ http_bench_async_epoll 运行时响应通过"
