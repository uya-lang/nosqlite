#include <stdio.h>

// 为 extern_function.uya 提供的外部函数实现
int add(int a, int b) {
    return a + b;
}

// 为 test_comprehensive_cast.uya 提供的外部函数实现
int tn(void* node) {
    return 1;  // 简单返回 1
}

int pt(const char* s) {
    printf("%s\n", s);
    return 1;
}

// 为 test_ffi_cast.uya 提供的外部函数实现
int test_ffi_ptr(void* ptr) {
    return 2;  // 简单返回 2
}

// 为 test_pointer_cast.uya 提供的外部函数实现
int process_data(void* data) {
    return 3;  // 简单返回 3
}

int print_int(int n) {
    printf("print_int: %d\n", n);
    return n;  // 返回 n 本身，这样测试可以验证返回值
}

// 为 test_simple_cast.uya 提供的外部函数实现
int proc(void* item) {
    return 4;  // 简单返回 4
}

int print(const char* s) {
    printf("%s", s);
    return 1;
}

/* test_extern_union.uya: extern union CValue 与 C 互操作（布局须与生成代码一致） */
union CValue {
    int i;
    double f;
};

void take_c_value(union CValue v) {
    (void)v;  /* 仅接收，不访问变体 */
}

union CValue make_c_value_i(int x) {
    union CValue u;
    u.i = x;
    return u;
}

union CValue make_c_value_f(double x) {
    union CValue u;
    u.f = x;
    return u;
}