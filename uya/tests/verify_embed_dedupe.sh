#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_SRC="$(mktemp "$ROOT/tests/embed_dedupe_mix.XXXXXX.uya")"
trap 'rm -f "$TMP_SRC" /tmp/embed_dedupe_mix.c' EXIT

ABS_PATH="$(cd "$ROOT" && pwd)/tests/fixtures/embed/basic.bin"

cat > "$TMP_SRC" <<EOF
const A: &[const byte] = @embed("fixtures/embed/basic.bin");
const B: &[const byte] = @embed("$ABS_PATH");

export fn main() i32 {
    return 0;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$TMP_SRC" -o /tmp/embed_dedupe_mix.c --c99 --no-split-c

COUNT="$(grep -c "static const unsigned char uya_embed_" /tmp/embed_dedupe_mix.c)"
if [ "$COUNT" != "1" ]; then
  echo "expected 1 embedded blob, got $COUNT" >&2
  exit 1
fi

echo "verify_embed_dedupe: ok"
