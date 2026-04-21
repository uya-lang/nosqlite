#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/checker.h"
#include "../src/parser.h"
#include "../src/lexer.h"
#include "../src/arena.h"
#include "../src/ast.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 辅助函数：解析源代码并返回AST
static ASTNode *parse_source(const char *source, Arena *arena) {
    Lexer lexer;
    lexer_init(&lexer, source, strlen(source), "test.uya", arena);
    
    Parser parser;
    parser_init(&parser, &lexer, arena);
    
    return parser_parse(&parser);
}

// 测试 Checker 初始化
void test_checker_init(void) {
    printf("测试 Checker 初始化...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    int result = checker_init(&checker, &arena);
    
    assert(result == 0);
    assert(checker.arena == &arena);
    assert(checker.scope_level == 0);
    assert(checker.error_count == 0);
    assert(checker.program_node == NULL);
    
    printf("  ✓ Checker 初始化测试通过\n");
}

// 测试空程序类型检查
void test_check_empty_program(void) {
    printf("测试空程序类型检查...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    ASTNode *program = parse_source("", &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 空程序类型检查测试通过\n");
}

// 测试变量声明类型检查（正确情况）
void test_check_var_decl_correct(void) {
    printf("测试变量声明类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: i32 = 10; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 变量声明类型检查（正确情况）测试通过\n");
}

// 测试变量声明类型检查（类型不匹配）
void test_check_var_decl_type_mismatch(void) {
    printf("测试变量声明类型检查（类型不匹配）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: i32 = true; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ 变量声明类型检查（类型不匹配）测试通过\n");
}

// 测试函数调用类型检查（正确情况）
void test_check_function_call_correct(void) {
    printf("测试函数调用类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "fn add(a: i32, b: i32) i32 { return a + b; }\n"
        "fn main() i32 { const x: i32 = add(10, 20); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 函数调用类型检查（正确情况）测试通过\n");
}

// 测试函数调用类型检查（参数个数不匹配）
void test_check_function_call_arg_count_mismatch(void) {
    printf("测试函数调用类型检查（参数个数不匹配）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "fn add(a: i32, b: i32) i32 { return a + b; }\n"
        "fn main() i32 { const x: i32 = add(10); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有参数个数错误
    
    printf("  ✓ 函数调用类型检查（参数个数不匹配）测试通过\n");
}

// 测试函数调用类型检查（参数类型不匹配）
void test_check_function_call_arg_type_mismatch(void) {
    printf("测试函数调用类型检查（参数类型不匹配）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "fn add(a: i32, b: i32) i32 { return a + b; }\n"
        "fn main() i32 { const x: i32 = add(10, true); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有参数类型错误
    
    printf("  ✓ 函数调用类型检查（参数类型不匹配）测试通过\n");
}

// 测试结构体类型检查
void test_check_struct_type(void) {
    printf("测试结构体类型检查...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "struct Point { x: i32, y: i32 }\n"
        "fn main() i32 { const p: Point = Point{ x: 10, y: 20 }; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 结构体类型检查测试通过\n");
}

// 测试字段访问类型检查
void test_check_member_access(void) {
    printf("测试字段访问类型检查...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "struct Point { x: i32, y: i32 }\n"
        "fn main() i32 { const p: Point = Point{ x: 10, y: 20 }; const x: i32 = p.x; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 字段访问类型检查测试通过\n");
}

// 测试数组访问类型检查
void test_check_array_access(void) {
    printf("测试数组访问类型检查...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "fn main() i32 { var arr: [i32: 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; var x: i32 = arr[0]; return x; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 数组访问类型检查测试通过\n");
}

// 测试算术运算符类型检查（正确情况）
void test_check_arithmetic_operator_correct(void) {
    printf("测试算术运算符类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: i32 = 10 + 20; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 算术运算符类型检查（正确情况）测试通过\n");
}

// 测试算术运算符类型检查（类型错误）
void test_check_arithmetic_operator_type_error(void) {
    printf("测试算术运算符类型检查（类型错误）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: i32 = true + 20; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ 算术运算符类型检查（类型错误）测试通过\n");
}

// 测试比较运算符类型检查（正确情况）
void test_check_comparison_operator_correct(void) {
    printf("测试比较运算符类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: bool = 10 < 20; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 比较运算符类型检查（正确情况）测试通过\n");
}

// 测试比较运算符类型检查（类型不匹配）
void test_check_comparison_operator_type_mismatch(void) {
    printf("测试比较运算符类型检查（类型不匹配）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: bool = 10 < true; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ 比较运算符类型检查（类型不匹配）测试通过\n");
}

// 测试逻辑运算符类型检查（正确情况）
void test_check_logical_operator_correct(void) {
    printf("测试逻辑运算符类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: bool = true && false; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 逻辑运算符类型检查（正确情况）测试通过\n");
}

// 测试逻辑运算符类型检查（类型错误）
void test_check_logical_operator_type_error(void) {
    printf("测试逻辑运算符类型检查（类型错误）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: bool = 10 && false; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ 逻辑运算符类型检查（类型错误）测试通过\n");
}

// 测试if语句条件类型检查（正确情况）
void test_check_if_condition_correct(void) {
    printf("测试if语句条件类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { if true { } return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ if语句条件类型检查（正确情况）测试通过\n");
}

// 测试if语句条件类型检查（类型错误）
void test_check_if_condition_type_error(void) {
    printf("测试if语句条件类型检查（类型错误）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { if 10 { } return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ if语句条件类型检查（类型错误）测试通过\n");
}

// 测试while语句条件类型检查（正确情况）
void test_check_while_condition_correct(void) {
    printf("测试while语句条件类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { while false { } return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ while语句条件类型检查（正确情况）测试通过\n");
}

// 测试while语句条件类型检查（类型错误）
void test_check_while_condition_type_error(void) {
    printf("测试while语句条件类型检查（类型错误）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { while 10 { } return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ while语句条件类型检查（类型错误）测试通过\n");
}

// 测试赋值语句（const变量不能赋值）
void test_check_assign_to_const(void) {
    printf("测试赋值语句（const变量不能赋值）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { const x: i32 = 10; x = 20; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有错误（const变量不能赋值）
    
    printf("  ✓ 赋值语句（const变量不能赋值）测试通过\n");
}

// 测试赋值语句（var变量可以赋值）
void test_check_assign_to_var(void) {
    printf("测试赋值语句（var变量可以赋值）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { var x: i32 = 10; x = 20; return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 赋值语句（var变量可以赋值）测试通过\n");
}

// 测试extern函数声明类型检查（正确情况）
void test_check_extern_function_decl(void) {
    printf("测试extern函数声明类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "extern fn add(a: i32, b: i32) i32;";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ extern函数声明类型检查测试通过\n");
}

// 测试调用extern函数的类型检查（正确情况）
void test_check_extern_function_call(void) {
    printf("测试调用extern函数的类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "extern fn add(a: i32, b: i32) i32;\n"
        "fn main() i32 { const x: i32 = add(10, 20); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 调用extern函数的类型检查测试通过\n");
}

// 测试调用extern函数的类型检查（参数类型不匹配）
void test_check_extern_function_call_type_mismatch(void) {
    printf("测试调用extern函数的类型检查（参数类型不匹配）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "extern fn add(a: i32, b: i32) i32;\n"
        "fn main() i32 { const x: i32 = add(10, true); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ 调用extern函数的类型检查（参数类型不匹配）测试通过\n");
}

// 测试可变参数函数声明类型检查（正确情况）
void test_check_varargs_function_decl(void) {
    printf("测试可变参数函数声明类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "extern fn printf(fmt: *byte, ...) i32;";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 可变参数函数声明类型检查测试通过\n");
}

// 测试调用可变参数函数的类型检查（正确情况）
void test_check_varargs_function_call(void) {
    printf("测试调用可变参数函数的类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "extern fn printf(fmt: *byte, ...) i32;\n"
        "fn main() i32 { const x: i32 = printf(\"test\"); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ 调用可变参数函数的类型检查测试通过\n");
}

// 测试调用可变参数函数的类型检查（参数不足）
void test_check_varargs_function_call_insufficient_args(void) {
    printf("测试调用可变参数函数的类型检查（参数不足）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = 
        "extern fn printf(fmt: *byte, ...) i32;\n"
        "fn main() i32 { const x: i32 = printf(); return 0; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有错误（参数不足）
    
    printf("  ✓ 调用可变参数函数的类型检查（参数不足）测试通过\n");
}

// 测试 len 表达式类型检查（正确情况）
void test_check_len_expr_correct(void) {
    printf("测试 len 表达式类型检查（正确情况）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { var arr: [i32: 5] = [1, 2, 3, 4, 5]; const len_val: i32 = len(arr); return len_val; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) == 0);
    
    printf("  ✓ len 表达式类型检查（正确情况）测试通过\n");
}

// 测试 len 表达式类型检查（参数不是数组类型）
void test_check_len_expr_type_error(void) {
    printf("测试 len 表达式类型检查（参数不是数组类型）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    TypeChecker checker;
    checker_init(&checker, &arena);
    
    const char *source = "fn main() i32 { var x: i32 = 10; const len_val: i32 = len(x); return len_val; }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    int result = checker_check(&checker, program);
    assert(result == 0);
    assert(checker_get_error_count(&checker) > 0);  // 应该有类型错误
    
    printf("  ✓ len 表达式类型检查（参数不是数组类型）测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Checker 测试...\n\n");
    
    test_checker_init();
    test_check_empty_program();
    test_check_var_decl_correct();
    test_check_var_decl_type_mismatch();
    test_check_function_call_correct();
    test_check_function_call_arg_count_mismatch();
    test_check_function_call_arg_type_mismatch();
    test_check_struct_type();
    test_check_member_access();
    test_check_array_access();
    test_check_arithmetic_operator_correct();
    test_check_arithmetic_operator_type_error();
    test_check_comparison_operator_correct();
    test_check_comparison_operator_type_mismatch();
    test_check_logical_operator_correct();
    test_check_logical_operator_type_error();
    test_check_if_condition_correct();
    test_check_if_condition_type_error();
    test_check_while_condition_correct();
    test_check_while_condition_type_error();
    test_check_assign_to_const();
    test_check_assign_to_var();
    test_check_extern_function_decl();
    test_check_extern_function_call();
    test_check_extern_function_call_type_mismatch();
    test_check_varargs_function_decl();
    test_check_varargs_function_call();
    test_check_varargs_function_call_insufficient_args();
    test_check_len_expr_correct();
    test_check_len_expr_type_error();
    
    printf("\n所有测试通过！\n");
    
    return 0;
}
