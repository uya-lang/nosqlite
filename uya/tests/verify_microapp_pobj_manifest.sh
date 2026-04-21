#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
OUT_POBJ="/tmp/microcontainer_hello.pobj"

rm -f "$OUT_POBJ"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export MICROAPP_TARGET_ARCH
export TARGET_GCC

"$ROOT_DIR/bin/uya" build --app microapp examples/microapp/microcontainer_hello_source.uya -o "$OUT_POBJ" >/tmp/verify_microapp_pobj_manifest.log 2>&1

python3 - <<'PY'
from pathlib import Path
path = Path("/tmp/microcontainer_hello.pobj")
data = path.read_bytes()
source_path = b"examples/microapp/microcontainer_hello_source.uya"
assert len(data) >= 84, len(data)
assert data[:4] == b"POBJ", data[:4]
assert data[4:6] == (8).to_bytes(2, "little"), data[4:6]
assert data[6:8] == (0).to_bytes(2, "little"), data[6:8]
assert int.from_bytes(data[8:12], "little") == 2, data[8:12]
assert int.from_bytes(data[12:16], "little") == 1, data[12:16]
assert int.from_bytes(data[16:20], "little") == 0, data[16:20]
assert int.from_bytes(data[20:24], "little") == 0, data[20:24]
assert int.from_bytes(data[24:28], "little") == len(source_path), data[24:28]
code_len = int.from_bytes(data[28:32], "little")
rodata_len = int.from_bytes(data[32:36], "little")
reloc_count = int.from_bytes(data[36:40], "little")
profile_id = int.from_bytes(data[40:44], "little")
image_flags = int.from_bytes(data[44:48], "little")
bridge_kind = int.from_bytes(data[48:52], "little")
bss_size = int.from_bytes(data[52:56], "little")
stack_hint = int.from_bytes(data[56:60], "little")
data_len = int.from_bytes(data[60:64], "little")
reloc_len = int.from_bytes(data[64:68], "little")
entry_va = int.from_bytes(data[68:72], "little")
code_va = int.from_bytes(data[72:76], "little")
rodata_va = int.from_bytes(data[76:80], "little")
data_va = int.from_bytes(data[80:84], "little")
assert code_len > 0, code_len
assert rodata_len > 0, rodata_len
assert reloc_count >= 0, reloc_count
assert profile_id == 1, profile_id
assert image_flags == 0, image_flags
assert bridge_kind == 2, bridge_kind
assert bss_size >= 0, bss_size
assert stack_hint == 65536, stack_hint
assert data_len >= 0, data_len
assert reloc_len == reloc_count * 8, (reloc_len, reloc_count)
assert entry_va >= code_va, (entry_va, code_va)
assert entry_va < code_va + code_len, (entry_va, code_va, code_len)
assert entry_va % 4 == 0, entry_va
assert code_va >= 65536, code_va
assert data[84:84 + len(source_path)] == source_path, data[84:84 + len(source_path)]
code_off = 84 + len(source_path)
rodata_off = code_off + code_len
data_off = rodata_off + rodata_len
reloc_off = data_off + data_len
assert rodata_va >= code_va + code_len, (rodata_va, code_va, code_len)
assert data_va >= rodata_va + rodata_len, (data_va, rodata_va, rodata_len)
assert len(data) == reloc_off + reloc_len, (len(data), reloc_off, reloc_len)
assert b"hello microapp" in data[rodata_off:rodata_off + rodata_len], data[rodata_off:rodata_off + rodata_len]
PY

echo "microapp pobj manifest ok"
