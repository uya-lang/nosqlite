# Bug Report: Uya C99 Codegen Segfault on `test` Block with Project Module Calls

日期：2026-04-22

## 状态

`已验证修复`

验证日期：2026-04-22

当前结论：

- 原始复现文件 [repro_uya_codegen_test_block_segfault.uya](/home/winger/nosqlite/nosqlite/repro_uya_codegen_test_block_segfault.uya) 已可稳定通过 `uya --c99 --nostdlib`，不再在 codegen 阶段 segfault。
- 页面基础测试 [test_storage_page_basics.uya](/home/winger/nosqlite/nosqlite/test_storage_page_basics.uya) 也可正常编译生成 C。

说明：

- 这个文档现在保留为“已修复问题的归档记录”。
- 当前仓库里仍存在另外一类与 `slotted page` 相关的编译/链接边角，但那已经不是本报告跟踪的原始问题。

## 摘要

在当前仓库里，Uya 编译器对某类 `test "..."` 文件会在 **类型检查通过后、C99 代码生成阶段** 发生 segmentation fault。

这个问题不是语法错误，也不是类型检查错误，而是 codegen 阶段崩溃。

当前已确认：

- 同一组业务逻辑如果写成 `main()` 风格的 runtime smoke，可以稳定编译、链接并运行通过。
- 把逻辑写进 `test "..."` 块后，编译器在 codegen 阶段崩溃。

## 影响范围

这会直接影响 TDD 工作流：

- 我们能先写失败测试
- 也能实现最小逻辑
- 但一旦用 `test` 块承载某些项目模块调用，编译器在 codegen 阶段 segfault

结果是：

- 只能先退回 `main()` 风格 runtime smoke
- 无法把这类场景稳定纳入标准 `test` 文件

## 复现文件

最小可复现文件已放在仓库：

- 失败复现：
  [repro_uya_codegen_test_block_segfault.uya](/home/winger/nosqlite/nosqlite/repro_uya_codegen_test_block_segfault.uya)
- 成功对照：
  [test_storage_slotted_page_runtime.uya](/home/winger/nosqlite/nosqlite/test_storage_slotted_page_runtime.uya)

两者的核心业务逻辑接近，区别主要在于：

- 失败文件使用 `test "..."` 块
- 成功文件使用 `main() -> i32` 方式组织

## 复现命令

在仓库根目录执行：

```bash
./uya/bin/uya --c99 --nostdlib nosqlite/repro_uya_codegen_test_block_segfault.uya -o /tmp/repro_codegen_test_block_segfault.c
```

## 原始实际结果

编译日志显示：

1. 词法/语法分析完成
2. AST 合并完成
3. 类型检查通过
4. 优化阶段完成
5. 进入“代码生成阶段”
6. 编译器崩溃

关键日志片段：

```text
=== 类型检查阶段 ===
类型检查通过

=== 优化阶段 (级别: 1) ===
...

=== 代码生成阶段 ===
模块名: nosqlite/repro_uya_codegen_test_block_segfault.uya
```

随后进程异常退出，退出码为 `-1`，对应 segmentation fault。

## 原始预期结果

预期行为应该是：

- 正常生成 `/tmp/repro_codegen_test_block_segfault.c`
- 后续能够被 `gcc` 链接
- 若测试逻辑有问题，应体现为测试失败或运行时返回码非 0
- 不应在 codegen 阶段直接崩溃

## 修复后验证结果

下面的命令现在已经可以成功生成 C 文件：

```bash
./uya/bin/uya --c99 --nostdlib nosqlite/repro_uya_codegen_test_block_segfault.uya -o /tmp/repro_codegen_test_block_segfault.c
./uya/bin/uya --c99 --nostdlib nosqlite/test_storage_page_basics.uya -o /tmp/nosqlite_test_storage_page_basics.c
```

这说明：

- 原始“`test` 块 + 项目模块调用 + `try`/结构体/切片组合会在 codegen 阶段崩溃”的问题已经解除
- 该问题至少在当前 NoSQLite 复现样本上已不再出现

## 成功对照

下面这条命令可以通过：

```bash
./uya/bin/uya --c99 --nostdlib nosqlite/test_storage_slotted_page_runtime.uya -o /tmp/nosqlite_test_storage_slotted_page_runtime.c
```

并且后续可以链接运行：

```bash
gcc --std=c99 -nostartfiles -no-pie /tmp/nosqlite_test_storage_slotted_page_runtime.c -o /tmp/nosqlite_test_storage_slotted_page_runtime
/tmp/nosqlite_test_storage_slotted_page_runtime
```

说明：

- `slotted page` 相关实现本身并不必然导致 codegen 崩溃
- 崩溃更像是“`test` 块 + 项目模块调用 + 若干错误联合/结构体/切片组合”触发的 codegen 边角

## 触发条件观察

当前已观察到以下特征同时出现时更容易触发：

1. 顶层使用 `test "..."` 块，而不是 `main()`
2. `test` 块中调用项目模块导出的函数，而非只调标准库
3. 调用链涉及：
   - 错误联合返回值 `!T`
   - 结构体返回值
   - 切片 `&[byte]`
   - 指针字段访问
4. 项目模块位于 `nosqlite/lib/storage/` 下

本例里典型调用包括：

- `slotted_page_init(...) !void`
- `slotted_page_insert_copy(...) !u16`
- `slotted_page_get_slot(...) !Slot`
- `slotted_page_cell_view(...) !SlottedPageCellView`

## 原临时规避方案

当前可行的临时规避方式：

- 不把这类场景写成 `test` 块
- 改写成 `main() -> i32` 的 runtime smoke
- 通过进程返回码判断成败

这就是当前 [test_storage_slotted_page_runtime.uya](/home/winger/nosqlite/nosqlite/test_storage_slotted_page_runtime.uya) 的用途。

## 可能的排查方向

下面是比较值得先看的方向：

1. `test` 块 lowering
   `test` 是否在 lowering 阶段生成了和普通函数不同的包裹结构，导致某些局部变量/切片/err_union 生命周期处理错误。

2. codegen 中的表达式展开
   尤其是：
   - `try foo()`
   - `const x: Struct = try foo()`
   - `slice.ptr[0: slice.len]`
   - `assert_eq_*` 宏展开后的嵌套表达式

3. 同模块符号重复或状态污染
   之前在别的测试文件里还见过同模块 helper 被重复展开进生成 C 的情况，因此也值得检查：
   - 依赖收集去重
   - 同模块多文件 codegen 合并
   - `test` 入口是否重复遍历依赖

4. `test` 与 `entry/runtime` 注入交互
   当前使用 `--nostdlib` 但仍自动注入 `std.runtime.entry`，建议确认 `test` lowering 和 runtime entry 拼装阶段是否有边界条件。

## 建议修复后的回归标准

修复编译器后，至少应添加两类回归：

1. 直接把 [repro_uya_codegen_test_block_segfault.uya](/home/winger/nosqlite/nosqlite/repro_uya_codegen_test_block_segfault.uya) 纳入编译器测试，确保：
   - 编译成功
   - 生成 C 成功

2. 增加一个更小的编译器回归用例，覆盖：
   - `test` 块
   - 项目模块函数
   - `try` 解包 `!Struct`
   - 切片字段访问

## 后续说明

修复这个问题后，我们尝试把原先的 `main()` 风格 runtime smoke 逐步迁回标准 `test` 文件。

在这个过程中又碰到了另一类独立问题，表现为：

- 某些文件图下的 codegen/link 仍会出现重复定义或其他边角
- 这和“原始 `test` 块 codegen segfault”不是同一个问题

因此：

- 本报告建议视为关闭
- 若继续处理 `slotted page` 那条链路上的重复定义/依赖收集问题，应单独开新 bug report

## 备注

当前仓库里，页面基础测试文件：

- [test_storage_page_basics.uya](/home/winger/nosqlite/nosqlite/test_storage_page_basics.uya)

已经可以正常编译、生成 C、链接并运行。

所以这个问题不是“整个 NoSQLite 代码不能编译”，而是非常具体的：

> 某一类 `test` 块组合在 **codegen** 阶段触发编译器崩溃。
