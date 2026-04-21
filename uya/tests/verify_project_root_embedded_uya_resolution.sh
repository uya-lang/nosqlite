#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${UYA_COMPILER:-}" ]; then
    COMPILER="$UYA_COMPILER"
elif [ -x "$REPO_ROOT/bin/uya-hosted" ]; then
    COMPILER="$REPO_ROOT/bin/uya-hosted"
else
    COMPILER="$REPO_ROOT/bin/uya"
fi

TMP_DIR="$(mktemp -d /tmp/uya-embedded-root.XXXXXX)"
OUT_C="$TMP_DIR/out.c"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/uya"
ln -s "$REPO_ROOT/lib" "$TMP_DIR/uya/lib"

cat > "$TMP_DIR/root_async_import.uya" <<'EOF'
use std.async;

export fn main() i32 {
    const w: Waker = Waker{};
    _ = w;
    return 0;
}
EOF

UYA_ROOT="$TMP_DIR/uya/lib/" "$COMPILER" build "$TMP_DIR/root_async_import.uya" -o "$OUT_C" --c99 >/tmp/verify_project_root_embedded_uya_resolution.log 2>&1
test -s "$OUT_C"

echo "embedded project-root stdlib resolution ok"
