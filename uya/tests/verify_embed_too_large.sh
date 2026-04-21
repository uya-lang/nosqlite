#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

truncate -s 2147483648 "$TMP_DIR/huge.bin"

cat > "$TMP_DIR/embed_too_large.uya" <<'EOF'
export fn main() i32 {
    const _x: &[const byte] = @embed("huge.bin");
    _ = _x;
    return 0;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
if "$ROOT/bin/uya" build "$TMP_DIR/embed_too_large.uya" -o "$TMP_DIR/should_not_exist.out" --c99 --no-split-c >/tmp/verify_embed_too_large.log 2>&1; then
  cat /tmp/verify_embed_too_large.log
  echo "expected @embed huge file rejection, but build succeeded" >&2
  exit 1
fi
cat /tmp/verify_embed_too_large.log
echo "verify_embed_too_large: ok"
