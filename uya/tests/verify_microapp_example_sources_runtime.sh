#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_examples_runtime.XXXXXX)"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export TARGET_GCC
export MICROAPP_TARGET_ARCH

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

verify_example() {
    local source_rel="$1"
    local expected="$2"
    local base
    base="$(basename "$source_rel" .uya)"
    local source="$ROOT_DIR/$source_rel"
    local run_log="$TMP_DIR/${base}.run.log"
    local build_log="$TMP_DIR/${base}.build.log"
    local loader_log="$TMP_DIR/${base}.loader.log"
    local uapp="$TMP_DIR/${base}.uapp"

    "$ROOT_DIR/bin/uya" run --app microapp "$source" >"$run_log" 2>&1
    grep -a -q "$expected" "$run_log" || dump_log_and_fail "example run 未输出预期内容: $source_rel" "$run_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$run_log" || dump_log_and_fail "example run 未命中 mapped payload: $source_rel" "$run_log"
    if grep -a -q "\[microapp loader\] launching native payload" "$run_log"; then
        dump_log_and_fail "example run 意外回退 native payload: $source_rel" "$run_log"
    fi

    "$ROOT_DIR/bin/uya" build --app microapp "$source" -o "$uapp" >"$build_log" 2>&1
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$uapp" >"$loader_log" 2>&1
    grep -a -q "$expected" "$loader_log" || dump_log_and_fail "example loader 未输出预期内容: $source_rel" "$loader_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$loader_log" || dump_log_and_fail "example loader 未命中 mapped payload: $source_rel" "$loader_log"
    if grep -a -q "\[microapp loader\] launching native payload" "$loader_log"; then
        dump_log_and_fail "example loader 意外回退 native payload: $source_rel" "$loader_log"
    fi
}

verify_example "examples/microapp/microcontainer_hello_source.uya" "hello microapp"
verify_example "examples/microapp/microcontainer_alloc_yield_source.uya" "alloc yield ok"
verify_example "examples/microapp/microcontainer_time_source.uya" "time ok"
verify_example "examples/microapp/microcontainer_bss_source.uya" "bss ok"
verify_example "examples/microapp/microcontainer_reloc_source.uya" "reloc ok"
verify_example "examples/microapp/microcontainer_reloc_data_source.uya" "reloc64 ok"

echo "microapp example sources runtime ok"
