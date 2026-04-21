#!/usr/bin/env bash
# 压测 pthread 测试集（全量编译+运行）。失败即停，退出码非 0。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
UYA="${UYA:-./bin/uya}"
N="${1:-100}"
SUITE=(
  tests/test_pthread_api.uya
  tests/test_pthread.uya
  tests/test_pthread_cond.uya
)
failed=0
for i in $(seq 1 "$N"); do
  for test_file in "${SUITE[@]}"; do
    # 勿用 `if ! cmd` 后读 $?`：bash 中 then 分支里 $? 常为 0，并非 cmd 的退出码
    set +e
    "$UYA" test "$test_file" >/dev/null 2>&1
    ec=$?
    set -e
    if [[ "$ec" -ne 0 ]]; then
      echo "fail at iteration $i ($test_file exit $ec)"
      failed=1
      break 2
    fi
  done
done
if [[ "$failed" -eq 0 ]]; then
  echo "ok: $N iterations"
fi
exit "$failed"
