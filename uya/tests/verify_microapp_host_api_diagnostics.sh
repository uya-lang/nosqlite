#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_host_api_diag.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_compile_fail_with() {
    local source="$1"
    local output="$2"
    shift 2
    local log="$TMP_DIR/$(basename "$source" .uya).log"
    if "$ROOT_DIR/bin/uya" --c99 --safety-proof --app microapp "$ROOT_DIR/$source" -o "$output" >"$log" 2>&1; then
        echo "✗ 预期编译失败，但编译成功: $source"
        echo "--- $log ---"
        cat "$log"
        exit 1
    fi
    for pattern in "$@"; do
        if ! grep -q "$pattern" "$log"; then
            echo "✗ 未命中期望报错: $source :: $pattern"
            echo "--- $log ---"
            cat "$log"
            exit 1
        fi
    done
}

expect_compile_fail_with \
    "tests/error_microapp_mode_host_api_libc.uya" \
    "$TMP_DIR/error_microapp_mode_host_api_libc.c" \
    "E4004" \
    "禁止直接导入宿主 API libc.write_stdout_bytes" \
    "std.microapp.io.write_stdout_bytes"

expect_compile_fail_with \
    "tests/error_microapp_mode_host_api_std_time.uya" \
    "$TMP_DIR/error_microapp_mode_host_api_std_time.c" \
    "E4004" \
    "禁止直接导入宿主 API std.time" \
    "std.microapp.time.unix_millis"

expect_compile_fail_with \
    "tests/error_microapp_mode_host_api_import_only.uya" \
    "$TMP_DIR/error_microapp_mode_host_api_import_only.c" \
    "E4004" \
    "禁止直接导入宿主 API std.time" \
    "std.microapp.time.unix_millis"

echo "microapp host api diagnostics ok"
