#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/verify_microapp_payload_symbols.XXXXXX)"
HOST_NM_BIN="$(command -v nm || true)"

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

if [ -z "$HOST_NM_BIN" ]; then
    echo "✗ microapp payload symbol audit 需要 host nm"
    exit 1
fi

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
export TARGET_GCC
export MICROAPP_TARGET_PROFILE=linux_x86_64_hardvm
export MICROAPP_TARGET_ARCH=x86_64

# Linux hard-vm P0 要求编译器对象提取链路不依赖外部 ELF 检查/导出工具。
export READELF=false
export OBJDUMP=false
export NM=false
export OBJCOPY=false

assert_symbol_absent() {
    local symbols_path="$1"
    local symbol="$2"
    local case_name="$3"
    if grep -F -x -q "$symbol" "$symbols_path"; then
        echo "✗ $case_name payload object 不应直接依赖宿主符号: $symbol"
        echo "--- symbols ---"
        cat "$symbols_path"
        exit 1
    fi
}

assert_no_host_symbol_prefix() {
    local symbols_path="$1"
    local prefix="$2"
    local case_name="$3"
    if grep -E -q "^${prefix}" "$symbols_path"; then
        echo "✗ $case_name payload object 不应出现宿主前缀符号: $prefix"
        echo "--- symbols ---"
        cat "$symbols_path"
        exit 1
    fi
}

assert_symbol_whitelist() {
    local symbols_path="$1"
    local case_name="$2"
    local unexpected="$TMP_DIR/$case_name.unexpected-symbols.log"
    grep -E -v \
        -e '^(\.data\.)?uya_microapp_bridge_abi_v1$' \
        -e '^\.(text|rodata)\.[A-Za-z0-9_.]+$' \
        -e '^ENTRY_(DEFAULT_STACK_LIMIT_BYTES|RLIMIT_STACK)$' \
        -e '^MICROAPP_IO_(DEVICE_(UART|GPIO|TIMER)|OP_(READ|WRITE))$' \
        -e '^MICROAPP_SYS_(ALLOC|IO|PRINT|TIME|YIELD)$' \
        -e '^_uya_async_frame_heap_fallback$' \
        -e '^main$' \
        -e '^main_main$' \
        -e '^saved_(argc|argv|envp)$' \
        -e '^std_microapp_[A-Za-z0-9_]+$' \
        -e '^std_runtime_[A-Za-z0-9_]+$' \
        -e '^str[0-9]+(\.[0-9]+)?$' \
        -e '^g_[A-Za-z0-9_]+$' \
        -e '^uya_call0_i32(_stack)?$' \
        -e '^uya_microapp_bridge_dispatch[0-9]+$' \
        -e '^uya_thread_call_[A-Za-z0-9_]+$' \
        -e '^uya_output_[0-9]+\.c$' \
        "$symbols_path" >"$unexpected" || true
    if [ -s "$unexpected" ]; then
        echo "✗ $case_name payload object 出现白名单外符号"
        echo "--- unexpected symbols ---"
        cat "$unexpected"
        echo "--- all symbols ---"
        cat "$symbols_path"
        exit 1
    fi
}

assert_single_result_surface() {
    local path="$1"
    local expected="$2"
    local case_name="$3"
    local count
    grep -a -F -q "$expected" "$path" || dump_log_and_fail "$case_name 未输出统一 result: $expected" "$path"
    count="$(grep -a -c '^\[microapp loader\] payload result=' "$path" || true)"
    if [ "$count" -ne 1 ]; then
        dump_log_and_fail "$case_name payload result 行数量异常: $count" "$path"
    fi
    if grep -a -q '^\[microapp loader\] payload fault class=' "$path"; then
        dump_log_and_fail "$case_name 不应输出旧 fault 诊断面" "$path"
    fi
}

verify_default_linux_profile_contract() {
    local uapp="$TMP_DIR/default-profile.uapp"
    local build_log="$TMP_DIR/default-profile.build.log"

    env -u MICROAPP_TARGET_PROFILE \
        -u MICROAPP_TARGET_ARCH \
        -u TARGET_OS \
        -u TARGET_ARCH \
        -u TARGET_TRIPLE \
        TARGET_GCC="$TARGET_GCC" \
        READELF=false \
        OBJDUMP=false \
        NM=false \
        OBJCOPY=false \
        "$ROOT_DIR/bin/uya" build --app microapp \
        "$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya" \
        -o "$uapp" >"$build_log" 2>&1

    grep -q "信息：microapp active profile=linux_x86_64_hardvm" "$build_log" \
        || dump_log_and_fail "默认 profile 未解析为 linux_x86_64_hardvm" "$build_log"
    grep -q "信息：microapp 目标 gcc 对象产物：" "$build_log" \
        || dump_log_and_fail "默认 profile 未输出目标对象产物路径" "$build_log"
    if grep -q "信息：microapp 目标 gcc 链接：" "$build_log"; then
        dump_log_and_fail "默认 profile 不应回退到中间 ELF 链接链路" "$build_log"
    fi
    if grep -q "信息：microapp 目标 gcc 导出 .text" "$build_log"; then
        dump_log_and_fail "默认 profile 不应依赖 objcopy 导出 .text" "$build_log"
    fi
}

verify_case() {
    local name="$1"
    local source_rel="$2"
    local expected_output="$3"
    local expected_status="${4:-0}"
    local expected_result="${5:-[microapp loader] payload result=ok}"
    local uapp="$TMP_DIR/$name.uapp"
    local build_log="$TMP_DIR/$name.build.log"
    local run_log="$TMP_DIR/$name.run.log"
    local undefined_log="$TMP_DIR/$name.undefined.log"
    local symbols_log="$TMP_DIR/$name.symbols.log"
    local symbol_names="$TMP_DIR/$name.symbol-names.log"

    "$ROOT_DIR/bin/uya" build --app microapp \
        --microapp-profile linux_x86_64_hardvm \
        "$ROOT_DIR/$source_rel" -o "$uapp" >"$build_log" 2>&1

    grep -q "信息：microapp active profile=linux_x86_64_hardvm" "$build_log" \
        || dump_log_and_fail "$name 未使用 linux_x86_64_hardvm profile" "$build_log"
    grep -q "信息：microapp 目标 gcc 对象产物：" "$build_log" \
        || dump_log_and_fail "$name 未输出目标对象产物路径" "$build_log"
    if grep -q "信息：microapp 目标 gcc 链接：" "$build_log"; then
        dump_log_and_fail "$name 不应回退到中间 ELF 链接链路" "$build_log"
    fi
    if grep -q "信息：microapp 目标 gcc 导出 .text" "$build_log"; then
        dump_log_and_fail "$name 不应依赖 objcopy 导出 .text" "$build_log"
    fi

    local obj_path
    obj_path="$(sed -n 's/^信息：microapp 目标 gcc 对象产物：//p' "$build_log" | tail -n 1)"
    if [ -z "$obj_path" ] || [ ! -f "$obj_path" ]; then
        dump_log_and_fail "$name 目标对象文件不存在: $obj_path" "$build_log"
    fi

    "$HOST_NM_BIN" -u "$obj_path" >"$undefined_log" 2>&1 || dump_log_and_fail "$name 无法读取 undefined symbols" "$undefined_log"
    if [ -s "$undefined_log" ]; then
        dump_log_and_fail "$name payload object 不应包含未解析宿主符号" "$undefined_log"
    fi

    "$HOST_NM_BIN" -a "$obj_path" >"$symbols_log" 2>&1 || dump_log_and_fail "$name 无法读取 symbols" "$symbols_log"
    awk 'NF > 0 { print $NF }' "$symbols_log" >"$symbol_names"

    grep -F -x -q "uya_microapp_bridge_abi_v1" "$symbol_names" \
        || dump_log_and_fail "$name payload object 缺少 bridge ABI slot" "$symbols_log"
    assert_symbol_whitelist "$symbol_names" "$name"

    assert_symbol_absent "$symbol_names" "write_stdout_bytes" "$name"
    assert_symbol_absent "$symbol_names" "posix_memalign" "$name"
    assert_symbol_absent "$symbol_names" "sched_yield" "$name"
    assert_symbol_absent "$symbol_names" "gettimeofday" "$name"
    assert_symbol_absent "$symbol_names" "malloc" "$name"
    assert_symbol_absent "$symbol_names" "free" "$name"
    assert_symbol_absent "$symbol_names" "fprintf" "$name"
    assert_symbol_absent "$symbol_names" "getenv" "$name"
    assert_symbol_absent "$symbol_names" "abort" "$name"
    assert_no_host_symbol_prefix "$symbol_names" "UYA_HOST_SYS_" "$name"
    assert_no_host_symbol_prefix "$symbol_names" "uya_microapp_syscall" "$name"

    local run_status=0
    set +e
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$uapp" >"$run_log" 2>&1
    run_status=$?
    set -e
    if [ "$run_status" -ne "$expected_status" ]; then
        dump_log_and_fail "$name loader 退出码异常: $run_status" "$run_log"
    fi
    if [ "$expected_output" != "-" ]; then
        grep -a -q "$expected_output" "$run_log" \
            || dump_log_and_fail "$name loader 未输出预期内容" "$run_log"
    fi
    grep -a -q "\[microapp loader\] executed mapped payload" "$run_log" \
        || dump_log_and_fail "$name loader 未命中 mapped payload 执行分支" "$run_log"
    assert_single_result_surface "$run_log" "$expected_result" "$name"
    if grep -a -q "\[microapp loader\] launching native payload" "$run_log"; then
        dump_log_and_fail "$name loader 意外回退 native payload" "$run_log"
    fi
    if grep -a -q "\[microapp loader\] payload result=validated" "$run_log"; then
        dump_log_and_fail "$name call-gate payload 不应停在 validated-only 结果面" "$run_log"
    fi
    if grep -a -q "\[microapp loader\] payload result=unwired" "$run_log"; then
        dump_log_and_fail "$name call-gate payload 不应输出 unwired 结果面" "$run_log"
    fi
}

verify_default_linux_profile_contract
verify_case "hello" "examples/microapp/microcontainer_hello_source.uya" "hello microapp"
verify_case "alloc_yield" "examples/microapp/microcontainer_alloc_yield_source.uya" "alloc yield ok"
verify_case "time" "examples/microapp/microcontainer_time_source.uya" "time ok"
verify_case "bss" "examples/microapp/microcontainer_bss_source.uya" "bss ok"
verify_case "reloc" "examples/microapp/microcontainer_reloc_source.uya" "reloc ok"
verify_case "reloc_data" "examples/microapp/microcontainer_reloc_data_source.uya" "reloc64 ok"
verify_case "exit_nonzero" "tests/fixtures/microapp/test_std_microapp_exit_nonzero.uya" "-" 7 "[microapp loader] payload result=exit code=7"
verify_case "fault_segv" "tests/fixtures/microapp/test_std_microapp_fault_segv.uya" "-" 139 "[microapp loader] payload result=fault class=segv code=1 signal=11"

echo "microapp payload symbol audit ok"
