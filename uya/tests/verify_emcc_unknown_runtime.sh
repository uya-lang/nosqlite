#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
SOURCE_UYA="$SCRIPT_DIR/emcc_unknown_runtime_smoke.uya"
HOST_BRIDGE_C="$SCRIPT_DIR/emcc_unknown_host.c"
BUILD_DIR="$SCRIPT_DIR/build/emcc_unknown_runtime"
OUT_C="$BUILD_DIR/emcc_unknown_runtime_smoke.c"
OUT_GEN_O="$BUILD_DIR/emcc_unknown_runtime_smoke.generated.o"
OUT_HOST_O="$BUILD_DIR/emcc_unknown_runtime_smoke.host.o"
OUT_JS="$BUILD_DIR/emcc_unknown_runtime_smoke.js"
OUT_LOG="$BUILD_DIR/emcc_unknown_runtime_smoke.log"

mkdir -p "$BUILD_DIR"
export UYA_ROOT="$REPO_ROOT/lib/"

if [ ! -x "$COMPILER" ]; then
    echo "✗ 未找到 $COMPILER（请先 make uya 或 make from-c）"
    exit 1
fi

if ! command -v emcc >/dev/null 2>&1; then
    echo "✗ 未找到 emcc，请先安装 Emscripten"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "✗ 未找到 node，无法执行 emcc 生成的 Node smoke"
    exit 1
fi

echo "验证 unknown target 经 emcc 编译并运行最小闭环..."
TARGET_OS=unknown TARGET_ARCH=unknown "$COMPILER" --c99 "$SOURCE_UYA" -o "$OUT_C"

sed -i '/@syscall C99 backend: supported targets/d' "$OUT_C"
sed -i 's/^int32_t main(int32_t argc, char \*\*argv) {$/__attribute__((used, visibility("default"))) int32_t main(int32_t argc, char **argv) {/' "$OUT_C"

emcc -std=c99 -O0 -fno-builtin -w \
    -include fcntl.h \
    -include sys/uio.h \
    -include sys/mman.h \
    -c "$OUT_C" \
    -o "$OUT_GEN_O"

emcc -std=gnu99 -O0 -Wall -Wextra -pedantic \
    -c "$HOST_BRIDGE_C" \
    -o "$OUT_HOST_O"

emcc -O0 "$OUT_GEN_O" "$OUT_HOST_O" \
    -o "$OUT_JS" \
    -sALLOW_MEMORY_GROWTH=1 \
    -sINITIAL_MEMORY=33554432 \
    -sEXIT_RUNTIME=1 \
    -sASSERTIONS=1 \
    -sENVIRONMENT=node \
    -sEXPORTED_FUNCTIONS=_main

node "$OUT_JS" >"$OUT_LOG" 2>&1

if ! grep -q 'EMCC_SMOKE_OK uya-emcc-payload' "$OUT_LOG"; then
    echo "✗ emcc smoke 输出未包含预期哨兵"
    cat "$OUT_LOG"
    exit 1
fi

echo "✓ emcc unknown runtime smoke 通过"
