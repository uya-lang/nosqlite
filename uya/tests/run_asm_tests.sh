#!/bin/bash

# run_asm_tests.sh - @asm 内联汇编测试运行脚本
# 自动运行所有 @asm 相关的测试并生成报告

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests"
BUILD_DIR="$PROJECT_ROOT/build"

# 统计变量
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 辅助函数
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}测试: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ 通过${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}✗ 失败: $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_skip() {
    echo -e "${YELLOW}⊘ 跳过: $1${NC}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

# 编译器检查
check_compiler() {
    print_header "检查编译器"
    
    if [ ! -f "$PROJECT_ROOT/bin/uya" ]; then
        echo -e "${RED}错误: 未找到编译器 $PROJECT_ROOT/bin/uya${NC}"
        echo -e "${YELLOW}请先编译编译器: cd compiler-c && make build${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 编译器已就绪${NC}"
}

# 编译测试文件
compile_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .uya)
    local c_file="$BUILD_DIR/${test_name}.c"
    local exe_file="$BUILD_DIR/${test_name}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_test "$test_name"
    
    # 编译到 C
    if ! "$PROJECT_ROOT/bin/uya" --c99 "$test_file" -o "$c_file" 2>&1; then
        print_fail "编译到 C 失败"
        return 1
    fi
    
    # 编译 C 到可执行文件
    if ! gcc -O2 -o "$exe_file" "$c_file" -lm 2>&1; then
        print_fail "编译 C 代码失败"
        return 1
    fi
    
    # 运行测试
    if ! "$exe_file" > /dev/null 2>&1; then
        print_fail "运行测试失败"
        return 1
    fi
    
    print_pass
    return 0
}

# 运行错误测试（应该编译失败）
compile_error_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .uya)
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_test "$test_name (错误测试)"
    
    # 应该编译失败
    if "$PROJECT_ROOT/bin/uya" --c99 "$test_file" > /dev/null 2>&1; then
        print_fail "应该编译失败但成功了"
        return 1
    fi
    
    print_pass
    return 0
}

# 主测试流程
main() {
    print_header "@asm 内联汇编测试套件"
    
    check_compiler
    
    # 1. 基础功能测试
    print_header "1. 基础功能测试"
    
    for test_file in "$TEST_DIR"/test_asm_basic.uya \
                     "$TEST_DIR"/test_asm_types.uya \
                     "$TEST_DIR"/test_asm_clobbers.uya; do
        if [ -f "$test_file" ]; then
            compile_test "$test_file"
        fi
    done
    
    # 2. 类型安全测试
    print_header "2. 类型安全测试"
    
    for test_file in "$TEST_DIR"/test_asm_type_safety.uya \
                     "$TEST_DIR"/test_asm_placeholder.uya; do
        if [ -f "$test_file" ]; then
            compile_test "$test_file"
        fi
    done
    
    # 3. 内存安全测试
    print_header "3. 内存安全测试"
    
    for test_file in "$TEST_DIR"/test_asm_memory_safety.uya \
                     "$TEST_DIR"/test_asm_edge_cases.uya; do
        if [ -f "$test_file" ]; then
            compile_test "$test_file"
        fi
    done
    
    # 4. 原子操作测试
    print_header "4. 原子操作测试"
    
    if [ -f "$TEST_DIR/test_asm_atomic.uya" ]; then
        compile_test "$TEST_DIR/test_asm_atomic.uya"
    fi
    
    # 5. 平台检测测试
    print_header "5. 平台检测测试"
    
    for test_file in "$TEST_DIR"/test_asm_platform.uya \
                     "$TEST_DIR"/test_asm_target.uya; do
        if [ -f "$test_file" ]; then
            compile_test "$test_file"
        fi
    done
    
    # 5.1 ARM64 平台测试
    print_header "5.1 ARM64 平台测试"
    
    if [ -f "$TEST_DIR/test_asm_arm64.uya" ]; then
        # 检测当前平台
        ARCH=$(uname -m)
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            echo -e "${GREEN}检测到 ARM64 平台，运行 ARM64 特定测试${NC}"
            compile_test "$TEST_DIR/test_asm_arm64.uya"
        else
            echo -e "${YELLOW}当前平台: $ARCH，跳过 ARM64 特定测试${NC}"
            print_skip "ARM64 测试（当前平台非 ARM64）"
        fi
    fi
    
    # 6. 系统调用测试
    print_header "6. 系统调用测试"
    
    if [ -f "$TEST_DIR/test_asm_syscall.uya" ]; then
        compile_test "$TEST_DIR/test_asm_syscall.uya"
    fi
    
    # 7. 代码生成测试
    print_header "7. 代码生成测试"
    
    for test_file in "$TEST_DIR"/test_asm_codegen.uya \
                     "$TEST_DIR"/test_asm_expressions.uya; do
        if [ -f "$test_file" ]; then
            compile_test "$test_file"
        fi
    done
    
    # 8. 错误测试（应该编译失败）
    print_header "8. 错误测试（应该编译失败）"
    
    for test_file in "$TEST_DIR"/error_asm_*.uya; do
        if [ -f "$test_file" ]; then
            compile_error_test "$test_file"
        fi
    done
    
    # 9. 性能基准测试（可选）
    print_header "9. 性能基准测试（可选）"
    
    for test_file in "$TEST_DIR"/bench_asm_*.uya; do
        if [ -f "$test_file" ]; then
            echo -e "${YELLOW}注意: 性能测试需要较长时间${NC}"
            read -p "运行性能测试? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                compile_test "$test_file"
            else
                print_skip "用户跳过性能测试"
            fi
        fi
    done
    
    # 10. 演示程序
    print_header "10. 演示程序"
    
    if [ -f "$PROJECT_ROOT/examples/demo_asm.uya" ]; then
        echo -e "${YELLOW}编译演示程序...${NC}"
        local demo_c="$BUILD_DIR/demo_asm.c"
        local demo_exe="$BUILD_DIR/demo_asm"
        
        if "$PROJECT_ROOT/bin/uya" --c99 "$PROJECT_ROOT/examples/demo_asm.uya" -o "$demo_c" 2>&1; then
            if gcc -O2 -o "$demo_exe" "$demo_c" -lm 2>&1; then
                echo -e "${GREEN}✓ 演示程序编译成功${NC}"
                echo -e "${YELLOW}运行演示程序:${NC}"
                echo -e "  $demo_exe"
            else
                echo -e "${RED}✗ 演示程序编译 C 代码失败${NC}"
            fi
        else
            echo -e "${RED}✗ 演示程序编译失败${NC}"
        fi
    fi
    
    # 生成测试报告
    print_header "测试报告"
    
    echo -e "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
    echo -e "${RED}失败: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}跳过: $SKIPPED_TESTS${NC}"
    
    local pass_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo -e "\n通过率: ${pass_rate}%"
    
    # 保存报告到文件
    cat > "$BUILD_DIR/test_report.txt" << EOF
@asm 内联汇编测试报告
生成时间: $(date)

总测试数: $TOTAL_TESTS
通过: $PASSED_TESTS
失败: $FAILED_TESTS
跳过: $SKIPPED_TESTS
通过率: ${pass_rate}%
EOF
    
    echo -e "\n${BLUE}测试报告已保存到: $BUILD_DIR/test_report.txt${NC}"
    
    # 返回退出码
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# 运行主函数
main "$@"
