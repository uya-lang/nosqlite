#!/bin/bash
# 验证 C99 代码生成在 split-C 输出时没有退化为病态 tiny-write。
# 当前选择 async-heavy 的 tests/test_std_async_scheduler.uya 作为较小复现体。
#
# 说明：
# 1. 这里只跟踪主编译器进程本身的 open/write，不跟踪后续 make/cc 子进程，
#    因为我们要测的是代码生成器的写出粒度，而不是链接器行为。
# 2. 编译命令即使在后续链接阶段失败，只要 split-C 缓存目录里已经出现写入，
#    这个脚本仍然可以完成统计并给出红/绿结果。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
SRC="$REPO_ROOT/tests/test_std_async_scheduler.uya"

MAX_WRITES="${UYA_CODEGEN_MAX_WRITES:-10000}"
MIN_AVG_BYTES="${UYA_CODEGEN_MIN_AVG_BYTES:-64}"
MAX_SMALL_WRITES="${UYA_CODEGEN_MAX_SMALL_WRITES:-4000}"

CACHE_DIR="$(mktemp -d /tmp/uya_codegen_emit_buffering.XXXXXX)"
OUT_BIN="$(mktemp /tmp/uya_codegen_emit_buffering_out.XXXXXX)"
TRACE_FILE="$(mktemp /tmp/uya_codegen_emit_buffering_trace.XXXXXX)"

cleanup() {
    rm -rf "$CACHE_DIR"
    rm -f "$OUT_BIN" "$TRACE_FILE"
}
trap cleanup EXIT

if [ ! -x "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

if [ ! -f "$SRC" ]; then
    echo "✗ 未找到复现源文件: $SRC"
    exit 1
fi

echo "验证：strace 统计 split-C 代码生成 write 粒度 ..."

set +e
timeout 20s strace -yy -e trace=open,openat,write -o "$TRACE_FILE" \
    "$COMPILER" build "$SRC" --split-c-dir "$CACHE_DIR" -o "$OUT_BIN" >/dev/null 2>&1
STATUS=$?
set -e

WRITE_LINES="$(grep 'write(' "$TRACE_FILE" | grep "$CACHE_DIR" || true)"
if [ -z "$WRITE_LINES" ]; then
    echo "✗ 未捕获到写入 split-C 缓存目录的 write(2)"
    echo "  编译器退出码: $STATUS"
    exit 1
fi

COUNT="$(printf '%s\n' "$WRITE_LINES" | wc -l | tr -d ' ')"
BYTES="$(printf '%s\n' "$WRITE_LINES" | sed -E 's/.*\) = ([0-9-]+)$/\1/' | awk '{ if ($1 > 0) s += $1 } END { print s + 0 }')"
SMALL_WRITES="$(printf '%s\n' "$WRITE_LINES" | sed -E 's/.*\) = ([0-9-]+)$/\1/' | awk '{ if ($1 >= 0 && $1 <= 8) c += 1 } END { print c + 0 }')"
AVG_BYTES="$(awk -v bytes="$BYTES" -v count="$COUNT" 'BEGIN { if (count == 0) { printf "0.00" } else { printf "%.2f", bytes / count } }')"

echo "  write 次数: $COUNT"
echo "  总字节数: $BYTES"
echo "  平均每次: $AVG_BYTES B"
echo "  <=8B 小写入: $SMALL_WRITES"
echo "  编译器退出码: $STATUS"

FAIL=0
if [ "$COUNT" -gt "$MAX_WRITES" ]; then
    echo "✗ write 次数过多：阈值 $MAX_WRITES，实际 $COUNT"
    FAIL=1
fi

if awk -v avg="$AVG_BYTES" -v min="$MIN_AVG_BYTES" 'BEGIN { exit !(avg < min) }'; then
    echo "✗ 平均 write 粒度过小：阈值 >= $MIN_AVG_BYTES B，实际 $AVG_BYTES B"
    FAIL=1
fi

if [ "$SMALL_WRITES" -gt "$MAX_SMALL_WRITES" ]; then
    echo "✗ 超小 write 过多：阈值 $MAX_SMALL_WRITES，实际 $SMALL_WRITES"
    FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
    echo "✗ 命中代码生成 tiny-write 病态回归"
    exit 1
fi

echo "✓ 代码生成 write 粒度通过阈值"
