#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/lexer.h"
#include "../src/arena.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 辅助函数：比较 Token
static int token_equals(const Token *token, TokenType expected_type, const char *expected_value) {
    if (token == NULL) {
        return 0;
    }
    if (token->type != expected_type) {
        return 0;
    }
    if (expected_value == NULL) {
        return token->value == NULL;
    }
    if (token->value == NULL) {
        return 0;
    }
    return strcmp(token->value, expected_value) == 0;
}

// 测试 Lexer 初始化
void test_lexer_init(void) {
    printf("测试 Lexer 初始化...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { return 0; }";
    int result = lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    assert(result == 0);
    assert(lexer.buffer_size == strlen(source));
    assert(strcmp(lexer.buffer, source) == 0);
    assert(lexer.position == 0);
    assert(lexer.line == 1);
    assert(lexer.column == 1);
    assert(lexer.filename != NULL);
    assert(strcmp(lexer.filename, "test.uya") == 0);
    
    printf("  ✓ Lexer 初始化测试通过\n");
}

// 测试标识符识别
void test_identifier_token(void) {
    printf("测试标识符识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "x";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_IDENTIFIER, "x"));
    
    printf("  ✓ 标识符识别测试通过\n");
}

// 测试关键字识别
void test_keyword_token(void) {
    printf("测试关键字识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_FN, "fn"));
    
    printf("  ✓ 关键字识别测试通过\n");
}

// 测试数字识别
void test_number_token(void) {
    printf("测试数字识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "42";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_NUMBER, "42"));
    
    printf("  ✓ 数字识别测试通过\n");
}

// 测试运算符识别
void test_operator_token(void) {
    printf("测试运算符识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    // 测试 + 运算符
    Lexer lexer;
    const char *source = "+";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_PLUS, "+"));
    
    // 测试 == 运算符
    arena_reset(&arena);
    const char *source2 = "==";
    lexer_init(&lexer, source2, strlen(source2), "test.uya", &arena);
    
    token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_EQUAL, "=="));
    
    printf("  ✓ 运算符识别测试通过\n");
}

// 测试标点符号识别
void test_punctuation_token(void) {
    printf("测试标点符号识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "(";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_LEFT_PAREN, "("));
    
    printf("  ✓ 标点符号识别测试通过\n");
}

// 测试空白字符跳过
void test_whitespace_skip(void) {
    printf("测试空白字符跳过...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "  x  ";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_IDENTIFIER, "x"));
    
    printf("  ✓ 空白字符跳过测试通过\n");
}

// 测试注释跳过
void test_comment_skip(void) {
    printf("测试注释跳过...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "// comment\nx";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_IDENTIFIER, "x"));
    
    printf("  ✓ 注释跳过测试通过\n");
}

// 测试 EOF Token
void test_eof_token(void) {
    printf("测试 EOF Token...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_EOF, NULL));
    
    printf("  ✓ EOF Token 测试通过\n");
}

// 测试可变参数标记（...）识别
void test_ellipsis_token(void) {
    printf("测试可变参数标记（...）识别...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "...";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Token *token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_ELLIPSIS, "..."));
    
    // 测试单独的点不会误识别为 ...
    arena_reset(&arena);
    const char *source2 = ".";
    lexer_init(&lexer, source2, strlen(source2), "test.uya", &arena);
    
    token = lexer_next_token(&lexer, &arena);
    assert(token != NULL);
    assert(token_equals(token, TOKEN_DOT, "."));
    
    printf("  ✓ 可变参数标记（...）识别测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Lexer 测试...\n\n");
    
    test_lexer_init();
    test_identifier_token();
    test_keyword_token();
    test_number_token();
    test_operator_token();
    test_punctuation_token();
    test_whitespace_skip();
    test_comment_skip();
    test_eof_token();
    test_ellipsis_token();
    
    printf("\n所有测试通过！\n");
    return 0;
}

