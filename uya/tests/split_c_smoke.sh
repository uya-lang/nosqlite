#!/usr/bin/env bash
# 可选：多文件 C（--split-c-dir / UYA_SPLIT_C_DIR）冒烟测试
# 用法：在仓库根目录 ./tests/split_c_smoke.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$ROOT/tests/test_std_ring_queue.uya" \
  --split-c-dir "$TMP" -o "$TMP/a.out" --c99
"$TMP/a.out"
echo "split_c_smoke: ok"
