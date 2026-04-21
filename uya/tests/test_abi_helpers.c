// ABI 测试辅助 C 函数
// 用于验证 Uya 代码与 C 代码的 ABI 兼容性

#include <stdint.h>

// 小结构体（8字节）
typedef struct {
    int32_t x;
    int32_t y;
} SmallStruct;

// 中等结构体（16字节）
typedef struct {
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
} MediumStruct;

// 大结构体（24字节）
typedef struct {
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
    int32_t e;
    int32_t f;
} LargeStruct;

// 测试 12: C 函数 - 小结构体参数（寄存器传递）
int32_t c_small_struct_param(SmallStruct s) {
    return s.x + s.y;
}

// 测试 13: C 函数 - 中等结构体参数（寄存器传递，x86-64 System V）
int32_t c_medium_struct_param(MediumStruct m) {
    return m.a + m.b + m.c + m.d;
}

// 测试 14: C 函数 - 大结构体参数（指针传递）
// 注意：根据 x86-64 System V ABI，大结构体（>16字节）必须通过指针传递
int32_t c_large_struct_param(LargeStruct *l) {
    return l->a + l->b + l->c + l->d + l->e + l->f;
}

// 测试 15: C 函数 - 小结构体返回值（寄存器返回）
SmallStruct c_small_struct_return(void) {
    SmallStruct s = { .x = 50, .y = 60 };
    return s;
}

// 测试 16: C 函数 - 中等结构体返回值（寄存器返回，x86-64 System V）
MediumStruct c_medium_struct_return(void) {
    MediumStruct m = { .a = 11, .b = 22, .c = 33, .d = 44 };
    return m;
}

// 测试 17: C 函数 - 大结构体返回值（sret 指针返回）
LargeStruct c_large_struct_return(void) {
    LargeStruct l = { .a = 1, .b = 2, .c = 3, .d = 4, .e = 5, .f = 6 };
    return l;
}

// 测试 18: C 函数 - 混合参数
int32_t c_mixed_params(int32_t a, SmallStruct s, int32_t b) {
    return a + s.x + s.y + b;
}

