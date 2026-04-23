#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_profile_matrix.XXXXXX)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

dump_and_fail() {
    local title="$1"
    local path="${2:-}"
    echo "✗ $title"
    if [ -n "$path" ] && [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

pick_first_available() {
    local cmd
    for cmd in "$@"; do
        if [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done
    return 1
}

verify_profile_compile_to_c() {
    local profile="$1"
    local expected_bridge="$2"
    local expected_arch="$3"
    local out_c="$TMP_DIR/${profile}.c"
    local log="$TMP_DIR/${profile}.log"

    if ! "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile "$profile" \
        "$SOURCE" -o "$out_c" >"$log" 2>&1; then
        dump_and_fail "profile matrix 编译失败: $profile" "$log"
    fi
    if [ ! -s "$out_c" ]; then
        dump_and_fail "profile matrix 未生成 C 输出: $profile" "$log"
    fi

    grep -q "信息：microapp active profile=${profile}, bridge=${expected_bridge}," "$log" \
        || dump_and_fail "profile matrix 未命中 profile/bridge 诊断: $profile" "$log"
    grep -q "目标架构=${expected_arch}" "$log" \
        || dump_and_fail "profile matrix 未命中目标架构诊断: $profile" "$log"
}

verify_profile_uapp_contract() {
    local profile="$1"
    local gcc_bin="$2"
    local expected_bridge="$3"
    local expected_arch="$4"
    local uapp="$TMP_DIR/${profile}.uapp"
    local log="$TMP_DIR/${profile}.uapp.log"
    local inspect="$TMP_DIR/${profile}.inspect.log"

    if ! TARGET_GCC="$gcc_bin" "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile "$profile" \
        "$SOURCE" -o "$uapp" >"$log" 2>&1; then
        dump_and_fail "profile matrix ${profile} .uapp 构建失败" "$log"
    fi

    "$ROOT_DIR/bin/uya" inspect-image "$uapp" >"$inspect" 2>&1
    grep -q "^profile=${profile}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 profile" "$inspect"
    grep -q "^bridge=${expected_bridge}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 bridge" "$inspect"
    grep -q "^target_arch=${expected_arch}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 target_arch" "$inspect"
}

verify_profile_uapp_contract_macos_fake() {
    local profile="$1"
    local expected_bridge="$2"
    local expected_arch="$3"
    local fake_gcc="$TMP_DIR/${profile}.fake-gcc"
    local uapp="$TMP_DIR/${profile}.uapp"
    local log="$TMP_DIR/${profile}.uapp.log"
    local inspect="$TMP_DIR/${profile}.inspect.log"

    if ! command -v llvm-mc >/dev/null 2>&1; then
        return 0
    fi

    cat >"$fake_gcc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o)
            out="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$out" ]; then
    echo "missing -o" >&2
    exit 1
fi

asm="$(mktemp /tmp/uya-fake-macos-arm64.XXXXXX.s)"
cat >"$asm" <<'ASM'
.text
.globl _main_main
_main_main:
    adrp x0, _msg@PAGE
    add x0, x0, _msg@PAGEOFF
    ret

.section __TEXT,__cstring
_msg:
    .asciz "hello profile matrix"

.section __DATA,__data
_data_ptr:
    .quad _msg
ASM

llvm-mc -triple=arm64-apple-macos -filetype=obj -o "$out" "$asm"
rm -f "$asm"
EOF
    chmod +x "$fake_gcc"

    if ! MICROAPP_TARGET_GCC="$fake_gcc" "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile "$profile" \
        "$SOURCE" -o "$uapp" >"$log" 2>&1; then
        dump_and_fail "profile matrix ${profile} .uapp 构建失败" "$log"
    fi

    "$ROOT_DIR/bin/uya" inspect-image "$uapp" >"$inspect" 2>&1
    grep -q "^profile=${profile}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 profile" "$inspect"
    grep -q "^bridge=${expected_bridge}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 bridge" "$inspect"
    grep -q "^target_arch=${expected_arch}$" "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未命中 target_arch" "$inspect"
    grep -Eq '^reloc_count=[1-9][0-9]*$' "$inspect" \
        || dump_and_fail "profile matrix ${profile} .uapp inspect 未体现 relocation" "$inspect"
}

verify_profile_compile_to_c "linux_x86_64_hardvm" "call_gate" "x86_64"
verify_profile_compile_to_c "linux_aarch64_hardvm" "call_gate" "aarch64"
verify_profile_compile_to_c "macos_arm64_hardvm" "call_gate" "aarch64"
verify_profile_compile_to_c "rv32_baremetal_softvm" "trap" "rv32"
verify_profile_compile_to_c "xtensa_baremetal_softvm" "trap" "xtensa"

X86_UAPP="$TMP_DIR/linux_x86_64_hardvm.uapp"
X86_INSPECT="$TMP_DIR/linux_x86_64_hardvm.inspect.log"
if command -v x86_64-linux-gnu-gcc >/dev/null 2>&1; then
    if ! TARGET_GCC=x86_64-linux-gnu-gcc \
        "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile linux_x86_64_hardvm \
        "$SOURCE" -o "$X86_UAPP" >"$TMP_DIR/linux_x86_64_hardvm.uapp.log" 2>&1; then
        dump_and_fail "profile matrix x86_64 .uapp 构建失败" "$TMP_DIR/linux_x86_64_hardvm.uapp.log"
    fi

    "$ROOT_DIR/bin/uya" inspect-image "$X86_UAPP" >"$X86_INSPECT" 2>&1
    grep -q '^profile=linux_x86_64_hardvm$' "$X86_INSPECT" \
        || dump_and_fail "profile matrix x86_64 .uapp inspect 未命中 profile" "$X86_INSPECT"
    grep -q '^bridge=call_gate$' "$X86_INSPECT" \
        || dump_and_fail "profile matrix x86_64 .uapp inspect 未命中 bridge" "$X86_INSPECT"
fi

AARCH64_GCC="$(pick_first_available aarch64-linux-gnu-gcc || true)"
if [ -n "$AARCH64_GCC" ]; then
    verify_profile_uapp_contract "linux_aarch64_hardvm" "$AARCH64_GCC" "call_gate" "aarch64"
fi

verify_profile_uapp_contract_macos_fake "macos_arm64_hardvm" "call_gate" "aarch64"

RV32_GCC="$(pick_first_available riscv32-unknown-elf-gcc riscv64-unknown-elf-gcc || true)"
if [ -n "$RV32_GCC" ]; then
    verify_profile_uapp_contract "rv32_baremetal_softvm" "$RV32_GCC" "trap" "rv32"
fi

XTENSA_GCC="$(pick_first_available xtensa-unknown-elf-gcc xtensa-esp32-elf-gcc || true)"
if [ -n "$XTENSA_GCC" ]; then
    verify_profile_uapp_contract "xtensa_baremetal_softvm" "$XTENSA_GCC" "trap" "xtensa"
fi

echo "microapp profile example matrix ok"
