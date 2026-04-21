// 等效的 C 文件：测试 buffer_ptr[0] 场景
// buffer_ptr 是 char* 类型（相当于 &byte）

char test_buffer_ptr_access() {
    // 创建一个缓冲区
    char buffer[100];
    
    // 获取缓冲区指针（char* 类型）
    char* buffer_ptr = &buffer[0];
    
    // 测试：直接使用 buffer_ptr 进行数组访问
    char temp = buffer_ptr[0];
    
    return temp;
}

int main() {
    char result = test_buffer_ptr_access();
    return 0;
}

