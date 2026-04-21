#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/arena.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 测试基本分配功能
void test_basic_alloc(void) {
    printf("测试基本分配功能...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 分配一些内存
    int *p1 = (int *)arena_alloc(&arena, sizeof(int));
    assert(p1 != NULL);
    *p1 = 42;
    assert(*p1 == 42);
    
    int *p2 = (int *)arena_alloc(&arena, sizeof(int));
    assert(p2 != NULL);
    *p2 = 100;
    assert(*p2 == 100);
    
    // 验证两次分配的内存不同
    assert(p1 != p2);
    
    // 验证之前分配的值仍然有效
    assert(*p1 == 42);
    assert(*p2 == 100);
    
    printf("  ✓ 基本分配测试通过\n");
}

// 测试重置功能
void test_reset(void) {
    printf("测试重置功能...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 分配一些内存并写入值
    int *p1 = (int *)arena_alloc(&arena, sizeof(int));
    assert(p1 != NULL);
    *p1 = 42;
    
    size_t offset_before = arena.offset;
    assert(offset_before > 0);
    
    // 重置 Arena
    arena_reset(&arena);
    assert(arena.offset == 0);
    
    // 重新分配，应该从开始位置分配
    int *p2 = (int *)arena_alloc(&arena, sizeof(int));
    assert(p2 != NULL);
    
    // 如果重置正确，新分配的内存应该在相同位置（或至少偏移应该小于之前的）
    // 注意：由于内存对齐，p1 和 p2 可能不完全相同，但 offset 应该重置了
    assert(arena.offset <= offset_before);
    
    printf("  ✓ 重置测试通过\n");
}

// 测试内存对齐
void test_alignment(void) {
    printf("测试内存对齐...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 分配不同大小的内存，验证对齐
    char *p1 = (char *)arena_alloc(&arena, 1);
    assert(p1 != NULL);
    assert((uintptr_t)p1 % 8 == 0);  // 应该对齐到 8 字节
    
    int *p2 = (int *)arena_alloc(&arena, sizeof(int));
    assert(p2 != NULL);
    assert((uintptr_t)p2 % 8 == 0);  // 应该对齐到 8 字节
    
    double *p3 = (double *)arena_alloc(&arena, sizeof(double));
    assert(p3 != NULL);
    assert((uintptr_t)p3 % 8 == 0);  // 应该对齐到 8 字节
    
    printf("  ✓ 内存对齐测试通过\n");
}

// 测试分配失败情况（空间不足）
void test_alloc_failure(void) {
    printf("测试分配失败情况...\n");
    
    // 使用小缓冲区测试
    uint8_t small_buffer[100];
    Arena arena;
    arena_init(&arena, small_buffer, sizeof(small_buffer));
    
    // 分配超过缓冲区大小的内存，应该返回 NULL
    void *p = arena_alloc(&arena, sizeof(small_buffer) + 1);
    assert(p == NULL);
    
    printf("  ✓ 分配失败测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Arena 分配器测试...\n\n");
    
    test_basic_alloc();
    test_reset();
    test_alignment();
    test_alloc_failure();
    
    printf("\n所有测试通过！\n");
    return 0;
}

