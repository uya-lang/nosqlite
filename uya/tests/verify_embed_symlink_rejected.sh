#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/assets"
printf 'ok' > "$TMP/assets/file.txt"
ln -s "$TMP/assets/file.txt" "$TMP/assets/link.txt"

cat > "$TMP/embed_symlink_fail.uya" <<'EOF'
export fn main() i32 {
    const _items: &[const EmbedDirEntry] = @embed_dir("assets");
    _ = _items;
    return 0;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
if "$ROOT/bin/uya" build "$TMP/embed_symlink_fail.uya" -o "$TMP/should_not_exist.out" --c99 --no-split-c >/tmp/verify_embed_symlink_rejected.log 2>&1; then
  cat /tmp/verify_embed_symlink_rejected.log
  echo "expected @embed_dir symlink rejection, but build succeeded" >&2
  exit 1
fi
cat /tmp/verify_embed_symlink_rejected.log
echo "verify_embed_symlink_rejected: ok"
