#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/ast.h"
#include "../src/arena.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 辅助函数：从 Arena 复制字符串
// 参数：arena - Arena 分配器，str - 源字符串
// 返回：分配在 Arena 中的字符串指针，失败返回 NULL
static const char *arena_strdup(Arena *arena, const char *str) {
    if (arena == NULL || str == NULL) {
        return NULL;
    }
    
    size_t len = strlen(str) + 1;
    char *result = (char *)arena_alloc(arena, len);
    if (result == NULL) {
        return NULL;
    }
    
    memcpy(result, str, len);
    return result;
}

// 测试创建数字节点
void test_create_number_node(void) {
    printf("测试创建数字节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    ASTNode *node = ast_new_node(AST_NUMBER, 1, 1, &arena);
    assert(node != NULL);
    assert(node->type == AST_NUMBER);
    assert(node->line == 1);
    assert(node->column == 1);
    assert(node->data.number.value == 0);  // 初始值为 0
    
    // 设置数值
    node->data.number.value = 42;
    assert(node->data.number.value == 42);
    
    printf("  ✓ 数字节点创建测试通过\n");
}

// 测试创建标识符节点
void test_create_identifier_node(void) {
    printf("测试创建标识符节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    ASTNode *node = ast_new_node(AST_IDENTIFIER, 2, 5, &arena);
    assert(node != NULL);
    assert(node->type == AST_IDENTIFIER);
    assert(node->line == 2);
    assert(node->column == 5);
    assert(node->data.identifier.name == NULL);  // 初始值为 NULL
    
    // 设置名称（从 Arena 分配字符串）
    node->data.identifier.name = arena_strdup(&arena, "x");
    assert(node->data.identifier.name != NULL);
    assert(strcmp(node->data.identifier.name, "x") == 0);
    
    printf("  ✓ 标识符节点创建测试通过\n");
}

// 测试创建布尔节点
void test_create_bool_node(void) {
    printf("测试创建布尔节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 测试 true
    ASTNode *true_node = ast_new_node(AST_BOOL, 3, 1, &arena);
    assert(true_node != NULL);
    assert(true_node->type == AST_BOOL);
    true_node->data.bool_literal.value = 1;
    assert(true_node->data.bool_literal.value == 1);
    
    // 测试 false
    ASTNode *false_node = ast_new_node(AST_BOOL, 3, 10, &arena);
    assert(false_node != NULL);
    false_node->data.bool_literal.value = 0;
    assert(false_node->data.bool_literal.value == 0);
    
    printf("  ✓ 布尔节点创建测试通过\n");
}

// 测试创建二元表达式节点
void test_create_binary_expr_node(void) {
    printf("测试创建二元表达式节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 创建操作数
    ASTNode *left = ast_new_node(AST_NUMBER, 4, 1, &arena);
    left->data.number.value = 10;
    
    ASTNode *right = ast_new_node(AST_NUMBER, 4, 5, &arena);
    right->data.number.value = 20;
    
    // 创建二元表达式节点
    ASTNode *expr = ast_new_node(AST_BINARY_EXPR, 4, 3, &arena);
    assert(expr != NULL);
    assert(expr->type == AST_BINARY_EXPR);
    expr->data.binary_expr.left = left;
    expr->data.binary_expr.op = 43;  // 假设 '+' 的 Token 类型值（暂时用 ASCII 值）
    expr->data.binary_expr.right = right;
    
    assert(expr->data.binary_expr.left->data.number.value == 10);
    assert(expr->data.binary_expr.right->data.number.value == 20);
    
    printf("  ✓ 二元表达式节点创建测试通过\n");
}

// 测试创建函数声明节点
void test_create_fn_decl_node(void) {
    printf("测试创建函数声明节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    ASTNode *fn = ast_new_node(AST_FN_DECL, 5, 1, &arena);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.name == NULL);
    assert(fn->data.fn_decl.params == NULL);
    assert(fn->data.fn_decl.param_count == 0);
    assert(fn->data.fn_decl.return_type == NULL);
    assert(fn->data.fn_decl.body == NULL);
    
    // 设置函数名称
    fn->data.fn_decl.name = arena_strdup(&arena, "add");
    assert(fn->data.fn_decl.name != NULL);
    assert(strcmp(fn->data.fn_decl.name, "add") == 0);
    
    printf("  ✓ 函数声明节点创建测试通过\n");
}

// 测试创建变量声明节点
void test_create_var_decl_node(void) {
    printf("测试创建变量声明节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 测试 const 变量
    ASTNode *const_var = ast_new_node(AST_VAR_DECL, 6, 1, &arena);
    assert(const_var != NULL);
    const_var->data.var_decl.name = arena_strdup(&arena, "x");
    const_var->data.var_decl.is_const = 1;
    assert(const_var->data.var_decl.is_const == 1);
    
    // 测试 var 变量
    ASTNode *var = ast_new_node(AST_VAR_DECL, 7, 1, &arena);
    assert(var != NULL);
    var->data.var_decl.name = arena_strdup(&arena, "y");
    var->data.var_decl.is_const = 0;
    assert(var->data.var_decl.is_const == 0);
    
    printf("  ✓ 变量声明节点创建测试通过\n");
}

// 测试创建程序节点
void test_create_program_node(void) {
    printf("测试创建程序节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    ASTNode *program = ast_new_node(AST_PROGRAM, 0, 0, &arena);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decls == NULL);
    assert(program->data.program.decl_count == 0);
    
    printf("  ✓ 程序节点创建测试通过\n");
}

// 测试创建类型节点
void test_create_type_node(void) {
    printf("测试创建类型节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 测试基本类型
    ASTNode *i32_type = ast_new_node(AST_TYPE_NAMED, 8, 1, &arena);
    assert(i32_type != NULL);
    i32_type->data.type_named.name = arena_strdup(&arena, "i32");
    assert(strcmp(i32_type->data.type_named.name, "i32") == 0);
    
    ASTNode *bool_type = ast_new_node(AST_TYPE_NAMED, 8, 10, &arena);
    bool_type->data.type_named.name = arena_strdup(&arena, "bool");
    assert(strcmp(bool_type->data.type_named.name, "bool") == 0);
    
    printf("  ✓ 类型节点创建测试通过\n");
}

// 测试创建指针类型节点
void test_create_pointer_type_node(void) {
    printf("测试创建指针类型节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 创建基础类型节点（i32）
    ASTNode *i32_type = ast_new_node(AST_TYPE_NAMED, 1, 1, &arena);
    assert(i32_type != NULL);
    i32_type->data.type_named.name = arena_strdup(&arena, "i32");
    
    // 测试普通指针类型（&i32）
    ASTNode *pointer_type = ast_new_node(AST_TYPE_POINTER, 1, 2, &arena);
    assert(pointer_type != NULL);
    assert(pointer_type->type == AST_TYPE_POINTER);
    assert(pointer_type->line == 1);
    assert(pointer_type->column == 2);
    assert(pointer_type->data.type_pointer.pointed_type == NULL);  // 初始值为 NULL
    assert(pointer_type->data.type_pointer.is_ffi_pointer == 0);   // 初始值为 0（普通指针）
    
    // 设置指向的类型和 FFI 标记
    pointer_type->data.type_pointer.pointed_type = i32_type;
    pointer_type->data.type_pointer.is_ffi_pointer = 0;  // 普通指针 &i32
    assert(pointer_type->data.type_pointer.pointed_type == i32_type);
    assert(pointer_type->data.type_pointer.is_ffi_pointer == 0);
    
    // 测试 FFI 指针类型（*i32）
    ASTNode *ffi_pointer_type = ast_new_node(AST_TYPE_POINTER, 1, 10, &arena);
    assert(ffi_pointer_type != NULL);
    ffi_pointer_type->data.type_pointer.pointed_type = i32_type;
    ffi_pointer_type->data.type_pointer.is_ffi_pointer = 1;  // FFI 指针 *i32
    assert(ffi_pointer_type->data.type_pointer.is_ffi_pointer == 1);
    
    printf("  ✓ 指针类型节点创建测试通过\n");
}

// 测试创建数组类型节点
void test_create_array_type_node(void) {
    printf("测试创建数组类型节点...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 创建基础类型节点（i32）
    ASTNode *i32_type = ast_new_node(AST_TYPE_NAMED, 1, 1, &arena);
    assert(i32_type != NULL);
    i32_type->data.type_named.name = arena_strdup(&arena, "i32");
    
    // 创建数组大小表达式节点（数字字面量 10）
    ASTNode *size_expr = ast_new_node(AST_NUMBER, 1, 6, &arena);
    assert(size_expr != NULL);
    size_expr->data.number.value = 10;
    
    // 测试数组类型（[i32: 10]）
    ASTNode *array_type = ast_new_node(AST_TYPE_ARRAY, 1, 2, &arena);
    assert(array_type != NULL);
    assert(array_type->type == AST_TYPE_ARRAY);
    assert(array_type->line == 1);
    assert(array_type->column == 2);
    assert(array_type->data.type_array.element_type == NULL);  // 初始值为 NULL
    assert(array_type->data.type_array.size_expr == NULL);     // 初始值为 NULL
    
    // 设置元素类型和大小表达式
    array_type->data.type_array.element_type = i32_type;
    array_type->data.type_array.size_expr = size_expr;
    assert(array_type->data.type_array.element_type == i32_type);
    assert(array_type->data.type_array.size_expr == size_expr);
    assert(array_type->data.type_array.size_expr->data.number.value == 10);
    
    printf("  ✓ 数组类型节点创建测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 AST 节点创建测试...\n\n");
    
    test_create_number_node();
    test_create_identifier_node();
    test_create_bool_node();
    test_create_binary_expr_node();
    test_create_fn_decl_node();
    test_create_var_decl_node();
    test_create_program_node();
    test_create_type_node();
    test_create_pointer_type_node();
    test_create_array_type_node();
    
    printf("\n所有测试通过！\n");
    return 0;
}

