#!/bin/bash
# test_outlibc.sh - 测试 --outlibc 功能
#
# 测试步骤：
# 1. 使用编译器生成 libuya.c 和 libuya.h
# 2. 验证生成的文件存在
# 3. 编译生成的库
# 4. 测试 C 程序使用生成的库

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPILER="$PROJECT_ROOT/bin/uya"
OUT_DIR="/tmp/uya_outlibc_test"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== 测试 --outlibc 功能 ===${NC}"

# 清理并创建输出目录
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# 步骤 1：生成 libuya.c 和 libuya.h
echo -e "${YELLOW}步骤 1：生成 libuya.c 和 libuya.h${NC}"
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}错误：编译器不存在，请先运行 make uya${NC}"
    exit 1
fi

# 检查编译器是否支持 --outlibc 选项
if "$COMPILER" --help 2>&1 | grep -q "outlibc"; then
    echo -e "${GREEN}编译器支持 --outlibc 选项${NC}"
else
    echo -e "${RED}编译器不支持 --outlibc 选项（功能待实现）${NC}"
    echo -e "${YELLOW}跳过测试，返回 0${NC}"
    exit 0
fi

# 运行 --outlibc
"$COMPILER" --outlibc "$OUT_DIR" --c99
if [ $? -ne 0 ]; then
    echo -e "${RED}错误：--outlibc 执行失败${NC}"
    exit 1
fi

# 步骤 2：验证生成的文件存在
echo -e "${YELLOW}步骤 2：验证生成的文件${NC}"
if [ -f "$OUT_DIR/libuya.h" ]; then
    echo -e "${GREEN}✓ libuya.h 已生成${NC}"
else
    echo -e "${RED}✗ libuya.h 未生成${NC}"
    exit 1
fi

if [ -f "$OUT_DIR/libuya.c" ]; then
    echo -e "${GREEN}✓ libuya.c 已生成${NC}"
else
    echo -e "${RED}✗ libuya.c 未生成${NC}"
    exit 1
fi

# 步骤 3：验证头文件内容
echo -e "${YELLOW}步骤 3：验证头文件内容${NC}"
if grep -q "typedef" "$OUT_DIR/libuya.h"; then
    echo -e "${GREEN}✓ libuya.h 包含类型定义${NC}"
else
    echo -e "${RED}✗ libuya.h 不包含类型定义${NC}"
    exit 1
fi

# 步骤 4：编译生成的库
echo -e "${YELLOW}步骤 4：编译生成的库${NC}"
cd "$OUT_DIR"
if gcc -c libuya.c -o libuya.o 2>&1; then
    echo -e "${GREEN}✓ libuya.c 编译成功${NC}"
else
    echo -e "${RED}✗ libuya.c 编译失败${NC}"
    exit 1
fi

# 步骤 5：创建测试程序
echo -e "${YELLOW}步骤 5：测试 C 程序使用生成的库${NC}"
cat > test_usage.c << 'EOF'
#include "libuya.h"

/* freestanding 模式入口点 */
void _start(void) {
    const char *s = "Hello, libuya!\n";
    uya_write(1, s, 15);
    uya_exit(0);
}
EOF

# 编译测试程序（freestanding 模式）
if gcc -nostdlib -ffreestanding test_usage.c libuya.o -o test_usage -lgcc 2>&1; then
    echo -e "${GREEN}✓ 测试程序编译成功（freestanding）${NC}"
else
    echo -e "${RED}✗ 测试程序编译失败${NC}"
    exit 1
fi

# 运行测试程序
if ./test_usage 2>&1 | grep -q "Hello"; then
    echo -e "${GREEN}✓ 测试程序运行成功${NC}"
else
    echo -e "${RED}✗ 测试程序运行失败${NC}"
    exit 1
fi

# 清理
cd "$PROJECT_ROOT"
rm -rf "$OUT_DIR"

echo -e "${GREEN}=== --outlibc 测试全部通过 ===${NC}"
exit 0
