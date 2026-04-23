#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_macos_object_extract.XXXXXX.dir)"

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
    echo "microapp macos object extract skipped (missing llvm-mc)"
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

asm="\$(mktemp /tmp/uya-fake-macos-arm64.XXXXXX.s)"
cat >"\$asm" <<'ASM'
$asm_body
ASM

llvm-mc -triple=arm64-apple-macos -filetype=obj -o "\$out" "\$asm"
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
        --microapp-profile macos_arm64_hardvm \
        "$SOURCE" -o "$uapp" >"$build_log" 2>&1 \
        || dump_log_and_fail "macos object extract 构建失败: $name" "$build_log"

    grep -q "信息：microapp 目标 gcc Mach-O 对象产物：" "$build_log" \
        || dump_log_and_fail "macos object extract 未命中 Mach-O 对象产物诊断: $name" "$build_log"
    grep -q "信息：microapp Mach-O 对象提取 code=" "$build_log" \
        || dump_log_and_fail "macos object extract 未命中 Mach-O 对象提取诊断: $name" "$build_log"
    if grep -q "信息：microapp 目标 gcc 链接：" "$build_log"; then
        dump_log_and_fail "macos object extract 不应链接中间 ELF: $name" "$build_log"
    fi
    if grep -q "信息：microapp 内部 ELF 提取：" "$build_log"; then
        dump_log_and_fail "macos object extract 不应回退到内部 ELF 提取: $name" "$build_log"
    fi

    "$ROOT_DIR/bin/uya" inspect-image "$uapp" >"$inspect_log" 2>&1
    grep -q '^profile=macos_arm64_hardvm$' "$inspect_log" \
        || dump_log_and_fail "macos object extract inspect 未命中 profile: $name" "$inspect_log"
    grep -q '^target_arch=aarch64$' "$inspect_log" \
        || dump_log_and_fail "macos object extract inspect 未命中 aarch64: $name" "$inspect_log"
    grep -Eq "^reloc_count=${expected_reloc_count_pattern}$" "$inspect_log" \
        || dump_log_and_fail "macos object extract inspect reloc_count 异常: $name" "$inspect_log"
}

make_fake_gcc "case_pageoff_add_unsigned" '.text
.globl _main_main
_main_main:
    adrp x0, _msg@PAGE
    add x0, x0, _msg@PAGEOFF
    ret

.section __TEXT,__cstring
_msg:
    .asciz "hello macos macho"

.section __DATA,__data
_data_ptr:
    .quad _msg'

make_fake_gcc "case_branch26" '.text
.globl _main_main
.globl _ext_helper
_main_main:
    bl _ext_helper
    ret
.section __TEXT,__textx,regular,pure_instructions
_ext_helper:
    ret'

make_fake_gcc "case_pageoff_ldst8" '.text
.globl _main_main
_main_main:
    adrp x0, _msg@PAGE
    ldrb w1, [x0, _msg@PAGEOFF]
    ret
.section __TEXT,__const
_msg:
    .byte 0x7f'

make_fake_gcc "case_pageoff_ldst128" '.text
.globl _main_main
_main_main:
    adrp x0, _msg@PAGE
    ldr q1, [x0, _msg@PAGEOFF]
    ret
.section __TEXT,__const
.balign 16
_msg:
    .quad 1
    .quad 2'

run_case "case_pageoff_add_unsigned" '[1-9][0-9]*'
run_case "case_branch26" '0'
run_case "case_pageoff_ldst8" '0'
run_case "case_pageoff_ldst128" '0'

echo "microapp macos object extract ok"
