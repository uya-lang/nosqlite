#!/usr/bin/env bash
# 验证用户程序 --nostdlib：可链接、可运行、静态可执行文件（无动态 libc 依赖）
set -euo pipefail
export LANG=C LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UYA="${UYA:-$ROOT/bin/uya}"
MIN="$ROOT/tests/programs/test_nostdlib_zero_dep.uya"
ASYNC="$ROOT/tests/programs/test_nostdlib_async_malloc.uya"

if [[ ! -x "$UYA" ]]; then
  echo "缺少 $UYA，请先 make uya" >&2
  exit 1
fi

run_one() {
  local src="$1"
  local name
  name="$(basename "$src" .uya)"
  local out="/tmp/uya_nostd_verify_${name}_$$"
  echo "==> nostdlib build: $src"
  "$UYA" build --nostdlib "$src" -o "$out"
  "$out"
  local ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "运行失败: exit $ec" >&2
    exit 1
  fi
  if ! file "$out" | grep -q 'statically linked'; then
    echo "期望静态链接: $out" >&2
    file "$out" >&2
    exit 1
  fi
  # 比解析 ldd 文案更可移植：静态 ELF 不应有 NEEDED 动态库条目
  if readelf -d "$out" 2>/dev/null | grep -q '(NEEDED)'; then
    echo "期望无动态段 NEEDED（零 libc.so 依赖）: $out" >&2
    readelf -d "$out" >&2 || true
    exit 1
  fi
  rm -f "$out"
  echo "    OK"
}

run_one "$MIN"
run_one "$ASYNC"
echo "nostdlib 用户程序零依赖（静态）验证通过"
