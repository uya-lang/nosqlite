#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$ROOT/tests/test_embed_builtin.uya" \
  --split-c-dir "$TMP" -o "$TMP/embed.out" --c99
"$TMP/embed.out"
echo "verify_embed_split_c: ok"
