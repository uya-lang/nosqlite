#!/bin/bash
# 验证 split-C stale lock 可自动回收，覆盖 owner pid 已死亡与旧版空锁目录两种残留形态。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
SRC="${UYA_SPLIT_LOCK_SRC:-$REPO_ROOT/tests/test_option_struct.uya}"

TMP_DIR="$(mktemp -d /tmp/uya_split_cache_stale_lock.XXXXXX)"

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

run_case_with_dead_owner_pid() {
    local cache_dir="$TMP_DIR/shared-cache-dead-pid"
    local lock_dir="$cache_dir/.uya-lock"
    local pid_file="$lock_dir/owner.pid"
    local out="$TMP_DIR/out-dead-pid"
    local log="$TMP_DIR/build-dead-pid.log"
    mkdir -p "$lock_dir"
    local fake_pid=$(( $$ + 100000 ))
    while kill -0 "$fake_pid" 2>/dev/null; do
        fake_pid=$(( fake_pid + 100000 ))
        if [ "$fake_pid" -ge 2147400000 ]; then
            echo "✗ 无法构造确定死亡的 fake pid"
            exit 1
        fi
    done
    printf '%s\n' "$fake_pid" >"$pid_file"
    echo "验证：遇到 owner pid 已死亡的 split-C stale lock 时，uya 应自动回收并继续编译 ..."
    if ! "$COMPILER" build "$SRC" --split-c-dir "$cache_dir" -o "$out" --c99 >"$log" 2>&1; then
        echo "✗ stale lock(owner pid) 回收后编译仍失败"
        cat "$log"
        exit 1
    fi
    if [ -d "$lock_dir" ]; then
        echo "✗ owner pid stale lock 编译完成后锁目录仍残留"
        find "$cache_dir" -maxdepth 2 -type d | sort
        cat "$log"
        exit 1
    fi
    if ! grep -q "检测到 stale split-C 锁，已回收" "$log"; then
        echo "✗ owner pid stale lock 编译日志未显示回收信息"
        cat "$log"
        exit 1
    fi
    if [ ! -f "$cache_dir/Makefile" ]; then
        echo "✗ owner pid stale lock 回收后未生成 split-C Makefile"
        cat "$log"
        exit 1
    fi
}

run_case_with_empty_lock_dir() {
    local cache_dir="$TMP_DIR/shared-cache-empty-lock"
    local lock_dir="$cache_dir/.uya-lock"
    local out="$TMP_DIR/out-empty-lock"
    local log="$TMP_DIR/build-empty-lock.log"
    mkdir -p "$lock_dir"
    echo "验证：遇到旧版残留的空 split-C 锁目录时，uya 应自动回收并继续编译 ..."
    if ! "$COMPILER" build "$SRC" --split-c-dir "$cache_dir" -o "$out" --c99 >"$log" 2>&1; then
        echo "✗ 空 stale lock 回收后编译仍失败"
        cat "$log"
        exit 1
    fi
    if [ -d "$lock_dir" ]; then
        echo "✗ 空 stale lock 编译完成后锁目录仍残留"
        find "$cache_dir" -maxdepth 2 -type d | sort
        cat "$log"
        exit 1
    fi
    if ! grep -q "检测到 incomplete split-C 锁，已回收" "$log"; then
        echo "✗ 空 stale lock 编译日志未显示回收信息"
        cat "$log"
        exit 1
    fi
    if [ ! -f "$cache_dir/Makefile" ]; then
        echo "✗ 空 stale lock 回收后未生成 split-C Makefile"
        cat "$log"
        exit 1
    fi
}

run_case_with_dead_owner_pid
run_case_with_empty_lock_dir
echo "verify_split_c_cache_stale_lock: ok"
