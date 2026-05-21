#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

if [ "$HOST_OS" != "Darwin" ]; then
    echo "microapp macos arm64 hosted runtime skipped (host_os=$HOST_OS)"
    exit 0
fi
if [ "$HOST_ARCH" != "arm64" ] && [ "$HOST_ARCH" != "aarch64" ]; then
    echo "microapp macos arm64 hosted runtime skipped (host_arch=$HOST_ARCH)"
    exit 0
fi

TMP_DIR="$(mktemp -d /tmp/verify_microapp_macos_arm64_runtime.XXXXXX)"

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

assert_single_result_surface() {
    local path="$1"
    local expected="$2"
    local count
    grep -a -F -q "$expected" "$path" || dump_log_and_fail "未输出统一 result: $expected" "$path"
    count="$(grep -a -c '^\[microapp loader\] payload result=' "$path" || true)"
    if [ "$count" -ne 1 ]; then
        dump_log_and_fail "payload result 行数量异常: $count" "$path"
    fi
    if grep -a -q '^\[microapp loader\] payload fault class=' "$path"; then
        dump_log_and_fail "不应输出旧 fault 诊断面" "$path"
    fi
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

TARGET_GCC_BIN="${TARGET_GCC:-}"
if [ -z "$TARGET_GCC_BIN" ] && command -v xcrun >/dev/null 2>&1; then
    TARGET_GCC_BIN="$(xcrun --find clang 2>/dev/null || true)"
fi
if [ -z "$TARGET_GCC_BIN" ]; then
    TARGET_GCC_BIN="$(pick_first_available clang cc || true)"
fi

if [ -z "$TARGET_GCC_BIN" ]; then
    echo "microapp macos arm64 hosted runtime skipped (missing compiler)"
    exit 0
fi

OBJCOPY_BIN="${OBJCOPY:-}"
if [ -z "$OBJCOPY_BIN" ] && command -v xcrun >/dev/null 2>&1; then
    OBJCOPY_BIN="$(xcrun --find llvm-objcopy 2>/dev/null || true)"
fi
if [ -z "$OBJCOPY_BIN" ]; then
    OBJCOPY_BIN="$(pick_first_available llvm-objcopy gobjcopy objcopy || true)"
fi

if [ -z "$OBJCOPY_BIN" ]; then
    echo "microapp macos arm64 hosted runtime skipped (missing objcopy)"
    exit 0
fi

export TARGET_GCC="$TARGET_GCC_BIN"
export OBJCOPY="$OBJCOPY_BIN"

build_case_uapp() {
    local name="$1"
    local source_rel="$2"
    local uapp="$TMP_DIR/${name}.uapp"
    local build_log="$TMP_DIR/${name}.build.log"

    local status=0
    rm -f "$uapp"
    set +e
    "$ROOT_DIR/bin/uya" build --app microapp --microapp-profile macos_arm64_hardvm \
        "$ROOT_DIR/$source_rel" -o "$uapp" >"$build_log" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        dump_log_and_fail "macos arm64 $name build 失败: $status" "$build_log"
    fi
    printf '%s\n' "$uapp"
}

run_case_ok() {
    local name="$1"
    local source_rel="$2"
    local expected_text="$3"
    local run_log="$TMP_DIR/${name}.run.log"
    local loader_log="$TMP_DIR/${name}.loader.log"
    local uapp=""

    local status=0
    echo "==> macos arm64 runtime: $name"
    set +e
    "$ROOT_DIR/bin/uya" run --app microapp --microapp-profile macos_arm64_hardvm \
        "$ROOT_DIR/$source_rel" >"$run_log" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        dump_log_and_fail "macos arm64 $name run 异常退出: $status" "$run_log"
    fi

    grep -a -q "$expected_text" "$run_log" || dump_log_and_fail "macos arm64 $name run 未输出期望文本: $expected_text" "$run_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$run_log" || dump_log_and_fail "macos arm64 $name run 未命中 mapped payload 执行分支" "$run_log"
    grep -a -q "\[microapp loader\] payload result=ok" "$run_log" || dump_log_and_fail "macos arm64 $name run 未输出统一 ok result" "$run_log"
    if grep -a -q "\[microapp loader\] launching native payload" "$run_log"; then
        dump_log_and_fail "macos arm64 $name run 意外回退到了 native payload ELF" "$run_log"
    fi

    uapp="$(build_case_uapp "$name" "$source_rel")"
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$uapp" >"$loader_log" 2>&1
    grep -a -q "$expected_text" "$loader_log" || dump_log_and_fail "macos arm64 $name loader 未输出期望文本: $expected_text" "$loader_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$loader_log" || dump_log_and_fail "macos arm64 $name loader 未命中 mapped payload 执行分支" "$loader_log"
    grep -a -q "\[microapp loader\] payload result=ok" "$loader_log" || dump_log_and_fail "macos arm64 $name loader 未输出统一 ok result" "$loader_log"
    if grep -a -q "\[microapp loader\] launching native payload" "$loader_log"; then
        dump_log_and_fail "macos arm64 $name loader 意外回退到了 native payload ELF" "$loader_log"
    fi
}

run_case_exit_nonzero() {
    local run_log="$TMP_DIR/exit_nonzero.run.log"
    local loader_log="$TMP_DIR/exit_nonzero.loader.log"
    local status=0
    local loader_status=0
    local uapp=""

    echo "==> macos arm64 runtime: exit_nonzero"
    set +e
    "$ROOT_DIR/bin/uya" run --app microapp --microapp-profile macos_arm64_hardvm \
        "$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_exit_nonzero.uya" >"$run_log" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 7 ]; then
        dump_log_and_fail "macos arm64 non-zero exit run 退出码异常: $status" "$run_log"
    fi
    grep -a -q "\[microapp loader\] executed mapped payload" "$run_log" || dump_log_and_fail "macos arm64 non-zero exit run 未命中 mapped payload 执行分支" "$run_log"
    grep -a -q "\[microapp loader\] payload result=exit code=7" "$run_log" || dump_log_and_fail "macos arm64 non-zero exit run 未输出统一 exit result" "$run_log"
    grep -a -q "\[microapp loader\] payload exited non-zero" "$run_log" || dump_log_and_fail "macos arm64 non-zero exit run 未透传非零退出码" "$run_log"

    uapp="$(build_case_uapp "exit_nonzero" "tests/fixtures/microapp/test_std_microapp_exit_nonzero.uya")"
    set +e
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$uapp" >"$loader_log" 2>&1
    loader_status=$?
    set -e
    if [ "$loader_status" -ne 7 ]; then
        dump_log_and_fail "macos arm64 non-zero exit loader 退出码异常: $loader_status" "$loader_log"
    fi
    grep -a -q "\[microapp loader\] executed mapped payload" "$loader_log" || dump_log_and_fail "macos arm64 non-zero exit loader 未命中 mapped payload 执行分支" "$loader_log"
    grep -a -q "\[microapp loader\] payload result=exit code=7" "$loader_log" || dump_log_and_fail "macos arm64 non-zero exit loader 未输出统一 exit result" "$loader_log"
    grep -a -q "\[microapp loader\] payload exited non-zero" "$loader_log" || dump_log_and_fail "macos arm64 non-zero exit loader 未透传非零退出码" "$loader_log"
}

run_case_fault() {
    local run_log="$TMP_DIR/fault_segv.run.log"
    local loader_log="$TMP_DIR/fault_segv.loader.log"
    local status=0
    local loader_status=0
    local uapp=""

    echo "==> macos arm64 runtime: fault_segv"
    set +e
    "$ROOT_DIR/bin/uya" run --app microapp --microapp-profile macos_arm64_hardvm \
        "$ROOT_DIR/tests/fixtures/microapp/test_std_microapp_fault_segv.uya" >"$run_log" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 139 ]; then
        dump_log_and_fail "macos arm64 fault run 退出码异常: $status" "$run_log"
    fi
    grep -a -q "\[microapp loader\] image loaded, ticking" "$run_log" || dump_log_and_fail "macos arm64 fault run 未进入 tick" "$run_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$run_log" || dump_log_and_fail "macos arm64 fault run 未命中 mapped payload 执行分支" "$run_log"
    assert_single_result_surface "$run_log" "[microapp loader] payload result=fault class=segv code=1 signal=11"

    uapp="$(build_case_uapp "fault_segv" "tests/fixtures/microapp/test_std_microapp_fault_segv.uya")"
    set +e
    "$ROOT_DIR/bin/uya" run lib/std/runtime/microapp/loader_main.uya -- "$uapp" >"$loader_log" 2>&1
    loader_status=$?
    set -e
    if [ "$loader_status" -ne 139 ]; then
        dump_log_and_fail "macos arm64 fault loader 退出码异常: $loader_status" "$loader_log"
    fi
    grep -a -q "\[microapp loader\] image loaded, ticking" "$loader_log" || dump_log_and_fail "macos arm64 fault loader 未进入 tick" "$loader_log"
    grep -a -q "\[microapp loader\] executed mapped payload" "$loader_log" || dump_log_and_fail "macos arm64 fault loader 未命中 mapped payload 执行分支" "$loader_log"
    assert_single_result_surface "$loader_log" "[microapp loader] payload result=fault class=segv code=1 signal=11"
}

run_case_ok "hello" "examples/microapp/microcontainer_hello_source.uya" "hello microapp"
run_case_ok "alloc_yield" "tests/fixtures/microapp/test_std_microapp_alloc_yield.uya" "alloc yield ok"
run_case_ok "time" "tests/fixtures/microapp/test_std_microapp_time_runtime.uya" "time ok"
run_case_ok "bss" "tests/fixtures/microapp/test_std_microapp_bss_runtime.uya" "bss ok"
run_case_ok "reloc" "examples/microapp/microcontainer_reloc_source.uya" "reloc ok"
run_case_ok "reloc_data" "examples/microapp/microcontainer_reloc_data_source.uya" "reloc64 ok"
run_case_exit_nonzero
run_case_fault

echo "microapp macos arm64 hosted runtime ok"
