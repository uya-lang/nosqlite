#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_portable_sources.XXXXXX)"

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

assert_no_host_symbol_leak() {
    local out_c="$1"
    local rel="$2"

    if grep -F -q 'uya_microapp_syscall' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应回退到历史 uya_microapp_syscall helper: $rel" "$out_c"
    fi
    if grep -F -q 'UYA_HOST_SYS_write' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接内嵌宿主 SYS_write shim: $rel" "$out_c"
    fi
    if grep -F -q 'UYA_HOST_SYS_mmap' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接内嵌宿主 SYS_mmap shim: $rel" "$out_c"
    fi
    if grep -F -q 'posix_memalign(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 posix_memalign: $rel" "$out_c"
    fi
    if grep -F -q 'sched_yield(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 sched_yield: $rel" "$out_c"
    fi
    if grep -F -q 'gettimeofday(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 gettimeofday: $rel" "$out_c"
    fi
    if grep -F -q 'malloc(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 malloc: $rel" "$out_c"
    fi
    if grep -F -q 'free(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 free: $rel" "$out_c"
    fi
    if grep -F -q 'fprintf(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 fprintf: $rel" "$out_c"
    fi
    if grep -F -q 'getenv(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 getenv: $rel" "$out_c"
    fi
    if grep -F -q 'abort(' "$out_c"; then
        dump_and_fail "portable microapp 生成代码不应直接依赖宿主 abort: $rel" "$out_c"
    fi
}

PORTABLE_SOURCES=(
    "examples/microapp/microcontainer_alloc_yield_source.uya"
    "examples/microapp/microcontainer_bss_source.uya"
    "examples/microapp/microcontainer_hello_source.uya"
    "examples/microapp/microcontainer_reloc_source.uya"
    "examples/microapp/microcontainer_reloc_data_source.uya"
    "examples/microapp/microcontainer_time_source.uya"
    "tests/fixtures/microapp/test_microapp_mmu_codegen.uya"
    "tests/fixtures/microapp/test_microapp_mmu_runtime.uya"
    "tests/fixtures/microapp/test_std_microapp_alloc_yield.uya"
    "tests/fixtures/microapp/test_std_microapp_bss_runtime.uya"
    "tests/fixtures/microapp/test_std_microapp_exit_nonzero.uya"
    "tests/fixtures/microapp/test_std_microapp_fault_segv.uya"
    "tests/fixtures/microapp/test_std_microapp_io_codegen.uya"
    "tests/fixtures/microapp/test_std_microapp_time_runtime.uya"
)

for rel in "${PORTABLE_SOURCES[@]}"; do
    src="$ROOT_DIR/$rel"
    if [ ! -f "$src" ]; then
        dump_and_fail "portable microapp 源码不存在: $rel"
    fi

    if grep -Eq '^[[:space:]]*use[[:space:]]+libc(\.|;|[[:space:]])' "$src"; then
        dump_and_fail "portable microapp 源码不应直接 use libc: $rel" "$src"
    fi
    if grep -Eq '^[[:space:]]*use[[:space:]]+std\.time(\.|;|[[:space:]])' "$src"; then
        dump_and_fail "portable microapp 源码不应直接 use std.time: $rel" "$src"
    fi

    out_c="$TMP_DIR/$(basename "$rel" .uya).c"
    build_log="$TMP_DIR/$(basename "$rel" .uya).log"
    if ! "$ROOT_DIR/bin/uya" build --app microapp "$src" -o "$out_c" >"$build_log" 2>&1; then
        dump_and_fail "portable microapp 源码应能在 --app microapp 下通过编译: $rel" "$build_log"
    fi
    if [ ! -s "$out_c" ]; then
        dump_and_fail "portable microapp 编译未生成输出: $rel" "$build_log"
    fi
    assert_no_host_symbol_leak "$out_c" "$rel"
done

echo "microapp portable sources ok"
