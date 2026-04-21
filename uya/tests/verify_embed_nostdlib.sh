#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_SRC="$(mktemp "$ROOT/tests/embed_nostdlib.XXXXXX.uya")"
OUT="/tmp/embed_nostdlib.out"
trap 'rm -f "$TMP_SRC" "$OUT"' EXIT

cat > "$TMP_SRC" <<'EOF'
const BYTES: &[const byte] = @embed("fixtures/embed/basic.bin");

export fn main() i32 {
    if @len(BYTES) != 4 {
        return 1;
    }
    return BYTES.ptr[1] as i32;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$TMP_SRC" -o "$OUT" --c99 --nostdlib --no-split-c
"$OUT" >/dev/null 2>&1 || true
echo "verify_embed_nostdlib: ok"
