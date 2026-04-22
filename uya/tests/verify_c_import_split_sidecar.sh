#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TMP_DIR=$(mktemp -d /tmp/verify_c_import_split_sidecar.XXXXXX)
LOG_FILE="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! "$ROOT_DIR/bin/uya" build --c99 --split-c-dir "$TMP_DIR/split" "$ROOT_DIR/tests/test_c_import_file.uya" -o "$TMP_DIR/out.c" >"$LOG_FILE" 2>&1; then
    cat "$LOG_FILE"
    echo "c_import split sidecar build failed" >&2
    exit 1
fi

if [ -e "$TMP_DIR/out.cimports.sh" ]; then
    echo "unexpected sidecar emitted for split-c explicit .c output" >&2
    exit 1
fi

if [ ! -f "$TMP_DIR/split/Makefile" ]; then
    echo "split-c output missing Makefile" >&2
    exit 1
fi

echo "c_import split sidecar ok"
