#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/parser.h"
#include "../src/lexer.h"
#include "../src/arena.h"
#include "../src/ast.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 测试 Parser 初始化
void test_parser_init(void) {
    printf("测试 Parser 初始化...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { return 0; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    int result = parser_init(&parser, &lexer, &arena);
    
    assert(result == 0);
    assert(parser.lexer == &lexer);
    assert(parser.arena == &arena);
    assert(parser.current_token != NULL);
    
    printf("  ✓ Parser 初始化测试通过\n");
}

// 测试解析空程序
void test_parse_empty_program(void) {
    printf("测试解析空程序...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 0);
    
    printf("  ✓ 空程序解析测试通过\n");
}

// 测试解析函数声明
void test_parse_function(void) {
    printf("测试解析函数声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn add(a: i32, b: i32) i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(strcmp(fn->data.fn_decl.name, "add") == 0);
    assert(fn->data.fn_decl.param_count == 2);
    assert(fn->data.fn_decl.return_type != NULL);
    assert(strcmp(fn->data.fn_decl.return_type->data.type_named.name, "i32") == 0);
    assert(fn->data.fn_decl.body != NULL);
    assert(fn->data.fn_decl.body->type == AST_BLOCK);
    
    // 检查参数
    assert(fn->data.fn_decl.params != NULL);
    assert(fn->data.fn_decl.params[0]->type == AST_VAR_DECL);
    assert(strcmp(fn->data.fn_decl.params[0]->data.var_decl.name, "a") == 0);
    assert(fn->data.fn_decl.params[1]->type == AST_VAR_DECL);
    assert(strcmp(fn->data.fn_decl.params[1]->data.var_decl.name, "b") == 0);
    
    printf("  ✓ 函数声明解析测试通过\n");
}

// 测试解析无参函数
void test_parse_function_no_params(void) {
    printf("测试解析无参函数...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(strcmp(fn->data.fn_decl.name, "main") == 0);
    assert(fn->data.fn_decl.param_count == 0);
    
    printf("  ✓ 无参函数解析测试通过\n");
}

// 测试解析结构体声明
void test_parse_struct(void) {
    printf("测试解析结构体声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "struct Point { x: i32, y: i32 }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *struct_decl = parser_parse_struct(&parser);
    assert(struct_decl != NULL);
    assert(struct_decl->type == AST_STRUCT_DECL);
    assert(strcmp(struct_decl->data.struct_decl.name, "Point") == 0);
    assert(struct_decl->data.struct_decl.field_count == 2);
    
    // 检查字段
    assert(struct_decl->data.struct_decl.fields != NULL);
    assert(struct_decl->data.struct_decl.fields[0]->type == AST_VAR_DECL);
    assert(strcmp(struct_decl->data.struct_decl.fields[0]->data.var_decl.name, "x") == 0);
    assert(struct_decl->data.struct_decl.fields[1]->type == AST_VAR_DECL);
    assert(strcmp(struct_decl->data.struct_decl.fields[1]->data.var_decl.name, "y") == 0);
    
    printf("  ✓ 结构体声明解析测试通过\n");
}

// 测试解析程序（包含函数和结构体）
void test_parse_program_with_declarations(void) {
    printf("测试解析程序（包含函数和结构体）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "struct Point { x: i32, y: i32 } fn main() i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 2);
    
    // 检查第一个声明（结构体）
    assert(program->data.program.decls[0]->type == AST_STRUCT_DECL);
    assert(strcmp(program->data.program.decls[0]->data.struct_decl.name, "Point") == 0);
    
    // 检查第二个声明（函数）
    assert(program->data.program.decls[1]->type == AST_FN_DECL);
    assert(strcmp(program->data.program.decls[1]->data.fn_decl.name, "main") == 0);
    
    printf("  ✓ 程序解析测试通过\n");
}

// 测试解析 return 语句
void test_parse_return_stmt(void) {
    printf("测试解析 return 语句...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "return 0;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_RETURN_STMT);
    assert(stmt->data.return_stmt.expr != NULL);
    assert(stmt->data.return_stmt.expr->type == AST_NUMBER);
    assert(stmt->data.return_stmt.expr->data.number.value == 0);
    
    printf("  ✓ return 语句解析测试通过\n");
}

// 测试解析变量声明
void test_parse_var_decl(void) {
    printf("测试解析变量声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var x: i32 = 10;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(strcmp(stmt->data.var_decl.name, "x") == 0);
    assert(stmt->data.var_decl.is_const == 0);
    assert(stmt->data.var_decl.type != NULL);
    assert(strcmp(stmt->data.var_decl.type->data.type_named.name, "i32") == 0);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_NUMBER);
    assert(stmt->data.var_decl.init->data.number.value == 10);
    
    printf("  ✓ 变量声明解析测试通过\n");
}

// 测试解析函数体中的语句
void test_parse_function_with_statements(void) {
    printf("测试解析函数体中的语句...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { var x: i32 = 10; return x; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.body != NULL);
    assert(fn->data.fn_decl.body->type == AST_BLOCK);
    assert(fn->data.fn_decl.body->data.block.stmt_count == 2);
    
    // 检查第一个语句（变量声明）
    ASTNode *stmt1 = fn->data.fn_decl.body->data.block.stmts[0];
    assert(stmt1 != NULL);
    assert(stmt1->type == AST_VAR_DECL);
    
    // 检查第二个语句（return）
    ASTNode *stmt2 = fn->data.fn_decl.body->data.block.stmts[1];
    assert(stmt2 != NULL);
    assert(stmt2->type == AST_RETURN_STMT);
    
    printf("  ✓ 函数体语句解析测试通过\n");
}

// 测试解析二元表达式（算术运算符）
void test_parse_binary_arithmetic_expr(void) {
    printf("测试解析二元算术表达式...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var x: i32 = 10 + 20;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_BINARY_EXPR);
    assert(stmt->data.var_decl.init->data.binary_expr.op == TOKEN_PLUS);
    
    printf("  ✓ 二元算术表达式解析测试通过\n");
}

// 测试解析一元表达式
void test_parse_unary_expr(void) {
    printf("测试解析一元表达式...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var x: i32 = -10;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_UNARY_EXPR);
    assert(stmt->data.var_decl.init->data.unary_expr.op == TOKEN_MINUS);
    
    printf("  ✓ 一元表达式解析测试通过\n");
}

// 测试解析函数调用
void test_parse_function_call(void) {
    printf("测试解析函数调用...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var x: i32 = add(10, 20);";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_CALL_EXPR);
    assert(stmt->data.var_decl.init->data.call_expr.callee != NULL);
    assert(stmt->data.var_decl.init->data.call_expr.callee->type == AST_IDENTIFIER);
    assert(strcmp(stmt->data.var_decl.init->data.call_expr.callee->data.identifier.name, "add") == 0);
    assert(stmt->data.var_decl.init->data.call_expr.arg_count == 2);
    
    printf("  ✓ 函数调用解析测试通过\n");
}

// 测试解析结构体字面量
void test_parse_struct_literal(void) {
    printf("测试解析结构体字面量...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var p: Point = Point{ x: 10, y: 20 };";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_STRUCT_INIT);
    assert(strcmp(stmt->data.var_decl.init->data.struct_init.struct_name, "Point") == 0);
    assert(stmt->data.var_decl.init->data.struct_init.field_count == 2);
    
    printf("  ✓ 结构体字面量解析测试通过\n");
}

// 测试解析字段访问
void test_parse_member_access(void) {
    printf("测试解析字段访问...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "var x: i32 = p.x;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_VAR_DECL);
    assert(stmt->data.var_decl.init != NULL);
    assert(stmt->data.var_decl.init->type == AST_MEMBER_ACCESS);
    assert(stmt->data.var_decl.init->data.member_access.object != NULL);
    assert(stmt->data.var_decl.init->data.member_access.object->type == AST_IDENTIFIER);
    assert(strcmp(stmt->data.var_decl.init->data.member_access.object->data.identifier.name, "p") == 0);
    assert(strcmp(stmt->data.var_decl.init->data.member_access.field_name, "x") == 0);
    
    printf("  ✓ 字段访问解析测试通过\n");
}

// 测试解析赋值表达式
void test_parse_assign_expr(void) {
    printf("测试解析赋值表达式...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "x = 10;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *stmt = parser_parse_statement(&parser);
    assert(stmt != NULL);
    assert(stmt->type == AST_ASSIGN);
    assert(stmt->data.assign.dest != NULL);
    assert(stmt->data.assign.dest->type == AST_IDENTIFIER);
    assert(strcmp(stmt->data.assign.dest->data.identifier.name, "x") == 0);
    assert(stmt->data.assign.src != NULL);
    assert(stmt->data.assign.src->type == AST_NUMBER);
    assert(stmt->data.assign.src->data.number.value == 10);
    
    printf("  ✓ 赋值表达式解析测试通过\n");
}

// 测试解析extern函数声明（无参数）
void test_parse_extern_function_no_params(void) {
    printf("测试解析extern函数声明（无参数）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "extern fn printf() void;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *decl = parser_parse_declaration(&parser);
    assert(decl != NULL);
    assert(decl->type == AST_FN_DECL);
    assert(strcmp(decl->data.fn_decl.name, "printf") == 0);
    assert(decl->data.fn_decl.param_count == 0);
    assert(decl->data.fn_decl.return_type != NULL);
    assert(strcmp(decl->data.fn_decl.return_type->data.type_named.name, "void") == 0);
    assert(decl->data.fn_decl.body == NULL);  // extern函数没有函数体
    
    printf("  ✓ extern函数声明（无参数）解析测试通过\n");
}

// 测试解析extern函数声明（带参数）
void test_parse_extern_function_with_params(void) {
    printf("测试解析extern函数声明（带参数）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "extern fn add(a: i32, b: i32) i32;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *decl = parser_parse_declaration(&parser);
    assert(decl != NULL);
    assert(decl->type == AST_FN_DECL);
    assert(strcmp(decl->data.fn_decl.name, "add") == 0);
    assert(decl->data.fn_decl.param_count == 2);
    assert(decl->data.fn_decl.return_type != NULL);
    assert(strcmp(decl->data.fn_decl.return_type->data.type_named.name, "i32") == 0);
    assert(decl->data.fn_decl.body == NULL);  // extern函数没有函数体
    
    // 检查参数
    assert(decl->data.fn_decl.params != NULL);
    assert(decl->data.fn_decl.params[0]->type == AST_VAR_DECL);
    assert(strcmp(decl->data.fn_decl.params[0]->data.var_decl.name, "a") == 0);
    assert(decl->data.fn_decl.params[1]->type == AST_VAR_DECL);
    assert(strcmp(decl->data.fn_decl.params[1]->data.var_decl.name, "b") == 0);
    
    printf("  ✓ extern函数声明（带参数）解析测试通过\n");
}

// 测试解析可变参数extern函数声明
void test_parse_extern_function_varargs(void) {
    printf("测试解析可变参数extern函数声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "extern fn printf(fmt: *byte, ...) i32;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *decl = parser_parse_declaration(&parser);
    assert(decl != NULL);
    assert(decl->type == AST_FN_DECL);
    assert(strcmp(decl->data.fn_decl.name, "printf") == 0);
    assert(decl->data.fn_decl.param_count == 1);  // 只有一个固定参数
    assert(decl->data.fn_decl.is_varargs == 1);  // 是可变参数函数
    assert(decl->data.fn_decl.return_type != NULL);
    assert(strcmp(decl->data.fn_decl.return_type->data.type_named.name, "i32") == 0);
    assert(decl->data.fn_decl.body == NULL);  // extern函数没有函数体
    
    // 检查参数
    assert(decl->data.fn_decl.params != NULL);
    assert(decl->data.fn_decl.params[0]->type == AST_VAR_DECL);
    assert(strcmp(decl->data.fn_decl.params[0]->data.var_decl.name, "fmt") == 0);
    
    printf("  ✓ 可变参数extern函数声明解析测试通过\n");
}

// 测试解析包含extern函数声明的程序
void test_parse_program_with_extern_function(void) {
    printf("测试解析包含extern函数声明的程序...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "extern fn add(a: i32, b: i32) i32;\n"
                         "fn main() i32 {\n"
                         "    return add(1, 2);\n"
                         "}";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 2);
    
    // 检查第一个声明（extern函数）
    ASTNode *extern_decl = program->data.program.decls[0];
    assert(extern_decl != NULL);
    assert(extern_decl->type == AST_FN_DECL);
    assert(strcmp(extern_decl->data.fn_decl.name, "add") == 0);
    assert(extern_decl->data.fn_decl.body == NULL);  // extern函数没有函数体
    
    // 检查第二个声明（普通函数）
    ASTNode *fn_decl = program->data.program.decls[1];
    assert(fn_decl != NULL);
    assert(fn_decl->type == AST_FN_DECL);
    assert(strcmp(fn_decl->data.fn_decl.name, "main") == 0);
    assert(fn_decl->data.fn_decl.body != NULL);  // 普通函数有函数体
    
    printf("  ✓ 包含extern函数声明的程序解析测试通过\n");
}

// 测试解析指针类型（普通指针 &i32）
void test_parse_pointer_type(void) {
    printf("测试解析指针类型（普通指针 &i32）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn test(p: &i32) i32 { return 0; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.param_count == 1);
    
    // 检查参数类型是指针类型
    ASTNode *param_type = fn->data.fn_decl.params[0]->data.var_decl.type;
    assert(param_type != NULL);
    assert(param_type->type == AST_TYPE_POINTER);
    assert(param_type->data.type_pointer.is_ffi_pointer == 0);  // 普通指针
    
    // 检查指向的类型
    ASTNode *pointed_type = param_type->data.type_pointer.pointed_type;
    assert(pointed_type != NULL);
    assert(pointed_type->type == AST_TYPE_NAMED);
    assert(strcmp(pointed_type->data.type_named.name, "i32") == 0);
    
    printf("  ✓ 指针类型解析测试通过\n");
}

// 测试解析 FFI 指针类型（*byte，仅用于 extern 函数）
void test_parse_ffi_pointer_type(void) {
    printf("测试解析 FFI 指针类型（*byte）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "extern fn strcmp(s1: *byte, s2: *byte) i32;";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_extern_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.param_count == 2);
    
    // 检查第一个参数类型是 FFI 指针类型
    ASTNode *param1_type = fn->data.fn_decl.params[0]->data.var_decl.type;
    assert(param1_type != NULL);
    assert(param1_type->type == AST_TYPE_POINTER);
    assert(param1_type->data.type_pointer.is_ffi_pointer == 1);  // FFI 指针
    
    // 检查指向的类型
    ASTNode *pointed_type = param1_type->data.type_pointer.pointed_type;
    assert(pointed_type != NULL);
    assert(pointed_type->type == AST_TYPE_NAMED);
    assert(strcmp(pointed_type->data.type_named.name, "byte") == 0);
    
    printf("  ✓ FFI 指针类型解析测试通过\n");
}

// 测试解析数组类型（[i32: 10]）
void test_parse_array_type(void) {
    printf("测试解析数组类型（[i32: 10]）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn test(arr: [i32: 10]) i32 { return 0; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.param_count == 1);
    
    // 检查参数类型是数组类型
    ASTNode *param_type = fn->data.fn_decl.params[0]->data.var_decl.type;
    assert(param_type != NULL);
    assert(param_type->type == AST_TYPE_ARRAY);
    
    // 检查元素类型
    ASTNode *element_type = param_type->data.type_array.element_type;
    assert(element_type != NULL);
    assert(element_type->type == AST_TYPE_NAMED);
    assert(strcmp(element_type->data.type_named.name, "i32") == 0);
    
    // 检查数组大小表达式
    ASTNode *size_expr = param_type->data.type_array.size_expr;
    assert(size_expr != NULL);
    assert(size_expr->type == AST_NUMBER);
    assert(size_expr->data.number.value == 10);
    
    printf("  ✓ 数组类型解析测试通过\n");
}

// 测试解析数组访问（arr[index]）
void test_parse_array_access(void) {
    printf("测试解析数组访问（arr[index]）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { var arr: [i32: 10] = []; var x: i32 = arr[0]; return x; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 1);
    
    // 检查函数声明
    ASTNode *fn = program->data.program.decls[0];
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.body != NULL);
    
    // 检查函数体中的语句
    ASTNode *body = fn->data.fn_decl.body;
    assert(body->type == AST_BLOCK);
    assert(body->data.block.stmt_count >= 2);
    
    // 找到第二个变量声明（var x: i32 = arr[0]）
    ASTNode *var_decl = NULL;
    for (int i = 0; i < body->data.block.stmt_count; i++) {
        ASTNode *stmt = body->data.block.stmts[i];
        if (stmt->type == AST_VAR_DECL) {
            ASTNode *init = stmt->data.var_decl.init;
            if (init && init->type == AST_ARRAY_ACCESS) {
                var_decl = stmt;
                break;
            }
        }
    }
    
    assert(var_decl != NULL);
    assert(strcmp(var_decl->data.var_decl.name, "x") == 0);
    
    // 检查初始化表达式是数组访问
    ASTNode *init = var_decl->data.var_decl.init;
    assert(init != NULL);
    assert(init->type == AST_ARRAY_ACCESS);
    
    // 检查数组表达式
    ASTNode *array_expr = init->data.array_access.array;
    assert(array_expr != NULL);
    assert(array_expr->type == AST_IDENTIFIER);
    assert(strcmp(array_expr->data.identifier.name, "arr") == 0);
    
    // 检查索引表达式
    ASTNode *index_expr = init->data.array_access.index;
    assert(index_expr != NULL);
    assert(index_expr->type == AST_NUMBER);
    assert(index_expr->data.number.value == 0);
    
    printf("  ✓ 数组访问解析测试通过\n");
}

// 测试解析嵌套类型（&[i32: 10]）
void test_parse_nested_pointer_array_type(void) {
    printf("测试解析嵌套类型（&[i32: 10]）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn test(arr: &[i32: 10]) i32 { return 0; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.param_count == 1);
    
    // 检查参数类型是指针类型
    ASTNode *param_type = fn->data.fn_decl.params[0]->data.var_decl.type;
    assert(param_type != NULL);
    assert(param_type->type == AST_TYPE_POINTER);
    assert(param_type->data.type_pointer.is_ffi_pointer == 0);
    
    // 检查指向的类型是数组类型
    ASTNode *pointed_type = param_type->data.type_pointer.pointed_type;
    assert(pointed_type != NULL);
    assert(pointed_type->type == AST_TYPE_ARRAY);
    
    // 检查数组元素类型
    ASTNode *element_type = pointed_type->data.type_array.element_type;
    assert(element_type != NULL);
    assert(element_type->type == AST_TYPE_NAMED);
    assert(strcmp(element_type->data.type_named.name, "i32") == 0);
    
    printf("  ✓ 嵌套指针数组类型解析测试通过\n");
}

// 测试解析 len 表达式
void test_parse_len_expr(void) {
    printf("测试解析 len 表达式...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { var arr: [i32: 5] = []; const len_val: i32 = len(arr); return len_val; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 1);
    
    // 检查函数声明
    ASTNode *fn = program->data.program.decls[0];
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(fn->data.fn_decl.body != NULL);
    
    // 检查函数体中的语句
    ASTNode *body = fn->data.fn_decl.body;
    assert(body->type == AST_BLOCK);
    assert(body->data.block.stmt_count >= 2);
    
    // 找到 len 表达式所在的变量声明
    ASTNode *len_var_decl = NULL;
    for (int i = 0; i < body->data.block.stmt_count; i++) {
        ASTNode *stmt = body->data.block.stmts[i];
        if (stmt->type == AST_VAR_DECL) {
            ASTNode *init = stmt->data.var_decl.init;
            if (init && init->type == AST_LEN) {
                len_var_decl = stmt;
                break;
            }
        }
    }
    
    assert(len_var_decl != NULL);
    assert(strcmp(len_var_decl->data.var_decl.name, "len_val") == 0);
    
    // 检查初始化表达式是 len 表达式
    ASTNode *init = len_var_decl->data.var_decl.init;
    assert(init != NULL);
    assert(init->type == AST_LEN);
    
    // 检查数组表达式
    ASTNode *array_expr = init->data.len_expr.array;
    assert(array_expr != NULL);
    assert(array_expr->type == AST_IDENTIFIER);
    assert(strcmp(array_expr->data.identifier.name, "arr") == 0);
    
    printf("  ✓ len 表达式解析测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Parser 测试...\n\n");
    
    test_parser_init();
    test_parse_empty_program();
    test_parse_function();
    test_parse_function_no_params();
    test_parse_struct();
    test_parse_program_with_declarations();
    test_parse_return_stmt();
    test_parse_var_decl();
    test_parse_function_with_statements();
    test_parse_binary_arithmetic_expr();
    test_parse_unary_expr();
    test_parse_function_call();
    test_parse_struct_literal();
    test_parse_member_access();
    test_parse_assign_expr();
    test_parse_extern_function_no_params();
    test_parse_extern_function_with_params();
    test_parse_extern_function_varargs();
    test_parse_program_with_extern_function();
    test_parse_pointer_type();
    test_parse_ffi_pointer_type();
    test_parse_array_type();
    test_parse_nested_pointer_array_type();
    test_parse_array_access();
    test_parse_len_expr();
    
    printf("\n所有测试通过！\n");
    
    return 0;
}

