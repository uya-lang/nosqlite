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

PORTABLE_SOURCES=(
    "examples/microapp/microcontainer_alloc_yield_source.uya"
    "examples/microapp/microcontainer_bss_source.uya"
    "examples/microapp/microcontainer_hello_source.uya"
    "examples/microapp/microcontainer_reloc_source.uya"
    "examples/microapp/microcontainer_reloc_data_source.uya"
    "examples/microapp/microcontainer_time_source.uya"
    "tests/fixtures/microapp/test_std_microapp_alloc_yield.uya"
    "tests/fixtures/microapp/test_std_microapp_bss_runtime.uya"
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
done

echo "microapp portable sources ok"
