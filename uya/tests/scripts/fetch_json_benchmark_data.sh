#!/usr/bin/env bash
# 可选：下载常用 JSON 吞吐基准样本（twitter / canada / citm_catalog），供本地大文件 parse 实验。
# 来源：simdjson 仓库 jsonexamples（MIT）；不纳入版本库，避免体积膨胀。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${JSON_BENCH_DATA_DIR:-$ROOT/tests/data/json}"
BASE="https://raw.githubusercontent.com/simdjson/simdjson/master/jsonexamples"
mkdir -p "$OUT"
for f in twitter.json canada.json citm_catalog.json; do
  dest="$OUT/$f"
  if [[ -f "$dest" ]]; then
    echo "skip (exists): $dest"
    continue
  fi
  echo "fetch $f -> $dest"
  curl -fsSL "$BASE/$f" -o "$dest"
done
echo "done. Set JSON_BENCH_DATA_DIR to override output directory."
