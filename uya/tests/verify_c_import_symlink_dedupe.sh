#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TMP_DIR=$(mktemp -d /tmp/verify_c_import_symlink.XXXXXX)
LOG_FILE="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/real/sub" "$TMP_DIR/proj"
ln -s "$TMP_DIR/real" "$TMP_DIR/linkreal"

cat > "$TMP_DIR/real/sub/dup.c" <<'EOF'
int dup_add(int a, int b) {
    return a + b;
}
EOF

cat > "$TMP_DIR/proj/main.uya" <<'EOF'
@c_import("../real/sub/dup.c");
@c_import("../linkreal/sub/dup.c");

use std.runtime.entry;

extern fn dup_add(a: i32, b: i32) i32;

export fn main() i32 {
    if dup_add(20, 22) == 42 {
        return 0;
    }
    return 1;
}
EOF

if ! UYA_SPLIT_C=0 "$ROOT_DIR/bin/uya" build --c99 "$TMP_DIR/proj/main.uya" -o "$TMP_DIR/out.bin" >"$LOG_FILE" 2>&1; then
    cat "$LOG_FILE"
    echo "c_import symlink dedupe build failed" >&2
    exit 1
fi

"$TMP_DIR/out.bin"
echo "c_import symlink dedupe ok"
