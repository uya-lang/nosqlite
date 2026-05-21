#!/bin/bash
# 验证 split-C 共享输出目录在并发编译时会 fail-fast，而不是继续写坏缓存产物。
# 第二个进程故意使用同一目录的另一种写法（末尾加 /），防止路径别名绕过锁。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
SRC="${UYA_SPLIT_LOCK_SRC:-$REPO_ROOT/tests/test_option_struct.uya}"

TMP_DIR="$(mktemp -d /tmp/uya_split_cache_lock.XXXXXX)"
CACHE_DIR="$TMP_DIR/shared-cache"
CACHE_DIR_ALIAS="${CACHE_DIR}/"
OUT1="$TMP_DIR/out-first"
OUT2="$TMP_DIR/out-second"
LOG1="$TMP_DIR/first.log"
LOG2="$TMP_DIR/second.log"
WRAP_DIR="$TMP_DIR/wrap-bin"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ ! -x "$COMPILER" ]; then
    echo "✗ 未找到编译器: $COMPILER（请先 make uya）"
    exit 1
fi

if [ ! -f "$SRC" ]; then
    echo "✗ 未找到测试源文件: $SRC"
    exit 1
fi

REAL_MAKE="$(command -v make)"
if [ -z "$REAL_MAKE" ]; then
    echo "✗ 未找到 make"
    exit 1
fi

mkdir -p "$WRAP_DIR"
cat >"$WRAP_DIR/make" <<'EOF'
#!/bin/sh
sleep "${UYA_SPLIT_CACHE_LOCK_SLEEP:-2}"
exec "$UYA_REAL_MAKE" "$@"
EOF
chmod +x "$WRAP_DIR/make"

echo "验证：两个 uya 进程并发写同一个 split-C cache（含路径别名）时，第二个进程应明确报 busy ..."

set +e
PATH="$WRAP_DIR:$PATH" UYA_REAL_MAKE="$REAL_MAKE" \
    "$COMPILER" build "$SRC" --split-c-dir "$CACHE_DIR" -o "$OUT1" --c99 >"$LOG1" 2>&1 &
P1=$!
set -e

READY=0
for _ in $(seq 1 100); do
    if grep -q "信息：多文件 C 链接：" "$LOG1" 2>/dev/null; then
        READY=1
        break
    fi
    if ! kill -0 "$P1" 2>/dev/null; then
        break
    fi
    sleep 0.05
done

if [ "$READY" -ne 1 ]; then
    wait "$P1" || true
    echo "✗ 第一个编译未进入 split-C 链接阶段，无法建立并发窗口"
    cat "$LOG1"
    exit 1
fi

set +e
"$COMPILER" build "$SRC" --split-c-dir "$CACHE_DIR_ALIAS" -o "$OUT2" --c99 >"$LOG2" 2>&1
STATUS2=$?
wait "$P1"
STATUS1=$?
set -e

if [ "$STATUS1" -ne 0 ]; then
    echo "✗ 第一个编译失败（应成功持锁完成）"
    cat "$LOG1"
    exit 1
fi

if [ "$STATUS2" -eq 0 ]; then
    echo "✗ 第二个编译意外成功（应明确拒绝共享 split-C cache）"
    cat "$LOG2"
    exit 1
fi

if ! grep -q "正在被另一编译进程使用" "$LOG2"; then
    echo "✗ 第二个编译未给出明确 busy 错误"
    cat "$LOG2"
    exit 1
fi

if grep -q "代码生成完成" "$LOG2"; then
    echo "✗ 第二个编译在报错前仍继续生成了 split-C 产物"
    cat "$LOG2"
    exit 1
fi

if [ ! -f "$CACHE_DIR/Makefile" ]; then
    echo "✗ 第一个编译结束后未生成 split-C Makefile"
    cat "$LOG1"
    exit 1
fi

echo "verify_split_c_cache_lock: ok"
