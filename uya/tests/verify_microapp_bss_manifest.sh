#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_bss_runtime.uya"
OUT_POBJ="$(mktemp /tmp/verify_microapp_bss_manifest.XXXXXX.pobj)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_bss_manifest_build.XXXXXX.log)"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export MICROAPP_TARGET_ARCH
export TARGET_GCC

cleanup() {
    rm -f "$OUT_POBJ" "$BUILD_LOG"
}
trap cleanup EXIT

"$ROOT_DIR/bin/uya" build --app microapp "$SOURCE" -o "$OUT_POBJ" >"$BUILD_LOG" 2>&1

python3 - "$OUT_POBJ" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
assert len(data) >= 84, len(data)
assert data[:4] == b"POBJ", data[:4]
assert int.from_bytes(data[4:6], "little") == 8
bss_size = int.from_bytes(data[52:56], "little")
code_va = int.from_bytes(data[72:76], "little")
rodata_va = int.from_bytes(data[76:80], "little")
data_va = int.from_bytes(data[80:84], "little")
assert bss_size > 0, bss_size
assert rodata_va >= code_va, (rodata_va, code_va)
assert data_va >= rodata_va, (data_va, rodata_va)
PY

echo "microapp bss manifest ok"
