#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_A="$(mktemp "$ROOT/tests/embed_dir_multifile_a.XXXXXX.uya")"
TMP_B="$(mktemp "$ROOT/tests/embed_dir_multifile_b.XXXXXX.uya")"
OUT_C="/tmp/embed_dir_multifile_reuse.c"
trap 'rm -f "$TMP_A" "$TMP_B" "$OUT_C"' EXIT

cat > "$TMP_A" <<'EOF'
const A: &[const EmbedDirEntry] = @embed_dir("fixtures/embed/assets");

fn a_len() i32 {
    return @len(A);
}
EOF

cat > "$TMP_B" <<'EOF'
const B: &[const EmbedDirEntry] = @embed_dir("fixtures/embed/assets");

export fn main() i32 {
    if @len(B) != 3 {
        return 1;
    }
    return 0;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$TMP_A" "$TMP_B" -o "$OUT_C" --c99 --no-split-c
COUNT="$(grep -c "static const struct EmbedDirEntry uya_embed_dir_" "$OUT_C")"
if [ "$COUNT" != "1" ]; then
  echo "expected 1 embedded directory table across multifile build, got $COUNT" >&2
  exit 1
fi
echo "verify_embed_dir_multifile_reuse: ok"
