#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/empty"

cat > "$TMP/embed_empty_dir.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.run_test;

fn test_embed_empty_dir() !void {
    const items: &[const EmbedDirEntry] = @embed_dir("empty");
    try assert_eq_i32(@len(items), 0);
}

test "embed_empty_dir" {
    run_test("embed_empty_dir", test_embed_empty_dir);
}
EOF

export UYA_ROOT="${ROOT}/lib/"
"$ROOT/bin/uya" build "$TMP/embed_empty_dir.uya" -o "$TMP/embed_empty_dir.out" --c99 --no-split-c
"$TMP/embed_empty_dir.out"
echo "verify_embed_empty_dir: ok"
