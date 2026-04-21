#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POBJ="$(mktemp /tmp/verify_microapp_inspect.XXXXXX.pobj)"
UAPP="$(mktemp /tmp/verify_microapp_inspect.XXXXXX.uapp)"
LEGACY_POBJ_V5="$(mktemp /tmp/verify_microapp_inspect_v5.XXXXXX.pobj)"
LEGACY_POBJ_V6="$(mktemp /tmp/verify_microapp_inspect_v6.XXXXXX.pobj)"
LEGACY_UAPP_V1="$(mktemp /tmp/verify_microapp_inspect_v1.XXXXXX.uapp)"
POBJ_LOG="$(mktemp /tmp/verify_microapp_inspect_pobj.XXXXXX.log)"
UAPP_LOG="$(mktemp /tmp/verify_microapp_inspect_uapp.XXXXXX.log)"
POBJ_V5_LOG="$(mktemp /tmp/verify_microapp_inspect_pobj_v5.XXXXXX.log)"
POBJ_V6_LOG="$(mktemp /tmp/verify_microapp_inspect_pobj_v6.XXXXXX.log)"
UAPP_V1_LOG="$(mktemp /tmp/verify_microapp_inspect_uapp_v1.XXXXXX.log)"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export MICROAPP_TARGET_ARCH
export TARGET_GCC

cleanup() {
    rm -f "$POBJ" "$UAPP" "$LEGACY_POBJ_V5" "$LEGACY_POBJ_V6" "$LEGACY_UAPP_V1" \
        "$POBJ_LOG" "$UAPP_LOG" "$POBJ_V5_LOG" "$POBJ_V6_LOG" "$UAPP_V1_LOG"
}
trap cleanup EXIT

"$ROOT_DIR/bin/uya" build --app microapp examples/microapp/microcontainer_hello_source.uya -o "$POBJ" >/tmp/verify_microapp_inspect_build_pobj.log 2>&1
"$ROOT_DIR/bin/uya" build --app microapp examples/microapp/microcontainer_hello_source.uya -o "$UAPP" >/tmp/verify_microapp_inspect_build_uapp.log 2>&1

python3 - "$POBJ" "$LEGACY_POBJ_V5" "$LEGACY_POBJ_V6" "$LEGACY_UAPP_V1" <<'PY'
from pathlib import Path
import hashlib
import struct
import sys

src = Path(sys.argv[1]).read_bytes()
out_v5 = Path(sys.argv[2])
out_v6 = Path(sys.argv[3])
out_uapp_v1 = Path(sys.argv[4])

magic = src[:4]
version = int.from_bytes(src[4:6], "little")
assert magic == b"POBJ", magic
assert version == 8, version

flags = src[6:8]
target_arch = src[8:12]
build_mode = src[12:16]
required_caps = src[16:20]
entry_offset = src[20:24]
source_path_len = int.from_bytes(src[24:28], "little")
code_len = int.from_bytes(src[28:32], "little")
rodata_len = int.from_bytes(src[32:36], "little")
reloc_count = src[36:40]
profile_id = src[40:44]
image_flags = src[44:48]
bridge_kind = src[48:52]
bss_size = src[52:56]
stack_hint = src[56:60]
data_len = int.from_bytes(src[60:64], "little")
reloc_len = src[64:68]
code_va_v8 = int.from_bytes(src[72:76], "little")
rodata_va_v8 = int.from_bytes(src[76:80], "little")
data_va_v8 = int.from_bytes(src[80:84], "little")

payload = src[84:]
source_path = payload[:source_path_len]
code = payload[source_path_len:source_path_len + code_len]
rodata = payload[source_path_len + code_len:source_path_len + code_len + rodata_len]
data = payload[source_path_len + code_len + rodata_len:source_path_len + code_len + rodata_len + data_len]
relocs = payload[source_path_len + code_len + rodata_len + data_len:source_path_len + code_len + rodata_len + data_len + int.from_bytes(reloc_len, "little")]

v5 = bytearray()
v5 += b"POBJ"
v5 += (5).to_bytes(2, "little")
v5 += flags
v5 += target_arch
v5 += build_mode
v5 += required_caps
v5 += entry_offset
v5 += source_path_len.to_bytes(4, "little")
v5 += code_len.to_bytes(4, "little")
v5 += rodata_len.to_bytes(4, "little")
v5 += (0).to_bytes(4, "little")
v5 += source_path
v5 += code
v5 += rodata
out_v5.write_bytes(v5)

v6 = bytearray()
v6 += b"POBJ"
v6 += (6).to_bytes(2, "little")
v6 += flags
v6 += target_arch
v6 += build_mode
v6 += required_caps
v6 += entry_offset
v6 += source_path_len.to_bytes(4, "little")
v6 += code_len.to_bytes(4, "little")
v6 += rodata_len.to_bytes(4, "little")
v6 += reloc_count
v6 += profile_id
v6 += image_flags
v6 += bridge_kind
v6 += bss_size
v6 += stack_hint
v6 += data_len.to_bytes(4, "little")
v6 += reloc_len
v6 += source_path
v6 += code
v6 += rodata
v6 += data
if int.from_bytes(reloc_len, "little") > 0:
    code_va_v6 = 176
    rodata_va_v6 = code_va_v6 + code_len
    data_va_v6 = rodata_va_v6 + data_len
    def map_va(va: int) -> int:
        if code_va_v8 <= va < code_va_v8 + code_len:
            return code_va_v6 + (va - code_va_v8)
        if rodata_va_v8 <= va < rodata_va_v8 + rodata_len:
            return rodata_va_v6 + (va - rodata_va_v8)
        if data_va_v8 <= va < data_va_v8 + data_len:
            return data_va_v6 + (va - data_va_v8)
        raise ValueError(f"va out of mapped image: {va:#x}")
    mapped_relocs = bytearray()
    raw_reloc_len = int.from_bytes(reloc_len, "little")
    for off in range(0, raw_reloc_len, 8):
        target_va = int.from_bytes(relocs[off:off + 4], "little")
        value_va = int.from_bytes(relocs[off + 4:off + 8], "little")
        mapped_relocs += map_va(target_va).to_bytes(4, "little")
        mapped_relocs += map_va(value_va).to_bytes(4, "little")
    v6 += mapped_relocs
else:
    v6 += relocs
out_v6.write_bytes(v6)

header_size = 96
legacy_code = bytes([115, 0, 0, 0])
legacy_rodata = b"legacy-v1\0"
total = header_size + len(legacy_code) + len(legacy_rodata)
u = bytearray(total)
struct.pack_into("<I", u, 0, 1431912704)
struct.pack_into("<H", u, 4, 1)
struct.pack_into("<H", u, 6, 1)
struct.pack_into("<I", u, 8, total)
struct.pack_into("<I", u, 12, 0)
struct.pack_into("<I", u, 16, len(legacy_code))
struct.pack_into("<I", u, 20, len(legacy_rodata))
struct.pack_into("<I", u, 24, 0)
struct.pack_into("<I", u, 60, 0)
u[64] = 1
u[65] = 1
u[header_size:header_size + len(legacy_code)] = legacy_code
u[header_size + len(legacy_code):header_size + len(legacy_code) + len(legacy_rodata)] = legacy_rodata
digest = hashlib.sha256(u).digest()
u[28:60] = digest
out_uapp_v1.write_bytes(u)
PY

"$ROOT_DIR/bin/uya" inspect-image "$POBJ" >"$POBJ_LOG" 2>&1
"$ROOT_DIR/bin/uya" inspect-image "$UAPP" >"$UAPP_LOG" 2>&1
"$ROOT_DIR/bin/uya" inspect-image "$LEGACY_POBJ_V5" >"$POBJ_V5_LOG" 2>&1
"$ROOT_DIR/bin/uya" inspect-image "$LEGACY_POBJ_V6" >"$POBJ_V6_LOG" 2>&1
"$ROOT_DIR/bin/uya" inspect-image "$LEGACY_UAPP_V1" >"$UAPP_V1_LOG" 2>&1

grep -q '^kind=pobj$' "$POBJ_LOG"
grep -q '^version=8$' "$POBJ_LOG"
grep -q '^target_arch=x86_64$' "$POBJ_LOG"
grep -q '^profile=linux_x86_64_hardvm$' "$POBJ_LOG"
grep -q '^bridge=call_gate$' "$POBJ_LOG"
grep -Eq '^reloc_count=[0-9]+$' "$POBJ_LOG"
grep -Eq '^reloc_size=[0-9]+$' "$POBJ_LOG"

grep -q '^kind=uapp$' "$UAPP_LOG"
grep -q '^validated=yes$' "$UAPP_LOG"
grep -q '^target_arch=x86_64$' "$UAPP_LOG"
grep -q '^profile=linux_x86_64_hardvm$' "$UAPP_LOG"
grep -q '^bridge=call_gate$' "$UAPP_LOG"
grep -Eq '^reloc_count=[0-9]+$' "$UAPP_LOG"

grep -q '^kind=pobj$' "$POBJ_V5_LOG"
grep -q '^version=5$' "$POBJ_V5_LOG"
grep -q '^target_arch=x86_64$' "$POBJ_V5_LOG"
grep -q '^reloc_count=0$' "$POBJ_V5_LOG"

grep -q '^kind=pobj$' "$POBJ_V6_LOG"
grep -q '^version=6$' "$POBJ_V6_LOG"
grep -q '^profile=linux_x86_64_hardvm$' "$POBJ_V6_LOG"
grep -Eq '^reloc_count=[0-9]+$' "$POBJ_V6_LOG"

grep -q '^kind=uapp$' "$UAPP_V1_LOG"
grep -q '^validated=yes$' "$UAPP_V1_LOG"
grep -q '^format_version=1$' "$UAPP_V1_LOG"
grep -q '^target_arch=rv32$' "$UAPP_V1_LOG"

echo "microapp inspect-image ok"
