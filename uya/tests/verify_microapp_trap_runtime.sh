#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_UAPP="$(mktemp /tmp/verify_microapp_trap_runtime.XXXXXX.uapp)"
EXIT_UAPP="$(mktemp /tmp/verify_microapp_trap_exit.XXXXXX.uapp)"
RUN_LOG="$(mktemp /tmp/verify_microapp_trap_runtime.XXXXXX.log)"
EXIT_LOG="$(mktemp /tmp/verify_microapp_trap_exit.XXXXXX.log)"

cleanup() {
    rm -f "$RUN_UAPP" "$EXIT_UAPP" "$RUN_LOG" "$EXIT_LOG"
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

python3 - "$RUN_UAPP" "$EXIT_UAPP" <<'PY'
from hashlib import sha256
from pathlib import Path
import struct
import sys

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

SYS_PRINT = 1
SYS_YIELD = 4

def rv32_addi(rd: int, rs1: int, imm: int) -> int:
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((rd & 0x1F) << 7) | 0x13

def rv32_ecall() -> int:
    return 0x00000073

def rv32_ebreak() -> int:
    return 0x00100073

def write_image(path: str, code_words: list[int], rodata: bytes) -> None:
    code = b"".join(struct.pack("<I", w) for w in code_words)
    total = IMAGE_HEADER_SIZE + len(code) + len(rodata)
    buf = bytearray(total)
    struct.pack_into("<I", buf, OFF_MAGIC, IMAGE_MAGIC)
    struct.pack_into("<H", buf, OFF_FORMAT_VER, 2)
    struct.pack_into("<H", buf, OFF_API_VER, 1)
    struct.pack_into("<I", buf, OFF_IMAGE_SIZE, total)
    struct.pack_into("<I", buf, OFF_ENTRY, 0)
    struct.pack_into("<I", buf, OFF_CODE_SIZE, len(code))
    struct.pack_into("<I", buf, OFF_RODATA_SIZE, len(rodata))
    struct.pack_into("<I", buf, OFF_RELOC_COUNT, 0)
    struct.pack_into("<I", buf, OFF_CAPS, 0)
    buf[OFF_BUILD_MODE] = 1
    buf[OFF_TARGET_ARCH] = 1
    struct.pack_into("<I", buf, OFF_DATA_SIZE, 0)
    struct.pack_into("<I", buf, OFF_BSS_SIZE, 0)
    struct.pack_into("<I", buf, OFF_STACK_HINT, 0)
    struct.pack_into("<I", buf, OFF_CODE_OFF, IMAGE_HEADER_SIZE)
    struct.pack_into("<I", buf, OFF_RODATA_OFF, IMAGE_HEADER_SIZE + len(code))
    struct.pack_into("<I", buf, OFF_DATA_OFF, IMAGE_HEADER_SIZE + len(code) + len(rodata))
    struct.pack_into("<I", buf, OFF_RELOC_OFF, IMAGE_HEADER_SIZE + len(code) + len(rodata))
    struct.pack_into("<I", buf, OFF_PROFILE, 3)
    struct.pack_into("<I", buf, OFF_FLAGS, 0)
    buf[OFF_BRIDGE_KIND] = 1
    struct.pack_into("<I", buf, OFF_ENTRY_VA, IMAGE_HEADER_SIZE)
    struct.pack_into("<I", buf, OFF_CODE_VA, IMAGE_HEADER_SIZE)
    struct.pack_into("<I", buf, OFF_RODATA_VA, IMAGE_HEADER_SIZE + len(code))
    struct.pack_into("<I", buf, OFF_DATA_VA, IMAGE_HEADER_SIZE + len(code) + len(rodata))
    buf[IMAGE_HEADER_SIZE:IMAGE_HEADER_SIZE + len(code)] = code
    buf[IMAGE_HEADER_SIZE + len(code):IMAGE_HEADER_SIZE + len(code) + len(rodata)] = rodata
    digest = sha256(buf).digest()
    buf[OFF_SHA256:OFF_SHA256 + len(digest)] = digest
    Path(path).write_bytes(buf)

run_ro = b"trap runtime ok\n"
run_code = [
    rv32_addi(10, 0, IMAGE_HEADER_SIZE + 9 * 4),
    rv32_addi(11, 0, len(run_ro)),
    rv32_addi(17, 0, SYS_PRINT),
    rv32_ecall(),
    rv32_addi(10, 0, 0),
    rv32_addi(11, 0, 0),
    rv32_addi(17, 0, SYS_YIELD),
    rv32_ecall(),
    rv32_ebreak(),
]
write_image(sys.argv[1], run_code, run_ro)

exit_code = [
    rv32_addi(10, 0, 7),
    rv32_ebreak(),
]
write_image(sys.argv[2], exit_code, b"")
PY

"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$RUN_UAPP" >"$RUN_LOG" 2>&1 || dump_log_and_fail "trap runtime loader run 失败" "$RUN_LOG"
grep -a -q "trap runtime ok" "$RUN_LOG" || dump_log_and_fail "trap runtime 未输出预期文本" "$RUN_LOG"
grep -a -q "\[microapp loader\] executed trap payload" "$RUN_LOG" || dump_log_and_fail "trap runtime 未命中 trap payload 执行分支" "$RUN_LOG"
grep -a -q "\[microapp loader\] payload result=ok" "$RUN_LOG" || dump_log_and_fail "trap runtime 未输出统一 ok result" "$RUN_LOG"

set +e
"$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$EXIT_UAPP" >"$EXIT_LOG" 2>&1
exit_status=$?
set -e
if [ "$exit_status" -ne 7 ]; then
    dump_log_and_fail "trap runtime non-zero exit 退出码异常: $exit_status" "$EXIT_LOG"
fi
grep -a -q "\[microapp loader\] executed trap payload" "$EXIT_LOG" || dump_log_and_fail "trap runtime non-zero exit 未命中 trap payload 执行分支" "$EXIT_LOG"
grep -a -q "\[microapp loader\] payload result=exit code=7" "$EXIT_LOG" || dump_log_and_fail "trap runtime non-zero exit 未输出统一 exit result" "$EXIT_LOG"

echo "microapp trap runtime ok"
