#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_SRC="$(mktemp /tmp/embed_dir_type_only.XXXXXX.uya)"
trap 'rm -f "$TMP_SRC" /tmp/embed_dir_type_only.out' EXIT

cat > "$TMP_SRC" <<'EOF'
fn takes(items: &[const EmbedDirEntry]) i32 {
    return @len(items);
}

export fn main() i32 {
    return 0;
}
EOF

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$TMP_SRC" -o /tmp/embed_dir_type_only.out --c99 --no-split-c
/tmp/embed_dir_type_only.out
echo "verify_embed_type_only: ok"
