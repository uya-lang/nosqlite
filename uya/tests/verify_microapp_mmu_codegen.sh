#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/tests/fixtures/microapp/test_microapp_mmu_codegen.uya"
RUNTIME_SOURCE="$ROOT_DIR/tests/fixtures/microapp/test_microapp_mmu_runtime.uya"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
OUT_C="$TMP_DIR/microapp_mmu_codegen.c"
RUN_EXE="$TMP_DIR/microapp_mmu_codegen"
RUNTIME_C="$TMP_DIR/microapp_mmu_runtime.c"
RUNTIME_EXE="$TMP_DIR/microapp_mmu_runtime"
BUILD_LOG="$TMP_DIR/build.log"
COMPILE_LOG="$TMP_DIR/compile.log"
RUN_LOG="$TMP_DIR/run.log"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_PROFILE:=rv32_baremetal_softvm}"
export TARGET_GCC
export MICROAPP_TARGET_PROFILE

"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$SOURCE" -o "$OUT_C" >"$BUILD_LOG" 2>&1

if [ ! -f "$OUT_C" ]; then
    cat "$BUILD_LOG"
    echo "✗ microapp MMU 代码生成未产出 C 文件"
    exit 1
fi

if ! grep -q 'static inline void \*uya_mmu_translate(void \*addr, size_t size, unsigned int access)' "$OUT_C"; then
    echo "✗ C 预lude 中缺少 uya_mmu_translate hook"
    exit 1
fi

if ! grep -q '/proc/self/maps' "$OUT_C"; then
    echo "✗ C 预lude 中缺少 native MMU maps 适配"
    exit 1
fi

if ! grep -q 'struct UyaMmuRegion' "$OUT_C"; then
    echo "✗ C 预lude 中缺少 native MMU region 定义"
    exit 1
fi

touch_start="$(grep -n 'touch(struct Holder' "$OUT_C" | tail -1 | cut -d: -f1 || true)"
if [ -z "$touch_start" ]; then
    echo "✗ 未找到 touch() 生成代码"
    exit 1
fi

touch_end=$((touch_start + 40))
touch_block="$(sed -n "${touch_start},${touch_end}p" "$OUT_C")"

translate_count="$(printf '%s\n' "$touch_block" | grep -o 'uya_mmu_translate' | wc -l | tr -d '[:space:]')"
if [ "$translate_count" -lt 6 ]; then
    echo "✗ touch() 生成代码中的 MMU 翻译调用太少: $translate_count"
    echo "$touch_block"
    exit 1
fi

if ! printf '%s\n' "$touch_block" | grep -q '__typeof__(_uya_obj) _uya_translated = (__typeof__(_uya_obj))uya_mmu_translate'; then
    echo "✗ 缺少成员访问的 MMU 包装"
    echo "$touch_block"
    exit 1
fi

if ! printf '%s\n' "$touch_block" | grep -q '__typeof__(_uya_base\[0\]) \*_uya_translated = (__typeof__(_uya_base\[0\]) \*)uya_mmu_translate'; then
    echo "✗ 缺少数组/切片访问的 MMU 包装"
    echo "$touch_block"
    exit 1
fi

if ! printf '%s\n' "$touch_block" | grep -q '__typeof__(\*_uya_ptr) \*_uya_translated = (__typeof__(\*_uya_ptr) \*)uya_mmu_translate'; then
    echo "✗ 缺少解引用的 MMU 包装"
    echo "$touch_block"
    exit 1
fi

"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$RUNTIME_SOURCE" -o "$RUNTIME_C" >"$BUILD_LOG" 2>&1
if [ ! -f "$RUNTIME_C" ]; then
    cat "$BUILD_LOG"
    echo "✗ microapp MMU 运行 fixture 未产出 C 文件"
    exit 1
fi

if ! "$TARGET_GCC" -std=c99 -O2 "$RUNTIME_C" -o "$RUNTIME_EXE" -lm >"$COMPILE_LOG" 2>&1; then
    cat "$COMPILE_LOG"
    echo "✗ microapp MMU 运行 fixture 编译失败"
    exit 1
fi

set +e
MICROAPP_DEBUG_MMU=1 "$RUNTIME_EXE" >"$RUN_LOG" 2>&1
run_status=$?
set -e
if [ "$run_status" -ne 2 ]; then
    cat "$COMPILE_LOG"
    cat "$RUN_LOG"
    echo "✗ microapp MMU 运行 fixture 退出码异常: $run_status"
    exit 1
fi

if ! grep -q '\[mmu\] translate' "$RUN_LOG"; then
    cat "$RUN_LOG"
    echo "✗ runtime fixture 未产生 translate 日志"
    exit 1
fi

if grep -q 'fallback direct' "$RUN_LOG"; then
    cat "$RUN_LOG"
    echo "✗ runtime fixture 退回到了 direct fallback"
    exit 1
fi

echo "microapp MMU codegen ok"
