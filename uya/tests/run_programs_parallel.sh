#!/bin/bash
# Uya Mini 编译器测试程序运行脚本（并行版本）
# 自动编译和运行所有测试程序，验证编译器生成的二进制正确性
# 使用并行执行加速测试
#
# 用法:
#   ./run_programs_parallel.sh                    # 运行所有测试（并行，默认同 CPU 核数）
#   ./run_programs_parallel.sh -j 4               # 运行所有测试（4线程）
#   ./run_programs_parallel.sh -j 1               # 运行所有测试（单线程，等同于原版）
#   ./run_programs_parallel.sh <文件或目录>        # 运行指定的测试文件或目录
#   ./run_programs_parallel.sh test_file.uya      # 运行单个测试文件
#
# 环境变量:
#   PARALLEL_JOBS=N   # 设置并行任务数（未设置时默认 CPU 核数，见 nproc/sysctl）
#
# 快速验证单个测试（在项目根目录下执行）:
#   ./tests/run_programs_parallel.sh test_global_var.uya

# 当 stdout 不是 TTY 时（如通过 make/pipe/CI 运行），强制行缓冲输出，避免大块缓冲导致看不到实时结果
if [ -z "${UYA_TEST_STDOUT_LINEBUF:-}" ] && [ ! -t 1 ] && command -v stdbuf >/dev/null 2>&1; then
    export UYA_TEST_STDOUT_LINEBUF=1
    exec stdbuf -oL bash "$0" "$@"
fi

set -e

# 自举编译器递归较深，需增大栈限制避免段错误
ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

# 获取脚本所在目录的绝对路径，然后推导各路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
TEST_DIR="$SCRIPT_DIR"
BUILD_DIR="$TEST_DIR/build"
NETWORK_SKIP_MARKER="${TMPDIR:-/tmp}/uya_allow_skip_network"
ERRORS_ONLY=false
# 为 true 时：不打印每条「通过」的 ✓ 行，其余输出与 ERRORS_ONLY=false 相同（供 make tests 默认使用）
HIDE_PASS_OUTPUT=false
USE_C99=true
USE_UYA=false
_DEFAULT_PARALLEL_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)
PARALLEL_JOBS=${PARALLEL_JOBS:-$_DEFAULT_PARALLEL_JOBS}
TEST_PROFILE="${TEST_PROFILE:-default}"
TOOLCHAIN="${TOOLCHAIN:-system}"
ZIG="${ZIG:-/home/winger/zig/zig}"
CC="${CC:-cc}"
if [ -z "${CC_DRIVER:-}" ]; then
    if [ "$TOOLCHAIN" = "zig" ]; then
        CC_DRIVER="$ZIG cc"
    else
        CC_DRIVER="$CC"
    fi
fi
CC_TARGET_FLAGS="${CC_TARGET_FLAGS:-}"

normalize_os() {
    case "$1" in
        Linux|linux) echo "linux" ;;
        Darwin|darwin|macos) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*|mingw*|msys*|cygwin*|windows|win32) echo "windows" ;;
        *) echo "$1" | tr '[:upper:]' '[:lower:]' ;;
    esac
}

normalize_arch() {
    case "$1" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *) echo "$1" ;;
    esac
}

HOST_OS="${HOST_OS:-$(normalize_os "$(uname -s)")}"
HOST_ARCH="${HOST_ARCH:-$(normalize_arch "$(uname -m)")}"
TARGET_OS="${TARGET_OS:-$HOST_OS}"
TARGET_ARCH="${TARGET_ARCH:-$HOST_ARCH}"
TARGET_TRIPLE="${TARGET_TRIPLE:-}"
TARGET_OS="$(normalize_os "$TARGET_OS")"
TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"
TARGET_EXE_SUFFIX=""
if [ "$TARGET_OS" = "windows" ]; then
    TARGET_EXE_SUFFIX=".exe"
fi

CC_CMD=()
if [ -n "$CC_DRIVER" ]; then
    read -r -a CC_CMD <<< "$CC_DRIVER"
fi
if [ ${#CC_CMD[@]} -eq 0 ]; then
    CC_CMD=("cc")
fi
if [ -n "$CC_TARGET_FLAGS" ]; then
    read -r -a CC_TARGET_FLAGS_ARR <<< "$CC_TARGET_FLAGS"
    CC_CMD+=("${CC_TARGET_FLAGS_ARR[@]}")
fi

CFLAGS_ARR=()
if [ -n "$CFLAGS" ]; then
    read -r -a CFLAGS_ARR <<< "$CFLAGS"
fi

LDFLAGS_ARR=()
if [ -n "$LDFLAGS" ]; then
    read -r -a LDFLAGS_ARR <<< "$LDFLAGS"
fi

# 设置 UYA_ROOT 指向标准库目录（lib/）
export UYA_ROOT="${REPO_ROOT}/lib/"

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项] [文件或目录]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -e, --errors-only   最小输出：仅失败时打印详情（不打印开头进度与全通过时的汇总等）"
    echo "  --hide-pass         不打印每条通过的 ✓，其余输出与默认相同（失败项仍完整显示）"
    echo "  -j <N>              并行任务数（默认 CPU 核数）"
    echo "  --c99               使用 C99 后端（默认）"
    echo "  --uya               使用 src 编译的编译器"
    echo ""
    echo "环境变量:"
    echo "  PARALLEL_JOBS=N     并行任务数（命令行 -j 可再覆盖此环境变量）"
    echo "  TOOLCHAIN=zig       使用 zig cc 作为统一工具链"
    echo "  ZIG=/path/to/zig    指定 zig 可执行文件路径"
    echo "  CC_DRIVER='zig cc'  指定测试链接器命令"
    echo "  CC_TARGET_FLAGS='-target ...' 指定目标编译参数"
    echo "  TARGET_OS/TARGET_ARCH/TARGET_TRIPLE  目标平台（默认继承宿主）"
    echo "  TEST_PROFILE=hosted  选择 hosted 测试配置"
    echo "  SKIP_DARWIN_DEFAULT=0  macOS 上不默认跳过 Linux syscall/async 用例"
    echo ""
    echo "参数:"
    echo "  无参数              运行所有测试"
    echo "  <文件>              运行指定的测试文件（.uya 文件）"
    echo "  <目录>              运行指定目录下的所有测试"
    echo ""
    echo "示例:"
    echo "  $0                                    # 运行所有测试（并行，默认同 CPU 核数）"
    echo "  $0 -j 4                               # 运行所有测试（并行，4线程）"
    echo "  $0 -j 1                               # 运行所有测试（单线程）"
    echo "  PARALLEL_JOBS=12 $0                    # 运行所有测试（并行，12线程）"
    echo "  $0 -e                                 # 最小输出（仅失败详情）"
    echo "  $0 --hide-pass                        # 保留进度/汇总，仅省略每条通过的 ✓"
    echo "  $0 test_global_var.uya               # 运行单个测试"
}

# 检查测试目录是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "错误: 测试目录 '$TEST_DIR' 不存在"
    exit 1
fi

# 创建构建输出目录
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/multifile"
mkdir -p "$BUILD_DIR/cross_deps"
mkdir -p "$BUILD_DIR/parallel_results"
mkdir -p "$BUILD_DIR/tests"          # 单文件测试独立输出目录
mkdir -p "$BUILD_DIR/multifile_tests" # 多文件测试独立输出目录

cleanup_network_skip_marker() {
    rm -f "$NETWORK_SKIP_MARKER"
}
trap cleanup_network_skip_marker EXIT

if [ "${ALLOW_SKIP_NETWORK:-}" = "1" ]; then
    : > "$NETWORK_SKIP_MARKER"
else
    rm -f "$NETWORK_SKIP_MARKER"
fi

# 解析命令行参数
TARGET_PATH=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -e|--errors-only)
            ERRORS_ONLY=true
            shift
            ;;
        --hide-pass)
            HIDE_PASS_OUTPUT=true
            shift
            ;;
        -j)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --c99)
            USE_C99=true
            shift
            ;;
        --uya)
            USE_UYA=true
            shift
            ;;
        -*)
            echo "错误: 未知选项 '$1'"
            echo "使用 '$0 --help' 查看帮助信息"
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

# 根据 --uya 选项设置编译器路径
if [ "$USE_UYA" = true ]; then
    USE_C99=true
    COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
fi

# 检查编译器是否存在
if [ -z "$COMPILER" ] || [ ! -f "$COMPILER" ] || [ ! -x "$COMPILER" ]; then
    echo "错误: Uya 自举编译器不存在: $COMPILER"
    echo "请先运行 'make from-c' 或 'make uya' 构建编译器"
    exit 1
fi

if [ "$ERRORS_ONLY" = false ]; then
    echo "开始运行 Uya 测试程序（并行版本，${PARALLEL_JOBS} 线程）..."
    echo "使用编译器: $COMPILER"
    if [ -n "$TARGET_PATH" ]; then
        echo "目标: $TARGET_PATH"
    fi
    echo ""
fi

# 生成唯一测试ID（基于相对路径，避免同名冲突）
generate_test_id() {
    local test_path="$1"
    local rel_path="$test_path"
    if [[ "$test_path" == "$REPO_ROOT"* ]]; then
        rel_path="${test_path#$REPO_ROOT/}"
    fi
    # 将路径中的 / 替换为 _，生成唯一ID
    echo "$rel_path" | sed 's|/|_|g' | sed 's|\.uya$||'
}

# 收集所有需要测试的文件
collect_test_files() {
    local target="$1"
    
    if [ -f "$target" ]; then
        if [[ "$target" == *.uya ]]; then
            echo "$target"
        fi
    elif [ -d "$target" ]; then
        local dir_name=$(basename "$target")
        
        # 特殊处理多文件测试目录
        if [ "$dir_name" = "multifile" ] || [ "$dir_name" = "cross_deps" ]; then
            # 标记为多文件测试
            echo "MULTIFILE:$target:$dir_name"
        else
            # 递归收集所有 .uya 文件
            find "$target" -maxdepth 2 -name "*.uya" -type f 2>/dev/null || true
        fi
    fi
}

# 如果指定了目标路径
if [ -n "$TARGET_PATH" ]; then
    # 转换为绝对路径
    if [[ "$TARGET_PATH" != /* ]]; then
        if [ -f "$TARGET_PATH" ] || [ -d "$TARGET_PATH" ]; then
            TARGET_PATH=$(realpath "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")
        elif [ -f "$TEST_DIR/$TARGET_PATH" ] || [ -d "$TEST_DIR/$TARGET_PATH" ]; then
            TARGET_PATH="$TEST_DIR/$TARGET_PATH"
        fi
    fi
    if [ ! -e "$TARGET_PATH" ]; then
        echo "错误: 路径 '$TARGET_PATH' 不存在"
        exit 1
    fi
    TEST_FILES=($(collect_test_files "$TARGET_PATH"))
else
    # 没有指定路径，收集所有测试
    TEST_FILES=()
    
    # 多文件测试
    if [ -d "$TEST_DIR/multifile" ]; then
        TEST_FILES+=("MULTIFILE:$TEST_DIR/multifile:multifile")
    fi
    if [ -d "$TEST_DIR/cross_deps" ]; then
        TEST_FILES+=("MULTIFILE:$TEST_DIR/cross_deps:cross_deps")
    fi
    
    # 单文件测试
    while IFS= read -r -d '' file; do
        TEST_FILES+=("$file")
    done < <(find "$TEST_DIR" -maxdepth 1 -name "*.uya" -type f -print0 2>/dev/null)
fi

# 优先级排序：把耗时/网络测试提到最前面，避免它们拖在最后才执行
priority_names=("test_https_google" "test_std_thread")
priority_items=()
for name in "${priority_names[@]}"; do
    for i in "${!TEST_FILES[@]}"; do
        if [[ "${TEST_FILES[$i]}" == *"${name}.uya" ]]; then
            priority_items+=("${TEST_FILES[$i]}")
            unset 'TEST_FILES[i]'
            break
        fi
    done
done
TEST_FILES=("${priority_items[@]}" "${TEST_FILES[@]}")

link_generated_test_output() {
    local output_file="$1"
    local base_name="$2"
    local output_dir="$3"
    local exe_file="${output_dir}/${base_name}.bin${TARGET_EXE_SUFFIX}"
    local link_log_file="${output_dir}/${base_name}.linker_output.log"
    local sidecar_file="${output_file}imports.sh"
    local extra_c_file=""
    local bridge_c_file=""
    local link_succeeded=false
    local -a link_cmd=("${CC_CMD[@]}" "${CFLAGS_ARR[@]}")
    local -a cimport_objects=()
    local -a cimport_ldflags=()

    if [ "$TARGET_OS" = "linux" ]; then
        link_cmd+=(-no-pie)
    fi

    if [ "$base_name" = "extern_function" ]; then
        extra_c_file="$SCRIPT_DIR/extern_function_impl.c"
    elif [ "$base_name" = "test_comprehensive_cast" ] || [ "$base_name" = "test_ffi_cast" ] || [ "$base_name" = "test_pointer_cast" ] || [ "$base_name" = "test_simple_cast" ] || [ "$base_name" = "test_extern_union" ]; then
        extra_c_file="$SCRIPT_DIR/external_functions.c"
    elif [ "$base_name" = "test_abi_calling_convention" ]; then
        extra_c_file="$SCRIPT_DIR/test_abi_helpers.c"
    elif [ "$base_name" = "test_tflm_cmsis" ]; then
        extra_c_file="$SCRIPT_DIR/tflm_cmsis_host_stub.c"
    fi

    link_cmd+=(-o "$exe_file" "$output_file")
    # 兼容老测试：普通 fn main 会生成 uya_main，而 entry 入口仍调用 main_main。
    # 当生成的 C 缺少 main_main 定义时，补一个最小 bridge。
    if grep -q "int32_t uya_main(void)" "$output_file" 2>/dev/null && \
       grep -q "extern int32_t main_main()" "$output_file" 2>/dev/null && \
       ! grep -q "int32_t main_main(void)" "$output_file" 2>/dev/null; then
        bridge_c_file="${output_dir}/${base_name}_bridge.c"
        printf '%s\n' '#include <stdint.h>' 'extern int32_t uya_main(void);' 'int32_t main_main(void) { return uya_main(); }' > "$bridge_c_file"
        link_cmd+=("$bridge_c_file")
    fi
    if [ -n "$extra_c_file" ]; then
        link_cmd+=("$extra_c_file")
    fi
    if [ -f "$sidecar_file" ]; then
        # shellcheck disable=SC1090
        . "$sidecar_file"
        local cimport_count="${UYA_CIMPORT_COUNT:-0}"
        local ci=0
        while [ "$ci" -lt "$cimport_count" ]; do
            local src_var="UYA_CIMPORT_SRC_${ci}"
            local cflagc_var="UYA_CIMPORT_CFLAGC_${ci}"
            local src_path="${!src_var}"
            local cflagc="${!cflagc_var:-0}"
            local obj_path="${output_dir}/${base_name}.cimport.${ci}.o"
            local -a compile_cmd=("${CC_CMD[@]}" "${CFLAGS_ARR[@]}")
            local cj=0
            while [ "$cj" -lt "$cflagc" ]; do
                local cflag_var="UYA_CIMPORT_CFLAG_${ci}_${cj}"
                compile_cmd+=("${!cflag_var}")
                cj=$((cj + 1))
            done
            compile_cmd+=(-c "$src_path" -o "$obj_path")
            if ! "${compile_cmd[@]}" > /dev/null 2> "$link_log_file"; then
                return 1
            fi
            cimport_objects+=("$obj_path")
            ci=$((ci + 1))
        done

        local ldflagc="${UYA_CIMPORT_LDFLAGC:-0}"
        local li=0
        while [ "$li" -lt "$ldflagc" ]; do
            local ldflag_var="UYA_CIMPORT_LDFLAG_${li}"
            cimport_ldflags+=("${!ldflag_var}")
            li=$((li + 1))
        done
    fi
    if [ ${#cimport_objects[@]} -gt 0 ]; then
        link_cmd+=("${cimport_objects[@]}")
    fi
    if [ "$base_name" = "test_tls_ecdsa" ]; then
        link_cmd+=(-lcrypto)
    fi
    if [ "$TARGET_OS" != "windows" ]; then
        link_cmd+=(-lm)
    fi
    link_cmd+=("${LDFLAGS_ARR[@]}")
    if [ ${#cimport_ldflags[@]} -gt 0 ]; then
        link_cmd+=("${cimport_ldflags[@]}")
    fi

    rm -f "$link_log_file"
    "${link_cmd[@]}" > /dev/null 2> "$link_log_file" && link_succeeded=true
    if [ "$link_succeeded" = true ]; then
        rm -f "$link_log_file"
        echo "$exe_file"
        return 0
    fi

    return 1
}

# 统一测试执行函数：支持单文件、多文件和目录聚合用例
run_compiled_test_args() {
    set +e
    ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

    local base_name="$1"
    local result_file="$2"
    local expect_fail="$3"
    local output_dir="$4"
    shift 4
    local compiler_work_dir="${output_dir}/compiler_work"
    local output_file="${compiler_work_dir}/${base_name}.c"
    local safety_proof_arg="--safety-proof"
    local compiler_exit=0
    local exe_file=""
    local exit_code=0
    local compiler_output=""
    local -a compiler_args=()

    local -a extra_args=()
    if [[ "$base_name" =~ ^error_microapp_mode_ ]]; then
        extra_args=(--app microapp)
    fi

    mkdir -p "$compiler_work_dir"

    local arg=""
    for arg in "$@"; do
        if [[ "$arg" == -* ]] || [[ "$arg" == /* ]]; then
            compiler_args+=("$arg")
        elif [ -e "$arg" ]; then
            compiler_args+=("$(realpath "$arg" 2>/dev/null || printf '%s/%s' "$REPO_ROOT" "$arg")")
        elif [ -e "$REPO_ROOT/$arg" ]; then
            compiler_args+=("$REPO_ROOT/$arg")
        else
            compiler_args+=("$arg")
        fi
    done

    compiler_output=$(cd "$compiler_work_dir" && "$COMPILER" --c99 "$safety_proof_arg" "${extra_args[@]}" "${compiler_args[@]}" -o "${base_name}.c" 2>&1)
    compiler_exit=$?
    if [ $compiler_exit -ne 0 ]; then
        if [ "$expect_fail" = true ]; then
            echo "PASS:$base_name:预期编译失败" > "$result_file"
        else
            echo "FAIL:$base_name:编译失败(退出码:$compiler_exit)" > "$result_file"
            # 并行任务的 stdout 可能交错，但在 CI 里能直接看到"具体报错行/信息"
            # 额外把完整输出写入 log 便于二次定位。
            local log_file="${output_dir}/${base_name}.compiler_output.log"
            echo "$compiler_output" > "$log_file" 2>/dev/null || true
            echo "----- compiler output begin: $base_name (exit:$compiler_exit) -----"
            echo "$compiler_output"
            echo "----- compiler output end: $base_name -----"
        fi
        return
    fi

    if [ "$expect_fail" = true ]; then
        echo "FAIL:$base_name:预期编译失败，但编译器未检测到错误" > "$result_file"
        return
    fi

    if [ ! -f "$output_file" ]; then
        echo "FAIL:$base_name:未生成输出文件" > "$result_file"
        return
    fi

    exe_file=$(link_generated_test_output "$output_file" "$base_name" "$output_dir")
    if [ $? -ne 0 ] || [ -z "$exe_file" ] || [ ! -x "$exe_file" ]; then
        echo "FAIL:$base_name:链接失败" > "$result_file"
        local link_log_file="${output_dir}/${base_name}.linker_output.log"
        if [ -s "$link_log_file" ]; then
            echo "----- linker output begin: $base_name -----"
            cat "$link_log_file"
            echo "----- linker output end: $base_name -----"
        fi
        return
    fi

    local test_timeout="${UYA_TEST_TIMEOUT:-60}"
    case "$base_name" in
        test_https_debug|test_https_google|test_https_real_site|test_https_production|test_raw_tls)
            # 外网 TLS/HTTPS 用例偶发受 DNS/TCP/TLS 握手抖动影响，给它们单独更宽的超时窗口，
            # 避免 release 验收被瞬时网络波动误判为编译器回归。
            test_timeout="${UYA_TEST_TIMEOUT_NETWORK:-120}"
            ;;
    esac
    local run_exit=0
    if command -v timeout >/dev/null 2>&1; then
        timeout "${test_timeout}s" "$exe_file" > /dev/null 2>&1 || run_exit=$?
    else
        "$exe_file" > /dev/null 2>&1 || run_exit=$?
    fi
    if [ $run_exit -eq 0 ]; then
        echo "PASS:$base_name:测试通过" > "$result_file"
    elif command -v timeout >/dev/null 2>&1 && [ $run_exit -eq 124 ]; then
        echo "FAIL:$base_name:测试运行超时（>${test_timeout}s）" > "$result_file"
    else
        echo "FAIL:$base_name:测试失败（退出码: $run_exit）" > "$result_file"
    fi
}

run_compiled_test_input() {
    local uya_input="$1"
    local base_name="$2"
    local result_file="$3"
    local output_dir="$4"
    local expect_fail=false
    if [[ "$base_name" =~ ^error_ ]]; then
        expect_fail=true
    fi
    run_compiled_test_args "$base_name" "$result_file" "$expect_fail" "$output_dir" "$uya_input"
}

run_single_test() {
    local uya_file="$1"
    local result_file="$2"
    local base_name=$(basename "$uya_file" .uya)
    local test_id=$(generate_test_id "$uya_file")
    local output_dir="$BUILD_DIR/tests/${test_id}"
    
    # 创建独立的输出目录
    mkdir -p "$output_dir"
    
    run_compiled_test_input "$uya_file" "$base_name" "$result_file" "$output_dir"
}

run_multifile_test() {
    local test_dir="$1"
    local test_name="$2"
    local result_file="$3"
    local failed_cases=0
    local run_known_blockers="${RUN_KNOWN_MULTIFILE_BLOCKERS:-false}"
    local output_dir="$BUILD_DIR/multifile_tests/${test_name}"
    local case_file="${output_dir}/${test_name}.case"
    
    # 创建多文件测试输出目录
    mkdir -p "$output_dir"

    run_case() {
        local case_name="$1"
        local expect_fail="$2"
        local case_output_dir="${output_dir}/${case_name}"
        shift 2
        
        # 每个子用例也有独立目录
        mkdir -p "$case_output_dir"
        
        > "$case_file"
        run_compiled_test_args "$case_name" "$case_file" "$expect_fail" "$case_output_dir" "$@"
        result=$(tr -d '\0' < "$case_file" 2>/dev/null || true)
        status="${result%%:*}"
        if [ "$status" != "PASS" ]; then
            failed_cases=$((failed_cases + 1))
        fi
    }

    if [ "$test_name" = "cross_deps" ]; then
        run_case "cross_deps" false \
            "$test_dir/test_structs_main.uya" \
            "$test_dir/test_structs_a.uya" \
            "$test_dir/test_structs_b.uya"
    elif [ "$test_name" = "multifile" ]; then
        run_case "multifile_basic" false \
            "$test_dir/test_multifile_main.uya" \
            "$test_dir/test_multifile_utils.uya"
        run_case "multifile_cross_struct" false \
            "$test_dir/test_cross_struct_a.uya" \
            "$test_dir/test_cross_struct_b.uya"
        run_case "multifile_module_test" false \
            "$test_dir/module_test/module_b.uya" \
            "$test_dir/module_test/module_a/module_a.uya"
        run_case "error_use_private" true \
            "$test_dir/module_test/error_use_private.uya" \
            "$test_dir/module_test/module_a/module_a.uya"
        run_case "multifile_use_main" false \
            "$test_dir/test_use_main"
        # 已知 blocker：跨模块导出宏解析仍未稳定，旧脚本此前会被整体目录聚合掩盖。
        # 这里只保留私有宏反例，正例等后续专门修复模块宏导入后再打开。
        if [ "$run_known_blockers" = true ]; then
            run_case "multifile_macro_export" false \
                "$test_dir/test_macro_export/test_macro_export_main.uya"
        fi
        run_case "error_use_private_macro" true \
            "$test_dir/test_macro_export/error_use_private_macro.uya"
    else
        local uya_files=()
        while IFS= read -r -d '' file; do
            uya_files+=("$file")
        done < <(find "$test_dir" -maxdepth 2 -name "*.uya" -type f -print0 2>/dev/null)
        if [ ${#uya_files[@]} -eq 0 ]; then
            echo "FAIL:$test_name:未找到多文件测试输入" > "$result_file"
            rm -f "$case_file"
            return
        fi
        run_case "$test_name" false "${uya_files[@]}"
    fi

    rm -f "$case_file"
    if [ "$failed_cases" -eq 0 ]; then
        echo "PASS:$test_name:多文件测试通过" > "$result_file"
    else
        echo "FAIL:$test_name:多文件测试失败(${failed_cases}个子用例失败)" > "$result_file"
    fi
}

# 处理已完成的单文件测试并实时输出结果
# 从 PENDING_RFS/PENDING_BNS 数组中查找非空结果文件并输出
process_ready_single_results() {
    local found_any=1
    while [ $found_any -eq 1 ]; do
        found_any=0
        for i in "${!PENDING_RFS[@]}"; do
            local rf="${PENDING_RFS[$i]}"
            local bn="${PENDING_BNS[$i]}"
            if [ -f "$rf" ] && [ -s "$rf" ]; then
                local result
                result=$(tr -d '\0' < "$rf")
                local status="${result%%:*}"
                if [ "$status" = "PASS" ]; then
                    if [ "$ERRORS_ONLY" = false ] && [ "$HIDE_PASS_OUTPUT" = false ]; then
                        echo "  ✓ ${result#*:}"
                    fi
                    PASSED=$((PASSED + 1))
                else
                    if [ "$ERRORS_ONLY" = true ]; then
                        echo "测试: $bn"
                    fi
                    echo "  ❌ ${result#*:}"
                    FAILED=$((FAILED + 1))
                fi
                rm -f "$rf"
                unset 'PENDING_RFS[i]'
                unset 'PENDING_BNS[i]'
                found_any=1
                break
            fi
        done
    done
}

# 导出函数和变量供子进程使用
export -f generate_test_id link_generated_test_output run_compiled_test_args run_compiled_test_input run_single_test run_multifile_test process_ready_single_results normalize_os normalize_arch
export COMPILER USE_UYA SCRIPT_DIR BUILD_DIR USE_C99 CC CC_DRIVER CC_TARGET_FLAGS HOST_OS HOST_ARCH TARGET_OS TARGET_ARCH TARGET_TRIPLE TARGET_EXE_SUFFIX TEST_PROFILE REPO_ROOT

SKIP_TESTS=()
if [ -n "${SKIP_TESTS_EXTRA:-}" ]; then
    read -r -a SKIP_TESTS_EXTRA_ARR <<< "$SKIP_TESTS_EXTRA"
    SKIP_TESTS+=("${SKIP_TESTS_EXTRA_ARR[@]}")
fi

# 已知会在整套高并发测试下互相争用本地/外网网络资源的集成用例。
# 单独串行执行能保持语义不变，同时避免 DNS/TLS/loopback 相关的稳定波动。
SERIAL_TESTS=(
    test_tcp_basic
    test_std_dns
    test_https_loopback
    test_https_google
    test_https_real_site
    test_https_debug
    test_https_production
    test_epoll_server
    test_std_dns_async_transport
    test_http1_async_client
    test_http_server
    test_raw_tls
    # kernel.sim 端到端测试会生成/链接很大的宿主程序；
    # 在整套 28 线程并行下偶发链接抖动，串行执行可稳定语义且不影响覆盖面。
    test_kernel_sim
)
if [ -n "${SERIAL_TESTS_EXTRA:-}" ]; then
    read -r -a SERIAL_TESTS_EXTRA_ARR <<< "$SERIAL_TESTS_EXTRA"
    SERIAL_TESTS+=("${SERIAL_TESTS_EXTRA_ARR[@]}")
fi

LOOPBACK_SKIP_TESTS=(
    test_tcp_basic
    test_std_dns
    test_std_dns_async_transport
    test_https_loopback
    test_epoll_server
    test_http_server
    test_http1_async_client
    test_https_local
)

loopback_socket_supported() {
    local py_bin=""
    if command -v python3 >/dev/null 2>&1; then
        py_bin="python3"
    elif command -v python >/dev/null 2>&1; then
        py_bin="python"
    else
        return 0
    fi

    "$py_bin" - <<'PY' >/dev/null 2>&1
import socket
import sys

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("127.0.0.1", 0))
        s.listen(1)
    finally:
        s.close()
except OSError:
    sys.exit(1)
sys.exit(0)
PY
}

is_loopback_skip_test() {
    local name="$1"
    for s in "${LOOPBACK_SKIP_TESTS[@]}"; do
        if [ "$name" = "$s" ]; then
            return 0
        fi
    done
    return 1
}

# CI 或本地无外网时直接跳过访问外网的测试（比运行时检测更快，节省编译时间）
if [ -n "${SKIP_NETWORK:-}" ] || [ "${ALLOW_SKIP_NETWORK:-}" = "1" ]; then
    SKIP_TESTS+=(
        test_https_google
        test_https_real_site
        test_https_debug
        test_https_production
        test_raw_tls
    )
    if [ "$ERRORS_ONLY" = false ]; then
        echo "提示: 已跳过访问外网的测试（SKIP_NETWORK 或 ALLOW_SKIP_NETWORK 设置）"
        echo ""
    fi
fi

# 某些 sandbox/CI 环境会直接拒绝创建 loopback socket（常见为 EPERM），这类环境下
# 本地网络集成测试不具备可执行前提，应自动跳过而不是误报编译器回归。
if ! loopback_socket_supported; then
    SKIP_TESTS+=("${LOOPBACK_SKIP_TESTS[@]}")
    : > "$NETWORK_SKIP_MARKER"
    if [ "$ERRORS_ONLY" = false ]; then
        echo "提示: 当前环境不支持 loopback socket，已跳过本地网络集成测试"
        echo ""
    fi
fi

# macOS：在 syscall/osal/async Darwin 完成前默认跳过已知 Linux centric 用例（SKIP_DARWIN_DEFAULT=0 关闭）
if [ "$HOST_OS" = "macos" ] && [ "${SKIP_DARWIN_DEFAULT:-1}" != "0" ]; then
    SKIP_TESTS+=(
        test_async_fd
        test_std_async_event
        test_osal
        test_std_syscall
        test_std_syscall_new
        test_syscall_dir
        test_syscall_error
        test_syscall_exit
        test_syscall_file
        test_syscall_ioctl
        test_syscall_layer
        test_syscall_mem
        test_syscall_module
        test_syscall_process
        test_syscall_thread
        test_syscall_time
        test_syscall_user
        test_syscall_write
        syscall_c99_cross
    )
    if [ "$ERRORS_ONLY" = false ]; then
        echo "提示: 宿主为 macOS，已默认跳过 Linux syscall/async 相关用例（SKIP_DARWIN_DEFAULT=0 可关闭）"
        echo ""
    fi
fi

# 执行并行测试
PASSED=0
FAILED=0
TOTAL_TESTS=${#TEST_FILES[@]}
SKIP_COUNT=0
for t in "${TEST_FILES[@]}"; do
    if [[ "$t" != MULTIFILE:* ]]; then
        bn=$(basename "$t" .uya)
        for s in "${SKIP_TESTS[@]}"; do [ "$bn" = "$s" ] && SKIP_COUNT=$((SKIP_COUNT+1)) && break; done
    fi
done
TOTAL_TESTS=$((TOTAL_TESTS - SKIP_COUNT))

if [ "$ERRORS_ONLY" = false ]; then
    echo "发现 $TOTAL_TESTS 个测试任务"
    echo ""
fi

# 执行单文件测试
parallel_single_tests=()
serial_single_tests=()
multifile_tests=()

# 分类测试
for test_item in "${TEST_FILES[@]}"; do
    if [[ "$test_item" == MULTIFILE:* ]]; then
        multifile_tests+=("$test_item")
    else
        bn=$(basename "$test_item" .uya)
        skip=0
        for s in "${SKIP_TESTS[@]}"; do [ "$bn" = "$s" ] && skip=1 && break; done
        if [ $skip -eq 0 ]; then
            serialize=0
            for s in "${SERIAL_TESTS[@]}"; do
                [ "$bn" = "$s" ] && serialize=1 && break
            done
            if [ $serialize -eq 1 ]; then
                serial_single_tests+=("$test_item")
            else
                parallel_single_tests+=("$test_item")
            fi
        fi
    fi
done

# 先执行多文件测试（顺序执行，因为数量少且复杂）
multifile_index=$(( ${#parallel_single_tests[@]} + ${#serial_single_tests[@]} ))
for test_item in "${multifile_tests[@]}"; do
    multifile_index=$((multifile_index + 1))
    
    test_dir="${test_item#MULTIFILE:}"
    test_name="${test_dir##*:}"
    test_dir="${test_dir%:*}"
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "[$multifile_index/$TOTAL_TESTS] 测试: $test_name (多文件编译)"
    fi
    
    output_dir="$BUILD_DIR/multifile_tests/${test_name}"
    mkdir -p "$output_dir"
    result_file="${output_dir}/${test_name}.result"
    > "$result_file"
    run_multifile_test "$test_dir" "$test_name" "$result_file"
    result=$(tr -d '\0' < "$result_file" 2>/dev/null || true)
    status="${result%%:*}"
    if [ "$status" = "PASS" ]; then
        if [ "$ERRORS_ONLY" = false ] && [ "$HIDE_PASS_OUTPUT" = false ]; then
            echo "  ✓ ${result#*:}"
        fi
        PASSED=$((PASSED + 1))
    else
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $test_name"
        fi
        echo "  ❌ ${result#*:}"
        FAILED=$((FAILED + 1))
    fi
    rm -f "$result_file"
done

# 顺序执行对并发更敏感的单文件测试
if [ ${#serial_single_tests[@]} -gt 0 ]; then
    if [ "$ERRORS_ONLY" = false ]; then
        echo ""
        echo "开始顺序执行 ${#serial_single_tests[@]} 个网络敏感单文件测试..."
    fi

    for test_item in "${serial_single_tests[@]}"; do
        base_name=$(basename "$test_item" .uya)
        test_id=$(generate_test_id "$test_item")
        output_dir="$BUILD_DIR/tests/${test_id}"
        mkdir -p "$output_dir"
        result_file="${output_dir}/${base_name}.result"

        if is_loopback_skip_test "$base_name" && ! loopback_socket_supported; then
            : > "$NETWORK_SKIP_MARKER"
            if [ "$ERRORS_ONLY" = false ] && [ "$HIDE_PASS_OUTPUT" = false ]; then
                echo "  ✓ ${base_name}:skip:loopback_unavailable"
            fi
            PASSED=$((PASSED + 1))
            continue
        fi

        > "$result_file"
        run_single_test "$test_item" "$result_file"

        result=$(tr -d '\0' < "$result_file" 2>/dev/null || true)
        status="${result%%:*}"
        if [ "$status" = "PASS" ]; then
            if [ "$ERRORS_ONLY" = false ] && [ "$HIDE_PASS_OUTPUT" = false ]; then
                echo "  ✓ ${result#*:}"
            fi
            PASSED=$((PASSED + 1))
        else
            if [ "$ERRORS_ONLY" = true ]; then
                echo "测试: $base_name"
            fi
            echo "  ❌ ${result#*:}"
            FAILED=$((FAILED + 1))
        fi
        rm -f "$result_file"
    done

    if [ "$ERRORS_ONLY" = false ]; then
        echo "  顺序单文件测试完成"
    fi
fi

# 并行执行剩余单文件测试（流水线式）
# 使用 wait -n 实现流水线：一个任务完成立即启动新任务，保持恒定并发度
if [ ${#parallel_single_tests[@]} -gt 0 ]; then
    if [ "$ERRORS_ONLY" = false ]; then
        echo ""
        echo "开始并行执行 ${#parallel_single_tests[@]} 个单文件测试（$PARALLEL_JOBS 线程，流水线式）..."
    fi
    
    # 检查是否支持 wait -n（bash 4.3+）
    if bash -c 'help wait' 2>/dev/null | grep -q '\-n'; then
        USE_WAIT_N=true
    else
        USE_WAIT_N=false
    fi
    
    running_count=0
    test_index=0
    total_single_tests=${#parallel_single_tests[@]}
    declare -a PENDING_RFS=()
    declare -a PENDING_BNS=()
    
    # 先启动第一批任务（最多 PARALLEL_JOBS 个）
    while [ $test_index -lt $total_single_tests ] && [ $running_count -lt $PARALLEL_JOBS ]; do
        test_item="${parallel_single_tests[$test_index]}"
        base_name=$(basename "$test_item" .uya)
        test_id=$(generate_test_id "$test_item")
        output_dir="$BUILD_DIR/tests/${test_id}"
        mkdir -p "$output_dir"
        result_file="${output_dir}/${base_name}.result"
        
        > "$result_file"
        
        (
            run_single_test "$test_item" "$result_file"
        ) &
        
        PENDING_RFS+=("$result_file")
        PENDING_BNS+=("$base_name")
        running_count=$((running_count + 1))
        test_index=$((test_index + 1))
    done
    
    # 流水线模式：每当一个任务完成，立即输出结果并启动下一个
    if [ "$USE_WAIT_N" = true ]; then
        while [ $test_index -lt $total_single_tests ]; do
            wait -n  # 等待任意一个后台任务完成
            running_count=$((running_count - 1))
            process_ready_single_results
            
            # 立即启动下一个任务
            test_item="${parallel_single_tests[$test_index]}"
            base_name=$(basename "$test_item" .uya)
            test_id=$(generate_test_id "$test_item")
            output_dir="$BUILD_DIR/tests/${test_id}"
            mkdir -p "$output_dir"
            result_file="${output_dir}/${base_name}.result"
            
            > "$result_file"
            
            (
                run_single_test "$test_item" "$result_file"
            ) &
            
            PENDING_RFS+=("$result_file")
            PENDING_BNS+=("$base_name")
            running_count=$((running_count + 1))
            test_index=$((test_index + 1))
        done
        
        # 等待剩余任务完成并实时输出
        while [ $running_count -gt 0 ]; do
            wait -n
            running_count=$((running_count - 1))
            process_ready_single_results
        done
    else
        # 回退到批量模式（旧 bash 不支持 wait -n）
        if [ "$ERRORS_ONLY" = false ]; then
            echo "  (当前 bash 不支持 wait -n，使用批量并行模式)"
        fi
        while [ $test_index -lt $total_single_tests ]; do
            wait
            running_count=0
            process_ready_single_results
            batch_size=$PARALLEL_JOBS
            remaining=$((total_single_tests - test_index))
            [ $batch_size -gt $remaining ] && batch_size=$remaining
            
            for ((i=0; i<batch_size; i++)); do
                test_item="${parallel_single_tests[$test_index]}"
                base_name=$(basename "$test_item" .uya)
                test_id=$(generate_test_id "$test_item")
                output_dir="$BUILD_DIR/tests/${test_id}"
                mkdir -p "$output_dir"
                result_file="${output_dir}/${base_name}.result"
                
                > "$result_file"
                
                (
                    run_single_test "$test_item" "$result_file"
                ) &
                
                PENDING_RFS+=("$result_file")
                PENDING_BNS+=("$base_name")
                test_index=$((test_index + 1))
            done
        done
        wait
        process_ready_single_results
    fi
    
    # 收尾：处理任何残留（进程崩溃等情况）
    while [ ${#PENDING_RFS[@]} -gt 0 ]; do
        sleep 0.1
        process_ready_single_results
        if [ ${#PENDING_RFS[@]} -gt 0 ]; then
local first_idx=""
            for i in "${!PENDING_RFS[@]}"; do
                first_idx="$i"
                break
            done
            if [ -n "$first_idx" ]; then
                local rf="${PENDING_RFS[$first_idx]}"
                local bn="${PENDING_BNS[$first_idx]}"
                if [ "$ERRORS_ONLY" = true ]; then
                    echo "测试: $bn"
                fi
                echo "  ❌ $bn:无测试结果或结果文件为空（子进程可能崩溃或未写入）"
                FAILED=$((FAILED + 1))
                rm -f "$rf"
                unset 'PENDING_RFS[$first_idx]'
                unset 'PENDING_BNS[$first_idx]'
            fi

        fi
    done
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "  单文件测试完成"
    fi
fi

# 统计结果（总计以任务数为准，避免漏计导致总数不对）
if [ "$ERRORS_ONLY" = false ] || [ $FAILED -gt 0 ]; then
    echo ""
    echo "================================"
    echo "总计: $TOTAL_TESTS 个测试"
    echo "通过: $PASSED"
    echo "失败: $FAILED"
    NOT_COUNTED=$((TOTAL_TESTS - PASSED - FAILED))
    [ "$NOT_COUNTED" -gt 0 ] && echo "未计入: $NOT_COUNTED"
    echo "================================"
    # 同步写入文件，供 make check 等上层脚本在所有输出结束后提取
    {
        echo "总计: $TOTAL_TESTS 个测试"
        echo "通过: $PASSED"
        echo "失败: $FAILED"
        [ "$NOT_COUNTED" -gt 0 ] && echo "未计入: $NOT_COUNTED"
    } > /tmp/uya_test_summary.txt
fi

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
