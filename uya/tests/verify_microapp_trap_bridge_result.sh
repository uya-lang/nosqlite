#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UAPP_PATH="$(mktemp /tmp/verify_microapp_trap_bridge.XXXXXX.uapp)"
LOADER_LOG="$(mktemp /tmp/verify_microapp_trap_bridge.XXXXXX.log)"

cleanup() {
    rm -f "$UAPP_PATH" "$LOADER_LOG"
}
trap cleanup EXIT

dump_log_and_fail() {
    local title="$1"
    local path="$2"
    echo "✗ $title"
    if [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

UAPP_TMP_PATH="$UAPP_PATH" python3 - <<'PY'
import os
from hashlib import sha256
from pathlib import Path

IMAGE_MAGIC = 1431912704
IMAGE_HEADER_SIZE = 176
OFF_MAGIC = 0
OFF_FORMAT_VER = 4
OFF_API_VER = 6
OFF_IMAGE_SIZE = 8
OFF_ENTRY = 12
OFF_CODE_SIZE = 16
OFF_RODATA_SIZE = 20
OFF_RELOC_COUNT = 24
OFF_SHA256 = 28
OFF_CAPS = 60
OFF_BUILD_MODE = 64
OFF_TARGET_ARCH = 65
OFF_DATA_SIZE = 96
OFF_BSS_SIZE = 100
OFF_STACK_HINT = 104
OFF_CODE_OFF = 108
OFF_RODATA_OFF = 112
OFF_DATA_OFF = 116
OFF_RELOC_OFF = 120
OFF_PROFILE = 124
OFF_FLAGS = 128
OFF_BRIDGE_KIND = 132
OFF_ENTRY_VA = 136
OFF_CODE_VA = 140
OFF_RODATA_VA = 144
OFF_DATA_VA = 148

code = bytes([115, 0, 0, 0])  # rv32 ecall
total = IMAGE_HEADER_SIZE + len(code)
buf = bytearray(total)

def w16(off: int, val: int) -> None:
    buf[off:off + 2] = val.to_bytes(2, "little")

def w32(off: int, val: int) -> None:
    buf[off:off + 4] = val.to_bytes(4, "little")

w32(OFF_MAGIC, IMAGE_MAGIC)
w16(OFF_FORMAT_VER, 2)
w16(OFF_API_VER, 1)
w32(OFF_IMAGE_SIZE, total)
w32(OFF_ENTRY, 0)
w32(OFF_CODE_SIZE, len(code))
w32(OFF_RODATA_SIZE, 0)
w32(OFF_RELOC_COUNT, 0)
w32(OFF_CAPS, 0)
buf[OFF_BUILD_MODE] = 1
buf[OFF_TARGET_ARCH] = 1
w32(OFF_DATA_SIZE, 0)
w32(OFF_BSS_SIZE, 0)
w32(OFF_STACK_HINT, 0)
w32(OFF_CODE_OFF, IMAGE_HEADER_SIZE)
w32(OFF_RODATA_OFF, IMAGE_HEADER_SIZE + len(code))
w32(OFF_DATA_OFF, IMAGE_HEADER_SIZE + len(code))
w32(OFF_RELOC_OFF, IMAGE_HEADER_SIZE + len(code))
w32(OFF_PROFILE, 0)
w32(OFF_FLAGS, 0)
buf[OFF_BRIDGE_KIND] = 1
w32(OFF_ENTRY_VA, IMAGE_HEADER_SIZE)
w32(OFF_CODE_VA, IMAGE_HEADER_SIZE)
w32(OFF_RODATA_VA, IMAGE_HEADER_SIZE + len(code))
w32(OFF_DATA_VA, IMAGE_HEADER_SIZE + len(code))
buf[IMAGE_HEADER_SIZE:IMAGE_HEADER_SIZE + len(code)] = code
digest = sha256(buf).digest()
buf[OFF_SHA256:OFF_SHA256 + len(digest)] = digest

Path(os.environ["UAPP_TMP_PATH"]).write_bytes(buf)
PY

"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$UAPP_PATH" >"$LOADER_LOG" 2>&1 || dump_log_and_fail "trap bridge loader run 失败" "$LOADER_LOG"

grep -a -q '\[microapp loader\] payload result=validated bridge=trap target=rv32' "$LOADER_LOG" || dump_log_and_fail "loader 未输出 trap validated 结果" "$LOADER_LOG"
grep -a -q '\[microapp loader\] trap bridge validated without native execution' "$LOADER_LOG" || dump_log_and_fail "loader 未解释 trap bridge 仅完成 validated" "$LOADER_LOG"
grep -a -q '\[microapp loader\] done' "$LOADER_LOG" || dump_log_and_fail "trap bridge 路径未输出 done" "$LOADER_LOG"
if grep -a -q '\[microapp loader\] no execution path' "$LOADER_LOG"; then
    dump_log_and_fail "trap bridge 路径不应再走 unwired 诊断" "$LOADER_LOG"
fi

echo "microapp trap bridge result ok"
