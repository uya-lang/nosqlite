#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES_DIR="$ROOT_DIR/examples/microapp"

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
    "microcontainer_alloc_yield_source.uya"
    "microcontainer_bss_source.uya"
    "microcontainer_hello_source.uya"
    "microcontainer_reloc_data_source.uya"
    "microcontainer_reloc_source.uya"
    "microcontainer_time_source.uya"
)

HOST_SIDE_TOOLS=(
    "microcontainer_hello.uya"
    "microcontainer_hello_build.uya"
    "microcontainer_hello_load.uya"
)

for name in "${PORTABLE_SOURCES[@]}"; do
    path="$EXAMPLES_DIR/$name"
    if [ ! -f "$path" ]; then
        dump_and_fail "portable source 示例不存在: $name"
    fi
    if grep -Eq '^[[:space:]]*use[[:space:]]+libc(\.|;|[[:space:]])' "$path"; then
        dump_and_fail "portable source 示例不应直接 use libc: $name" "$path"
    fi
    if grep -Eq '^[[:space:]]*use[[:space:]]+std\.time(\.|;|[[:space:]])' "$path"; then
        dump_and_fail "portable source 示例不应直接 use std.time: $name" "$path"
    fi
done

for name in "${HOST_SIDE_TOOLS[@]}"; do
    path="$EXAMPLES_DIR/$name"
    if [ ! -f "$path" ]; then
        dump_and_fail "host-side tool 示例不存在: $name"
    fi
done

if ! grep -Eq '^[[:space:]]*use[[:space:]]+libc(\.|;|[[:space:]])|^[[:space:]]*use[[:space:]]+kernel(\.|;|[[:space:]])' "$EXAMPLES_DIR/microcontainer_hello.uya"; then
    dump_and_fail "legacy microcontainer_hello 示例应保留宿主/内核耦合属性" "$EXAMPLES_DIR/microcontainer_hello.uya"
fi

if ! grep -Eq '^[[:space:]]*use[[:space:]]+libc(\.|;|[[:space:]])' "$EXAMPLES_DIR/microcontainer_hello_build.uya"; then
    dump_and_fail "microcontainer_hello_build.uya 应明确是 host-side build 工具示例" "$EXAMPLES_DIR/microcontainer_hello_build.uya"
fi

if ! grep -Eq 'microapp_hosted_loader_run' "$EXAMPLES_DIR/microcontainer_hello_load.uya"; then
    dump_and_fail "microcontainer_hello_load.uya 应明确走 hosted loader 工具路径" "$EXAMPLES_DIR/microcontainer_hello_load.uya"
fi

README_PATH="$ROOT_DIR/docs/microcontainer/README.md"
if ! grep -F -q 'examples/microapp/microcontainer_hello_build.uya' "$README_PATH"; then
    dump_and_fail "README 未声明 host-side build/load 工具示例边界" "$README_PATH"
fi
if ! grep -F -q '不属于 portable source 子集' "$README_PATH"; then
    dump_and_fail "README 未明确 host-side build/load 示例不属于 portable source 子集" "$README_PATH"
fi

echo "microapp example boundary ok"
