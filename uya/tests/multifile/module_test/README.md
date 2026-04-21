# 模块系统测试

本目录包含模块系统（export/use）的测试用例。

## 目录结构

按照规范，模块基于目录：
- `module_a/` - 模块 A 目录（包含 module_a.uya）
- `module_b.uya` - 模块 B：使用模块 A 的导出项（位于项目根目录，属于 main 模块）
- `error_use_private.uya` - 测试使用未导出项的错误检测

## 测试用例

- `module_a/module_a.uya` - 模块 A：导出函数和结构体
- `module_b.uya` - 模块 B：使用 `use module_a.public_func;` 导入模块 A 的导出项
- `error_use_private.uya` - 测试使用未导出项的错误检测（预期编译失败）

## 运行测试

```bash
# 编译 module_a 和 module_b（目录即模块）
cd compiler-mini
./build/compiler-mini --c99 tests/programs/multifile/module_test/module_a/module_a.uya tests/programs/multifile/module_test/module_b.uya -o test.c
gcc -std=c99 -o test test.c tests/bridge.c
./test

# 测试错误检测（预期编译失败）
./build/compiler-mini --c99 tests/programs/multifile/module_test/module_a/module_a.uya tests/programs/multifile/module_test/error_use_private.uya -o test_error.c
# 应该报错：模块 'module_a' 中未找到导出项 'private_func'
```

