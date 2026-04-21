# 测试框架重构 TODO

## 目标
实现测试框架标准化，最终目标：
1. **统一入口点**: `export fn main() !int` 或 `export fn main() int`
2. **标准化测试格式**: `test "测试名称" {}` 块
3. **统一命令行接口**: `uya build` / `uya run` / `uya test`
4. **0依赖运行**: 无需 bridge.c

## 命令行接口设计

### 命令概览

| 命令 | 说明 | 示例 |
|------|------|------|
| `uya build <file>` | 编译为可执行文件 | `uya build main.uya -o app` |
| `uya run <file>` | 编译并运行 | `uya run main.uya` |
| `uya test <file>` | 编译测试并运行 | `uya test tests.uya` |

### `uya build` 命令
```bash
# 编译为可执行文件
uya build main.uya -o myapp

# 指定后端
uya build main.uya -o myapp --c99

# 编译为库
uya build lib.uya --outlibc ./libout
```

### `uya run` 命令
```bash
# 编译并运行
uya run main.uya

# 传递运行时参数
uya run main.uya -- --arg1 --arg2
```

### `uya test` 命令
```bash
# 运行单个测试文件
uya test tests.uya

# 运行目录下所有测试
uya test tests/

# 显示详细输出
uya test tests.uya -v
```

## 当前阶段

| 阶段 | 描述 | 状态 |
|------|------|------|
| Phase 0 | 设计规划 | ✅ 完成 |
| Phase 1 | 编译器子命令支持 (`build`/`run`/`test`) | ✅ 完成 |
| Phase 2 | 自动生成 main 函数 (test 模式) | ✅ 完成 |
| Phase 3 | 测试文件迁移到 `test "xxx" {}` 格式 | 🚧 进行中（42%） |
| Phase 4 | 移除手动 `use std.runtime.entry` | ✅ 完成 |
| Phase 5 | 验证与清理 | 📋 待开始 |

## 当前进度（旧格式迁移）
- **已迁移到 `test "xxx" {}` 格式**: 约 235 个文件
- **待迁移（仍使用旧格式）**: 约 321 个文件
- **测试文件总数**: 约 556 个
- **更新日期**: 2026-04-03

## 迁移模式

### 标准迁移模板
```uya
use std.testing.expect;
use std.testing.assert_eq_i32;
use std.testing.test_suite_begin;
use std.testing.test_suite_end;
use std.testing.run_test;

fn test_xxx() !void {
    try expect(condition);
    // 或
    try assert_eq_i32(actual, expected);
}

fn main() i32 {
    test_suite_begin("Module Tests");
    run_test("test name", test_xxx);
    return test_suite_end();
}
```

### 迁移规则
1. `fn main() i32` 保持不变（不使用 `export`）
2. 测试函数返回 `!void`，使用 `try` 传播错误
3. `if condition { return N; }` → `try expect(condition);`
4. `if x != expected { return N; }` → `try assert_eq_i32(x, expected);`

---

## 待迁移文件分类

> **注意（2026-04-03）**：以下分类列表创建于 2026-02-21，部分文件已在后续迁移中完成（如类别 A 大部分、类别 C/D 的多数文件）。列表中标记为"待迁移"的文件需逐个验证当前状态（检查是否包含 `test "` 块）。

### 类别 A: 可直接迁移 (约 40 个文件)
这些文件只使用基本语法，无需特殊处理（**大部分已完成迁移**）：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_null_literal.uya | 待迁移 | null 字面量测试 |
| test_number_literals.uya | 待迁移 | 数字字面量测试 |
| test_operator_precedence.uya | 待迁移 | 运算符优先级 |
| test_pointer_array_access.uya | 待迁移 | 指针数组访问 |
| test_pointer_array_field_access.uya | 待迁移 | 指针数组字段访问 |
| test_pointer_cast.uya | 待迁移 | 指针类型转换 |
| test_pointer_member_access.uya | 待迁移 | 指针成员访问 |
| test_ptr_arithmetic.uya | 待迁移 | 指针算术 |
| test_ptr_from_usize.uya | 待迁移 | usize 到指针 |
| test_return.uya | 待迁移 | 返回值测试 |
| test_saturating_wrapping.uya | 待迁移 | 饱和/回绕运算 |
| test_scope_rules.uya | 待迁移 | 作用域规则 |
| test_simple_cast.uya | 待迁移 | 简单类型转换 |
| test_simple_compare.uya | 待迁移 | 简单比较 |
| test_simple_conversion_correct.uya | 待迁移 | 简单转换 |
| test_simple_return.uya | 待迁移 | 简单返回 |
| test_type_alias.uya | 待迁移 | 类型别名 |
| test_type_conversion_comprehensive.uya | 待迁移 | 类型转换综合 |
| test_type_conversion_pointer.uya | 待迁移 | 指针类型转换 |
| test_nested_struct_access.uya | 待迁移 | 嵌套结构体访问 |
| test_main_first_stmt.uya | 待迁移 | main 首语句 |
| test_raw_string.uya | 待迁移 | 原始字符串 |

### 类别 B: 宏相关测试 (约 25 个文件)
需要检查宏展开后的代码类型（**大部分仍为旧格式**）：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_macro_comprehensive.uya | 待迁移 | 宏综合测试 |
| test_macro_edge_cases.uya | 待迁移 | 宏边界情况 |
| test_macro_expr_bool.uya | 待迁移 | 宏布尔表达式 |
| test_macro_expr_int.uya | 待迁移 | 宏整数表达式 |
| test_macro_integration.uya | 待迁移 | 宏集成测试 |
| test_macro_interp.uya | 待迁移 | 宏插值 |
| test_macro_mc_eval.uya | 待迁移 | 宏编译期求值 |
| test_macro_mc_get_env.uya | 待迁移 | 宏获取环境变量 |
| test_macro_mc_type_auto.uya | 待迁移 | 宏类型自动推导 |
| test_macro_mc_type.uya | 待迁移 | 宏类型 |
| test_macro_multiple_calls.uya | 待迁移 | 宏多次调用 |
| test_macro_nested_call.uya | 待迁移 | 宏嵌套调用 |
| test_macro_nested.uya | 待迁移 | 宏嵌套 |
| test_macro_param_pattern.uya | 待迁移 | 宏参数模式 |
| test_macro_param_stmt.uya | 待迁移 | 宏参数语句 |
| test_macro_param_type.uya | 待迁移 | 宏参数类型 |
| test_macro_simple_interp.uya | 待迁移 | 宏简单插值 |
| test_macro_simple.uya | 待迁移 | 宏简单测试 |
| test_macro_stmt_return.uya | 待迁移 | 宏语句返回 |
| test_macro_stmt.uya | 待迁移 | 宏语句 |
| test_macro_struct_return.uya | 待迁移 | 宏结构体返回 |
| test_macro_sugar.uya | 待迁移 | 宏语法糖 |
| test_macro_type_return.uya | 待迁移 | 宏类型返回 |
| test_macro_type.uya | 待迁移 | 宏类型 |
| test_macro_with_params.uya | 待迁移 | 宏参数 |

### 类别 C: 错误处理测试 (约 8 个文件)
使用 error 类型，需要特殊处理（**大部分已完成迁移**）：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_err_handling.uya | 待迁移 | 错误处理 |
| test_error_forward_use.uya | 待迁移 | 错误前向使用 |
| test_error_global.uya | 待迁移 | 全局错误 |
| test_error_handling.uya | 待迁移 | 错误处理 |
| test_error_runtime_only.uya | 待迁移 | 运行时错误 |
| test_error_same_id.uya | 待迁移 | 相同 ID 错误 |
| test_return_error.uya | 待迁移 | 返回错误 |
| test_main_with_errors.uya | 待迁移 | main 带错误 |
| test_try_div.uya | 待迁移 | try 除法 |
| test_try_only.uya | 待迁移 | 仅 try |

### 类别 D: 外部函数/FFI 测试 (约 12 个文件)
使用 extern 函数，需要 bridge.c 支持（**大部分已完成迁移**）：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_abi_calling_convention.uya | 待迁移 | ABI 调用约定 |
| test_escape_chars.uya | 待迁移 | 转义字符 (extern printf) |
| test_export_for_c_complete.uya | 待迁移 | C 导出完整版 |
| test_export_for_c.uya | 待迁移 | C 导出 |
| test_extern_ffi_pointer.uya | 待迁移 | FFI 指针 |
| test_extern_union.uya | 待迁移 | extern 联合体 |
| test_ffi_cast.uya | 待迁移 | FFI 类型转换 |
| test_for_iterator.uya | 待迁移 | 迭代器 (extern) |
| test_iter_simple.uya | 待迁移 | 简单迭代 (extern) |
| test_varargs.uya | 待迁移 | 可变参数 |
| test_varargs_full.uya | 待迁移 | 完整可变参数 |
| test_unistd.uya | 待迁移 | POSIX unistd |

### 类别 E: 标准库测试 (约 20 个文件)
依赖标准库模块：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_std_io.uya | 待迁移 | 标准输入输出 |
| test_stdio.uya | 待迁移 | stdio |
| test_std_mem.uya | 待迁移 | 内存操作 |
| test_std_runtime_simple.uya | 待迁移 | 运行时简单版 |
| test_std_runtime.uya | 待迁移 | 运行时 |
| test_std_stdio.uya | 待迁移 | 标准 stdio |
| test_std_stdlib_debug.uya | 待迁移 | stdlib 调试 |
| test_std_stdlib_malloc_only.uya | 待迁移 | 仅 malloc |
| test_std_stdlib_malloc.uya | 待迁移 | malloc |
| test_std_stdlib_simple.uya | 待迁移 | stdlib 简单版 |
| test_std_stdlib.uya | 待迁移 | stdlib |
| test_std_string.uya | 待迁移 | 字符串 |
| test_std_syscall_new.uya | 待迁移 | syscall 新版 |
| test_std_syscall.uya | 待迁移 | syscall |

### 类别 F: 系统调用测试 (约 6 个文件)
依赖 syscall：

| 文件 | 状态 | 备注 |
|------|------|------|
| test_syscall_error.uya | 待迁移 | syscall 错误 |
| test_syscall_exit.uya | 待迁移 | syscall exit |
| test_syscall_module.uya | 待迁移 | syscall 模块 |
| test_syscall_write.uya | 待迁移 | syscall write |
| test_string_interp_minimal.uya | 待迁移 | 字符串插值最小版 |
| test_string_interp_one.uya | 待迁移 | 字符串插值单次 |
| test_string_interp_simple.uya | 待迁移 | 字符串插值简单版 |
| test_string_interp.uya | 待迁移 | 字符串插值 |
| test_string_literal.uya | 待迁移 | 字符串字面量 |

### 类别 G: 模块相关测试 (约 4 个文件)

| 文件 | 状态 | 备注 |
|------|------|------|
| test_module_export.uya | 待迁移 | 模块导出 |
| test_module_use_simple.uya | 待迁移 | 模块 use 简单版 |
| test_multilevel_module.uya | 待迁移 | 多级模块 |

### 类别 H: 其他特殊测试 (约 5 个文件)

| 文件 | 状态 | 备注 |
|------|------|------|
| test_as_force_cast.uya | 待迁移 | 强制类型转换 |
| test_comprehensive_cast.uya | 待迁移 | 综合类型转换 |
| test_src_location.uya | 待迁移 | 源码位置 |
| test_struct_method_err.uya | 待迁移 | 结构体方法错误 |
| test_struct_pointer_return.uya | 待迁移 | 结构体指针返回 |

---

## 新测试框架设计（`--test` 模式）

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                      测试文件格式                            │
├─────────────────────────────────────────────────────────────┤
│  // 旧格式（需要迁移）                                       │
│  use std.runtime.entry;                                    │
│  use std.testing.*;                                        │
│  export fn main() i32 {                                    │
│      test_suite_begin("Tests");                            │
│      run_test("test1", test_fn);                           │
│      return test_suite_end();                              │
│  }                                                         │
├─────────────────────────────────────────────────────────────┤
│  // 新格式（目标）                                          │
│  use std.testing.check_eq_i32;                             │
│                                                            │
│  test "test_addition" {                                    │
│      check_eq_i32(1 + 1, 2);                               │
│  }                                                         │
│                                                            │
│  test "test_subtraction" {                                 │
│      check_eq_i32(5 - 3, 2);                               │
│  }                                                         │
└─────────────────────────────────────────────────────────────┘

编译器 `--test` 模式流程：
1. 解析所有 `test "name" {}` 块
2. 自动生成 main 函数
3. 调用 uya_run_tests() 运行所有测试
```

### Phase 0: 设计规划 🚧 进行中

| 任务 | 状态 | 说明 |
|------|------|------|
| 确定新测试格式规范 | 🚧 进行中 | `test "name" {}` 块语法 |
| 确定 `uya test` 命令行为 | 📋 待开始 | 自动生成 main |
| 确定入口点规范 | 📋 待开始 | `export fn main() !int` 或 `int` |
| 确定断言函数命名 | 📋 待开始 | `check_eq_*` vs `assert_eq_*` |

### Phase 1: 编译器修改

| 任务 | 状态 | 文件 | 说明 |
|------|------|------|------|
| 添加子命令解析框架 | ✅ 完成 | `src/main.uya` | `build`/`run`/`test` 子命令 |
| 实现 `uya build` | ✅ 完成 | `src/main.uya` | 编译为可执行文件 |
| 实现 `uya run` | ✅ 完成 | `src/main.uya` | 编译并生成运行提示 |
| 实现 `uya test` | ✅ 完成 | `src/main.uya` | 编译测试并生成运行提示 |
| 收集所有 `test "name" {}` 块 | 📋 待开始 | `src/main.uya` | 测试发现 |
| 入口点检测逻辑 | 📋 待开始 | `src/main.uya` | 区分 test/app 模式 |
| 自动生成 main 函数 | 📋 待开始 | `src/codegen/c99/main.uya` | test 模式下生成 |

### Phase 2: 标准库修改

| 任务 | 状态 | 文件 | 说明 |
|------|------|------|------|
| 添加 `check_*` 系列断言 | 📋 待开始 | `lib/std/testing/testing.uya` | 不返回错误的新断言 |
| 改进测试运行器 | 📋 待开始 | `lib/std/testing/testing.uya` | `uya_run_tests()` 函数 |
| 测试结果输出 | 📋 待开始 | `lib/std/testing/testing.uya` | 格式化输出 |

### Phase 3: 测试文件迁移

| 类别 | 文件数 | 状态 | 说明 |
|------|--------|------|------|
| 类别 A: 基础测试 | ~40 | 📋 待开始 | 简单迁移 |
| 类别 B: 宏测试 | ~25 | 📋 待开始 | 检查兼容性 |
| 类别 C: 错误处理 | ~8 | 📋 待开始 | 特殊处理 |
| 类别 D: FFI 测试 | ~12 | 📋 待开始 | 可能保留旧格式 |
| 类别 E: 标准库测试 | ~20 | 📋 待开始 | 检查依赖 |
| 类别 F: 系统调用 | ~9 | 📋 待开始 | 检查兼容性 |
| 类别 G: 模块测试 | ~3 | 📋 待开始 | 简单迁移 |
| 类别 H: 特殊测试 | ~5 | 📋 待开始 | 检查兼容性 |

### Phase 4: 移除旧依赖

| 任务 | 状态 | 说明 |
|------|------|------|
| 移除 `use std.runtime.entry` | 📋 待开始 | 编译器自动包含 |
| 移除 `run_test()` 调用 | 📋 待开始 | 使用 `test "name" {}` 块 |
| 更新 Makefile | 📋 待开始 | 使用 `--test` 参数 |
| 更新测试运行脚本 | 📋 待开始 | `make tests-uya` |

### Phase 5: 验证与清理

| 任务 | 状态 | 说明 |
|------|------|------|
| 全量测试通过 | 📋 待开始 | `make check` |
| 自举验证通过 | 📋 待开始 | `make b` |
| 文档更新 | 📋 待开始 | 更新开发文档 |
| 移除过时代码 | 📋 待开始 | 清理旧测试框架 |

---

## 0依赖目标

### ✅ 已实现（方案C）
编译器已支持自动检测 `export fn main` 并自动包含 `std.runtime.entry`：

1. **编译器修改** (`src/main.uya`)：
   - `detect_main_function()` 返回值：0=无main，1=fn main，2=export fn main
   - 检测到 `export fn main` 时自动添加 `lib/std/runtime/entry/entry.uya`
   - 在依赖收集之前添加，确保 entry.uya 的依赖也被收集

2. **使用方式**：
   ```uya
   // 测试文件
   use std.testing.expect;
   use std.testing.test_suite_begin;
   use std.testing.test_suite_end;
   use std.testing.run_test;
   
   fn test_xxx() !void {
       try expect(condition);
   }
   
   // 使用 export fn main，编译器自动包含 entry.uya
   export fn main() i32 {
       test_suite_begin("Tests");
       run_test("test", test_xxx);
       return test_suite_end();
   }
   ```

3. **编译运行**：
   ```bash
   # 编译（自动包含 entry.uya 和依赖）
   ./bin/uya test.uya -o test
   
   # 直接用 gcc 编译，无需 bridge.c
   gcc -x c -o test_bin test -std=c99 -lm
   ./test_bin
   ```

### 架构说明
```
应用程序：
  export fn main() i32 { ... }  → 编译为 main_main()
  
std.runtime.entry：
  export extern fn main(argc, argv) → 真正的 C 入口
  extern fn main_main() i32        → 调用应用程序的 main
  
std.runtime：
  export var saved_argc: i32
  export var saved_argv: & &byte
  export fn get_argc() i32
  export fn get_argv(index) &byte
```

---

## 执行计划

### Phase 1: 直接迁移 (优先级高)
迁移类别 A 的 40 个文件，预计新增 100+ 测试用例。

### Phase 2: 宏测试迁移
检查每个宏测试文件，确认宏展开后的类型兼容性。

### Phase 3: 错误处理测试
研究 error 类型在测试框架中的最佳实践。

### Phase 4: FFI/Extern 测试
确定这些测试是否需要保留 bridge.c 依赖，或可重构为纯 Uya 测试。

### Phase 5: 标准库测试
确保标准库模块测试与测试框架兼容。

### Phase 6: 0依赖实现
实现编译器或标准库层面的 0依赖运行方案。

---

## 更新日志

- 2026-02-19: Phase 1 完成 - 实现 `uya build`/`run`/`test` 子命令
- 2026-02-19: 添加新测试框架设计（`--test` 模式），Phase 0 进行中
- 2026-02-19: 更新进度（302/391，77%）
- 2026-02-15: 创建文档，已迁移 159 个文件

- 2026-02-19: Phase 2 & 4 完成
  - 编译器自动检测 `test "..."` 和 `export fn main`
  - 自动添加 `std.runtime.entry`（无需手动 use）
  - 测试脚本改为检测生成的 C 代码中的 main 函数
  - `test "name" {}` 块自动生成 `main_main()` 调用测试运行器
