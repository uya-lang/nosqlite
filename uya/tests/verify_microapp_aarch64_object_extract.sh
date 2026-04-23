#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_aarch64_object_extract.XXXXXX.dir)"

cleanup() {
    rm -rf "$TMP_DIR"
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

if ! command -v llvm-mc >/dev/null 2>&1; then
    echo "microapp aarch64 object extract skipped (missing llvm-mc)"
    exit 0
fi

make_fake_gcc() {
    local name="$1"
    local asm_body="$2"
    local path="$TMP_DIR/$name"
    cat >"$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

out=""
while [ "\$#" -gt 0 ]; do
    case "\$1" in
        -o)
            out="\$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "\$out" ]; then
    echo "missing -o" >&2
    exit 1
fi

asm="\$(mktemp /tmp/uya-fake-aarch64.XXXXXX.s)"
cat >"\$asm" <<'ASM'
$asm_body
ASM

llvm-mc -triple=aarch64-linux-gnu -filetype=obj -o "\$out" "\$asm"
rm -f "\$asm"
EOF
    chmod +x "$path"
}

run_case() {
    local name="$1"
    local expected_reloc_count_pattern="$2"
    local fake_gcc="$TMP_DIR/$name"
    local uapp="$TMP_DIR/$name.uapp"
    local build_log="$TMP_DIR/$name.build.log"
    local inspect_log="$TMP_DIR/$name.inspect.log"

    MICROAPP_TARGET_GCC="$fake_gcc" \
        "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile linux_aarch64_hardvm \
        "$SOURCE" -o "$uapp" >"$build_log" 2>&1 \
        || dump_log_and_fail "aarch64 object extract 构建失败: $name" "$build_log"

    grep -q "信息：microapp 目标 gcc 对象产物：" "$build_log" \
        || dump_log_and_fail "aarch64 object extract 未命中对象产物诊断: $name" "$build_log"
    grep -q "信息：microapp 对象提取 code=" "$build_log" \
        || dump_log_and_fail "aarch64 object extract 未命中对象提取诊断: $name" "$build_log"
    if grep -q "信息：microapp 目标 gcc 链接：" "$build_log"; then
        dump_log_and_fail "aarch64 object extract 不应再链接中间 ELF: $name" "$build_log"
    fi
    if grep -q "信息：microapp 内部 ELF 提取：" "$build_log"; then
        dump_log_and_fail "aarch64 object extract 不应回退到内部 ELF 提取: $name" "$build_log"
    fi

    "$ROOT_DIR/bin/uya" inspect-image "$uapp" >"$inspect_log" 2>&1
    grep -q '^profile=linux_aarch64_hardvm$' "$inspect_log" \
        || dump_log_and_fail "aarch64 object extract inspect 未命中 profile: $name" "$inspect_log"
    grep -q '^target_arch=aarch64$' "$inspect_log" \
        || dump_log_and_fail "aarch64 object extract inspect 未命中 aarch64: $name" "$inspect_log"
    grep -Eq "^reloc_count=${expected_reloc_count_pattern}$" "$inspect_log" \
        || dump_log_and_fail "aarch64 object extract inspect reloc_count 异常: $name" "$inspect_log"
}

make_fake_gcc "case_call26" '.text
.globl main_main
.globl ext_helper
.type main_main,%function
.type ext_helper,%function
main_main:
    bl ext_helper
    ret
.section .text.helper,"ax"
ext_helper:
    ret'

make_fake_gcc "case_jump26" '.text
.globl main_main
.globl ext_jump
.type main_main,%function
.type ext_jump,%function
main_main:
    b ext_jump
    ret
.section .text.jump,"ax"
ext_jump:
    ret'

make_fake_gcc "case_adr_lo21" '.text
.globl main_main
.type main_main,%function
main_main:
    adr x0, msg
    ret
.section .rodata
.balign 8
msg:
    .asciz "hi"'

make_fake_gcc "case_ld_prel_lo19" '.text
.globl main_main
.type main_main,%function
main_main:
    ldr x0, litptr
    ret
.section .rodata
.balign 8
litptr:
    .xword 0x1122334455667788'

make_fake_gcc "case_ldst_abs64" '.text
.globl main_main
.type main_main,%function
main_main:
    adrp x0, msg
    ldr x1, [x0, #:lo12:msg]
    ret
.section .rodata
.balign 8
msg:
    .xword 0x1122334455667788
.section .data
.balign 8
data_ptr:
    .xword msg'

make_fake_gcc "case_ldst32" '.text
.globl main_main
.type main_main,%function
main_main:
    adrp x0, msg
    ldr w1, [x0, #:lo12:msg]
    ret
.section .rodata
.balign 4
msg:
    .word 0x11223344'

make_fake_gcc "case_ldst8" '.text
.globl main_main
.type main_main,%function
main_main:
    adrp x0, msg
    ldrb w1, [x0, #:lo12:msg]
    ret
.section .rodata
msg:
    .byte 0x7f'

make_fake_gcc "case_ldst16" '.text
.globl main_main
.type main_main,%function
main_main:
    adrp x0, msg
    ldrh w1, [x0, #:lo12:msg]
    ret
.section .rodata
.balign 2
msg:
    .hword 0x1234'

make_fake_gcc "case_ldst128" '.text
.globl main_main
.type main_main,%function
main_main:
    adrp x0, msg
    ldr q1, [x0, #:lo12:msg]
    ret
.section .rodata
.balign 16
msg:
    .quad 0x1122334455667788
    .quad 0x99aabbccddeeff00'

run_case "case_call26" '0'
run_case "case_jump26" '0'
run_case "case_adr_lo21" '0'
run_case "case_ld_prel_lo19" '0'
run_case "case_ldst_abs64" '[1-9][0-9]*'
run_case "case_ldst32" '0'
run_case "case_ldst8" '0'
run_case "case_ldst16" '0'
run_case "case_ldst128" '0'

echo "microapp aarch64 object extract ok"
