/* 
 * 示例：如何在 C 代码中调用 Uya 导出的函数
 * 
 * 编译步骤：
 * 1. 编译 Uya 代码：uya-c test_export_for_c_complete.uya -o test_export_for_c_complete.c
 * 2. 编译 C 代码：gcc test_export_for_c_complete.c test_export_for_c_usage.c -o test
 * 3. 运行：./test
 */

// 声明 Uya 导出的函数（这些函数在 Uya 代码中用 export fn 定义）
extern int uya_add(int a, int b);
extern int uya_multiply(int a, int b);
extern int uya_strlen(const char *s);
extern void uya_print_answer(void);

int main(void) {
    // 调用 Uya 导出的函数
    int result1 = uya_add(10, 20);
    printf("uya_add(10, 20) = %d\n", result1);  // 应该输出 30
    
    int result2 = uya_multiply(5, 6);
    printf("uya_multiply(5, 6) = %d\n", result2);  // 应该输出 30
    
    const char *str = "Hello";
    int len = uya_strlen(str);
    printf("uya_strlen(\"Hello\") = %d\n", len);  // 应该输出 5
    
    uya_print_answer();
    
    return 0;
}

