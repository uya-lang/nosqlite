#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POBJ="/tmp/microcontainer_hello.pobj"
UAPP="/tmp/microcontainer_hello_from_pobj.uapp"

rm -f "$POBJ" "$UAPP"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export MICROAPP_TARGET_ARCH
export TARGET_GCC

"$ROOT_DIR/bin/uya" build --app microapp examples/microapp/microcontainer_hello_source.uya -o "$POBJ" >/tmp/verify_microapp_pack_image_build.log 2>&1
"$ROOT_DIR/bin/uya" pack-image "$POBJ" -o "$UAPP" >/tmp/verify_microapp_pack_image_pack.log 2>&1

python3 - <<'PY'
from pathlib import Path
source_path = b"examples/microapp/microcontainer_hello_source.uya"
pobj = Path("/tmp/microcontainer_hello.pobj").read_bytes()
data = Path("/tmp/microcontainer_hello_from_pobj.uapp").read_bytes()
assert len(data) >= 100, len(data)
assert data[:4] == b"\x00AYU", data[:4]
assert data[4:6] == (2).to_bytes(2, "little"), data[4:6]
assert data[6:8] == (1).to_bytes(2, "little"), data[6:8]
code_size = int.from_bytes(data[16:20], "little")
rodata_size = int.from_bytes(data[20:24], "little")
reloc_count = int.from_bytes(data[24:28], "little")
entry_offset = int.from_bytes(data[12:16], "little")
entry_va = int.from_bytes(data[136:140], "little")
code_va = int.from_bytes(data[140:144], "little")
rodata_va = int.from_bytes(data[144:148], "little")
code_off = int.from_bytes(data[108:112], "little")
rodata_off = int.from_bytes(data[112:116], "little")
build_mode = data[64]
target_arch = data[65]
assert code_size > 0, code_size
assert rodata_size > 0, rodata_size
assert reloc_count >= 0, reloc_count
assert entry_offset == 0, entry_offset
assert entry_va >= code_va, (entry_va, code_va)
assert entry_va < code_va + code_size, (entry_va, code_va, code_size)
assert entry_va % 4 == 0, entry_va
assert code_va >= 65536, code_va
assert rodata_va >= code_va + code_size, (rodata_va, code_va, code_size)
assert code_off >= 160, code_off
assert rodata_off == code_off + code_size, (rodata_off, code_off, code_size)
assert build_mode == 1, build_mode
assert target_arch == 2, target_arch
assert data[code_off:code_off + code_size] == pobj[84 + len(source_path):84 + len(source_path) + code_size]
assert b"hello microapp" in data[rodata_off:rodata_off + rodata_size]
PY

echo "microapp pack-image ok"
