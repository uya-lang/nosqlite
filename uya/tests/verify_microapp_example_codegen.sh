#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/tests/build"

HELLO_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya"
ALLOC_YIELD_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_alloc_yield_source.uya"
TIME_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_time_source.uya"
BSS_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_bss_source.uya"
RELOC_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_reloc_source.uya"
RELOC_DATA_SOURCE="$ROOT_DIR/examples/microapp/microcontainer_reloc_data_source.uya"

HELLO_OUT="$BUILD_DIR/microcontainer_hello_source_codegen_microapp.c"
ALLOC_YIELD_OUT="$BUILD_DIR/microcontainer_alloc_yield_source_codegen_microapp.c"
TIME_OUT="$BUILD_DIR/microcontainer_time_source_codegen_microapp.c"
BSS_OUT="$BUILD_DIR/microcontainer_bss_source_codegen_microapp.c"
RELOC_OUT="$BUILD_DIR/microcontainer_reloc_source_codegen_microapp.c"
RELOC_DATA_OUT="$BUILD_DIR/microcontainer_reloc_data_source_codegen_microapp.c"

HELLO_LOG="/tmp/verify_microapp_example_codegen_hello.log"
ALLOC_YIELD_LOG="/tmp/verify_microapp_example_codegen_alloc_yield.log"
TIME_LOG="/tmp/verify_microapp_example_codegen_time.log"
BSS_LOG="/tmp/verify_microapp_example_codegen_bss.log"
RELOC_LOG="/tmp/verify_microapp_example_codegen_reloc.log"
RELOC_DATA_LOG="/tmp/verify_microapp_example_codegen_reloc_data.log"

mkdir -p "$BUILD_DIR"
rm -f "$HELLO_OUT" "$ALLOC_YIELD_OUT" "$TIME_OUT" "$BSS_OUT" "$RELOC_OUT" "$RELOC_DATA_OUT"

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export TARGET_GCC
export MICROAPP_TARGET_ARCH

"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$HELLO_SOURCE" -o "$HELLO_OUT" >"$HELLO_LOG" 2>&1
"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$ALLOC_YIELD_SOURCE" -o "$ALLOC_YIELD_OUT" >"$ALLOC_YIELD_LOG" 2>&1
"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$TIME_SOURCE" -o "$TIME_OUT" >"$TIME_LOG" 2>&1
"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$BSS_SOURCE" -o "$BSS_OUT" >"$BSS_LOG" 2>&1
"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$RELOC_SOURCE" -o "$RELOC_OUT" >"$RELOC_LOG" 2>&1
"$ROOT_DIR/bin/uya" build --app microapp --no-safety-proof "$RELOC_DATA_SOURCE" -o "$RELOC_DATA_OUT" >"$RELOC_DATA_LOG" 2>&1

for pair in \
    "$HELLO_OUT:$HELLO_LOG:hello" \
    "$ALLOC_YIELD_OUT:$ALLOC_YIELD_LOG:alloc_yield" \
    "$TIME_OUT:$TIME_LOG:time" \
    "$BSS_OUT:$BSS_LOG:bss" \
    "$RELOC_OUT:$RELOC_LOG:reloc" \
    "$RELOC_DATA_OUT:$RELOC_DATA_LOG:reloc_data"
do
    IFS=":" read -r out log name <<EOF
$pair
EOF
    if [ ! -f "$out" ]; then
        cat "$log"
        echo "✗ official microapp 示例 codegen 未产出 C 文件: $name"
        exit 1
    fi
done

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$HELLO_OUT"; then
    echo "✗ hello 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_ALLOC,' "$ALLOC_YIELD_OUT"; then
    echo "✗ alloc/yield 官方示例未通过 MICROAPP_SYS_ALLOC 走 microapp syscall shim"
    exit 1
fi
if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_YIELD,' "$ALLOC_YIELD_OUT"; then
    echo "✗ alloc/yield 官方示例未通过 MICROAPP_SYS_YIELD 走 microapp syscall shim"
    exit 1
fi
if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$ALLOC_YIELD_OUT"; then
    echo "✗ alloc/yield 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_TIME,' "$TIME_OUT"; then
    echo "✗ time 官方示例未通过 MICROAPP_SYS_TIME 走 microapp syscall shim"
    exit 1
fi
if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$TIME_OUT"; then
    echo "✗ time 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$BSS_OUT"; then
    echo "✗ bss 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$RELOC_OUT"; then
    echo "✗ reloc 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

if ! grep -q 'uya_microapp_bridge_dispatch2(MICROAPP_SYS_PRINT,' "$RELOC_DATA_OUT"; then
    echo "✗ reloc_data 官方示例未通过 MICROAPP_SYS_PRINT 走 microapp syscall shim"
    exit 1
fi

for path in "$HELLO_OUT" "$ALLOC_YIELD_OUT" "$TIME_OUT" "$BSS_OUT" "$RELOC_OUT" "$RELOC_DATA_OUT"; do
    if grep -F -q 'uya_microapp_syscall' "$path"; then
        echo "✗ official microapp 示例生成代码不应回退到历史 uya_microapp_syscall helper: $path"
        exit 1
    fi
    if grep -F -q 'UYA_HOST_SYS_write' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接内嵌宿主 SYS_write shim: $path"
        exit 1
    fi
    if grep -F -q 'UYA_HOST_SYS_mmap' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接内嵌宿主 SYS_mmap shim: $path"
        exit 1
    fi
    if grep -F -q 'posix_memalign(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 posix_memalign: $path"
        exit 1
    fi
    if grep -F -q 'sched_yield(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 sched_yield: $path"
        exit 1
    fi
    if grep -F -q 'gettimeofday(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 gettimeofday: $path"
        exit 1
    fi
    if grep -F -q 'malloc(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 malloc: $path"
        exit 1
    fi
    if grep -F -q 'free(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 free: $path"
        exit 1
    fi
    if grep -F -q 'fprintf(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 fprintf: $path"
        exit 1
    fi
    if grep -F -q 'getenv(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 getenv: $path"
        exit 1
    fi
    if grep -F -q 'abort(' "$path"; then
        echo "✗ official microapp 示例生成代码不应直接依赖宿主 abort: $path"
        exit 1
    fi
done

echo "microapp official example codegen ok"
