#!/usr/bin/env bash
# 压测 tests/test_epoll_server.uya（与单测一致：run_programs_parallel.sh --uya --c99）。
# 失败即停，退出码非 0；全部通过时打印 ok。
#
# 勿写：for i in $(seq 1 N); do ./tests/run_programs_parallel.sh ... || echo fail $i; done && echo all ok
# 原因：失败时 `echo` 仍成功，整个 for 的退出状态为 0，会误报「全部通过」。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
N="${1:-100}"
if [[ ! -f "$ROOT/bin/uya" ]] || [[ ! -x "$ROOT/bin/uya" ]]; then
  echo "错误: 缺少可执行编译器 $ROOT/bin/uya（请先 make uya 或 make from-c）" >&2
  exit 2
fi
logfile=$(mktemp "${TMPDIR:-/tmp}/uya_stress_epoll.XXXXXX")
trap 'rm -f "$logfile"' EXIT
failed=0
for i in $(seq 1 "$N"); do
  set +e
  ./tests/run_programs_parallel.sh --uya --c99 tests/test_epoll_server.uya >"$logfile" 2>&1
  ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    echo "fail at iteration $i (exit $ec)" >&2
    echo "--- 本轮完整输出（末尾 60 行）---" >&2
    tail -n 60 "$logfile" >&2
    failed=1
    break
  fi
done
if [[ "$failed" -eq 0 ]]; then
  echo "ok: $N iterations"
fi
exit "$failed"
