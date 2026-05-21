#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
CC_CMD="${CC_DRIVER:-${CC:-cc}}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$REPO_ROOT/benchmarks/uyagin_http_bench.uya"
OUT_C="$BUILD_DIR/verify_uyagin_http_bench_runtime.c"
OUT_BIN="$BUILD_DIR/verify_uyagin_http_bench_runtime"
PORT=18896
HOST="127.0.0.1"
BASE_URL="http://$HOST:$PORT"
CFLAGS_USE="${UYA_BENCH_CFLAGS:--std=c99 -O3 -fno-builtin -pthread -I$REPO_ROOT}"

if [ ! -f "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER"
    exit 1
fi

echo "验证：构建 uyagin_http_bench 运行时二进制 ..."
"$COMPILER" --c99 "$SRC" -o "$OUT_C" >/dev/null
$CC_CMD $CFLAGS_USE -no-pie "$OUT_C" -o "$OUT_BIN" -lm

server_pid=""
cleanup() {
    if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "验证：启动服务并检查 benchmark 路由 ..."
"$OUT_BIN" --port "$PORT" --threads 1 >"$BUILD_DIR/uyagin_http_bench_runtime.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 100); do
    if curl -sS --max-time 1 "$BASE_URL/plaintext" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

plain_body="$BUILD_DIR/uyagin_bench_plain.txt"
json_body="$BUILD_DIR/uyagin_bench_json.txt"
param_body="$BUILD_DIR/uyagin_bench_param.txt"
mw_body="$BUILD_DIR/uyagin_bench_mw.txt"
mw_headers="$BUILD_DIR/uyagin_bench_mw_headers.txt"
blob_headers="$BUILD_DIR/uyagin_bench_blob_headers.txt"
blob_body="$BUILD_DIR/uyagin_bench_blob.bin"
metrics_body="$BUILD_DIR/uyagin_bench_metrics.json"

curl -sS --max-time 3 "$BASE_URL/plaintext" -o "$plain_body"
curl -sS --max-time 3 "$BASE_URL/json" -o "$json_body"
curl -sS --max-time 3 "$BASE_URL/users/42" -o "$param_body"
curl -sS --max-time 3 -H 'Authorization: Bearer bench' -D "$mw_headers" "$BASE_URL/middleware/ping" -o "$mw_body"
curl -sS --max-time 3 -D "$blob_headers" "$BASE_URL/blob64k" -o "$blob_body"
curl -sS --max-time 3 "$BASE_URL/__uyagin/metrics" -o "$metrics_body"

if ! grep -q '^hello world!$' "$plain_body"; then
    echo "✗ /plaintext body 不匹配"
    exit 1
fi

if ! python3 - <<'PY'
import socket
addr = ("127.0.0.1", 18896)
req = b"GET /plaintext HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n"
s = socket.create_connection(addr, timeout=2)
s.sendall(req)
first = s.recv(4096)
if b"hello world!" not in first:
    raise SystemExit(1)
s.sendall(req)
second = s.recv(4096)
s.close()
if b"hello world!" not in second:
    raise SystemExit(2)
PY
then
    echo "✗ /plaintext keep-alive 双请求验证失败"
    exit 1
fi

json_len="$(wc -c <"$json_body" | tr -d ' ')"
if [ "$json_len" != "100" ]; then
    echo "✗ /json body 长度不是 100B，而是 $json_len"
    exit 1
fi

if ! grep -q '^42$' "$param_body"; then
    echo "✗ /users/42 body 不匹配"
    exit 1
fi

if ! grep -q 'HTTP/1.1 200 OK' "$mw_headers"; then
    echo "✗ /middleware/ping 未返回 200"
    exit 1
fi
if ! grep -q '^authorized$' "$mw_body"; then
    echo "✗ /middleware/ping 授权请求 body 不匹配"
    exit 1
fi

if ! grep -q 'Content-Length: 65536' "$blob_headers"; then
    echo "✗ /blob64k Content-Length 不匹配"
    exit 1
fi
blob_len="$(wc -c <"$blob_body" | tr -d ' ')"
if [ "$blob_len" != "65536" ]; then
    echo "✗ /blob64k body 长度不是 65536，而是 $blob_len"
    exit 1
fi

if ! grep -q '"heap_fallback_count":' "$metrics_body"; then
    echo "✗ /__uyagin/metrics 缺少 heap_fallback_count"
    exit 1
fi

echo "✓ uyagin_http_bench 运行时响应通过"
