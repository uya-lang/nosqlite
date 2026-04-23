# Uya 语言规范 0.49.47（完整版 · 2026-04-21）

> 零GC · 默认高级安全 · 单页纸可读完  
> 无lifetime符号 · 无隐式控制 · 编译期证明（本函数内）

---

## 目录

- [核心特性](#核心特性)
- [设计哲学](#设计哲学)
- [语法规范](./grammar_formal.md) - 完整BNF语法规范（编译器实现参考）
- [语法速查](./grammar_quick.md) - 语法速查手册（日常开发参考）
- [测试规范](./testing_guide.md) - 测试编写规范与最佳实践
- [1. 文件与词法](#1-文件与词法)
- [1.5. 模块系统](#15-模块系统)
- [2. 类型系统](#2-类型系统)
- [3. 变量与作用域](#3-变量与作用域)
- [4. 结构体](#4-结构体)
  - [4.1. C 内存布局说明](#41-c-内存布局说明)
  - [4.2. 结构体内存布局详细规则](#42-结构体内存布局详细规则)
  - [4.3. 结构体默认值语法](#43-结构体默认值语法)
  - [4.5. 联合体（union）](#45-联合体union)
- [5. 函数](#5-函数)
  - [5.1. 普通函数](#51-普通函数)
    - [5.1.1. main函数签名](#511-main函数签名)
    - [5.1.2. 函数调用约定详细说明](#512-函数调用约定详细说明)
  - [5.2. 外部 C 函数（FFI）](#52-外部-c-函数ffi)
  - [5.3. 外部 C 结构体（FFI）](#53-外部-c-结构体ffi)
  - [5.4. 可变参数函数](#54-可变参数函数)
- [6. 接口（interface）](#6-接口interface)
- [7. 栈式数组（零 GC）](#7-栈式数组零-gc)
- [8. 控制流](#8-控制流)
- [9. defer 和 errdefer](#9-defer-和-errdefer)
- [10. 运算符与优先级](#10-运算符与优先级)
- [11. 类型转换](#11-类型转换)
- [12. 内存模型 & RAII](#12-内存模型--raii)
  - [12.5. 移动语义](#125-移动语义)
- [13. 原子操作](#13-原子操作)
- [14. 内存安全](#14-内存安全)
- [15. 并发安全](#15-并发安全)
- [16. 标准库](#16-标准库)
- [17. 字符串与格式化](#17-字符串与格式化)
- [18. 异步编程](#18-异步编程)
- [19. 内联汇编](#19-内联汇编)
- [25. 宏系统](#25-宏系统)
- [附录 A. 完整示例](#附录-a-完整示例)
- [附录 B. 扩展特性](#附录-b-扩展特性)
- [附录 C. 交叉编译（工具链）](#附录-c-交叉编译工具链)
- [术语表](#术语表)
- [规范变更](#规范变更)

---

## 规范变更

### 0.49.47（2026-04-21）

- **标准库 `std.sql`**：新增 `lib/std/sql/`。首版提供参考 Go `database/sql` 的数据库通用抽象：`Value`、`NamedArg`、`ColumnInfo`、`Driver`、`Conn`、`Stmt`、`Rows`、`Tx`、`Result`、高层 `DB` / `Row` 包装与 `db_open`。为兼容当前 C99 backend，接口方法优先采用普通返回值与 `out` 参数的稳定组合。
- **测试**：新增 `tests/test_std_sql.uya`，覆盖 fake driver 的 open / ping / prepare / exec / query / query_row / tx 主链路。
- **标准库 `std.crypto`**：新增 `lib/std/crypto/blake2b.uya` 与 `lib/std/crypto/blake2s.uya`。接口分别为 `blake2b_digest(data, digest_out)` 与 `blake2s_digest(data, digest_out)`；均为纯 Uya 一次性摘要实现，分别输出 64 / 32 字节。
- **标准库 `std.crypto`**：新增 `lib/std/crypto/md5.uya` 与 `lib/std/crypto/crc32.uya`。接口分别为 `md5_digest(data, digest_out)` 与 `crc32_compute(data)`；MD5 为 RFC 1321 一次性摘要实现，CRC-32 使用 IEEE/ZIP 反射多项式 `0xEDB88320`。
- **内核复用**：`lib/kernel/update.uya` 的元数据 CRC32 计算改为直接复用 `std.crypto.crc32`，避免同一算法在标准库和内核层重复维护。
- **测试**：新增 `tests/test_crypto_md5.uya` 与 `tests/test_crypto_crc32.uya`，并保留 `tests/test_kernel_update.uya` 对 CRC32 集成路径的回归覆盖。

### 0.49.46（2026-04-17）

- **macOS hosted 交叉构建**：C99 `@syscall` backend 增加 Darwin `x86_64` / `arm64` 路径，`libc.syscall`、`libc.stdlib`、`libc.errno`、`libc.time` 等补入第一轮 Darwin hosted 兼容分支。
- **Darwin libc bridge**：生成的 C99 在 hosted Darwin 目标下允许通过 helper bridge 到宿主 libc，当前已覆盖 `stat/fstat/lstat`、`fcntl`、`pipe2`、`clock_gettime`、`nanosleep`、`getcwd`、目录遍历等 bring-up 所需能力。
- **验证边界**：已在 Linux 上通过 `zig cc` 实测交叉产出 `Mach-O 64-bit arm64` 与 `Mach-O 64-bit x86_64` 编译器产物；macOS 真机运行与主测试闭环仍属后续 smoke / 迁移工作。

### 0.49.45（2026-04-14）

- **`@frame(foo)` 异步帧类型构造器**：暴露 `@async_fn` 的状态机帧类型。语法为 `@frame(fn_name)` 或 `@frame(fn_name<ConcreteType>)`。`var f: @frame(foo);` 允许无初始化声明。
- **`@frame(foo)` 生命周期方法**：当前公开高层方法为 `frame.start(...)`、`frame.poll(&waker)`、`frame.stop()`；分别对应 caller-owned frame 的启动、推进和停止/清理。
- **Pinned 语义**：`@frame` 类型禁止按值移动、整体赋值、按值传参、按值返回。按引用传递 `&frame` 不受影响。包含 `@frame` 字段的父结构体也视为 pinned aggregate。
- **内置函数白名单**：`@frame` 加入 `@` 内置函数词法白名单。

### 0.49.44（2026-04-02）

- **@print/@println：字符串插值段** `${expr}` 当 `expr` 为 **`&const byte`** 或 **`&[const byte]`** 时，按 **C 字符串语义**以 **`%s`** 输出（要求缓冲区以结尾 `\0`）。

### 0.49.43（2026-03-26）

- **字符串字面量 → `[byte: N]` 赋值**：与初始化相同，按字节复制（含结尾 `\0`），**`N ≥ 可见字节数 + 1`**；赋值前数组余量视为清零（实现为 `memset` 再拷贝）。
- **字符串字面量 → `&[const byte]` / `&[const byte: N]` 赋值**：语义为**重指向**静态字面量存储（更新切片的 **`ptr`/`len`**），**不**对原缓冲区做 `memcpy`；**不得**将字符串字面量直接赋给元素可变的 **`&[byte]`**（须使用元素只读的 **`&[const byte]`**）。
- **赋值左值**：上述规则适用于**任意深度的成员访问链**（如 **`a.b.c = "..."`**、**`obj.inner.name = "..."`**），与顶层 **`buf = "..."`**、**`obj.field = "..."`** 相同，由**最右侧字段**的类型决定是数组复制还是切片重指向。
- **子区间视图**：表达式级子切片 **`&"hello"[i:j]`** 等语义不变，仍用于取得字面量上的任意区间视图。
- **实现说明（只读与 C）**：语言层 **`&[const byte]`** 表示元素只读；当前 C99 后端对切片胖指针仍可能使用 **`uint8_t *`** 字段，**经切片对字面量存储写入**在 C 中属未定义行为——应避免对指向字面量的 **`&[const byte]`** 做元素写。

### 0.49.42（2026-03-22）

- **词法 · 十六进制与 Unicode 转义**（普通双引号字符串与字符串插值段内，**非**原始字符串）：
  - **`\\xHH`**：**`H`** 为十六进制数字（**`0-9` `a-f` `A-F`**），**恰好两位**，表示单字节 **`0x00`..`0xFF`**（与 C 常见写法一致）。
  - **`\\uXXXX`**：**`X`** 为十六进制数字，**恰好四位**，表示 **BMP** 码点 **`U+0000`..`U+FFFF`**；在字面量中展开为 **UTF-8** 字节序列（**1～3** 字节）。**`U+D800`..`U+DFFF`**（UTF-16 代理区）**非法**，词法报错。
- **字符字面量**：在既有转义之外支持 **`\\xHH`**；**`\\uXXXX`** 仅当数值 **`≤ 255`** 时合法（单 **`byte`** 语义，与 **`\\x`** 在 **`0x00`..`0xFF`** 范围内一致），否则词法报错。

### 0.49.41（2026-03-22）

- **字符串字面量后缀（切片 / 下标）**：普通双引号 **`"..."`** 可作为**主表达式**，并允许与标识符、数组字面量相同的 **`[` `]`** 后缀：
  - **`"text"[i]`**：按字节下标，类型为 **`byte`**（基类型为字符串字面量的 `*byte` / 指向 **`byte`** 的指针语义）。
  - **`"text"[start:len]`**：切片表达式，类型为 **`&[byte]`**（与 **`&arr[start:len]`** 一致）；**`&"hello"[0:3]`** 为一元 **`&`** 作用于该切片，类型为 **`&[byte]`**（指向切片胖指针的指针，与现有 **`const s: &[byte] = &buf[0:n];`** 一致）。
  - **编译期边界**（安全证明）：将字面量的逻辑长度视为 **「`strlen`(可见内容) + 1」**（含结尾 **`\\0`**），与 **`const a: [byte: N] = "hello";`** 中 **`N ≥ 可见字符数+1`** 一致，用于 **`[start:len]`** 的常量 **`start`/`len`** 检查。
- **词法 · 双引号字符串转义**：在 **`\\n` `\\t` `\\\\` `\\"` `\\0`** 之外，明确支持 **`\\r`**（回车，ASCII 13），与字符字面量 **`'\\r'`** 一致。
- **`@print` / `@println`**：除既有 **`i8`/`[i8:N]`/`&[i8]`** 等外，明确支持以 **C 字符串形式**打印 **`byte`（`TYPE_BYTE`）**、**`u8`** 的 **`[T:N]`**、**`&[T]`**（元素为 **`byte`/`u8`/`i8`**）及相应指针；见 [builtin_functions.md](./builtin_functions.md#7-调试打印函数)。

### 0.49.40（2026-03-22）

- **标准库 `std.thread`**：对外仅保留 **`async_compute<T>(pool, compute_fn, arg) -> Future<!T>`** 作为线程池计算任务入口；已移除 12 个 **`async_compute_i32` / `async_compute_usize` / …** 特化导出（**破坏性变更**）。**`AsyncComputeI32Future`** 等 **typedef** 仍为 **`AsyncComputeFuture<T>`** 的别名。**C99**：**`async_compute<T>`** 单态仍由专用路径生成（因 **`thread_type_is_*(T)`** 在 C 体阶段无法可靠折叠，不能仅靠展开 Uya 函数体）；现改为调用 **`std_thread_async_compute_future_new_<T>`** 再装箱 **`Future<!T>`**，与 **`thread_async_compute_future_new<T>`** 语义一致。**测试**：**`test_std_thread.uya`**、**`test_async_compute_types.uya`** 已改用泛型入口。

### 0.49.38（2026-03-20）

- **SIMD：`@vector.reduce_mul(v)`**（阶段 4 / `reduce_*` 子集）：**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，语义为 **`v.lanes[0] * v.lanes[1] * … * v.lanes[N-1]`**（按通道使用与标量 **`\*`** 相同的包装/溢出规则）。**C99**：**`i32`/`u32`/`f32`** 的 **`×2`/`×4`** 发射 **`uya_simd_*_reduce_mul_*`** 助手（SSE2 `_mm_mul_*`；i32/u32 ×4 用 SSE4.1 `_mm_mullo_epi32`，无 SSE4.1 时自动回退标量循环）；其余类型用 **`while` 循环**累乘。**`×2`**：`f32` 用 SSE2 `_mm_mul_ss`，整数用标量；**`×4`**：`f32` 用 SSE2 `_mm_mul_ps`。**测试**：`test_simd_vector_reduce_mul.uya`。

### 0.49.39（2026-03-20）

- **SIMD：`@vector.reduce_min(v)` / `@vector.reduce_max(v)`**（阶段 4 / `reduce_*` 子集）：**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，分别为各通道的最小值 / 最大值。**C99**：全部 **`while` 循环** scalar 回退（SSE2 无水平 min/max，等效使用 SSE4.1 `_mm_min_epi32`/`_mm_max_epi32` 时需额外检测；其余与 `reduce_add` 一致的元素类型约束）。**测试**：`test_simd_vector_reduce_min_max.uya`。

### 0.49.37（2026-03-20）

- **C99 SIMD（实现）**：**`@vector.reduce_add`** 对 **`i32`/`u32`/`f32`** 的 **`×2`/`×4`** 按需发射 **`uya_simd_*_reduce_add_*`** 助手；类型收集阶段为 **函数形参** 与 **块内** **`const`/`var`** 维护与代码生成一致的局部类型视图，使 **`simd_emit_reduce_add_*`** 与 **`c99_simd_need_emit_i32_u32_f32`** 正确置位（修复仅引用局部/形参向量时的 **链接 undefined**）。**语言语义**与 **0.49.36** 一致。

### 0.49.36（2026-03-20）

- **SIMD：`@vector.reduce_add(v)`**（阶段 4 / `reduce_*` 子集）：**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**（与第一阶段向量元素集一致）；结果为标量 **`T`**，语义为 **`v.lanes[0] + v.lanes[1] + … + v.lanes[N-1]`**（按通道使用与标量 **`+`** 相同的包装/溢出规则）。**C99**：默认语句表达式内临时向量 + **`while` 循环**累加；**`i32`/`u32`/`f32`** 的 **`×2`/`×4`** 在 **0.49.37** 起可发射按需 **`uya_simd_*_reduce_add_*`** 助手（见该条）。**测试**：`test_simd_vector_reduce_add.uya`；负例 **`error_simd_vector_reduce_add_not_vector.uya`**。

### 0.49.35（2026-03-20）

- **SIMD：`@vector.select(m, a, b)`**（阶段 4 扩展）：**`m`** 为 **`@mask(N)`**，**`a`**、**`b`** 为**完全相同**的 **`@vector(T,N)`**，且 **`N`** 与掩码通道数一致；逐通道语义为 **`m.lanes[i]` 为真则取 `a.lanes[i]`，否则取 `b.lanes[i]`**；结果类型为 **`@vector(T,N)`**。目标向量类型上下文与 **`@vector.splat`** / **`load`** 一致（含与同一代数式对侧向量对齐推断）。**C99**：逐通道三元表达式写入结果 **`struct uya_simd_vector_*`**（与标量回退布局一致；未单独接 SSE `blend`）。**测试**：`test_simd_vector_select.uya`；负例 **`error_simd_vector_select_mask_lanes.uya`**。

### 0.49.34（2026-03-20）

- **SIMD：`@vector.store(ptr, v)`**（阶段 4 扩展）：**`v`** 为 **`@vector(T,N)`**，**`ptr`** 为 **`&T`**，与 **`v`** 的元素类型匹配（**`byte`/`u8`** 互通规则与 **`@vector.load`** 一致）；将 **`v`** 的内存表示按 **`sizeof(@vector(T,N))`** 写入 **`ptr`** 所指地址；**结果为 `void`**，**不可**用于需要非 **`void`** 的上下文。**C99**：**`__uya_memcpy((void*)ptr, &v_tmp, sizeof(...))`**。**测试**：`test_simd_vector_store.uya`；负例 **`error_simd_vector_store_pointee_mismatch.uya`**。

### 0.49.33（2026-03-20）

- **SIMD：`@vector.load(ptr)`**（阶段 4 扩展）：从 **`ptr`** 所指向内存按 **`sizeof(@vector(T,N))`** 装入 **`@vector(T,N)`**；**`ptr`** 须为 **`&T`**（**`&byte`** 与 **`&u8`** 在与 **`u8`** 元素向量匹配时互通）；目标 **`@vector(T,N)`** 由 **`const`/`var` 标注、`return`、与同一代数/比较式对侧 `@vector` 等上下文**确定（与 **`@vector.splat`** 一致）。**C99**：**`__uya_memcpy`** 写入 **`struct uya_simd_vector_*`**（语义与标量回退布局一致；非直接 `mm_loadu`）。**测试**：`test_simd_vector_load.uya`；负例 **`error_simd_vector_load_pointee_mismatch.uya`**。**`std.json`**：`skip_ws` 增加 **`@vector(u8,16)`** 块扫描（全空白则 **`pos += 16`**，否则回退标量循环）。

### 0.49.30（2026-03-19）

- **C99 SIMD：`i8` / `u8` / `i64` / `u64`**：`types.uya` 生成 **`uya_simd_sse_*_i8x16`/`x8`/`x4`/`x2`**、**`*_u8x*`**、**`*_i64x2`**、**`*_u64x2`** 及 **掩码**（**SSE** / **NEON** / **`#else`** 三档）；`expr.uya`：**`fast_kind` 123–186**、**i8/u8** 按 **16/8/4/2** 剩余宽度选助手、**i64/u64** 按 **2** 通道平铺；**`@vector.splat`** 与 **一元 `-`**。**脚本**：`scripts/gen_simd_i8_i64_helpers.py`（`sse` / `portable`）。**测试**：`test_simd_i8_u8_i64_sse.uya`。

### 0.49.29（2026-03-19）

- **C99 SIMD：`2×i32` / `2×u32` / `2×f32` 快路径**：新增 **`uya_simd_sse_*_i32x2`**、**`*_u32x2`**、**`*_f32x2`** 及对应 **`@mask(2)`** 比较助手（**SSE** 低 **64 位** `loadl`/`storel`、**NEON** `int32x2_t` / `uint32x2_t` / `float32x2_t`、**`#else`** 二通道循环）；**`@vector.splat`** 与 **一元 `-`**（`i32`/`f32`）走 **`splat_*x2` / `neg_*x2`**。`expr.uya`：`c99_simd_sse_i32_u32_f32_two_or_x4_lane_ok`、`c99_simd_emit_sse_binary_fast_at` 在 **`lanes == 2`** 时分派 **`x2`**。**测试**：`test_simd_vec2_i32_u32_f32.uya`；夹具 **`simd_c99_neon.uya`** 增补 **2×** 片段。

### 0.49.28（2026-03-19）

- **SIMD**：**`2×/4×f64` 向量 `+` / `-` / 一元 `-`**（`uya_simd_sse_add_f64x2`、`sub_f64x2`、`neg_f64x2`）；**`4×/8×i16`** 增补 **六种比较**、**一元 `-`**、**`@vector.splat` 快路径**（**4×** 使用 **`_i16x4` / `_i16x4_mask`** 等 **64 位** 访存，**8×** 使用 **`_i16x8`**）；**`4×/8×u16` 向量 `+` / `-` / `*` 与六种比较、`splat`**（`**_u16x4` / `_u16x8`** 等，无符号比较在 SSE 上为 **0x8000 bias + 有符号比较**）。

### 0.49.27（2026-03-20）

- **SIMD**：新增 `4×/8×i16` 向量 `-` / `*` C99 快路径（`uya_simd_sse_sub_i16x8`、`uya_simd_sse_mul_i16x8`，SSE2 `__m128i` / NEON `int16x8_t` / 标量；4× 复用 8× 助手）。

### 0.49.26（2026-03-19）

- **SIMD**：新增 `4×/8×i16` 向量 `+` / `==` C99 快路径（`uya_simd_sse_add_i16x8`、`uya_simd_sse_eq_i16x8_mask`，SSE2 `__m128i` / NEON `int16x8_t` / 标量；4× 复用 8× 助手）。

### 0.49.25（2026-03-19）

- **SIMD**：新增 `2×/4×f64` 向量 `*` / `/` C99 快路径（`uya_simd_sse_mul_f64x2`、`uya_simd_sse_div_f64x2`，SSE2 `__m128d` / NEON `float64x2_t` / 标量；4× 为两次 2× 调用）。

### 0.49.24（2026-03-19）

- **SIMD**：新增 `4×i32` / `4×u32` 向量 `<<` / `>>` C99 快路径（`uya_simd_sse_shl_i32x4`、`uya_simd_sse_shr_i32x4`、`uya_simd_sse_shl_u32x4`、`uya_simd_sse_shr_u32x4`，三档均为标量逐通道位移）。

### 0.49.23（2026-03-19）

- **C99 SIMD：`4×i32` / `4×u32` 向量 `%`（取模）**：新增 **`uya_simd_sse_rem_i32x4`**、**`uya_simd_sse_rem_u32x4`**（三档均为对应整数类型 **四通道 C 取模**）。`expr.uya` 映射 **`fast_kind` 17 / 27**。
- **测试**：`test_simd_u32_basic.uya` 增补 `u32` 取模；`test_simd_vector_mod_i32.uya` 继续覆盖 `i32`；夹具 **`simd_c99_neon.uya`** 增补 `i32`/`u32` 取模。

### 0.49.22（2026-03-19）

- **C99 SIMD：`4×i32` 向量 `/`**：新增 **`uya_simd_sse_div_i32x4`**（**SSE / NEON / `#else`** 均为 **`int32_t` 四通道 C 除法**）。`expr.uya` 映射 **`fast_kind` 16**。
- **测试**：`test_simd_div_f32_i32.uya` 增补 `-7 / 2 → -3`；夹具 **`simd_c99_neon.uya`** 增补 `i32` 除与 `u32` `* /`，供 NEON 交叉片段覆盖 `div_i32x4`、`mul_u32x4`、`div_u32x4`。

### 0.49.21（2026-03-19）

- **C99 SIMD：`4×u32` 向量 `/`**：新增 **`uya_simd_sse_div_u32x4`**（**SSE / NEON / `#else`** 均为 **`uint32_t` 四通道 C 除法**，无硬件整除向量指令）。`expr.uya` 映射 **`fast_kind` 26**。多宽仍按 x4 分块调用。
- **测试**：`test_simd_u32_basic.uya` 增补 `7u32 / 2u32 → 3u32`（向零截断）。

### 0.49.20（2026-03-19）

- **C99 SIMD：`4×u32` 向量 `*`**：新增 **`uya_simd_sse_mul_u32x4`**（x86：与 `i32` 相同在 **`__SSE4_1__`** 下用 `_mm_mullo_epi32`，否则 **`uint32_t` 逐通道**；ARM NEON：`vmulq_u32`；**`#else`**：`uint32_t` 循环）。`expr.uya` 映射 **`fast_kind` 22**。多宽向量仍按 x4 分块调用。
- **测试**：`test_simd_u32_basic.uya` 增补 `0x80000000u32 * 2u32 → 0` 用例。

### 0.49.19（2026-03-19）

- **C99 SIMD lowering（32 / 64 通道）**：**`@vector(i32|u32|f32, 32|64)`** 与 **`@mask(32|64)`** 通过 **8 / 16 次** 既有 **`uya_simd_sse_*x4`**（连续 `lanes` 块）；**`@vector.splat`**、一元 **`-`** 与已支持二元式同逻辑。**无新 C 符号**。（**`@vector(..., 2)`** 等仍走标量逐通道，不调用 x4 助手。）
- **测试**：`test_simd_vec32_sse_chain.uya`、`test_simd_vec64_sse_chain.uya`。

### 0.49.18（2026-03-19）

- **C99 SIMD lowering（16 通道）**：**`@vector(i32|u32|f32, 16)`** 与 **`@mask(16)`** 通过 **四次** 既有 **`uya_simd_sse_*x4`**（`lanes` 偏移 `0, 4, 8, 12`）；**`@vector.splat`**、一元 **`-`** 与已支持二元式同逻辑。**无新 C 符号**。
- **测试**：`test_simd_vec16_sse_chain.uya`。

### 0.49.17（2026-03-19）

- **C99 SIMD lowering（8 通道）**：对 **`@vector(i32|u32|f32, 8)`** 与 **`@mask(8)`**，在已有 **4×** `uya_simd_sse_*` 助手不变的前提下，代码生成对 **低/高 4 通道**各调用一次（`lanes` / `&lanes[4]`）；**`@vector.splat`**、一元 **`-`** 与已支持的二元比较/算术等同理。**无新 C 助手符号**。
- **测试**：`test_simd_vec8_sse_chain.uya`。

### 0.49.16（2026-03-19）

- **C99 SIMD lowering（ARM NEON）**：在 **`(GCC 或 Clang) && defined(__ARM_NEON)`** 时，生成的 C 在 **`#elif UYA_HAVE_SIMD_ARM_NEON`** 分支内 **`#include <arm_neon.h>`**，对既有 **`uya_simd_sse_*`** 助手名提供 **4×`i32`/`u32`/`f32`** 的 NEON 实现（与 x86_64 的 **`#if UYA_HAVE_SIMD_X86_SSE`** 择一；**`#else`** 仍为逐通道标量）。**`expr.uya` 调用名不变**（历史命名保留）。
- **验证**：`tests/verify_simd_c99_neon.sh`（源 `tests/simd_c99_neon.uya`，与默认并行测试共用；`zig cc` 对抽出之 NEON 片段做 **AArch64** 与 **arm-linux-gnueabihf + NEON** 交叉 `-c`，避免完整生成 C 与交叉 libc `stdint`  typedef 冲突）。

### 0.49.15（2026-03-19）

- **C99 SIMD lowering（4×`u32` 有序比较）**：在 x86_64 SSE 快路径上，**4×`u32`** 的 **`<` `>` `<=` `>=`** → `@mask(4)` 生成 `uya_simd_sse_{lt,gt,le,ge}_u32x4_mask`（与 `0x80000000` 异或后用 `_mm_cmplt_epi32` 等有符号内建实现无符号序关系；`<=`/`>=` 结合 `_mm_cmpeq_epi32`）；**`==` / `!=`** 仍走按位 `uya_simd_sse_{eq,ne}_i32x4_mask`。宿主 **`#else`** 为同名标量 `static inline`。
- **测试**：`test_simd_sse_compare_ops.uya`（含 `0xFFFFFFFEu32` / `0xFFFFFFFFu32` 与 `0` / `0xFFFFFFFFu32` 绕序场景）。

### 0.49.14（2026-03-19）

- **C99 `@syscall`**：在 **Linux ARM32（EABI，`__arm__` 且非 `__aarch64__`）** 下增加 **`#elif defined(__arm__) && !defined(__aarch64__) && defined(__linux__)`** 分支：`svc 0`，系统调用号在 **r7**，参数 **r0**–**r5**；内联汇编在 Thumb 下通过临时操作数保存/恢复 r7（与常见 musl 做法一致）。**x86_64** 与 **Linux AArch64** 路径不变。
- **验证**：`tests/verify_syscall_c99_cross.sh`（`make check` / `make check-hosted`）；其中 ARM 目标对完整生成 C 与 gnueabihf 头文件可能 typedef 冲突，脚本仅抽出 ARM 分支片段做 **`zig cc -target arm-linux-gnueabihf -c`** 检查。

### 0.49.13（2026-03-19）

- **C99 `@syscall`**：生成 `uya_syscall0`…`uya_syscall6` 时，在 **Linux AArch64** 目标下增加 **`#elif (defined(__aarch64__) || defined(_M_ARM64)) && defined(__linux__)`** 分支（`svc 0`，`x8`=系统调用号，`x0`–`x5`=参数），便于 **`zig cc -target aarch64-linux-gnu`** 等交叉编译时不再落入唯一条 `#error`；**x86_64** 路径不变。
- **验证**：`make check` / `make check-hosted`（含 `@syscall` 生成 C 的交叉目标检查，脚本见当前仓库 `tests/verify_syscall_c99_cross.sh`）。

### 0.49.12（2026-03-19）

- **C99 SIMD lowering（向量比较扩展）**：在 x86_64 SSE 快路径上，**4×`i32`** 支持 **`==` `!=` `<` `>` `<=` `>=`** → `@mask(4)`；**4×`f32`** 同样六种关系（`_mm_cmp*_ps`）；**4×`u32`** 在 0.49.12 起 **`==` / `!=`** 走 `uya_simd_sse_{eq,ne}_i32x4_mask`；**有序比较** 在 **0.49.15** 起走 `uya_simd_sse_{lt,gt,le,ge}_u32x4_mask`（此前为逐通道标量）。宿主 **`#else`** 为同名标量 `static inline`。
- **测试**：`test_simd_sse_compare_ops.uya`。
- **文档**：§5.1.1 勘误——使用 **`bin/uya` / `uya build` 等官方入口**时，编译器在检测到 **`export fn main`**、非导出的 **`fn main`** 或顶层 **`test "…"`** 时，会**自动**将 `std/runtime/entry/entry.uya` 加入编译单元；用户程序**不需要**、也**不应依赖**在源码中写 `use std.runtime.entry` 来引入该文件。仅在你**自行**只把 `app.uya` 交给其它工具链、且**未**走上述驱动时，才需手动把 `entry.uya` 列入输入（见下文说明）。

### 0.49.11（2026-03-19）

- **文档**：新增 [附录 C. 交叉编译（工具链）](#附录-c-交叉编译工具链)，说明 `HOST_*` / `TARGET_*`、`TARGET_TRIPLE`、`CC_DRIVER` / `CC_TARGET_FLAGS`、`TOOLCHAIN=zig` 与 `make` / `compile.sh` / `uya build -e` 的关系；详述与限制见 [UYA_BUILD_RUN.md](./UYA_BUILD_RUN.md)。

### 0.49.10（2026-03-19）

- **C99 SIMD 阶段 4（初版 lowering）**：在 `(GCC 或 Clang) && x86_64 && SSE2` 时，对 **4 宽** `@vector(int32_t|uint32_t|f32, 4)` 的部分运算（`+`、`-`、有符号 `i32` 的 `*`（SSE4.1 为 `_mm_mullo_epi32`，否则按通道标量）、`&`、`|`、`^`、`==`→`@mask(4)`）及 **`@vector.splat` / 一元 `-`** 生成对 `uya_simd_sse_*` **static inline** 的调用；宿主 C 在 **`#if UYA_HAVE_SIMD_X86_SSE`** 分支内使用 `<emmintrin.h>` / `<xmmintrin.h>` 内建，**`#else`** 分支为逐通道标量实现，保证非 x86 与 MSVC 等环境语义一致。表达式内**不使用**预处理器分支（避免 GNU 语句表达式内出现 `#if`）。
- **测试**：`test_simd_sse_lower_i32x4.uya`。

### 0.49.9（2026-03-19）

- **C99 `catch` 与类型别名载荷**：当 `catch` 需从生成的 `struct err_union_*` C 类型名反推成功载荷类型时，若载荷名为**类型别名**（例如 `type Vec4i32 = @vector(i32, 4)`），中间结果变量须使用与该别名 `typedef` 一致的 C 标识符，不得误写为 `struct Vec4i32` 等不存在的结构体标签。
- **C99 SIMD 掩码预收集**：在输出 `uya_simd_mask_N` 等定义之前，代码生成收集阶段对函数体内的向量相等比较预解析 `@mask(N)` 并注册；遍历 AST 进入函数体时须具备当前函数上下文，以便解析局部/参数上的向量类型。
- **测试**：`test_simd_return_splat_binary.uya`（含 `catch` + `!Vec4i32`）、`test_simd_mask_inline_compare.uya`（源码中不显式写出 `@mask` 类型，仅 `@vector.all(向量 == splat)`）。

### 0.49.8（2026-03-19）

- **SIMD 类型检查**：`return` 表达式的期望类型与函数返回类型一致；当返回类型为 `@vector(T, N)` 或 `!T` 且成功载荷为 `@vector(T, N)` 时，类型检查器在推断 `return` 子表达式之前，按该向量类型绑定其中未解析的 `@vector.splat`（含嵌套二元式中「两侧均为 splat」的情形），与变量初始化上下文及 C99 代码生成行为对齐。
- **C99 错误联合**：`emit_pending_err_union_structs` 对载荷为 `@vector`/`@mask` 或**类型别名**最终指向它们的 `!T`，输出完整 `struct err_union_*` 定义，避免仅前向声明导致宿主 C 编译失败。
- **测试**：`test_simd_return_splat_binary.uya`。

### 0.49.7（2026-03-19）

- **SIMD 代码生成**：当 `@vector.splat` 在 AST 上尚未绑定 `simd_splat_target_type` 时，C99 代码生成仍可从当前 **`expected_type`（如 `const`/`var` 初始化上下文）**、当前**函数返回类型**（若可解析为 `@vector`），或与同一代数表达式**对侧**已能解析出的 `@vector` 类型，解析出目标向量类型，从而对 `@vector.splat(a) + @vector.splat(b)` 等形式生成按通道 SIMD 回退代码，而非误走标量饱和/包装路径。
- **测试**：`test_simd_splat_binary_context.uya`。

### 0.49.6（2026-03-19）

- **SIMD 向量饱和 / 包装运算**：`+|`、`-|`、`*|` 可用于相同类型的 **有符号整数元素** `@vector(T, N)`，按通道语义与标量一致；`+%`、`-%`、`*%` 可用于相同类型的 **任意整数元素** `@vector(T, N)`，按通道包装语义与标量一致。
- **`@vector.splat` 推断**：上述运算符与同通道算术、取模等一样，可从对侧 `@vector` 推断 `@vector.splat` 的目标类型。
- **测试**：`test_simd_vector_sat_wrap_i32.uya`；负例 `error_simd_float_vector_plus_pipe.uya`、`error_simd_u32_vector_plus_pipe.uya`（取代原 `error_simd_vector_plus_pipe` / `error_simd_vector_plus_percent` / `error_simd_vector_asterisk_pipe`）。

### 0.49.5（2026-03-19）

- **SIMD 向量取模**：`%%` 可用于相同类型的整数元素 `@vector(T, N)`，按通道取模，结果类型不变；浮点元素向量不支持向量 `%%`（与标量规则一致）。
- **`@vector.splat` 推断**：向量取模表达式与向量算术、比较、位运算、位移一样，可从对侧 `@vector` 推断 `@vector.splat` 的目标类型。
- **测试**：`test_simd_vector_mod_i32.uya`；负例 `error_simd_float_vector_mod.uya`（原 `error_simd_vector_mod.uya` 由「不支持向量取模」改为浮点向量取模非法）。

### 0.49.4（2026-03-19）

- **SIMD 一元运算**：明确一元 `-` 可用于整数或浮点元素的 `@vector(T, N)`；一元 `~` 仅用于整数元素向量（与既有实现一致）。
- **测试**：`test_simd_unary_ops.uya`。

### 0.49.3（2026-03-19）

- **SIMD `@vector.splat` 推断**：在向量算术、比较以及整数向量的位运算、位移中，若另一侧表达式类型为已解析的 `@vector(T, N)`，则编译器可将该类型作为 `@vector.splat(x)` 的目标向量类型（仍须满足参数 `x` 与元素类型 `T` 一致或可隐式转换）。

### 0.49.2（2026-03-19）

- **浮点字面量后缀**：修复 `TOKEN_FLOAT` 路径下 `f32` / `f64` 后缀识别（此前仅截取尾部连续字母，无法识别含数字的 `f32`/`f64`）。
- **SIMD 文档与示例**：明确 `@vector.splat(x)` 的参数类型须与目标向量元素类型 `T` 一致或可隐式转换；`f32` 向量应使用 `1.0f32` 等后缀字面量（无后缀浮点默认为 `f64`）。
- **测试**：`test_simd_struct_field_ops.uya`（结构体字段上的向量/掩码与 `@vector.all`）、`test_simd_splat_f32_suffix.uya`。

### 0.49.1（2026-03-19）

- **SIMD 向量内建**（新增规范）：
  - 新增 `@vector(T, N)` 向量类型与 `@mask(N)` 掩码类型
  - 新增最小辅助内建：`@vector.splat(x)`、`@vector.any(m)`、`@vector.all(m)`
  - 第一阶段支持向量算术、整数向量位运算、比较与掩码逻辑
  - `@mask(N)` 不隐式转换为 `bool`
  - 详见 §16 内置函数、[grammar_formal.md](./grammar_formal.md)

### 0.49（2026-03-17）

- **字符串字面量赋值**（规范明确，编译器已实现）：
  - 字符串字面量可赋给 `[byte: N]`（自动 `\0` 结尾，长度需 ≥ 可见字符数+1）、`&byte`、`*byte`
  - 详见 §1.4 字符串字面量
- **字符字面量**（新增语法与类型）：
  - 单引号字面量 `'x'`、`'\n'` 等可赋给 `byte` 类型
  - 支持转义：`\n` `\t` `\0` `\\` `\'` `\r` `\"`
  - 用于数组元素赋值、常量初始化等，如 `buf[3] = 'c'`、`const c: byte = 'A';`

### 0.47（2026-02-16）

- **泛型方法支持**（新增）：
  - 结构体/联合体方法支持泛型参数：`fn method<T>(self: &Self) ReturnType`
  - 方法调用支持显式类型参数：`obj.method<ConcreteType>()`
  - 单态化生成专门函数，零运行时开销
  - **用途**：简化 Union 类型安全访问，实现类型转换方法

- **语法更新**：
  - 更新附录 B.1 泛型语法，添加方法泛型章节（B.1.4）
  - 文档标注泛型函数、结构体泛型、接口泛型、方法泛型的完整语法

### 0.46（2026-02-15）

- **应用程序入口规范化**：
  - 应用程序 main 函数必须使用 `export fn main() i32` 或 `export fn main() !i32`
  - `export fn main()` 编译为 `main_main()`，由 `lib/std/runtime/entry/entry.uya` 调用
  - 测试程序同样使用 `export fn main() i32`，实现零依赖（无需 bridge.c）
  - **用途**：统一应用程序入口规范，支持纯 Uya 运行时

### 0.45（2026-02-15）

- **Scheme C 双入口架构**（新增）：
  - `export fn main()` → 生成 `main_main()`（应用入口）
  - `export extern fn main(argc: i32, argv: &&byte)` → 生成 `main()`（C 入口，供 C 调用）
  - `fn main()` → 生成 `uya_main()`（旧架构兼容）
  - 新增 `lib/std/runtime/entry/` 模块提供 C 入口函数
  - **用途**：支持标准 C main 签名，与 C 生态无缝集成

- **libc 标准库增强**：
  - `fprintf`/`sprintf`/`snprintf` 格式与 C99 对齐：`%g`、`%zu`、`%zd`、`%a`/`%A`（十六进制浮点）、`%j`/`%t`/`%h`/`%hh`、flags/width/precision、`%*s`、`%u` 等
  - `readdir` 使用 `sys_getdents64` 实现

### 0.44（2026-02-14）

- **`@va_start` / `@va_end` / `@va_arg` / `@va_copy` 内置函数**（新增）：
  - 语法：`@va_start(&ap, last)`、`@va_end(&ap)`、`@va_arg(ap, Type)`、`@va_copy(&dest, src)`
  - `va_list` 是编译器内置类型，大小与目标平台相关
  - 在可变参数函数内初始化/结束 va_list 访问，或接收 va_list 参数的函数内使用 @va_arg
  - 编译时展开为 C 的 `va_start`/`va_end`/`va_arg`/`va_copy` 宏
  - 用于将可变参数传递给 vprintf/vfprintf 等 C 函数，支持纯 Uya 实现 libc.stdarg、libc.vprintf
  - **约束**：`@va_start` 仅可在形参含 `...` 的可变参数函数内使用；`@va_arg` 可在可变参数函数内或接收 va_list 参数的函数内使用
  - **示例**：
    ```uya
    fn sum_ints(count: i32, ...) i32 {
        var ap: va_list = va_list{};
        @va_start(&ap, count);
        var total: i32 = 0;
        var i: i32 = 0;
        while i < count {
            total += @va_arg(ap, i32);
            i += 1;
        }
        @va_end(&ap);
        return total;
    }
    ```

### 0.43（2026-02-14）

- **`extern "libc" fn` 语法**（新增）：
  - 语法：`extern "libc" fn name(...) type;` 或 `export extern "libc" fn name(...) type { }`
  - 显式声明 C 标准库函数，明确 FFI 意图
  - `byte` 映射为 `char`（与 C 标准库兼容）
  - 生成的 C 代码：裸函数名（无模块前缀）
  - **示例**：
    ```uya
    // 链接到 C 标准库
    extern "libc" fn strlen(s: *const byte) usize;
    
    // 用 Uya 实现 C 标准库函数
    export extern "libc" fn my_strlen(s: *const byte) usize {
        if s == null { return 0; }
        var len: usize = 0;
        while s[len] != 0 { len = len + 1; }
        return len;
    }
    ```

- **`extern` 变量支持**（新增）：
  - **导入 C 全局变量**：
    - `extern const name: type;` - 导入只读 C 变量
    - `extern var name: type;` - 导入可变 C 变量
  - **导出 Uya 变量给 C**：
    - `export const name: type = value;` - 导出只读常量
    - `export var name: type = value;` - 导出可变变量
    - `export extern const name: type;` - 链接到 C 库定义
  - **示例**：
    ```uya
    // 导入 C 标准库变量
    extern const errno: i32;
    extern const stdout: *void;
    
    // 导出给 C 使用
    export const VERSION: &byte = "1.0.0";
    export var debug_mode: i32 = 0;
    ```
  - **设计目的**：
    - 允许 Uya 代码访问 C 库的全局状态
    - `const`/`var` 明确区分只读和可变
    - 类型检查确保 C 兼容性

### 0.42（2026-02-04）

- **只读指针类型 `&const T`**（新增）：
  - 语法：`&const T` 表示只读指针，指向类型 `T` 的值，但不能通过该指针修改值
  - **C 代码生成**：`&const T` → `const T *`（C 的 const 指针）
  - **使用场景**：
    - 函数参数：只读字符串参数应使用 `&const byte` 而不是 `&byte`
    - 标准库函数：`strcmp`, `strlen`, `strstr` 等函数的只读参数应使用 `&const byte`
    - 类型安全：编译期检查，防止通过只读指针修改值
  - **与 `&T` 的区别**：
    - `&T`：可变指针，可以修改指向的值（C 代码生成：`T *`）
    - `&const T`：只读指针，不能修改指向的值（C 代码生成：`const T *`）
  - **类型转换规则**：
    - `&T` 可以隐式转换为 `&const T`（放宽约束，安全）
    - `&const T` 不能转换为 `&T`（收紧约束，需要显式转换）
  - **示例**：
    ```uya
    // 标准库函数定义（Uya 实现，以裸 C 名称导出）
    export extern fn strcmp(s1: &const byte, s2: &const byte) i32 {
        // Uya 实现代码
        return 0;
    }
    // 生成的 C 代码：int strcmp(const char *s1, const char *s2) { ... }
    // 注意：不带 uya_ 前缀

    // 标准库函数声明（链接到 C 标准库）
    export extern fn malloc(size: usize) *void;
    // 不生成代码，链接到 C 标准库的 malloc

    // 普通导出函数（带 uya_ 前缀）
    export fn my_function() i32 { return 42; }
    // 生成的 C 代码：int uya_my_function(void) { return 42; }

    // 函数参数
    fn process_string(s: &const byte) void {
        // s 是只读的，不能修改 *s
    }
    ```
  - **FFI 指针类型**：
    - `*const T`：FFI 只读指针（C 代码生成：`const T *`）
    - `*T`：FFI 可变指针（C 代码生成：`T *`）
  - **设计目的**：
    - 类型系统更精确，编译期捕获 const 限定符错误
    - 生成的 C 代码更符合 C 标准，减少 `-Wdiscarded-qualifiers` 警告
    - 减少代码生成器的特殊处理逻辑

- **函数导出规则完善**：
  - **`fn`**：内部函数，生成的 C 代码添加 `static` 关键字（`static void foo(void)`）
  - **`export fn`**：导出函数，若被当前编译单元的入口/测试/可达代码引用，则生成的 C 代码不添加 `static`（`void foo(void)`），带 `uya_` 前缀（`uya_foo`）
  - **`extern fn`**：外部 C 函数声明，生成的 C 代码为 `extern void foo(void);`
  - **`extern fn`**（有函数体）：Uya 实现的 C 兼容函数，生成的 C 代码为 `void foo(void) { ... }`（不带 `uya_` 前缀）
  - **`export extern fn`**（无函数体）：不生成任何代码，链接到 C 标准库的实现
  - **`export extern fn`**（有函数体）：Uya 实现，始终保留并生成 C 代码 `void foo(void) { ... }`（不带 `uya_` 前缀）
  - **设计目的**：
    - 明确函数可见性：内部函数使用 `static`，避免符号冲突
    - 符合 C 语言惯例：只有导出的函数才在全局命名空间
    - 提升代码质量：减少不必要的全局符号
    - 支持标准库实现：Uya 标准库中的函数可以以裸 C 名称导出

### 0.40（2026-02-04）

- **内置函数命名统一**：
  - `@sizeof(T)` → `@size_of(T)`（复合概念用 snake_case）
  - `@alignof(T)` → `@align_of(T)`（复合概念用 snake_case）
  - **命名惯例确立**：
    - 单一概念：`@len`, `@max`, `@min`（短形式）
    - 复合概念：`@size_of`, `@align_of`, `@async_fn`（下划线分隔）

- **泛型语法确定**：
  - 使用尖括号：`<T>`
  - 约束紧邻参数：`<T: Ord>`
  - 多约束连接：`<T: Ord + Clone + Default>`
  - 示例：`fn max<T: Ord>(a: T, b: T) T { ... }`，`struct Vec<T: Default> { ... }`

- **结构体默认值语法**（第 4 章）：
  - 支持在结构体定义中为字段指定默认值：`field: Type = default_value`
  - 初始化时可以使用 `Struct{}` 使用所有默认值，或 `Struct{ field: value }` 部分使用默认值（有默认值的字段可以忽略）
  - 默认值必须是编译期常量，零运行时开销
  - 与移动语义、RAII、接口实现完全兼容

- **异步编程基础设施**（新增第 18 章）：
  - **语言核心**（编译器实现）：
    - `@async_fn`：异步属性，可用于顶层函数、结构体/联合体方法实现和接口方法签名，触发 CPS 变换生成显式状态机
    - `@await`：唯一显式挂起点
    - `union Poll<T>`：异步计算结果类型
    - `interface Future<T>`：异步计算抽象
  - **函数签名约束**：必须返回 `Future<!T>` 或 `!Future<T>`（显式异步，无隐式包装）
  - **标准库实现**（基于核心类型）：
    - `std.async`：`Task<T>`, `Waker`
    - `std.channel`：`Channel<T>`, `MpscChannel<T>`
    - `std.runtime`：`Scheduler`
    - `std.thread`：`ThreadPool`, `async_compute<T>`
  - **设计哲学**：
    - 显式控制：所有挂起必须 `@await`，取消必须显式检查 `is_cancelled()`
    - 零成本：状态机栈分配，无运行时堆分配，无隐式锁
    - 编译期证明：状态机安全性、Send/Sync 推导、跨线程验证编译期完成
    - 类型安全：`Poll<T>` 使用 `union`（编译期标签跟踪），非 `enum`

- **宏系统规范细化**（新增第 25 章）：
  - **宏定义语法**：`mc ID(param_list) return_tag { statements }`
  - **编译时内置函数**：
    - `@mc_eval(expr)`：编译时求值
    - `@mc_type(expr)`：编译时类型反射，返回 `TypeInfo` 结构体
    - `@mc_ast(expr)`：代码转抽象语法树
    - `@mc_code(ast)`：抽象语法树转代码
    - `@mc_error(msg)`：编译时错误报告
    - `@mc_get_env(name)`：编译时环境变量读取
    - `@mc_source(expr)`：编译期将表达式序列化为字符串（源码形式）
  - **缓存机制**：相同宏调用自动缓存，提升编译性能
  - **安全限制**：递归深度、展开次数、嵌套层数限制
  - **完整示例**：编译时断言、类型驱动代码生成、配置系统等

### 0.39（2026-02-01）

- **方法 self 统一为 &T，*T 仅用于 FFI**（破坏性变更）：
  - 方法首个参数统一为 `self: &Self` 或 `self: &StructName`，替换原有 `self: *Self`
  - `*T` 仅用于 extern 函数声明/调用；调用 FFI 时可用 `&expr as *T` 转换
  - 与 `&T` 的区别：`&T` 用于普通变量、函数参数及方法 self；`*T` 仅用于 FFI

### 0.36（2026-02-01）

- **drop 定义位置**：
  - drop 只能在**结构体内部**或**方法块**中定义，禁止顶层 `fn drop(self: T) void`。
  - 与「不引入函数重载」的设计一致；每个类型的 drop 通过类型命名空间（结构体/方法块）区分。
  - 结构体：`struct S { fn drop(self: S) void { ... } }` 或 `S { fn drop(self: S) void { ... } }`。
  - 联合体同理：在联合体内部或方法块中定义 drop。

### 0.35（2026-02-01）

- **联合体支持**：
  - 添加 `union` 关键字定义标签联合体
  - 编译期标签跟踪确保类型安全
  - 强制模式匹配访问，处理所有变体
  - 与 C union 100% 内存布局兼容
  - 支持联合体方法和接口实现
  - 零运行时开销，标签仅在编译期使用
  - 详细错误信息指导正确使用

### 0.34（2026-01-31）

- **参数列表即元组（在函数体内可当元组访问）**
  - 当函数使用 **`@params` 内置变量**时，编译器将整个参数列表视为一个元组。
  - **统一语义**：对于**所有函数**（无论是否可变参数），`@params` 都包含所有参数，提供统一、类型安全的访问方式。
  - 示例：`fn f(x: i32, y: i32)` 内部可通过 `@params` 访问类型为 `(i32, i32)` 的值，使用 `@params.0`、`@params.1` 或解构 `const (a, b) = @params`。
  - 参数的类型序列在类型论上等价于一个元组类型；命名参数与「按位置访问的元组」两种视图并存，便于转发、泛型、反射式用法。

- **可变参数（C语法兼容 + 类型安全元组访问）**
  - **声明语法**：沿用 C 的 `...` 语法，如 `fn printf(fmt: *byte, ...) i32;`
  - **统一访问**：函数体内使用 `@params` 访问**所有参数**（包括固定参数和可变参数）作为元组
  - **编译器智能优化**：
    - 当函数体内**使用 `@params`**时，编译器自动生成代码将可变参数打包为元组
    - 当函数体内**未使用 `@params`**时，编译器直接转发参数，不生成元组打包代码，实现零开销转发
  - **ABI 兼容**：生成的可变参数函数在 ABI 层使用 C variadic 约定；函数入口使用 `va_start` 等将 `...` 读入并组为元组（仅当使用 `@params` 时）；Uya 调用 Uya 时按元组传参、生成时拆为 C variadic 传参。C 可直接调用 Uya 导出的可变参数函数，无需额外包装。
  - **格式串推断**：对 printf 风格 API，当使用 `@params` 时，可由格式串推断可变参数元组类型，实现类型检查。

- **字符串插值与 printf 的结合**
  - 插值格式说明符与 C printf 保持一致（已有）；当插值结果**仅作为 printf / print 的格式参数**时，允许编译器将插值**脱糖为单次** `printf(fmt, ...)` 调用，即生成「格式串 + 变参」一次调用，无需中间缓冲区。
  - 保留现有语义：插值结果类型仍为 `[i8: N]`，可赋给变量或作他用；仅在「仅用于打印」的上下文中可做上述优化。

---

## 核心特性

- **联合体**（第 4.5 章）：`union` 关键字，编译期标签跟踪，与 C union 100% 互操作，零运行时开销
- **原子类型**（第 13 章）：`atomic T` 关键字，自动原子指令，零运行时锁
- **内存安全强制**（第 14 章）：所有 UB 必须被编译期证明为安全（在当前函数内），常量错误→编译错误，变量证明失败→编译错误并给出修改建议
- **并发安全强制**（第 15 章）：零数据竞争
- **移动语义**（第 12.5 章）：结构体赋值时转移所有权，避免不必要的拷贝
- **字符串插值**（第 17 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **异步编程**（第 18 章）：`@async_fn`/`@await` + `union Poll<T>` + `interface Future<T>`，状态机零分配，挂起显式，并发安全编译期证明
- **模块系统**（第 1.5 章）：目录级模块、显式导出、路径导入，编译期解析
- **简化 for 循环语法**（第 8 章）：支持 `for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}` 等简化语法
- **运算符简化**（第 10 章）：`try` 关键字用于溢出检查，`+|`/`-|`/`*|` 用于饱和运算，`+%`/`-%`/`*%` 用于包装运算

---


## 设计哲学

### 核心思想：坚如磐石

Uya语言的设计哲学是**坚如磐石**（绝对可靠、不可动摇），将所有运行时不确定性转化为编译期的确定性结果：要么证明绝对安全，要么返回显式错误。

**核心机制**：
- 程序员提供**显式证明**，编译器验证证明的正确性
- 编译器在**当前函数内**完成所有安全验证，证明失败则报编译错误并给出修改建议
- 每个操作都有明确的**数学证明**，消除任何运行时不确定性
- 证明范围：仅限当前函数内的代码路径，跨函数调用需要显式处理
- 证明失败：编译器无法完成证明时，报编译错误并给出友好的修改建议
- 零运行时未定义行为，程序行为完全可预测

**示例**：

[examples/example_000.uya](./examples/example_000.uya)

> **注**：如需了解 Uya 与其他语言的对比，请参阅 [comparison.md](./comparison.md)

### 结果与收益

Uya的"坚如磐石"设计哲学带来以下不可动摇的收益：

1. **绝对的安全性**：通过数学证明彻底消除缓冲区溢出、空指针解引用等内存安全漏洞
2. **完全的可预测性**：程序行为在编译期完全确定，无任何运行时未定义行为
3. **最优的性能**：开发者编写显式安全检查，编译器在当前函数内验证其充分性，消除冗余的运行时安全检查，仅保留必要的错误处理逻辑
4. **明确的错误处理**：可能失败的操作返回错误联合类型`!T`，强制显式错误处理
5. **长期的可维护性**：代码行为清晰可预测，减少调试和维护成本

**性能保证**：

[examples/safe_access.uya](./examples/safe_access.uya)

**关键说明**：
- 编译器在当前函数内进行证明，证明失败则报编译错误并给出修改建议
- 错误路径保留显式检查，确保安全
- 编译器自动消除冗余检查，只保留必要的错误处理逻辑
- 证明失败：编译器无法完成证明时，报编译错误并给出友好的修改建议


### 设计哲学强化（0.40）

**显式控制**：
- 所有挂起必须 `@await`（异步编程），取消必须显式检查 `is_cancelled()`
- 无隐式转换，所有异步操作显式类型，无隐式包装
- 内置函数命名统一：单一概念用短形式（`@len`, `@max`, `@min`），复合概念用 snake_case（`@size_of`, `@align_of`, `@async_fn`）

**零成本**：
- 状态机栈分配（异步编程），无运行时堆分配，无隐式锁
- 编译期优化：状态机大小和布局编译期确定，零运行时开销
- 所有内置函数编译期折叠，零运行时调用开销

**编译期证明**：
- 状态机安全性、Send/Sync 推导、跨线程验证编译期完成
- 泛型语法确定：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`

### 一句话总结

> **Uya 的设计哲学 = 坚如磐石 = 程序员提供证明，编译器在当前函数内验证证明，运行时绝对安全**；
> **将运行时的不确定性转化为编译期的确定性，证明失败则报编译错误并给出修改建议。**
> **显式控制、零成本、编译期证明：所有挂起显式、状态机零分配、并发安全编译期验证。**

---

## 1 文件与词法

- 文件编码 UTF-8，Unix 换行 `\n`。
- **模块系统**：每个目录自动成为一个模块，详见[第 1.5 章](#15-模块系统)。
  - 项目根目录（包含 `main` 函数的目录）是 `main` 模块
  - 子目录路径映射到模块路径（如 `std/io/` → `std.io`）
  - 目录下的所有 `.uya` 文件都属于同一个模块
- 关键字保留：
  ```
  struct   const var fn return extern true false if while break continue
  defer errdefer try catch error null interface atomic union
  export use
  ```
- **内置函数**：所有内置函数均以 `@` 开头，无需导入。包括：`@size_of(T)`、`@align_of(T)`、`@len(a)`（数组长度）、`@max`、`@min`（整数类型极值，类型由上下文推断）、`@error_id(err)`（提取错误值的数值 ID）、`@embed("file")`（编译期嵌入单文件）、`@embed_dir("dir")`（编译期嵌入目录）。另外，`@c_import("path", cflags?, ldflags?);` 是顶层构建指令，用于把外部 C 源纳入当前构建图。
- 标识符 `[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- 数值字面量：
  - 整数字面量：
    - **十进制**：`123`（默认类型 `i32`，除非上下文需要其他整数类型）
    - **十六进制**：`0xFF`、`0x1A2B`、`0XDEAD_BEEF`（`0x` 或 `0X` 前缀）
    - **八进制**：`0o755`、`0O644`、`0o7_777`（`0o` 或 `0O` 前缀）
    - **二进制**：`0b1010`、`0B1111_0000`（`0b` 或 `0B` 前缀）
    - **下划线分隔符**：数字中可以包含下划线 `_` 提高可读性（如 `1_000_000`、`0xFF_00_AA`）
      - 下划线可以出现在任意两个数字之间
      - 下划线不能出现在开头、结尾或连续出现
      - 下划线不能紧跟在进制前缀之后（如 `0x_FF` 非法，`0xFF_00` 合法）
    - **类型后缀**（与实现保持一致）：
      - 支持的整数后缀：`i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`usize`
      - 语法形式：`<整数字面量><后缀>`，例如：
        - `100i8`、`-10i16`、`123i32`、`0i64`
        - `255u8`、`0xFFu8`、`1024u16`、`0b1010u32`
        - `100usize`
      - **含前缀的数字**（如 `0xFF`、`0b1010`）的后缀直接跟在数字末尾：`0xFFu8`、`0b1010i16`
      - 如果没有显式后缀，整数字面量默认类型为 `i32`
  - 浮点字面量：`123.456`（默认类型 `f64`，除非上下文需要 `f32`）
    - 也支持下划线分隔符：`3.141_592_653`、`1_000.5`、`1.0e1_0`
    - 仅支持十进制表示（不支持十六进制浮点如 `0x1.0p10`）
    - **类型后缀**：
      - 支持的浮点后缀：`f32`、`f64`
      - 示例：`1.5f32`、`3.14f64`、`1e10f64`
      - 如果没有显式后缀，浮点字面量默认类型为 `f64`
- 布尔字面量：`true`、`false`，类型为 `bool`
- 空指针字面量：`null`，类型为 `*byte`
  - 用于与 `*byte` 类型比较，表示空指针：`if ptr == null { ... }`
  - 可以作为 FFI 函数参数（如果函数接受 `*byte`）：`some_function(null);`
  - 不支持将 `null` 赋值给 `*byte` 类型的变量（未来可能支持）
- 字符串字面量：
  - **普通字符串字面量**：`"..."`，类型为 `*byte`（FFI 专用类型）；用于初始化时语义见下。
    - **自动添加 `\0` 结尾**：字符串字面量在语义上自动包含结尾的 null 字符（`\0`），因此长度为「可见字符数 + 1」。
    - 支持转义序列：`\n` 换行、`\r` 回车、`\t` 制表符、`\\` 反斜杠、`\"` 双引号、`\0` null 字符、**`\xHH`**（单字节十六进制）、**`\uXXXX`**（BMP 码点 → UTF-8；代理码点非法，**0.49.42**）
    - **字符串字面量的赋值与初始化**（以下目标类型均合法，字面量自动带 `\0` 结尾）：
      - ✅ 可初始化 / **赋值**给 `[byte: N]`：当「字面量可见字节数 + 1（`\0`）」≤ **`N`** 时，按字节拷贝到数组并保证以 `\0` 结尾；赋值时整数组先清零再写入（例如 `var buf: [byte: 8] = "ab"; buf = "xy";`）。**赋值左值**可以是标识符或**任意深度的成员访问链**（**`a.b.c = "..."`** 与 **`buf = "..."`** 规则相同，**0.49.43**）。
      - ✅ 可**赋值**给 **`&[const byte]`** / **`&[const byte: N]`**（**0.49.43**）：**重指向**字面量存储（更新 **`ptr`/`len`**），**不** `memcpy` 旧缓冲区；**不可**将字符串字面量赋给 **`&[byte]`**（元素非只读切片）。
      - ✅ 可赋值给 `&byte`：表示指向该字面量（只读）的普通指针
      - ✅ 可赋值给 `*byte`：表示 C 风格字符串指针（FFI），用于 FFI 调用等
      - **只读与实现（0.49.43）**：**`&[const byte]`** 在语义上禁止元素写；C 后端字段类型见 [规范变更 0.49.43](#规范变更) 中「实现说明（只读与 C）」。
    - **其他使用**：
      - ✅ 可以作为 FFI 函数调用的参数：`printf("hello\n");`
      - ✅ 可以作为 FFI 函数声明的参数类型示例：`extern printf(fmt: *byte, ...) i32;`
      - ✅ 可以与 `null` 比较（如果函数返回 `*byte`）：`if ptr == null { ... }`
      - ✅ **后缀下标与切片**（**0.49.41**）：字面量可作为主表达式接 **`[` `]`**，与数组类似：
        - **`"hello"[0]`** → **`byte`**；**`"hello"[0:3]`** → **`&[byte]`**（切片视图，不分配堆内存）
        - **`const s: &[byte] = &"hello"[0:3];`** → **`s.ptr`/`s.len`** 与 **`&buf[0:3]`** 相同用法
        - 常量 **`start`/`len`** 的越界检查按 **「可见字符数 + 1（含 `\0`）」** 作为逻辑数组长度
      - ❌ 不能用字符串作**数组类型的键**：`arr["hello"]` 表示用字符串索引某数组 **`arr`**（非上述字面量后缀），仍非法
  - **原始字符串字面量**：`` `...` ``，类型为 `*byte`（无转义序列，用于包含特殊字符的字符串）
    - 不支持任何转义序列，所有字符按字面量处理；同样自动带 `\0` 结尾，赋值规则与普通字符串字面量一致。
    - 示例：`` `C:\Users\name` `` 表示字面量字符串，不进行转义
  - **字符字面量**：`'a'`、`'x'`、`'\n'`、`'\t'`（0.43 新增），类型为 `byte`
    - 使用单引号包围，支持转义序列：`\n`（换行）、`\r`（回车）、`\t`（制表）、`\\`（反斜杠）、`\'`（单引号）、`\0`（空字符）、`\"`（双引号）、**`\xHH`**、**`\uXXXX`**（仅当 **`0 ≤ 值 ≤ 255`**，**0.49.42**）
    - 值为字符的 ASCII 码（整数）
    - **可赋值给 `byte` 类型**：`const c: byte = 'A';` → `c` 的值为 65
  - **字符串插值**：`"text${expr}text"` 或 `"text${expr:format}text"`，类型为 `[i8: N]`（编译期展开的定长栈数组）
    - **类型说明**：`i8` 是有符号 8 位整数，与 `byte`（无符号 8 位整数）大小相同但符号不同
    - 字符串插值使用 `i8` 是因为 C 字符串通常使用 `char`（有符号），与 C 互操作兼容
    - 支持两种形式：
      - 基本形式：`"a${x}"`（无格式说明符）
      - 格式化形式：`"pi=${pi:.2f}"`（带格式说明符，与 C printf 保持一致）
    - 语法：详见 [grammar_formal.md](./grammar_formal.md#13-字符串插值)
    - 格式说明符 `spec` 与 C printf 保持一致，[详见第 17 章](#17-字符串与格式化)
    - 编译期展开为定长栈数组，零运行时解析开销，零堆分配
    - 示例：`const msg: [i8: 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";`
- 数组字面量：
  - 列表式：`[expr1, expr2, ..., exprN]`（元素数量必须等于数组大小）
  - 重复式：`[value: N]`（value 重复 N 次，与数组类型 `[T: N]` 一致；N 为编译期常量）
  - 数组字面量的所有元素类型必须完全一致
  - 元素类型必须与数组声明类型匹配（不支持类型推断）
  - 示例：`const arr: [f32: 4] = [1.0, 2.0, 3.0, 4.0];`（元素类型 `f32` 必须与数组元素类型 `f32` 完全匹配）
- 注释 `// 到行尾` 或 `/* 块 */`（可嵌套）。

---

## 1.5 模块系统

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#7-模块系统)

### 1.5.1 设计目标

- **目录 + 单文件模块系统**：每个目录自动成为一个模块；每个 `.uya` 文件也可作为同名子模块导入
- **显式导出机制**：使用 `export` 关键字标记可导出的项
- **路径式导入**：使用 `use` 关键字和路径语法导入模块
- **编译期解析**：所有模块解析在编译期完成

### 1.5.2 模块定义

- 每个目录自动成为一个模块
- 每个 `.uya` 文件也自动拥有一个包含文件名的模块别名
- 模块名默认为目录名；文件模块名为目录模块名加文件名（去掉 `.uya`）
- **模块路径基准**：模块路径相对于 **项目根目录**（包含 `main` 函数的目录）计算
- 项目根目录是模块系统的根
- 所有模块路径都相对于项目根目录解析
- **根目录模块**：项目根目录本身是一个特殊模块，模块名为 `main`
  - 项目根目录是包含 `main` 函数的目录
  - 项目根目录下的所有 `.uya` 文件都属于 `main` 模块
  - 使用：`use main.some_function;` 或 `use main;`
- **子目录模块**：目录路径（相对于项目根目录）直接映射到模块路径
  - 项目根目录下的 `std/io/` → 模块路径 `std.io`
  - 项目根目录下的 `math/utils/` → 模块路径 `math.utils`
  - 目录下的所有 `.uya` 文件都属于同一个模块
- **单文件模块别名**：文件路径也可映射为模块路径
  - 项目根目录下的 `std/io/file.uya` → 兼容模块路径 `std.io.file`
  - `use std.io.read_file;` 与 `use std.io.file.read_file;` 都可导入 `file.uya` 中导出的 `read_file`
  - 目录模块和文件模块同时存在时，整体模块导入优先按目录模块解析；避免同时创建同名目录和同名 `.uya` 文件
- **限制**：不支持 `mod` 关键字（块级模块），模块由目录与 `.uya` 文件路径自动推导，符合零新关键字哲学

### 1.5.3 导出机制

- 使用 `export` 关键字标记可导出的项
- 语法：`export fn`, `export struct`, `export interface`, `export const`, `export error`
- **FFI 导出**：
  - `export extern` 或 `extern export` 用于导出 C FFI 函数：`export extern printf(fmt: *byte, ...) i32;` 或 `extern export printf(fmt: *byte, ...) i32;`（两种顺序等价）
  - `export struct` 用于导出结构体：`export struct MyStruct { field1: i32, field2: f64 }`
  - **统一标准**：
    - 所有结构体统一使用 C 内存布局，支持所有类型（包括切片、interface 等）
    - 导出的结构体可以直接与 C 代码互操作
    - 结构体可以有方法、drop、实现接口，同时保持 100% C 兼容性
    - 详见 [4.1 C 内存布局说明](#41-c-内存布局说明)
  - 导出后，其他模块可以通过 `use` 导入并使用这些 FFI 函数/结构体
  - 详见 [5.3 外部 C 结构体（FFI）](#53-外部-c-结构体ffi)
- 未标记 `export` 的项仅在模块内可见
- **为什么使用 `export` 而不是 `pub`**：
  - `export` 语义更明确，专门用于模块导出
  - `pub` 通常表示"公开可见性"（public vs private），概念更通用
  - Uya 选择 `export` 以强调模块间的导出关系，语义更清晰

### 1.5.4 导入机制

- 使用 `use` 关键字导入模块
- 路径语法：`use math.utils;`、`use math.utils.add;` 或 `use math.utils.file.add;`
- 支持别名：`use math.utils as math_utils;`
- **限制**：不支持通配符导入（`use math.*;`），避免命名污染和可读性下降
- **模块间引用规则**：
  - 根目录模块（main）可以引用子目录模块：`use std.io;`
  - 子目录模块可以引用其他子目录模块：`use std.io;`
  - **子目录引用 main 模块的处理方式**：
    - **允许但检测循环依赖**（推荐）：
      - 允许子目录模块引用 main 模块：`use main.helper;`
      - 编译器在编译期检测循环依赖并报错
      - 程序员需要手动打破循环（将共享功能提取到独立模块）
      - 示例：如果 `main.uya` 引用 `std.io`，`std.io` 引用 `main.helper`，编译器检测到循环并报错
- 所有模块引用都是显式的，需要通过 `use` 导入
- **导入后的使用方式**：
  - **导入整个模块**：`use main;` 或 `use std.io;`
    - 使用模块中的导出项时，需要加上模块名前缀：`main.helper_func()` 或 `std.io.read_file()`
    - 示例：
[examples/example.uya](./examples/example.uya)
  - **导入特定项**：`use main.helper_func;` 或 `use std.io.read_file;`
    - 导入后可以直接使用，无需模块名前缀
    - 示例：
[examples/example_1.uya](./examples/example_1.uya)
  - **导入结构体/接口**：`use std.io.File;` 或 `use std.io.IWriter;`
    - 导入后可以直接使用类型名，无需模块名前缀
    - 示例：
[examples/example_2.uya](./examples/example_2.uya)
  - **使用别名导入**：`use std.io as io;`
    - 使用别名时，需要用别名作为前缀
    - 示例：
[examples/example_3.uya](./examples/example_3.uya)
  - **混合使用**：可以同时导入整个模块和特定项
    - 示例：
[examples/example_4.uya](./examples/example_4.uya)

### 1.5.5 模块路径

- **路径基准**：所有模块路径相对于 **项目根目录**（包含 `main` 函数的目录）计算
- **根目录**：特殊模块名 `main`
  - 项目根目录是包含 `main` 函数的目录
  - 项目根目录下的文件 → `main` 模块
  - 示例：`use main.helper;` 或 `use main;`
- **子目录**：目录路径（相对于项目根目录）直接映射到模块路径（目录分隔符 `/` 转换为 `.`）
  - 项目根目录下的 `std/io/` → 模块路径 `std.io`
  - 项目根目录下的 `math/utils/` → 模块路径 `math.utils`
  - 使用：`use std.io;` 或 `use std.io.read_file;`
- **同目录文件合并规则**：
  - **同一目录下的所有 `.uya` 文件都属于同一个目录模块**
  - 目录模块路径由目录路径决定，不包含文件名
  - 例如：`std/io/file.uya` 和 `std/io/stream.uya` 都属于 `std.io` 模块
  - 编译器会自动收集同一目录下的所有 `.uya` 文件，合并为一个目录模块
  - 所有文件中的 `export` 项都可以通过目录模块路径访问
- **单文件模块兼容规则**：
  - 每个 `.uya` 文件还可以通过包含文件名的模块路径访问
  - 例如：`std/io/file.uya` 也可作为 `std.io.file`，`std/io/stream.uya` 也可作为 `std.io.stream`
  - 这允许大型目录模块逐步拆成更细的文件模块，同时保留旧的目录模块导入写法
  - 推荐新代码按实际文件边界使用文件模块路径；旧代码可继续使用目录模块路径
- 使用 `.` 分隔路径段
- **路径解析规则**：
  - 编译器在项目根目录中查找模块
  - 模块路径 `std.io` 对应项目根目录下的 `std/io/` 目录，也可对应 `std/io.uya` 文件
  - 当查找模块时，编译器会：
    1. 对整体模块导入优先检查是否存在同名目录（策略1：目录模块）
    2. 若目录不存在，再检查是否存在同名 `.uya` 文件（策略2：单文件模块）
    3. 对 `use a.b.c.item;`，若 `a/b/c.uya` 或 `a/b/c/` 存在，则 `a.b.c` 是模块；否则退回为从模块 `a.b` 导入导出项 `c`
  - 所有模块引用都相对于项目根目录解析

### 1.5.6 项目根目录说明

- **项目根目录识别**：模块系统的根目录是包含 `fn main() i32` 函数的目录
- **自动识别逻辑**：
  - 编译器扫描所有源文件，找到包含 `fn main() i32` 的文件
  - 该文件所在的最顶层目录即为项目根目录
  - 示例：如果 `project/src/main.uya` 包含 `fn main() i32`，则 `project/src/` 是项目根目录
- **限制**：不支持显式指定项目根目录（如通过 `-root` 编译选项），未来可能支持
- 所有模块路径都相对于项目根目录计算
- 编译器在项目根目录中查找和解析模块
- 项目根目录本身是 `main` 模块
- **路径解析**：
  - `use std.io;` 在项目根目录下查找 `std/io/` 目录
  - `use main.helper;` 在项目根目录下查找 `helper.uya` 文件
  - 所有模块引用都相对于项目根目录解析（绝对相对于项目根目录）
- **多入口项目说明**：
  - 如果项目中有多个 `fn main() i32`，编译器会报错，要求明确项目根目录
  - 测试/工具等应作为独立的子目录模块，不包含 `main` 函数
- **项目结构示例**：
[examples/example_008.txt](./examples/example_008.txt)

### 1.5.7 限制和说明

- **循环依赖处理**：
  - **允许子目录引用 main，但检测循环依赖**：
    - 允许 `use main.xxx;` 在子目录中使用
    - 编译器在编译期构建依赖图，检测强连通分量（循环依赖）
    - **循环依赖是编译错误，非运行时行为**：发现循环依赖时立即编译错误，要求程序员手动打破循环
    - 检测算法：构建有向图，使用 DFS 或 Tarjan 算法检测强连通分量
  - **打破循环的方法**：
    - 将共享功能提取到独立的子目录模块中（如 `common/`）
    - 所有模块都引用 `common` 模块，而不是相互引用
    - 示例：`main` 和 `std.io` 都引用 `common.helper`，而不是相互引用
- **模块可见性规则**：
  - **未 export 的项严格私有**：未标记 `export` 的项仅在模块内可见，其他模块无法访问
  - 所有模块引用都是显式的，需要通过 `use` 导入
- **模块初始化**：
  - **明确不支持模块初始化**（如 `init` 函数）
  - 所有模块解析在编译期完成
- **编译期解析规则**：
  - 所有模块路径在编译期解析
  - 模块依赖关系在编译期构建，用于循环依赖检测
- 与现有特性的兼容性
- 模块路径必须相对于项目根目录（包含 main 函数的目录）

### 1.5.8 完整示例

[examples/file.uya](./examples/file.uya)

---

## 2 类型系统

| Uya 类型        | 大小/对齐 | 备注                     |
|-----------------|-----------|--------------------------|
| `i8` `i16` `i32` `i64` | 1 2 4 8 B | 对齐 = 类型大小；支持 `@max`/`@min` 内置函数访问极值 |
| `u8` `u16` `u32` `u64` | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型，用于与 C 互操作和格式化 |
| `usize`         | 4/8 B（平台相关） | 无符号大小类型，用于内存地址和大小；32位平台=4B，64位平台=8B |
| `f32` `f64`     | 4/8 B     | 对齐 = 类型大小          |
| `bool`          | 1 B       | 0/1，对齐 1 B            |
| `byte`          | 1 B       | 对应 C 的 char，用于字节数组和 C 字符串兼容 |
| `void`          | 0 B       | 仅用于函数返回类型       |
| `*byte`         | 4/8 B（平台相关） | FFI 指针类型 `*T` 的一个实例（T=byte），用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）；FFI 指针类型 `*T` 支持所有 C 兼容类型（见第 5.2 章）|
| `&T`            | 4/8 B（平台相关） | 可变指针，无 lifetime 符号，见下方说明；32位平台=4B，64位平台=8B |
| `&const T`      | 4/8 B（平台相关） | 只读指针（0.42 新增），无 lifetime 符号；32位平台=4B，64位平台=8B |
| `&atomic T`  | 4/8 B（平台相关） | 原子指针，关键字驱动，[见第 13 章](#13-原子操作012-终极简洁)；32位平台=4B，64位平台=8B |
| `atomic T`      | sizeof(T) | 语言级原子类型，[见第 13 章](#13-原子操作012-终极简洁) |
| `[T: N]`        | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `[[T: N]: M]`   | M·N·sizeof(T) | 多维数组，M 和 N 为编译期正整数，对齐 = T 的对齐 |
| `&[T]`          | 8/16 B（平台相关） | 切片引用（动态长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `&[T: N]`       | 8/16 B（平台相关） | 切片引用（编译期已知长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `struct S { }`  | 字段顺序布局 | 对齐 = 最大字段对齐，见下方说明 |
| `union U { ... }` | 最大变体大小 | 对齐 = 最大变体对齐，见[第 4.5 章](#45-联合体union) |
| `union U { ... }`（嵌套） | 最大变体大小 | 可嵌套结构体、数组、其他联合体 |
| `interface I { }` | 8/16 B（平台相关） | vtable 指针(4/8B) + 数据指针(4/8B)，[见第 6 章接口](#6-接口interface)；32位平台=8B，64位平台=16B |
| `fn(...) type` | 4/8 B（平台相关） | 函数指针类型，用于 FFI 回调，[见 5.2](#52-外部-c-函数ffi) |
| `enum E { }` | sizeof(底层类型) | 枚举类型，默认底层类型为 i32，见下方说明 |
| `(T1, T2, ...)` | 字段顺序布局 | 元组类型，见下方说明 |
| `!T`            | 错误联合类型  | max(sizeof(T), sizeof(错误标记)) + 对齐填充 | `T | Error`，见下方说明 |

- 无隐式转换；支持异步编程（见第 18 章）；无 lifetime 符号。

**多维数组类型说明**：
- **声明语法**：`[[T: N]: M]` 表示 M 行 N 列的二维数组，类型为 `T`
  - `T` 是元素类型（如 `i32`, `f32` 等）
  - `N` 是列数（内层维度），必须是编译期正整数
  - `M` 是行数（外层维度），必须是编译期正整数
  - 更高维度的数组可以继续嵌套：`[[[T: N]: M]: K]` 表示三维数组
- **内存布局**：多维数组在内存中按行优先顺序存储（row-major order）
  - 二维数组 `[[T: N]: M]` 的内存布局：`[row0_col0, row0_col1, ..., row0_colN-1, row1_col0, ..., rowM-1_colN-1]`
  - 大小计算：`M * N * sizeof(T)` 字节
  - 对齐规则：对齐值 = `T` 的对齐值
- **访问语法**：使用多个索引访问多维数组元素
  - 二维数组：`arr[i][j]` 访问第 i 行第 j 列的元素
  - 三维数组：`arr[i][j][k]` 访问第 i 层第 j 行第 k 列的元素
- **边界检查**：所有维度的索引都需要编译期证明安全
  - 对于 `arr[i][j]`，必须证明 `i >= 0 && i < M && j >= 0 && j < N`
  - 常量错误 → 编译错误；变量证明失败 → 编译错误并给出修改建议
- **示例**：
[examples/example_010.uya](./examples/example_010.uya)

**类型相关的极值常量**：
- 整数类型（`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`）支持通过 `@max` 和 `@min` 内置函数访问极值
- 语法：`@max` 和 `@min`（编译器从上下文类型推断）
- 编译器根据上下文类型自动推断极值类型，这些是编译期常量
- 示例：
[examples/example_011.uya](./examples/example_011.uya)

**指针类型说明**：
- `*byte`：FFI 指针类型 `*T` 的一个实例（T=byte），专门用于 FFI，表示 C 字符串指针（null 终止），只能用于：
  - FFI 函数参数和返回值类型声明
  - 与 `null` 比较（空指针检查）
  - 字符串字面量在 FFI 调用时自动转换为 `*byte`
  - 不支持将 `*byte` 赋值给变量或进行其他操作
- **FFI 指针类型 `*T`**：支持所有 C 兼容类型，包括：
  - 整数类型：`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`
  - 浮点类型：`*f32`, `*f64`
  - 特殊类型：`*bool`, `*byte`（C 字符串），`*void`（通用指针）
  - C 结构体：`*CStruct`（指向外部 C 结构体的指针）
  - **使用规则**：
    - ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
    - ✅ 可用字符串字面量初始化：`const s: *byte = "hello";`（见 §1.4 字符串字面量）
    - ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`），但必须提供长度约束证明
    - ❌ 其他情形不能用于普通变量声明（编译错误）
    - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）
  - 详见 [第 5.2 章](#52-外部-c-函数ffi) 和 [第 5.3 章](#53-外部-c-结构体ffi)
- `&T`：普通指针类型（可变指针），4/8 字节（平台相关），无 lifetime 符号
  - 用于指向类型 `T` 的值，可以通过该指针修改值
  - 32位平台=4字节，64位平台=8字节
  - C 代码生成：`T *`（可变指针）
  - 空指针检查：`if ptr == null { ... }`（需要显式检查，编译期证明失败则报编译错误并给出修改建议）
  - 支持异步编程（见第 18 章）
  - **`&void` 类型**：通用指针类型，可以转换为任何指针类型（`&void` → `&T`），用于实现类型擦除和通用指针操作
    - 示例：`var ptr: &void = &buffer as &void; var byte_ptr: &byte = ptr as &byte;`
- `&const T`：只读指针类型（0.42 新增），4/8 字节（平台相关），无 lifetime 符号
  - 用于指向类型 `T` 的值，但不能通过该指针修改值
  - 32位平台=4字节，64位平台=8字节
  - C 代码生成：`const T *`（只读指针）
  - **类型转换规则**：
    - `&T` 可以隐式转换为 `&const T`（放宽约束，安全）
    - `&const T` 不能隐式转换为 `&T`（收紧约束，需要显式转换）
  - **使用场景**：
    - 函数参数：只读字符串参数应使用 `&const byte` 而不是 `&byte`
    - 标准库函数：`strcmp`, `strlen`, `strstr` 等函数的只读参数应使用 `&const byte`
    - 类型安全：编译期检查，防止通过只读指针修改值
  - **示例**：
    ```uya
    // 只读字符串参数
    export fn strcmp(s1: &const byte, s2: &const byte) i32 { ... }
    
    // 可变指针可以隐式转换为只读指针
    var s: &byte = ...;
    const result = strcmp(s, "hello");  // &byte 隐式转换为 &const byte
    ```
- `&atomic T`：原子指针类型，4/8 字节（平台相关），关键字驱动
  - 用于指向原子类型 `atomic T` 的指针
  - [见第 13 章原子操作](#13-原子操作012-终极简洁)
- `*T`：用于方法签名和 FFI 函数声明，表示指针参数；除用字符串字面量初始化（如 `const s: *byte = "hello";`）外不能用于普通变量声明
  - **语法规则**：
    - `*T` 仅用于 FFI 函数声明（如 `extern printf(fmt: *byte, ...) i32;`）或字符串字面量赋给 `*byte`（见 §1.4）
    - 方法 self 统一使用 `&T`：`fn method(self: &Self, ...)`，与普通指针一致
    - 调用 FFI 时可用 `&expr as *T` 将 Uya 普通指针转为 FFI 指针
    - 与 `&T` 的区别：`&T` 用于普通变量、函数参数及方法 self；`*T` 仅用于 FFI
  - **示例**：
    - 接口方法：`fn write(self: &Self, buf: *byte, len: i32)` 中，`&Self` 表示指向实现接口的结构体类型的引用
    - 结构体方法：`fn distance(self: &Self) f32` 中，`&Self` 表示指向当前结构体类型的引用
    - `*byte` 表示指向 `byte` 类型的指针参数
    - `Self` 是占位符，编译期替换为具体类型
  - **FFI 调用规则**：接口方法内部调用 FFI 函数时，参数类型应使用 `*byte`（FFI 语法），与接口语法一致
  - 仅支持 `*T` 语法（不支持 `T*`）
  - 接口方法调用时，`self` 参数自动传递（无需显式传递）

**错误类型和错误联合类型**：

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#9-错误处理)

- **错误类型定义**：使用 `error.ErrorName` 语法，支持预定义和运行时错误
  - **预定义错误**（可选）：使用 `error ErrorName;` 定义
    - 错误类型可在**顶层**（文件级别，与函数、结构体定义同级）预定义
    - 预定义错误类型是编译期常量，用于标识不同的错误情况
    - 预定义错误类型名称必须唯一（全局命名空间）
    - 预定义错误类型属于全局命名空间，使用点号（`.`）访问：`error.ErrorName`
    - 预定义错误定义示例：`error DivisionByZero;`、`error FileNotFound;`
    - 预定义错误使用示例：`return error.DivisionByZero;`、`return error.FileNotFound;`
  - **运行时错误**（新增）：使用 `error.ErrorName` 语法直接创建错误，无需预定义
    - 语法：`return error.ErrorMessage;`
    - 错误名称在使用时自动创建，无需预先声明
    - 编译器在编译期收集所有使用的错误名称，生成错误类型
    - 支持任意错误名称，无需预先定义
    - 示例：`return error.FileNotFound;`、`return error.OutOfMemory;`、`return error.InvalidInput;`
  - **错误名称规则**：
    - 错误名称遵循标识符规则：`[A-Za-z_][A-Za-z0-9_]*`
    - 错误名称区分大小写
    - 同一文件中，相同错误名称指向同一错误类型
    - 不同文件中的相同错误名称是不同的错误类型（除非通过接口传递）
  - **错误类型推断**：
    - 函数返回 `!T` 类型时，所有可能的错误类型自动推断
    - 编译器自动推断函数可能返回的所有错误
    - 无需显式声明函数可能返回的错误集合

- **错误联合类型**：`!T` 表示 `T | Error`
  - `!T` 在内存中表示为 `T` 或错误码的联合体
  - **标记位实现**：使用 `error_id` 字段（32位无符号整数）作为标记位，`error_id == 0` 表示成功（使用 `value` 字段），`error_id != 0` 表示错误（使用 `error_id` 字段）
  - 错误码使用 32 位无符号整数（`uint32_t`）表示
  - **error_id 分配与稳定性**：
    - `error_id` 由 `hash(error_name)` 生成（djb2 算法）
    - 相同错误名在任意编译中映射到相同 `error_id`，保证稳定性
    - 不同错误名 hash 冲突时，编译器报错并提示冲突的两个名称，开发者需重命名其一
  - 示例：`!i32` 表示 `i32 | Error`，`!void` 表示 `void | Error`

- **错误类型的大小和对齐**：
  - 错误类型本身不占用运行时内存（编译期常量）
  - **错误联合类型 `!T` 的大小计算**：
    - 基础大小 = `max(sizeof(T), sizeof(错误标记))`
    - 对齐值 = `max(alignof(T), alignof(错误标记))`
    - 最终大小 = 向上对齐到对齐值的倍数
    - 错误标记是 32 位无符号整数（`uint32_t`），固定为 4 字节，与错误联合类型的 C 内存布局一致
  - **示例**：`!i32` 在 64 位系统上：
    - `sizeof(i32)` = 4 字节，`sizeof(错误标记)` = 4 字节（`uint32_t`）
    - 基础大小 = `max(4, 4)` = 4 字节
    - 对齐值 = `max(4, 4)` = 4 字节
    - 最终大小 = 4 字节（已对齐）
- 所有对象大小必须在**编译期**确定。
- **类型对齐规则**：
  - 基础类型对齐 = 类型大小（自然对齐）
  - 结构体对齐 = 最大字段对齐值
  - 数组对齐 = 元素类型对齐
  - 与 C11 `_Alignas` 语义一致

**枚举类型说明**：

- **语法**：`enum EnumName { Variant1, Variant2, ... }` 或 `enum EnumName : UnderlyingType { Variant1 = value1, Variant2 = value2, ... }`
- **默认底层类型**：`i32`（如果未指定）
- **显式赋值**：支持为枚举变体显式指定值
- **底层类型指定**：支持指定底层整数类型（`u8`, `u16`, `u32`, `i8`, `i16`, `i32`, `i64` 等）
- **内存布局**：与 C 枚举完全兼容，大小和对齐由底层类型决定
- **类型安全**：编译期类型检查，枚举值只能与相同枚举类型比较
- **与 match 集成**：支持在 match 表达式中匹配枚举，支持穷尽性检查（必须处理所有变体或使用 else 分支）
- **示例**：
```uya
enum Color { RED, GREEN, BLUE }
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500
}
enum SmallEnum : u8 { A = 1, B = 2 }
```

**元组类型说明**：

- **语法**：`(T1, T2, ..., Tn)`，其中 `Ti` 是类型
- **类型别名**：支持使用 `type` 关键字定义元组类型别名，如 `type Point = (i32, i32);`
- **字面量语法**：`(value1, value2, ...)`
- **字段访问**：使用 `.0`, `.1`, `.2` 等索引访问元组字段（从 0 开始）
- **编译期边界检查**：访问越界立即编译错误（如 `tuple.5` 访问只有 3 个元素的元组）
- **内存布局**：字段按顺序存储，对齐规则与结构体相同（对齐 = 最大字段对齐值）
- **解构赋值**：支持元组解构，如 `const (x, y) = point;` 或 `const (x, _, z) = get_tuple();`
- **独立类型系统**：元组是一级类型，非语法糖，有明确的类型语义和错误信息
- **示例**：
```uya
type Point = (i32, i32);
const p: (i32, i32) = (10, 20);
const x = p.0;  // 访问第一个元素
const y = p.1;  // 访问第二个元素
```

**联合体类型说明**：

- **语法**：`union UnionName { variant1: Type1, variant2: Type2, ... }`
- **内存布局**：与 C union 完全兼容，大小为最大变体的大小，对齐为最大变体的对齐值
- **编译期标签跟踪**：标签在编译期跟踪，不占用运行时内存
- **安全访问**：所有访问必须通过模式匹配或已知标签的直接访问
- **零运行时开销**：无标签存储，无运行时检查，性能与 C union 相同
- **C 互操作**：内存布局与 C union 完全相同，可直接互操作
- **示例**：
```uya
union IntOrFloat {
    i: i32,
    f: f64
}

union NetworkPacket {
    ipv4: [byte: 4],
    ipv6: [byte: 16],
    raw: *byte
}
```

---

## 3 变量与作用域

[examples/variables_scope.uya](./examples/variables_scope.uya)

- 初始化表达式类型必须与声明完全一致。
- `const` 声明的变量**不可变**；使用 `var` 声明可变变量。
- 可变变量可重新赋值；不可变变量赋值会编译错误。
- **常量变量**：使用 `const NAME: Type = value;` 声明编译期常量
  - 常量必须在编译期求值
  - 常量可在编译期常量表达式中使用（如数组大小 `[T; SIZE]`）
  - 常量不可重新赋值
  - `const` 常量可以在顶层或函数内声明
  - `const` 常量可以作为数组大小：`const N: i32 = 10; const arr: [i32: N] = ...;`
- **编译期常量表达式**：
  - 字面量：整数、浮点、布尔、字符串
  - 常量变量：`const NAME`
  - 算术运算：`+`, `-`, `*`, `/`, `%`（如果操作数都是常量）
  - 位运算：`&`, `|`, `^`, `~`, `<<`, `>>`（如果操作数都是常量）
  - 比较运算：`==`, `!=`, `<`, `>`, `<=`, `>=`（如果操作数都是常量）
  - 逻辑运算：`&&`, `||`, `!`（如果操作数都是常量）
  - 不支持：函数调用、变量引用（非常量）、数组/结构体字面量
- **类型推断**：不支持类型推断，所有变量必须显式类型注解
- **变量遮蔽**：
  - 同一作用域内不能有同名变量
  - **禁止变量遮蔽**：内层作用域不能声明与外层作用域同名的变量（编译错误）
  - 所有作用域内的变量名必须唯一，不能遮蔽外层作用域的变量
- **忽略标识符 `_`**：特殊语法标记，用于显式忽略值
  - `_` 不是普通标识符，不能引用或赋值
  - **显式忽略返回值**：`_ = process_data();` 强制显式忽略返回值（编译期检查）
  - **解构忽略**：`const (x, _, z) = get_tuple();` 在元组解构中忽略中间元素
  - **模式匹配忽略**：在 match 表达式中使用 `_` 作为通配符忽略值，如 `match result { (200, _, body) => process(body), _ => handle_default() }`
  - **可重复使用**：`_` 可以在同一作用域内多次使用，不会冲突
  - **禁止作为变量名**：不能将 `_` 用作普通变量名（编译错误）
  - **示例**：
```uya
_ = process_data()                    // 显式忽略返回值
const (x, _, z) = get_tuple()         // 解构忽略中间元素
match result {
    (200, _, body) => process(body),  // 模式匹配忽略
    _ => handle_default()             // 通配忽略
}
```
- 作用域 = 最近 `{ }`；离开作用域按字段逆序调用 `drop(T)`（RAII）。

---

## 4 结构体

[examples/vec3.uya](./examples/vec3.uya)

- **统一标准**：所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- **支持所有类型**：结构体可以包含所有类型（包括切片、interface、错误联合类型等）
- 内存布局与 C 相同，字段顺序保留。
- **C 兼容性**：所有结构体都可以直接与 C 代码互操作，编译器自动生成对应的 C 兼容布局
- **完整 Uya 能力**：所有结构体都可以有方法、drop（RAII）、实现接口，同时保持 100% C 兼容性
  - ✅ 可以有方法（结构体内部或外部定义）
  - ✅ 可以有 drop 函数（实现 RAII 自动资源管理）
  - ✅ 可以实现接口（支持动态派发）
  - ✅ C 代码看到：纯数据，标准布局，100% C 兼容
  - ✅ Uya 代码看到：完整对象，有方法、接口、RAII，100% Uya 能力
- **结构体前向引用**：结构体可以在定义之前使用（如果编译器支持多遍扫描），或必须在定义之后使用（单遍扫描实现）
- **字段填充规则**：与 C 标准一致（填充字节明确为 0）
  - 每个字段按自身对齐要求对齐
  - 字段之间插入填充字节（值为 0）以满足对齐
  - 结构体末尾可能插入填充字节（值为 0）以满足数组元素对齐
  - **示例**：`struct { i8 a; i32 b; }` 在 64 位系统上：
    - `a`（`i8`）在偏移 0，对齐值 = 1 字节
    - `b`（`i32`）在偏移 4（中间 3 字节填充），对齐值 = 4 字节
    - 结构体大小 = 8 字节，对齐值 = 4 字节（最大字段对齐值）
- 结构体可以嵌套固定大小数组或其他结构体，**不可自引用**。
- 空结构体大小 = 1 字节（C 标准）
- **字段类型支持**：
  - 基础类型：`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `byte`, `usize`
  - 数组类型：`[T: N]`（固定大小数组）
  - 切片类型：`&[T]` 或 `&[T: N]`（在 C 中表示为 `{ void* ptr; size_t len; }`）
  - 接口类型：`InterfaceName`（在 C 中表示为 `{ void* vtable; void* data; }`）
  - 指针类型：`&T`（在 C 中表示为 `T*`）
  - 错误联合类型：`!T`（在 C 中表示为带标记的联合体）
  - 原子类型：`atomic T`（在 C 中表示为 `_Atomic T`）
  - 嵌套结构体：其他结构体类型
- **结构体字面量语法**：`TypeName{ field1: value1, field2: value2, ... }`
  - 字段名必须与结构体定义中的字段名完全匹配
  - 字段顺序可以任意（语法允许），但为了可读性和一致性，**强烈建议按定义顺序**
- 支持字段访问 `v.x`、数组元素 `arr[i]`（i 必须为 `i32`）。
- **指针自动解引用**：如果字段访问的对象是指针类型（`&StructName`），编译器会自动解引用（等价于 `(*ptr).field`）
  - 示例：`ptr.field`（如果 `ptr` 是 `&Point` 类型，自动解引用为 `(*ptr).field`）
- **字段赋值**：支持字段赋值 `obj.field = value`（如果 `obj` 是结构体类型）或 `ptr.field = value`（如果 `ptr` 是指向结构体的指针类型，自动解引用）
  - 示例：`point.x = 10;`、`ptr.x = 10;`（如果 `ptr` 是 `&Point` 类型）
- 支持嵌套访问：`struct_var.field.subfield`、`struct_var.array_field[index]`（访问链从左到右求值）
- **C99 后端**：字段链每一级按左值是否为指针类型生成 `.` 或 `->`（含方法体内 `self` 上的多级指针字段链；局部变量名在 C 中经关键字/保留名转义时，仍按实际类型选对操作符）。回归见 `tests/test_c99_pointer_access.uya`
- **多维数组字段**：结构体字段可以是多维数组
  - 声明示例：`struct Matrix { data: [[f32: 4]: 4] }`（4x4 矩阵）
  - 访问语法：`struct_var.array_field[i][j]`（如果字段是多维数组）
  - 所有维度的索引都需要边界检查证明
  - 示例：
[examples/mat3x4.uya](./examples/mat3x4.uya)
- 访问链可以任意嵌套：`struct_var.field1.array_field[i].subfield`
- **数组边界检查**（适用于所有数组访问）：强制编译期证明
  - 常量索引越界 → **编译错误**
  - 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误并给出修改建议**
  - 编译期证明安全（在当前函数内），证明失败则报编译错误并给出修改建议
- **切片语法**：支持切片语法 `&arr[start:len]`
  - **字符串字面量**（**0.49.41**）：**`"text"[start:len]`** 合法，语义等价于对「长度为 **可见字符数+1**（含 **`\\0`**）的只读字节序列」切片；**`&"text"[start:len]`** 与对同长度 **`[byte:N]`** 缓冲区的 **`&buf[start:len]`** 一致，得到 **`&[byte]`**。
  - **操作符语法**：`&arr[start:len]` 返回从索引 `start` 开始，长度为 `len` 的切片视图（引用）
  - **负数索引**：支持负数索引，`-1` 表示最后一个元素，`-n` 表示倒数第 n 个元素
    - 例如：`&arr[-3:3]` 表示从倒数第3个元素开始，长度为3的切片
    - 例如：`&arr[-5:2]` 表示从倒数第5个元素开始，长度为2的切片
  - **切片边界检查**：编译期或运行时证明 `start >= -len(arr) && start < len(arr) && len >= 0 && start + len <= len(arr)`
    - 如果使用负数索引，编译器会自动转换为正数索引：`-n` 转换为 `len(arr) - n`
    - 例如：`&arr[-3:3]` 对于长度为10的数组，-3转换为7，验证 `7 >= 0 && 7 < 10 && 3 >= 0 && 7 + 3 <= 10`
  - **切片结果类型**：
    - 动态长度切片：`&arr[start:len]` 返回 `&[T]`（切片引用，动态长度）
    - 已知长度切片：如果 `len` 是编译期常量，可以显式指定为 `&[T: N]`（已知长度切片引用）
    - 示例：`const slice: &[i32] = &arr[2:5];`（动态长度）
    - 示例：`const exact_slice: &[i32: 3] = &arr[2:3];`（已知长度）
  - **切片语义**：切片是原数据的视图，修改原数组会影响切片，切片不拥有数据
  - 切片是胖指针（指针+长度），无堆分配，编译期验证安全，运行时直接访问内存
- **字段可变性**：只有 `var` 结构体变量才能修改其字段
  - `const s: S = ...` 时，`s.field = value` 会编译错误
  - `var s: S = ...` 时，可以修改 `s.field`
  - 字段可变性由外层变量决定，不支持字段级可变性标记
  - **嵌套结构体示例**：
[examples/inner.uya](./examples/inner.uya)
- **结构体初始化**：
  - **完整初始化**（现有语法）：`StructName{ field1: value1, field2: value2, ... }`，所有字段显式赋值
  - **默认值初始化**（新增语法，0.40）：支持字段默认值，详见 [4.3 结构体默认值语法](#43-结构体默认值语法)

### 4.1 C 内存布局说明

所有结构体遵循 C 标准内存布局，可以直接与 C 代码互操作：

**基础类型布局**：
- 与 C 标准类型完全一致（`int`, `float`, `double`, `char` 等）
- 对齐规则遵循 C11 `_Alignas` 语义

**切片类型 `&[T]` 在 C 中的表示**：
```c
struct slice {
    void* ptr;    // 8 bytes (64位) 或 4 bytes (32位)
    size_t len;   // 8 bytes (64位) 或 4 bytes (32位)
};
```
- 总大小：16 bytes (64位) 或 8 bytes (32位)
- 对齐：8 bytes (64位) 或 4 bytes (32位)

**接口类型 `InterfaceName` 在 C 中的表示**：
```c
struct interface {
    void* vtable;  // 8 bytes (64位) 或 4 bytes (32位)
    void* data;    // 8 bytes (64位) 或 4 bytes (32位)
};
```
- 总大小：16 bytes (64位) 或 8 bytes (32位)
- 对齐：8 bytes (64位) 或 4 bytes (32位)

**错误联合类型 `!T` 在 C 中的表示**：
```c
// 错误联合类型的通用定义
struct error_union_T {
    uint32_t error_id; // 错误码：0 = 成功（使用 value），非0 = 错误（使用 error_id）
    T value;           // 成功时的值类型
};
```

**语义说明**：
- `error_id == 0`：表示成功，使用 `value` 字段，`value` 字段包含成功时的值
- `error_id != 0`：表示错误，`error_id` 包含错误类型标识符（非零值），`value` 字段不应被读取（内容未指定，但为安全起见，编译器可以初始化为零值）

**具体示例**：

`!i32` 在 C 中的表示：
```c
struct error_union_i32 {
    uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
    int32_t value;     // 成功时：i32 值
};
```

`!void` 在 C 中的表示：
```c
struct error_union_void {
    uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
    // void 类型无需 value 字段
};
```

`!Point`（结构体类型）在 C 中的表示：
```c
struct error_union_Point {
    uint32_t error_id;      // 0 = 成功，非0 = 错误类型标识符
    struct Point value;      // 成功时：Point 结构体
};
```

**大小和对齐规则**：
- 大小：`sizeof(uint32_t) + sizeof(T) + 对齐填充`
- 对齐：`max(alignof(uint32_t), alignof(T))`
- 错误码（`error_id`）为 32 位无符号整数，用于标识错误类型
- `error_id == 0` 表示成功，非零值表示不同的错误类型
- **error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同值

**使用示例**：
```c
// C 代码中使用错误联合类型
struct error_union_i32 result = some_function();
if (result.error_id == 0) {
    // 成功：使用 result.value
    int32_t value = result.value;
} else {
    // 错误：使用 result.error_id
    uint32_t error = result.error_id;
}
```

**示例：包含切片、接口和错误联合类型的结构体**：
```uya
struct Container {
    id: i32,
    data: &[i32],           // 切片字段
    writer: IWriter,        // 接口字段
    result: !i32,           // 错误联合类型字段
    count: usize
}
```

对应的 C 结构体：
```c
struct Container {
    int32_t id;
    struct {
        void* ptr;
        size_t len;
    } data;                 // 切片在 C 中的表示
    struct {
        void* vtable;
        void* data;
    } writer;              // 接口在 C 中的表示
    struct {
        uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
        int32_t value;     // 成功时：i32 值
    } result;              // 错误联合类型在 C 中的表示
    size_t count;
};
```

**与 C 互操作**：
- 所有 Uya 结构体可以直接传递给 C 函数
- C 结构体可以直接在 Uya 中使用（无需 `extern` 关键字）
- 编译器自动处理布局转换，确保 100% C 兼容性

**完整 Uya 能力**：
所有结构体（包括与 C 互操作的结构体）都可以有方法、drop（RAII）、实现接口，同时保持 100% C 兼容性：

```uya
// 结构体定义（C 兼容布局）
struct File {
    fd: i32
}

// ✅ 可以有方法（结构体内部定义）
struct File {
    fd: i32,
    fn read(self: &Self, buf: *byte, len: i32) !i32 {
        extern read(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = read(self.fd, buf, len);
        if result < 0 {
            return error.ReadFailed;
        }
        return result;
    }
}

// ✅ 可以有方法（结构体外部定义）
File {
    fn write(self: &Self, buf: *byte, len: i32) !i32 {
        extern write(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = write(self.fd, buf, len);
        if result < 0 {
            return error.WriteFailed;
        }
        return result;
    }
}

// ✅ 可以有 drop（RAII 自动资源管理），只能在结构体内部或方法块中定义
File {
    fn drop(self: File) void {
        extern close(fd: i32) i32;
        close(self.fd);
    }
}

// ✅ 可以实现接口（在结构体定义时声明接口）
interface IReadable {
    fn read(self: &Self, buf: *byte, len: i32) !i32;
}

struct File : IReadable {
    fd: i32,
    fn read(self: &Self, buf: *byte, len: i32) !i32 {
        extern read(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = read(self.fd, buf, len);
        if result < 0 {
            return error.ReadFailed;
        }
        return result;
    }
}

// 使用示例
fn example() !void {
    extern open(path: *byte, flags: i32) i32;
    const file: File = File{ fd: open("test.txt", 0) };
    
    // 使用结构体方法
    const bytes: i32 = try file.read(&buffer[0], 100);
    
    // 实现接口，支持动态派发
    const reader: IReadable = file;
    const bytes2: i32 = try reader.read(&buffer[0], 100);
    
    // 离开作用域时自动调用 drop，关闭文件（RAII）
}
```

**核心特性**：同一个结构体，两面性：
- **C 代码看到**：纯数据，标准布局，100% C 兼容
- **Uya 代码看到**：完整对象，有方法、接口、RAII，100% Uya 能力

### 4.2 结构体内存布局详细规则

本节详细说明结构体的内存布局规则，包括字段对齐、填充、嵌套结构体等。

#### 4.2.1 字段对齐规则

结构体字段的对齐遵循以下规则：

1. **基础类型对齐**：
   - `i8`, `u8`, `bool`, `byte`：对齐值 = 1 字节
   - `i16`, `u16`：对齐值 = 2 字节
   - `i32`, `u32`, `f32`：对齐值 = 4 字节
   - `i64`, `u64`, `f64`：对齐值 = 8 字节
   - `usize`, `&T`, `*T`（FFI指针）：对齐值 = 4/8 字节（平台相关）

2. **字段偏移计算**：
   - 第一个字段的偏移 = 0
   - 后续字段的偏移 = 向上对齐到该字段对齐值的倍数
   - 偏移量计算公式：`offset(field_n) = align_up(offset(field_n-1) + sizeof(field_n-1), alignof(field_n))`
   - **`align_up(value, alignment)` 函数说明**：
     - 功能：将 `value` 向上对齐到 `alignment` 的倍数
     - 定义：`align_up(value, alignment) = ((value + alignment - 1) / alignment) * alignment`
     - 等价于：`align_up(value, alignment) = (value + alignment - 1) & ~(alignment - 1)`（当 alignment 是 2 的幂时）
     - 示例：
       - `align_up(5, 4) = 8`（5 向上对齐到 4 的倍数 = 8）
       - `align_up(8, 4) = 8`（8 已经是 4 的倍数，保持不变）
       - `align_up(0, 8) = 0`（0 向上对齐到 8 的倍数 = 0）
       - `align_up(9, 8) = 16`（9 向上对齐到 8 的倍数 = 16）

3. **填充字节插入**：
   - 在字段之间插入填充字节以满足对齐要求
   - **填充字节的内容明确为 0**（零填充）
   - 这确保了结构体布局的可预测性，符合 Uya "坚如磐石"的设计哲学
   - 注意：虽然 C 标准中填充字节内容是未定义的，但 Uya 明确指定为 0 填充，以提供确定的行为

**示例 1：基本对齐**：
```uya
struct Example1 {
    a: i8,   // 偏移 0，大小 1
    b: i32,  // 偏移 4（跳过 1-3 填充），大小 4
    c: i8,   // 偏移 8，大小 1
}
// 64位平台：大小 = 12 字节（最后填充 3 字节以满足数组对齐），对齐 = 4 字节
// 32位平台：大小 = 12 字节，对齐 = 4 字节
```

**示例 2：8字节对齐**：
```uya
struct Example2 {
    a: i8,   // 偏移 0，大小 1
    b: i64,  // 偏移 8（跳过 1-7 填充），大小 8
    c: i8,   // 偏移 16，大小 1
}
// 64位平台：大小 = 24 字节（最后填充 7 字节），对齐 = 8 字节
// 32位平台：大小 = 20 字节（最后填充 3 字节），对齐 = 8 字节
```

#### 4.2.2 嵌套结构体布局

嵌套结构体字段的对齐规则：

1. **嵌套结构体字段对齐**：
   - 嵌套结构体的对齐值 = 其最大字段的对齐值
   - 嵌套结构体字段的偏移必须对齐到嵌套结构体的对齐值

2. **嵌套结构体大小**：
   - 嵌套结构体的大小包括其所有字段和填充字节

**示例 3：嵌套结构体**：
```uya
struct Inner {
    x: i32,  // 偏移 0，大小 4
    y: i32,  // 偏移 4，大小 4
} // Inner 大小 = 8 字节，对齐 = 4 字节

struct Outer {
    a: i8,        // 偏移 0，大小 1
    inner: Inner, // 偏移 4（跳过 1-3 填充，对齐到 4），大小 8
    b: i8,        // 偏移 12，大小 1
}
// 大小 = 16 字节（最后填充 3 字节），对齐 = 4 字节
```

#### 4.2.3 数组字段布局

数组字段的内存布局：

1. **数组字段对齐**：
   - 数组字段的对齐值 = 元素类型的对齐值
   - 数组字段的偏移必须对齐到元素类型的对齐值

2. **数组字段大小**：
   - 数组字段大小 = `N * sizeof(T)`（N 为元素数量，T 为元素类型）

3. **多维数组字段**：
   - 多维数组字段的对齐值 = 元素类型的对齐值
   - 多维数组字段大小 = `M * N * sizeof(T)`（M、N 为维度，T 为元素类型）

**示例 4：数组字段**：
```uya
struct Example4 {
    a: i8,           // 偏移 0，大小 1
    arr: [i32: 3],   // 偏移 4（跳过 1-3 填充，对齐到 4），大小 12
    b: i64,          // 偏移 16，大小 8
}
// 64位平台：大小 = 24 字节，对齐 = 8 字节（最大字段对齐）
```

#### 4.2.4 特殊类型字段布局

1. **切片字段 `&[T]`**：
   - 切片字段在结构体中表示为两个连续字段：`ptr`（指针）和 `len`（长度）
   - 64位平台：`ptr`（8字节）+ `len`（8字节）= 16字节，对齐 = 8字节
   - 32位平台：`ptr`（4字节）+ `len`（4字节）= 8字节，对齐 = 4字节

2. **接口字段 `InterfaceName`**：
   - 接口字段在结构体中表示为两个连续字段：`vtable`（指针）和 `data`（指针）
   - 64位平台：`vtable`（8字节）+ `data`（8字节）= 16字节，对齐 = 8字节
   - 32位平台：`vtable`（4字节）+ `data`（4字节）= 8字节，对齐 = 4字节

3. **错误联合类型字段 `!T`**：
   - 错误联合类型字段包含 `error_id`（32位）和 `value`（类型 T）
   - 对齐值 = `max(4, alignof(T))`
   - 大小 = `max(4, sizeof(T)) + 对齐填充`

#### 4.2.5 结构体大小和对齐

1. **结构体对齐值**：
   - 结构体的对齐值 = 所有字段对齐值的最大值
   - 包括嵌套结构体字段的对齐值

2. **结构体大小计算**：
   - 结构体大小 = 最后一个字段的偏移 + 最后一个字段的大小
   - 最终大小向上对齐到结构体的对齐值
   - 这是为了确保结构体在数组中正确对齐

**示例 5：结构体大小计算**：
```uya
struct Example5 {
    a: i8,   // 偏移 0，大小 1，对齐 = 1
    b: i32,  // 偏移 4，大小 4，对齐 = 4
    c: i64,  // 偏移 8，大小 8，对齐 = 8
}
// 最后一个字段 c 的偏移 + 大小 = 8 + 8 = 16
// 结构体对齐值 = max(1, 4, 8) = 8
// 最终大小 = 16（已对齐到 8）
```

**示例 6：需要末尾填充的结构体**：
```uya
struct Example6 {
    a: i8,   // 偏移 0，大小 1
    b: i32,  // 偏移 4，大小 4
}
// 最后一个字段 b 的偏移 + 大小 = 4 + 4 = 8
// 结构体对齐值 = max(1, 4) = 4
// 最终大小 = 8（已对齐到 4，满足数组对齐要求）
// 如果是结构体数组 Example6[2]，第二个元素的 a 字段偏移为 8，对齐到 4
```

#### 4.2.6 平台差异

不同平台的结构体布局差异主要来自指针大小的不同：

| 类型 | 32位平台 | 64位平台 |
|------|---------|---------|
| `&T` | 4字节，对齐4 | 8字节，对齐8 |
| `*T`（FFI） | 4字节，对齐4 | 8字节，对齐8 |
| `usize` | 4字节，对齐4 | 8字节，对齐8 |
| `&[T]` | 8字节（ptr 4B + len 4B），对齐4 | 16字节（ptr 8B + len 8B），对齐8 |
| `interface` | 8字节（vtable 4B + data 4B），对齐4 | 16字节（vtable 8B + data 8B），对齐8 |

**示例 7：平台差异**：
```uya
struct PlatformStruct {
    ptr: &i32,
    len: usize,
}
// 32位平台：ptr(4B, offset=0) + len(4B, offset=4) = 8字节，对齐=4
// 64位平台：ptr(8B, offset=0) + len(8B, offset=8) = 16字节，对齐=8
```

#### 4.2.7 空结构体

空结构体（无字段）的特殊规则：

- **大小**：1 字节（C 标准要求，确保每个结构体实例有唯一地址）
- **对齐**：1 字节
- **用途**：主要用于类型标记和接口实现

```uya
struct Empty { }  // 大小 = 1 字节，对齐 = 1 字节
```

---

### 4.3 结构体默认值语法

#### 4.3.1 设计目标

- **减少样板代码**：常用默认值无需在每次初始化时重复书写
- **显式控制**：默认值在结构体定义处显式声明，一目了然
- **编译期常量**：默认值必须是编译期可求值的常量，零运行时开销
- **兼容现有语义**：与移动语义、RAII、接口实现完全兼容

#### 4.3.2 字段默认值声明

在结构体定义中，使用 `= expr` 为字段指定默认值：

```uya
// 基础类型默认值
struct Point {
    x: f32 = 0.0,
    y: f32 = 0.0
}

struct Config {
    name: [i8: 64] = [],           // 空数组（零初始化）
    port: i32 = 8080,
    debug: bool = false,
    timeout: f64 = 30.0
}

// 嵌套结构体默认值
struct Size {
    width: i32 = 0,
    height: i32 = 0
}

struct Window {
    title: [i8: 128] = "Untitled",
    size: Size = Size{},            // 嵌套结构体使用其默认值
    position: Point = Point{ x: 100.0, y: 100.0 }
}
```

#### 4.3.3 初始化语法

**完整初始化**（现有语法，保持不变）：
```uya
const p1: Point = Point{ x: 1.0, y: 2.0 };  // 所有字段显式赋值
```

**使用默认值**（新增语法）：
```uya
// 方式1：完全使用默认值
const origin: Point = Point{};  // x=0.0, y=0.0

// 方式2：部分字段使用默认值（有默认值的字段可以忽略）
const p2: Point = Point{ x: 5.0 };           // x=5.0, y=0.0（y 使用默认值）
const p3: Point = Point{ y: 3.0 };           // x=0.0（x 使用默认值）, y=3.0
const p4: Point = Point{ y: 2.0 };           // x=0.0（x 使用默认值）, y=2.0
```

#### 4.3.4 约束与规则

##### 4.3.4.1 默认值必须是编译期常量

```uya
const DEFAULT_PORT: i32 = 8080;

struct Server {
    port: i32 = DEFAULT_PORT,      // ✅ 常量变量
    host: [i8: 64] = "localhost",   // ✅ 字符串字面量（编译期常量）
    
    // ❌ 错误：默认值必须是编译期常量
    // socket: i32 = get_socket(),  // 函数调用不允许
    // timestamp: i64 = current_time()  // 运行时值不允许
}
```

##### 4.3.4.2 无默认值的字段必须显式初始化

**规则**：有默认值的字段在初始化时可以忽略，只需提供无默认值的字段。

```uya
struct User {
    id: i32,           // 无默认值，必须显式提供
    name: [i8: 64] = "Anonymous",  // 有默认值，可以忽略
    age: i32 = 0                    // 有默认值，可以忽略
}

// ✅ 正确：所有无默认值字段都提供了值，有默认值的字段自动使用默认值
const u1: User = User{ id: 1 };  // name="Anonymous", age=0（使用默认值）

// ✅ 正确：可以显式覆盖有默认值的字段
const u2: User = User{ id: 2, name: "Tom" };  // name="Tom", age=0（使用默认值）

// ❌ 错误：缺少无默认值字段 id
// const u3: User = User{ name: "Tom" };
// 编译错误：字段 'id' 没有默认值，必须显式初始化
```

##### 4.3.4.3 与移动语义的交互

```uya
struct Buffer {
    data: [byte: 1024] = [],
    len: i32 = 0,
    capacity: i32 = 1024
}

// 使用默认值初始化时，数组字段是零初始化的，无移动语义问题
const buf1: Buffer = Buffer{};  // 安全，无移动

// 部分初始化时，显式提供的值遵循移动语义
var temp_data: [byte: 1024] = [1, 2, 3];
// const buf2: Buffer = Buffer{ data: temp_data };  // ❌ temp_data 被移动
```

##### 4.3.4.4 与 drop 的兼容性

```uya
struct File {
    fd: i32 = -1,      // 默认值为 -1（表示无效文件描述符）
    path: [i8: 256] = []
}

File {
    fn drop(self: File) void {
        if self.fd >= 0 {
            extern close(fd: i32) i32;
            close(self.fd);
        }
    }
}

// 使用默认值创建 File，fd=-1，drop 时不会调用 close
const f1: File = File{};  // 安全，fd=-1，drop 中检查并跳过
```

##### 4.3.4.5 接口实现与默认值

```uya
interface Drawable {
    fn draw(self: &Self) void;
}

struct Circle : Drawable {
    center: Point = Point{},
    radius: f32 = 1.0,
    
    fn draw(self: &Self) void {
        // 实现...
    }
}

// 使用默认值创建并装箱为接口
const shape: Drawable = Circle{};  // 使用所有默认值
```

#### 4.3.5 编译器实现要点

##### 4.3.5.1 语法分析

扩展结构体字段定义语法：

```ebnf
field_decl ::= field_name ":" type ( "=" const_expr )?
```

##### 4.3.5.2 类型检查

1. **默认值类型检查**：确保 `const_expr` 的类型与字段类型兼容
2. **编译期求值**：验证 `const_expr` 可在编译期求值
3. **完整性检查**：确保初始化时所有无默认值字段都被提供

##### 4.3.5.3 代码生成

```uya
// 源代码
const p: Point = Point{ x: 5.0 };

// 编译器展开后（概念上）
const p: Point = Point{
    x: 5.0,
    y: 0.0  // 插入默认值
};
```

**内存布局保持不变**：默认值在编译期嵌入代码，结构体内存布局与无默认值版本完全一致。

#### 4.3.6 复杂示例

```uya
// 网络配置结构体
struct NetworkConfig {
    // 基础配置
    host: [i8: 64] = "0.0.0.0",
    port: i32 = 8080,
    
    // 高级配置
    backlog: i32 = 128,
    keep_alive: bool = true,
    timeout_sec: f64 = 30.0,
    
    // 嵌套结构体
    ssl: SslConfig = SslConfig{
        enabled: false,
        cert_path: [],
        key_path: []
    }
}

// 使用示例
fn create_server(config: NetworkConfig) !void {
    // ...
}

fn main() !i32 {
    // 1. 使用全部默认值
    const default_server = create_server(NetworkConfig{});
    
    // 2. 修改端口，其余默认
    const custom_port = create_server(NetworkConfig{ port: 3000 });
    
    // 3. 修改嵌套字段（部分使用默认值）
    const with_ssl = create_server(NetworkConfig{
        port: 443,
        ssl: SslConfig{ enabled: true, cert_path: "cert.pem", key_path: "key.pem" }
    });
    
    return 0;
}
```

#### 4.3.7 与现有规范的兼容性

| 特性 | 兼容性 | 说明 |
|------|--------|------|
| 移动语义 | ✅ 兼容 | 显式提供的值遵循移动规则，默认值无移动（零初始化或常量） |
| RAII/drop | ✅ 兼容 | 默认值可设计为"安全空状态"（如 fd=-1） |
| 接口实现 | ✅ 兼容 | 带默认值的结构体可正常实现接口 |
| C 互操作 | ✅ 兼容 | 内存布局不变，C 侧无感知 |
| 原子类型 | ✅ 兼容 | 支持 `atomic T` 字段的默认值（必须是编译期常量） |
| 联合体字段 | ⚠️ 需讨论 | 联合体变体选择不能默认，建议禁止联合体字段默认值 |

#### 4.3.8 限制

1. **编译期常量限制**：默认值必须是编译期可求值的常量，不支持运行时计算
2. **无动态默认值**：不支持 `rand()`、`now()` 等运行时默认值
3. **联合体内禁止**：联合体（union）字段不能有默认值（因需要显式选择变体）
4. **切片字段限制**：切片字段 `&[T]` 不能有默认值（因需运行时数据）

#### 4.3.9 设计哲学一致性

> **显式控制**：默认值在结构体定义处显式声明，使用者通过 `Struct{}` 或 `Struct{ field: value }` 显式选择使用默认（有默认值的字段可以忽略）。
>
> **编译期证明**：所有默认值在编译期验证和展开，零运行时开销，类型安全保证。
>
> **零成本**：默认值不占用额外内存，不改变结构体布局，代码生成与手写显式初始化相同。

#### 4.3.10 示例：对比有无默认值

**无默认值（当前）**：
```uya
struct HttpRequest {
    method: [i8: 16],
    path: [i8: 256],
    version: [i8: 16],
    headers_count: i32
}

// 每次初始化都要写很多样板代码
const req = HttpRequest{
    method: "GET",
    path: "/",
    version: "HTTP/1.1",
    headers_count: 0
};
```

**有默认值（新增）**：
```uya
struct HttpRequest {
    method: [i8: 16] = "GET",
    path: [i8: 256] = "/",
    version: [i8: 16] = "HTTP/1.1",
    headers_count: i32 = 0
}

// 简洁的初始化
const req1 = HttpRequest{};           // 全部默认
const req2 = HttpRequest{ path: "/api/users" };  // 仅修改 path
```

---

## 4.5 联合体（union）

### 4.5.1 设计目标

Uya 联合体提供编译期证明安全的标签联合体：
- **编译期类型安全**：通过编译期标签跟踪确保访问正确的成员
- **内存安全强制**：所有访问必须通过编译期证明安全
- **C 内存布局兼容**：与 C union 100% 互操作
- **零运行时开销**：标签仅在编译期使用，运行时无额外检查
- **显式控制**：强制模式匹配，无隐式类型转换

### 4.5.2 联合体定义

- **语法**：`union UnionName { variant1: Type1, variant2: Type2, ... }`
- **变体命名**：变体名遵循标识符规则 `[A-Za-z_][A-Za-z0-9_]*`
- **变体类型**：支持所有类型（基础类型、数组、结构体、指针、其他联合体）
- **嵌套支持**：联合体可以嵌套结构体、数组和其他联合体
- **内存布局**：大小为最大变体的大小，对齐为最大变体的对齐值
- **空联合体**：不允许空联合体（至少需要一个变体）
- **示例**：
```uya
union IntOrFloat {
    i: i32,
    f: f64
}

union NetworkPacket {
    ipv4: [byte: 4],
    ipv6: [byte: 16],
    raw: *byte
}

union ComplexUnion {
    simple: IntOrFloat,
    pair: (i32, f64),
    buffer: [byte: 64]
}
```

### 4.5.3 联合体创建

使用联合体名和变体名创建联合体值：

```uya
// 创建联合体
const int_val: IntOrFloat = IntOrFloat.i(42);
const float_val: IntOrFloat = IntOrFloat.f(3.14159);

// 数组变体
const ipv4_packet: NetworkPacket = NetworkPacket.ipv4([192, 168, 1, 1]);

// 指针变体
extern malloc(size: usize) *void;
const raw_packet: NetworkPacket = NetworkPacket.raw(malloc(1024) as *byte);
```

### 4.5.4 安全访问机制

所有联合体访问必须通过安全机制：

#### 4.5.4.1 模式匹配（主要访问方式）

使用 `match` 表达式访问联合体，必须处理所有变体：

```uya
fn process_value(value: IntOrFloat) void {
    match value {
        .i(x) => printf("整数: %d\n", x),
        .f(x) => printf("浮点: %.2f\n", x)
    }
}

fn process_packet(packet: NetworkPacket) !void {
    match packet {
        .ipv4(addr) => {
            printf("IPv4: %d.%d.%d.%d\n", addr[0], addr[1], addr[2], addr[3]);
        },
        .ipv6(addr) => {
            for 0..16 |i| {
                printf("%02x", addr[i]);
                if i % 2 == 1 && i < 15 { printf(":"); }
            }
            printf("\n");
        },
        .raw(ptr) => {
            // 处理原始数据
            return error.UnsupportedFormat;
        }
    }
}
```

#### 4.5.4.2 已知标签的直接访问

当编译器可以证明当前标签时，允许直接访问：

```uya
fn direct_access() void {
    var value: IntOrFloat = IntOrFloat.i(42);
    
    // ✅ 编译器知道当前标签是 .i
    const x: i32 = value.i;
    
    // ❌ 编译错误：编译器知道当前标签不是 .f
    // const y: f64 = value.f;
    
    // 重新赋值后标签状态更新
    value = IntOrFloat.f(3.14);
    
    // ✅ 编译器知道当前标签是 .f
    const z: f64 = value.f;
    
    // ❌ 编译错误：编译器知道当前标签不是 .i
    // const w: i32 = value.i;
}
```

#### 4.5.4.3 编译期标签跟踪

编译器在编译期跟踪联合体的标签状态：

| 标签状态 | 描述 | 访问规则 |
|---------|------|---------|
| `Known(.variant)` | 已知具体标签 | 允许直接访问对应变体 |
| `Unknown` | 未知标签 | 必须使用模式匹配 |
| `Multiple([.v1, .v2])` | 多个可能标签 | 必须使用模式匹配 |

### 4.5.5 编译期证明规则

编译器必须在编译期证明联合体访问安全：

1. **常量创建证明**：
```uya
const v = IntOrFloat.i(42);
// 编译器证明：v 的标签是 .i
```

2. **赋值证明**：
```uya
var v: IntOrFloat;
v = IntOrFloat.f(3.14);
// 编译器更新：v 的标签现在是 .f
```

3. **分支证明**：
```uya
fn branch_example(cond: bool) void {
    var v: IntOrFloat;
    
    if cond {
        v = IntOrFloat.i(10);
    } else {
        v = IntOrFloat.f(3.14);
    }
    
    // 编译器无法确定标签 → 必须使用模式匹配
    match v {
        .i(x) => printf("%d\n", x),
        .f(x) => printf("%f\n", x)
    }
}
```

4. **循环证明**：
```uya
fn loop_example() void {
    var v: IntOrFloat = IntOrFloat.i(0);
    
    while some_condition() {
        // 循环可能修改标签 → 标签状态为 Unknown
        v = get_next_value();
        
        // 必须使用模式匹配
        match v {
            .i(x) => process_int(x),
            .f(x) => process_float(x)
        }
    }
}
```

### 4.5.6 与 C 互操作

#### 4.5.6.1 外部 C 联合体

声明和使用 C 联合体：

```uya
// 声明外部 C 联合体
extern union CValue {
    i: i32,
    f: f64,
    buffer: [byte: 16]
}

// 使用外部联合体
fn use_c_union() void {
    extern get_c_value() union CValue;
    const cv: union CValue = get_c_value();
    
    // 访问外部联合体需要模式匹配
    match cv {
        .i(val) => printf("C 整数: %d\n", val),
        .f(val) => printf("C 浮点: %f\n", val),
        .buffer(buf) => printf("C 缓冲区: %p\n", &buf[0])
    }
}
```

#### 4.5.6.2 Uya 联合体传递给 C

Uya 联合体可直接传递给 C 函数：

```uya
// C 函数声明
extern process_c_union(u: union CValue) void;

fn pass_to_c() void {
    const u: IntOrFloat = IntOrFloat.i(42);
    
    // 安全转换：内存布局相同
    process_c_union(u as union CValue);
}
```

#### 4.5.6.3 内存布局保证

Uya 联合体与 C union 内存布局完全相同：

```c
// C 代码看到的 Uya 联合体
union IntOrFloat {
    int32_t i;
    double f;
};

union NetworkPacket {
    uint8_t ipv4[4];
    uint8_t ipv6[16];
    void* raw;
};
```

### 4.5.7 联合体方法

联合体支持方法定义，使用 `Self` 占位符：

```uya
union IntOrFloat {
    i: i32,
    f: f64,
    
    // 联合体方法
    fn as_f64(self: &Self) f64 {
        match *self {
            .i(x) => x as f64,
            .f(x) => x
        }
    }
    
    fn is_int(self: &Self) bool {
        match *self {
            .i(_) => true,
            .f(_) => false
        }
    }
}

// 使用方法
const v = IntOrFloat.i(42);
const as_float = v.as_f64();  // 42.0
const is_int = v.is_int();    // true
```

### 4.5.8 联合体实现接口

联合体可实现接口：

```uya
interface Printable {
    fn print(self: &Self) void;
}

union IntOrFloat : Printable {
    i: i32,
    f: f64,
    
    fn print(self: &Self) void {
        match *self {
            .i(x) => printf("整数: %d\n", x),
            .f(x) => printf("浮点: %.2f\n", x)
        }
    }
}

// 使用接口
const printable: Printable = IntOrFloat.f(3.14);
printable.print();  // 输出: 浮点: 3.14
```

### 4.5.9 移动语义

联合体支持移动语义：

```uya
union BufferOrString {
    buffer: [byte: 64],
    str: *byte
}

fn move_example() void {
    var u1: BufferOrString = BufferOrString.buffer([]);
    
    // 移动联合体
    const u2: BufferOrString = u1;  // u1 被移动
    
    // ❌ 编译错误：u1 已移动，不能再次使用
    // const x = u1.buffer;
    
    // ✅ u2 可以使用
    match u2 {
        .buffer(buf) => printf("缓冲区大小: %d\n", @len(buf)),
        .str(s) => printf("字符串: %s\n", s)
    }
}
```

### 4.5.10 drop 机制

联合体支持 `drop` 函数，仅对当前活跃变体调用清理。drop 只能在联合体内部或方法块中定义：

```uya
union FileOrBuffer {
    file: File,      // 有 drop 函数
    buffer: [byte: 1024]  // 无 drop 函数
}

FileOrBuffer {
    fn drop(self: FileOrBuffer) void {
        match self {
            .file(f) => {
                // 调用 File 的 drop
                drop(f);
            },
            .buffer(_) => {
                // 缓冲区无需清理
            }
        }
    }
}
```

### 4.5.11 编译期常量联合体

联合体可在编译期构造和使用：

```uya
const PI_UNION: IntOrFloat = IntOrFloat.f(3.141592653589793);
const ANSWER_UNION: IntOrFloat = IntOrFloat.i(42);

// 编译期模式匹配
const PI_VALUE: f64 = match PI_UNION {
    .i(x) => x as f64,
    .f(x) => x
};  // 编译期求值：3.141592653589793
```

### 4.5.12 限制

1. **无默认初始化**：必须显式指定变体创建联合体
2. **禁止无标签访问**：必须通过模式匹配或已知标签的直接访问
3. **禁止类型双关**：不能通过一种类型写入，另一种类型读取（除非显式模式匹配）
4. **变体类型支持**：变体类型支持引用类型（`&T`），Tagged Union 设计确保安全：
   - 每次赋值会完全覆盖旧值（包括标签和数据）
   - 不存在悬垂引用的风险
   - 建议使用值类型或 FFI 指针（`*T`）以提高 C 互操作性
5. **标签状态传播**：函数间标签信息不传播，返回联合体的函数调用者必须使用模式匹配

### 4.5.13 错误信息示例

```uya
fn error_examples() void {
    var u: IntOrFloat = IntOrFloat.i(10);
    
    // 错误：访问错误的变体
    // const x: f64 = u.f;
    // 错误信息：联合体 'u' 当前标签是 '.i'，不能访问变体 '.f'
    
    // 错误：未处理所有变体
    // match u {
    //     .i(x) => printf("%d\n", x)
    // }
    // 错误信息：模式匹配必须处理所有变体，缺少: .f
    
    // 错误：未知标签时直接访问
    // fn get_union() IntOrFloat { ... }
    // const v = get_union();
    // const x = v.i;
    // 错误信息：联合体 'v' 标签未知，必须使用模式匹配访问
}
```

### 4.5.14 完整示例

```uya
// 定义联合体（示意：用标签区分两类负载，与「成功/失败」命名无关）
union ValueOrMsg {
    value: i32,
    msg: *byte
}

fn process_value_or_msg(u: ValueOrMsg) !i32 {
    match u {
        .value(n) => {
            printf("数值: %d\n", n);
            return n;
        },
        .msg(s) => {
            printf("消息: %s\n", s);
            return error.OperationFailed;
        }
    }
}

fn main() !i32 {
    const a = ValueOrMsg.value(42);
    const b = ValueOrMsg.msg("提示信息");
    const _ = try process_value_or_msg(a);
    const _ = try process_value_or_msg(b) catch |e| {
        printf("捕获错误: %v\n", e);
        return 1;
    };
    return 0;
}
```

### 4.5.15 设计哲学一致性

Uya 联合体设计完全符合「坚如磐石」哲学：

1. ✅ **程序员提供证明**：通过模式匹配显式处理所有情况
2. ✅ **编译器验证证明**：在编译期验证标签一致性和完全性
3. ✅ **运行时绝对安全**：无未定义行为，所有访问都是类型安全的
4. ✅ **零运行时开销**：无标签存储，无运行时检查
5. ✅ **C 兼容性**：内存布局与 C union 完全相同
6. ✅ **显式控制**：强制模式匹配，无隐式转换
7. ✅ **编译期证明**：所有安全检查在编译期完成

**一句话总结**：Uya 联合体 = C union 内存布局 + Rust enum 类型安全 + 编译期标签证明，零运行时开销，100% 内存安全。

---

## 5 函数

### 5.1 普通函数

[examples/add.uya](./examples/add.uya)

- **函数定义语法**：
  - `fn name(...) type { ... }`：内部函数，生成的 C 代码添加 `static` 关键字
  - `export fn name(...) type { ... }`：导出函数，生成的 C 代码不添加 `static`
  - `extern fn name(...) type;`：外部 C 函数声明（无函数体）
  - `export extern fn name(...) type { ... }` 或 `extern export fn name(...) type { ... }`：导出外部 C 函数（FFI），两种顺序等价
- **函数可见性规则**（0.42 新增）：
  - **`fn`**：内部函数，生成的 C 代码为 `static void foo(void) { ... }`
    - 仅在当前编译单元可见，不导出到全局符号表
    - 避免符号冲突，提升代码质量
    - 生成的 C 函数名带 `uya_` 前缀（如 `uya_foo`）
  - **`export fn`**：导出函数，生成的 C 代码为 `void module_prefix_foo(void) { ... }`
    - 导出到全局符号表，供其他模块使用
    - 用于库函数、公共 API
    - **模块前缀规则**：生成的 C 函数名带模块前缀（如 `std_io_foo`、`main_bar`）
      - **同目录文件合并规则**：同一目录下的所有 `.uya` 文件都属于同一个模块（模块路径由目录路径决定，不包含文件名）
      - `lib/std/io/file.uya` 和 `lib/std/io/stream.uya` 都属于 `std.io` 模块 → 模块前缀 `std_io`
      - `lib/std/io/file.uya` 中的 `export fn fopen(...)` → `std_io_fopen(...)`
      - `lib/std/io/stream.uya` 中的 `export fn fgetc(...)` → `std_io_fgetc(...)`
      - `lib/std/mem/mem.uya`、`lib/std/mem/allocator.uya`、`lib/std/mem/arena.uya` 等同目录文件均属于 **`std.mem`** 模块 → 模块前缀 **`std_mem`**
      - `lib/std/mem/mem.uya` 中的 `export fn mem_copy(...)` → `std_mem_mem_copy(...)`
      - `lib/std/mem/allocator.uya` 中的 `export fn get_allocator(...)` → `std_mem_get_allocator(...)`（示例）
      - 主模块（项目根目录）→ 模块前缀 `main`
      - 主模块 `main.uya` 中的 `export fn my_func(...)` → `main_my_func(...)`
      - **模块前缀提取规则**：
        - 标准库路径 `lib/std/xxx/yyy.uya` → 模块 `std.xxx` → 模块前缀 `std_xxx`
        - 标准库路径 `lib/libc/xxx/yyy.uya` → 模块 `libc.xxx` → 模块前缀 `libc_xxx`
        - 主模块（项目根目录）→ 模块 `main` → 模块前缀 `main`
        - 模块路径中的 `.` 替换为 `_` 作为 C 函数名前缀
        - **注意**：函数名包含模块名（如 `mem_copy`）会导致生成的 C 函数名重复（如 `std_mem_mem_copy`），建议避免这种命名方式
  - **`extern fn`**：外部 C 函数声明，生成的 C 代码为 `extern void foo(void);`
    - 声明外部 C 函数，供 Uya 代码调用
    - 无函数体，仅声明
    - 不添加模块前缀（裸函数名）
  - **`extern fn`**（有函数体）：Uya 实现的 C 兼容函数，生成的 C 代码为 `void foo(void) { ... }`
    - 用 Uya 实现，但以裸函数名导出（不带模块前缀）
    - 用于包装 C 标准库函数或提供 C 兼容的实现
  - **`export extern fn`** 或 **`extern export fn`**：导出外部 C 函数（FFI），两种顺序等价
    - **无函数体**：不生成任何代码，链接到 C 标准库的实现
      - 用于声明 C 标准库函数（如 `malloc`, `free`, `strcmp`）
      - 示例：`export extern fn malloc(size: usize) *void;` → 链接到 C 标准库的 `malloc`
    - **有函数体**：生成函数定义 `void foo(void) { ... }`（不带模块前缀）
      - 用 Uya 实现，但以裸函数名导出（C 名称）
      - 用于在 Uya 标准库中实现 C 标准库函数
      - 示例：`export extern fn strcmp(s1: &const byte, s2: &const byte) i32 { ... }` → 生成 `int strcmp(const char *s1, const char *s2) { ... }`
- **`extern "libc" fn`**（0.43 新增）：显式声明 C 标准库函数
  - **语法**：`extern "libc" fn name(...) type;`
  - **用途**：显式声明 C 标准库函数（与 `extern fn` 等价，明确意图）
  - **byte 映射规则**：`byte` → `char`（C 字符类型，与 C 标准库兼容）
  - **示例**：
    ```uya
    // extern 与 extern "libc" 等价，byte 都映射为 char
    extern fn strlen(s: &byte) usize;
    extern "libc" fn atoi(s: &byte) i32;
    extern "libc" fn printf(fmt: &byte, ...) i32;
    ```
  - **设计目的**：明确表达 FFI 意图，使代码更清晰
- **函数调用语法**：`func_name(arg1, arg2, ...)`
- 参数按值传递（`memcpy`）。
- **返回值处理规则**：
  - 返回值 ≤ 16 byte 用寄存器，>16 byte 用 sret 指针（与 C 一致）
  - 错误联合类型 `!T` 的返回值处理：
    - 如果 `!T` 的大小 ≤ 16 byte，使用寄存器返回（错误联合类型作为普通结构体处理）
    - 如果 `!T` 的大小 > 16 byte，使用 sret 指针返回（错误联合类型作为普通结构体处理）
    - **错误标记处理**：错误联合类型在内存中表示为结构体 `{ error_id: u32, value: T }`，返回值传递方式与普通结构体完全相同，错误标记（`error_id` 字段）不单独处理

#### 5.1.2 函数调用约定详细说明

本节详细说明函数调用约定（ABI），包括参数传递、返回值传递、寄存器使用等规则。

**调用约定原则**：
- Uya 遵循目标平台的 C 调用约定（C ABI）
- 不同平台有不同的调用约定规则
- 编译器根据目标平台自动选择合适的调用约定

##### 5.1.2.1 x86-64 System V ABI（Linux、macOS、BSD）

这是 x86-64 平台上最常用的调用约定，用于 Linux、macOS 和大多数 Unix 系统。

**参数传递规则**：
1. **整数和指针参数**（前 6 个）：
   - 第 1 个参数 → `rdi` 寄存器
   - 第 2 个参数 → `rsi` 寄存器
   - 第 3 个参数 → `rdx` 寄存器
   - 第 4 个参数 → `rcx` 寄存器
   - 第 5 个参数 → `r8` 寄存器
   - 第 6 个参数 → `r9` 寄存器
   - 第 7 个及以后的参数 → 栈（从右到左压栈）

2. **浮点参数**（前 8 个）：
   - `f32`、`f64` 参数使用 XMM 寄存器（`xmm0` ~ `xmm7`）
   - 整数和浮点参数分别使用各自的寄存器序列
   - 参数位置由其在参数列表中的位置决定（整数和浮点共享参数编号）

3. **结构体参数**：
   - 如果结构体大小 ≤ 16 字节：
     - 使用寄存器传递（最多 2 个 8 字节寄存器）
     - 如果结构体适合 1 个寄存器，使用 `rdi`/`rsi`/`rdx`/`rcx`/`r8`/`r9`
     - 如果结构体适合 2 个寄存器，使用连续的两个寄存器（如 `rdi`+`rsi`）
   - 如果结构体大小 > 16 字节：
     - 使用指针传递（调用者分配内存并传递指针）
     - 指针本身通过寄存器传递（如 `rdi`）

4. **参数对齐**：
   - 栈参数按 8 字节对齐
   - 结构体参数按其对齐值对齐

**返回值传递规则**：
1. **整数和指针返回值**：
   - 返回值大小 ≤ 8 字节 → `rax` 寄存器
   - 返回值大小 = 16 字节 → `rax`（低 8 字节）+ `rdx`（高 8 字节）

2. **浮点返回值**：
   - `f32`、`f64` → `xmm0` 寄存器
   - 16 字节浮点向量 → `xmm0` + `xmm1`（如果支持）

3. **结构体返回值**：
   - 如果结构体大小 ≤ 16 字节：
     - 使用寄存器返回（`rax` + `rdx`，或 `xmm0` + `xmm1`）
   - 如果结构体大小 > 16 字节：
     - 使用 sret 指针返回
     - 调用者在栈上分配内存，传递指针作为隐式第一个参数（在 `rdi` 中）
     - 函数将返回值写入该内存，`rax` 返回该指针

4. **错误联合类型 `!T` 返回值**：
   - 错误联合类型的大小 = `max(sizeof(T), sizeof(错误标记)) + 对齐填充`
   - 如果大小 ≤ 16 字节，使用寄存器返回
   - 如果大小 > 16 字节，使用 sret 指针返回
   - 错误标记固定为 32 位无符号整数（4 字节），返回值传递方式与普通结构体完全相同

**寄存器保存规则**：
- **调用者保存寄存器**（调用者负责保存）：`rax`, `rcx`, `rdx`, `rsi`, `rdi`, `r8` ~ `r11`, `xmm0` ~ `xmm15`
- **被调用者保存寄存器**（被调用者负责保存）：`rbx`, `rbp`, `r12` ~ `r15`, `xmm8` ~ `xmm15`（部分系统）

**栈对齐**：
- 函数调用时，栈指针必须 16 字节对齐
- 在 `call` 指令前，栈指针（`rsp`）必须是 16 的倍数减 8（因为 `call` 指令会压入 8 字节返回地址）

**示例 1：基本参数传递**：
```uya
fn example(a: i32, b: i32, c: i32, d: i32, e: i32, f: i32, g: i32) i32 {
    // a -> rdi (32位，零扩展到64位)
    // b -> rsi
    // c -> rdx
    // d -> rcx
    // e -> r8
    // f -> r9
    // g -> 栈（[rsp+8]，跳过返回地址）
    return a + b;
}
```

**示例 2：结构体参数传递**：
```uya
struct Point {
    x: i32,
    y: i32,
}  // 大小 = 8 字节

fn process_point(p: Point, z: i32) i32 {
    // p (8字节) -> rdi (低4字节 x) + rdi 高4字节(零) + rsi (低4字节 y) + rsi 高4字节(零)
    // 或者简化为：p -> rdi (整个8字节，包含x和y)
    // z -> rdx
    return p.x + p.y + z;
}
```

**示例 3：大结构体参数**：
```uya
struct LargeStruct {
    data: [i32: 10],  // 40 字节
}

fn process_large(s: LargeStruct) void {
    // s (40字节 > 16字节) -> 使用指针传递
    // 调用者分配栈空间，传递指针 -> rdi
    // 函数内部通过指针访问结构体
}
```

**示例 4：结构体返回值**：
```uya
struct SmallResult {
    x: i64,
    y: i64,
}  // 大小 = 16 字节

fn get_result() SmallResult {
    // 返回值 16 字节 -> rax (x) + rdx (y)
    return SmallResult{ x: 100, y: 200 };
}

struct LargeResult {
    data: [i32: 10],  // 40 字节
}

fn get_large_result() LargeResult {
    // 返回值 40 字节 > 16 字节 -> 使用 sret 指针
    // 调用者在栈上分配内存，传递指针作为隐式第一个参数（rdi）
    // 函数将结果写入 [rdi]，返回 rdi 的值（rax = rdi）
    var result: LargeResult = LargeResult{ data: [0: 10] };
    return result;
}
```

##### 5.1.2.2 x86-64 Microsoft x64 Calling Convention（Windows）

Windows x86-64 平台使用不同的调用约定。

**参数传递规则**：
1. **整数和指针参数**（前 4 个）：
   - 第 1 个参数 → `rcx` 寄存器
   - 第 2 个参数 → `rdx` 寄存器
   - 第 3 个参数 → `r8` 寄存器
   - 第 4 个参数 → `r9` 寄存器
   - 第 5 个及以后的参数 → 栈（从右到左压栈）

2. **浮点参数**：
   - `f32`、`f64` 参数使用 XMM 寄存器（`xmm0` ~ `xmm3`）
   - 整数和浮点参数共享参数位置（不是分开的序列）

3. **结构体参数**：
   - 如果结构体大小 ≤ 8 字节：
     - 使用寄存器传递（1 个 8 字节寄存器）
   - 如果结构体大小 > 8 字节：
     - 使用指针传递（调用者分配内存并传递指针）

**返回值传递规则**：
- 与 System V ABI 类似，但有以下差异：
  - 返回值大小 ≤ 8 字节 → `rax` 寄存器
  - 返回值大小 > 8 字节 → 使用 sret 指针返回（不是 16 字节）

**栈对齐**：
- 函数调用时，栈指针必须 16 字节对齐
- 调用者负责分配栈空间并确保对齐

##### 5.1.2.3 ARM64 ABI（AArch64）

ARM64 平台的调用约定。

**参数传递规则**：
1. **整数和指针参数**（前 8 个）：
   - 使用 `x0` ~ `x7` 寄存器
   - 第 9 个及以后的参数 → 栈

2. **浮点参数**（前 8 个）：
   - 使用 `v0` ~ `v7`（128位 SIMD/浮点寄存器）
   - 整数和浮点参数共享参数位置

3. **结构体参数**：
   - 如果结构体大小 ≤ 16 字节且可放入寄存器：
     - 使用 `x0` ~ `x7` 或 `v0` ~ `v7` 传递
   - 如果结构体大小 > 16 字节：
     - 使用指针传递

**返回值传递规则**：
- 返回值大小 ≤ 16 字节 → `x0` 或 `x0`+`x1`（或 `v0`）
- 返回值大小 > 16 字节 → 使用 sret 指针返回（`x8` 传递返回值的指针）

##### 5.1.2.4 32位平台调用约定

32位 x86 平台遵循 cdecl 调用约定（x86 平台的 C 标准调用约定）。

**参数传递规则**：
- 所有参数通过栈传递（从右到左压栈）
- 参数按 4 字节对齐（或按类型对齐值对齐）

**返回值传递规则**：
- 返回值大小 ≤ 4 字节 → `eax` 寄存器
- 返回值大小 = 8 字节 → `eax`（低4字节）+ `edx`（高4字节）
- 返回值大小 > 8 字节 → 使用 sret 指针返回

##### 5.1.2.5 错误联合类型返回值处理

错误联合类型 `!T` 的返回值处理遵循普通结构体的规则：

```uya
// 错误联合类型的大小计算
// !T 大小 = max(sizeof(T), sizeof(错误标记)) + 对齐填充
// 错误标记固定为 32 位无符号整数（4 字节，uint32_t）

fn divide(a: i32, b: i32) !i32 {
    // !i32 大小 = max(4, 4) = 4 字节
    // 4 字节 ≤ 8 字节（x86-64），使用 rax 返回
    if b == 0 {
        return error.DivisionByZero;
    }
    return a / b;
}

struct LargeResult {
    data: [i32: 10],  // 40 字节
}

fn process() !LargeResult {
    // !LargeResult 大小 = max(40, 4) = 40 字节
    // 40 字节 > 16 字节（x86-64），使用 sret 指针返回
    var result: LargeResult = LargeResult{ data: [0: 10] };
    return result;
}
```

##### 5.1.2.6 调用约定总结

| 平台 | 整数参数寄存器 | 浮点参数寄存器 | 返回值寄存器 | sret 阈值 |
|------|--------------|--------------|-------------|-----------|
| x86-64 System V | rdi, rsi, rdx, rcx, r8, r9 | xmm0 ~ xmm7 | rax (+ rdx) | 16 字节 |
| x86-64 Windows | rcx, rdx, r8, r9 | xmm0 ~ xmm3 | rax | 8 字节 |
| ARM64 | x0 ~ x7 | v0 ~ v7 | x0 (+ x1) | 16 字节 |
| 32位 x86 | 栈 | 栈 | eax (+ edx) | 8 字节 |

**重要说明**：
- 所有调用约定都与 C ABI 完全兼容
- 编译器根据目标平台自动选择正确的调用约定
- 参数和返回值的具体传递方式由后端（如 LLVM）处理
- 程序员无需关心底层细节，只需编写符合 Uya 语法的代码
- 返回类型可以是具体类型、`void` 或错误联合类型 `!T`。
- `void` 函数可以省略 `return` 语句，或使用 `return;`。
- **返回值证明规则**：
  - **函数内部**：编译器可以证明返回值的安全性（在 `return` 语句之前）
  - **调用者**：编译器不能自动证明函数返回值的安全性，必须显式处理
  - 返回值是指针时，调用者需要显式检查（如 `if ptr == null { return error; }`）
  - 返回值是错误联合类型时，必须使用 `try` 或 `catch` 处理
  - 返回值用于数组索引时，调用者需要显式检查边界
  - 示例：`const result: i32 = try divide(10, 2);` 显式处理可能的错误
  - 示例：`const ptr: &i32 = get_pointer(); if ptr == null { return error; }` 显式检查空指针
- **递归函数**：支持递归函数调用（函数可以调用自身），递归深度受栈大小限制
- **函数前向引用**：函数可以在定义之前调用（编译器多遍扫描）
- **函数指针**：支持函数指针类型（语法：`fn(param_types) return_type`），用于 FFI 回调场景
  - 可以使用 `&function_name` 获取导出函数的函数指针
  - 支持类型别名：`type ComparFunc = fn(*void, *void) i32;`
  - 详见 [5.2 外部 C 函数（FFI）](#52-外部-c-函数ffi)
- **变参函数调用**：参数数量必须与 C 函数声明匹配（编译期检查有限）
- **程序入口点**：必须定义 `export fn main() i32` 或 `export fn main() !i32`
  - 编译为 `main_main()`，由 `lib/std/runtime/entry/entry.uya` 调用
  - 详见 [5.1.1 main函数签名](#511-main函数签名)
- **`return` 语句**：
  - `return expr;` 用于有返回值的函数
  - `return;` 用于 `void` 函数（可省略）
  - `return error.ErrorName;` 用于返回错误（错误联合类型函数）
  - `return` 语句后的代码不可达
  - 函数末尾的 `return` 可以省略（如果返回类型是 `void`）

#### 5.1.1 main函数签名

Uya 应用程序入口函数必须使用 `export` 修饰符：

| 声明方式 | 编译结果 | 用途 |
|----------|----------|------|
| `export fn main() i32` | `main_main()` | 应用程序入口（推荐） |
| `export fn main() !i32` | `main_main()` | 带错误处理的应用程序入口 |
| `export extern fn main(argc, argv)` | `main()` | C 入口（供 C 调用，如 entry.uya） |
| `fn main()` | `uya_main()` | 旧架构兼容（不推荐） |

**入口机制**：
```
C Runtime → entry.uya::main() → main_main()
                              └─ 用户应用代码
```

**默认（推荐）**：使用 **`bin/uya`**、**`uya build` / `run` / `test`** 或 **`src/compile.sh`** 时，编译器会**自动**把标准库中的 **`entry.uya`** 加入输入列表，**无需**在用户源码里写 `use std.runtime.entry`（该 `use` 只存在于 `entry.uya` 等标准库模块内部，用于解析依赖）。

**手动列出输入时**（例如仅用生成的 C 驱动、或自定义脚本且未调用上述入口）：需保证 `entry.uya` 参与编译，否则缺少 C 的 `main` 与 `main_main` 桥接。示例：
```bash
bin/uya --c99 app.uya …   # 推荐：由驱动自动加入 entry.uya
# 若必须手写多文件列表：
# bin/uya --c99 app.uya <UYA_ROOT>/std/runtime/entry/entry.uya -o app.c
```

**签名选择**：

1. **简单签名**：`export fn main() i32`
   - 用于简单程序，无错误处理需求
   - 不能使用`try`关键字（编译错误）
   - 必须使用`catch`处理所有可能的错误

2. **完整签名**：`export fn main() !i32`（推荐）
   - 用于需要错误处理的程序
   - 可以使用`try`关键字传播错误
   - 程序成功时返回0，错误时返回非0退出码
   - 编译器自动处理错误到退出码的转换

**推荐使用 `export fn main() !i32`**，以符合Uya的"显式控制"和"编译期证明"哲学。

- **切片参数**：函数可以直接接受切片类型作为参数
  - **语法**：`fn func_name(param: &[T]) ReturnType` 或 `fn func_name(param: &[T: N]) ReturnType`
  - **切片类型**：
    - `&[T]`：动态长度切片引用（胖指针：指针(4/8B) + 长度(4/8B)，平台相关；32位平台=8B，64位平台=16B）
    - `&[T: N]`：已知长度切片引用（胖指针：指针(4/8B) + 长度(4/8B)，平台相关；32位平台=8B，64位平台=16B，N 为编译期常量）
  - **函数体内访问**：
    - `param[i]` 访问切片元素（需要边界检查证明）
    - `@len(param)` 获取切片长度（对于 `&[T]`）或使用编译期常量 `N`（对于 `&[T: N]`）
  - **调用方式**：直接传递切片 `&arr[start:len]` 或 `&arr[start:N]`
  - 切片是胖指针，直接传递，无额外包装
  - **示例**：
[examples/process.uya](./examples/process.uya)

- **`try` 关键字**：
  - `try expr` 用于传播错误和溢出检查
  - **错误传播**：如果 `expr` 返回错误，当前函数立即返回该错误
  - **溢出检查**：如果 `expr` 是算术运算（`+`, `-`, `*`, `/`），自动检查溢出，溢出时返回 `error.Overflow`
  - 如果 `expr` 返回值，继续执行
  - **只能在返回错误联合类型的函数中使用**，且 `expr` 必须是返回错误联合类型的表达式或算术运算
  - **可能抛出的错误类型**：
    - **错误传播模式**：`try expr` 可能抛出 `expr` 返回的所有错误类型
      - 例如：`try divide(10, 2)` 可能抛出 `divide` 函数返回的所有错误（如 `error.DivisionByZero`）
    - **溢出检查模式**：`try a + b`、`try a - b`、`try a * b`、`try a / b` 可能抛出 `error.Overflow`
      - 加法溢出：`try a + b` 在 `a + b` 超出类型范围时返回 `error.Overflow`
      - 减法溢出：`try a - b` 在 `a - b` 超出类型范围时返回 `error.Overflow`
      - 乘法溢出：`try a * b` 在 `a * b` 超出类型范围时返回 `error.Overflow`
      - 除法溢出：`try a / b` 在 `a / b` 超出类型范围时返回 `error.Overflow`（如 `@min / -1`）
  - **错误传播示例**：`const result: i32 = try divide(10, 2);`（`divide` 必须返回 `!i32`，可能抛出 `error.DivisionByZero` 等）
  - **溢出检查示例**：
    - `const result: i32 = try a + b;`（自动检查 `a + b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a - b;`（自动检查 `a - b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a * b;`（自动检查 `a * b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a / b;`（自动检查 `a / b` 是否溢出，可能抛出 `error.Overflow`）

- **`catch` 语法**：
  - `expr catch |err| { statements }` 用于捕获并处理错误
  - `expr catch { statements }` 用于捕获所有错误（不绑定错误变量）
  - 如果 `expr` 返回错误，执行 catch 块
  - 如果 `expr` 返回值，跳过 catch 块
  - **类型规则**：`catch` 表达式的类型是 `expr` 成功时的值类型（不是错误联合类型）
    - `expr catch { default_value }` 的类型 = `expr` 的值类型
    - `catch` 块必须返回与 `expr` 成功值类型相同的值
    - **重要限制**：`catch` 块**不能返回错误联合类型**，只能返回值类型或使用 `return` 提前返回函数
  - **catch 块的返回方式**（两种方式，语义不同）：
    
    **方式 1：表达式返回值**（catch 块返回一个值给 catch 表达式）
    - catch 块的最后一条表达式作为返回值（不需要 `return` 关键字）
    - 这个值会成为整个 `catch` 表达式的值
    - 示例：
[examples/example_018.uya](./examples/example_018.uya)
    
    **方式 2：使用 `return` 提前返回函数**（catch 块直接退出函数）
    - catch 块中使用 `return` 会**立即返回函数**（不是返回 catch 块的值）
    - 跳过后续所有 defer 和 drop
    - 示例：
[examples/main.uya](./examples/main.uya)
    
    **重要区别**：
    - 表达式返回值：catch 块返回一个值，程序继续执行
    - `return` 语句：catch 块直接退出函数，程序不继续执行
- **错误处理**：
  - 支持**错误联合类型** `!T` 和 **try/catch** 语法，用于函数错误返回
  - 函数可以返回错误联合类型：`fn foo() !i32` 表示返回 `i32` 或 `Error`
  - 使用 `try` 关键字传播错误：`const result: i32 = try divide(10, 2);`
  - 使用 `catch` 语法捕获错误：`const result: i32 = divide(10, 0) catch |err| { ... };`
  - **无运行时 panic 路径**：所有 UB 必须被编译期证明为安全，失败即编译错误
  - **灵活错误定义**：支持预定义错误（`error ErrorName;`）和运行时错误（`error.ErrorName`），无需预先声明
- **错误类型的操作**：
  - 错误类型支持直接使用 `==` / `!=` 比较
  - 兼容旧写法：`if err == error.FileNotFound { ... }`
  - 运行时错误同样如此：`if err == error.SomeRuntimeError { ... }`
  - catch 块中可以判断错误类型并做不同处理
  - 错误类型不能直接打印，需要通过模式匹配处理
  - 也可显式比较错误 ID：`if @error_id(err) == @error_id(error.PredefinedError) || @error_id(err) == @error_id(error.RuntimeError) { ... }`
  - 可通过 `@error_id(err)` 读取错误值的数值 ID；对 `@syscall` 失败路径，该 ID 等于底层 errno 值
  
**错误处理设计哲学**：
- **编译期检查**：错误处理是编译期检查，编译器在当前函数内验证错误处理
- **显式错误**：错误是类型系统的一部分，必须显式处理
- **编译期检查**：编译器确保所有错误都被处理
- **无 panic、无断言**：所有 UB 必须被编译期证明为安全，失败即编译错误

**错误处理与内存安全的关系**：
- **`try`/`catch` 只用于函数错误返回**，不用于捕获 UB
- **所有 UB 必须被编译期证明为安全**，失败即编译错误，不生成代码
- 错误处理用于处理可预测的、显式的错误情况（如文件不存在、网络错误等）

**示例：错误处理**：
[examples/safe_divide.uya](./examples/safe_divide.uya)

### 5.2 外部 C 函数（FFI）

**步骤 1：顶层声明**  
[examples/extern_c_function.uya](./examples/extern_c_function.uya)

**步骤 2：正常调用**  
[examples/extern_c_function_1.uya](./examples/extern_c_function_1.uya)

#### 5.2.1 导入 C 函数（声明外部函数）

- 语法：`extern fn name(...) type;`（分号结尾，无函数体）
- 用于声明外部 C 函数，供 Uya 代码调用

**重要语法规则**：
- extern 函数声明必须使用 Uya 的函数参数语法：`param_name: type`
- **FFI 指针类型 `*T` 和 `*const T`**（0.42 新增 `*const T`）：支持所有 C 兼容类型
  - **可变指针 `*T`**：
    - 整数类型：`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`
    - 浮点类型：`*f32`, `*f64`
    - 特殊类型：`*bool`, `*byte`（C 字符串），`*void`（通用指针）
    - C 结构体：`*CStruct`（指向外部 C 结构体的指针）
    - C 代码生成：`T *`（可变指针）
  - **只读指针 `*const T`**（0.42 新增）：
    - 整数类型：`*const i8`, `*const i16`, `*const i32`, `*const i64`, `*const u8`, `*const u16`, `*const u32`, `*const u64`
    - 浮点类型：`*const f32`, `*const f64`
    - 特殊类型：`*const bool`, `*const byte`（只读 C 字符串），`*const void`（只读通用指针）
    - C 结构体：`*const CStruct`（指向外部 C 结构体的只读指针）
    - C 代码生成：`const T *`（只读指针）
    - **使用场景**：标准库函数的只读参数，如 `strlen`, `strcmp` 等
    - **示例**：`extern fn strlen(s: *const byte) usize;`
- 指针类型参数使用 `*T` 语法（如 `*byte` 表示指向 `byte` 的指针，`*u16` 表示指向 `u16` 的指针）
- **Uya 指针传递给 FFI 函数**：
  - ✅ **Uya 普通指针 `&T` 可以通过显式转换传递给 FFI 函数的指针类型参数 `*T`**
  - 使用 `as` 进行显式转换：`&T as *T`（安全转换，无精度损失，编译期检查）
  - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `write(1, &buffer[0] as *byte, 10);`
  - 这是 FFI 调用时的显式规则，符合 Uya "显式控制"的设计哲学
  - 类型兼容规则：`&T` 可以转换为 `*T`（如果 `T` 类型兼容），详见 [第 11 章类型转换](#11-类型转换)
- **返回值类型**：返回值类型放在参数列表的 `)` 后面，遵循 Uya 的函数语法
  - 指针类型返回值使用 `*T` 语法（如 `*void` 表示指向 `void` 的指针，对应 C 的 `void*`）
  - 示例：`extern malloc(size: i32) *void;`（返回 `void*` 指针）
  - 示例：`extern printf(fmt: *byte, ...) i32;`（返回 `i32`）
  - 也支持箭头语法：`extern malloc(size: i32) -> *void;`
- 变参函数使用 `...` 表示可变参数列表

- 声明必须出现在**顶层**；不可与调用混写在一行。
- 调用生成原生 `call rel32` 或 `call *rax`，**无包装函数**。
- 返回后按 C 调用约定清理参数。
- **调用约定**：与目标平台的 C 调用约定一致（如 x86-64 System V ABI 或 Microsoft x64 calling convention），具体由后端实现决定

#### 5.2.2 导出函数给 C（导出函数）

- 语法：`extern fn name(...) type { ... }`（花括号包含函数体）
- 用于将 Uya 函数导出为 C 函数，供 C 代码调用
- 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
- 函数参数和返回值必须使用 C 兼容的类型

**示例**：
```uya
// 导出函数给 C
extern fn compare(a: *void, b: *void) i32 {
    const val_a: i32 = *(a as *i32);
    const val_b: i32 = *(b as *i32);
    if val_a < val_b { return -1; }
    if val_a > val_b { return 1; }
    return 0;
}

// 使用函数指针类型别名
type ComparFunc = fn(*void, *void) i32;

// 声明需要函数指针的 C 函数
extern qsort(base: *void, nmemb: usize, size: usize, compar: ComparFunc) void;

fn main() i32 {
    const arr: [i32: 5] = [5, 2, 8, 1, 9];
    
    // 使用 &compare 获取函数指针并传递给 C 函数
    qsort(&arr[0], 5, 4, &compare);
    
    return 0;
}
```

**函数指针类型**：
- 语法：`fn(param_types) return_type`
- 支持类型别名：`type FuncAlias = fn(...) type;`
- `&function_name` 的类型是函数指针类型（不是 `*void`）
- 仅在 FFI 上下文中使用，用于与 C 函数指针互操作

#### 5.2.3 导入/导出 C 变量

Uya 支持 `extern` 导入和导出 C 全局变量/常量，用于与 C 代码共享全局状态。

**导入 C 全局变量**：

- 语法：`extern const name: type;`（只读变量）或 `extern var name: type;`（可变变量）
- 用于声明外部 C 全局变量，供 Uya 代码访问
- 生成的 C 代码：`extern type name;`

**示例**：
```uya
// 导入 C 标准库全局变量
extern const errno: i32;           // C: extern int errno;
extern var optind: i32;            // C: extern int optind;
extern const stdout: *void;        // C: extern FILE *stdout;
extern const stderr: *void;        // C: extern FILE *stderr;

fn main() i32 {
    // 读取外部变量
    const err: i32 = errno;
    
    // 写入外部变量（仅 var 声明）
    optind = 1;
    
    return 0;
}
```

**导出 Uya 变量给 C**：

- 语法：`export const name: type = value;` 或 `export var name: type = value;`
- 用于将 Uya 全局变量导出为 C 全局变量，供 C 代码访问
- 生成的 C 代码：`type name = value;`（不带 `static`）

**示例**：
```uya
// 导出全局常量给 C
export const VERSION: &byte = "1.0.0";  // C: const char *VERSION = "1.0.0";

// 导出全局变量给 C
export var debug_mode: i32 = 0;         // C: int debug_mode = 0;

// 导出 extern 变量（链接到 C 库定义）
export extern const ENOENT: i32;        // 不生成定义，链接到 C 库
```

**语法规则**：

| 语法 | 用途 | C 代码生成 |
|------|------|-----------|
| `extern const name: type;` | 导入只读 C 变量 | `extern const type name;` |
| `extern var name: type;` | 导入可变 C 变量 | `extern type name;` |
| `export const name: type = val;` | 导出只读 Uya 常量 | `const type name = val;` |
| `export var name: type = val;` | 导出可变 Uya 变量 | `type name = val;` |
| `export extern const name: type;` | 链接到 C 库定义的常量 | 不生成，链接到 C 库 |
| `export extern var name: type;` | 链接到 C 库定义的变量 | 不生成，链接到 C 库 |

**类型限制**：

- 必须使用 C 兼容类型：
  - 基本类型：`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `byte`
  - 指针类型：`*T`, `*const T`, `&T`, `&const T`
  - C 结构体：extern struct 类型
- 不支持 Uya 特有类型（如切片、错误联合等）

**设计目的**：

1. **互操作性**：允许 Uya 代码访问 C 库的全局状态（如 `errno`, `stdout`）
2. **可控性**：`const` 和 `var` 明确区分只读和可变
3. **安全性**：类型检查确保 C 兼容性
4. **简洁性**：语法与 `extern fn` 保持一致

**FFI 指针使用示例**：

[examples/safe_access_1.uya](./examples/safe_access_1.uya)

**FFI 指针使用规则**：
- ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
- ✅ 可用字符串字面量初始化 `*byte`：`const s: *byte = "hello";`（见 §1.4）
- ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`），但必须提供长度约束证明
- ❌ 其他情形不能用于普通变量声明（编译错误）
- ❌ 不能进行普通指针算术（只能用于 FFI 上下文）

**禁止用法示例**：
[examples/safe_example.uya](./examples/safe_example.uya)

**统一指针语法的完整规则**：

1. **普通指针** `&T`：Uya 内部安全指针
   - **用途**：Uya 内部安全指针
   - **支持**：所有 Uya 类型
   - **边界检查**：必须编译期证明
   - **示例**：`&i32`, `&f64`, `&MyStruct`

2. **FFI 指针** `*T`：仅用于 C 语言互操作
   - **用途**：仅用于 C 语言互操作
   - **支持**：所有 C 兼容类型（`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`）
   - **特殊规则**：
     - ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`）
     - ✅ **必须**提供长度约束证明
     - ✅ 可用字符串字面量初始化 `*byte`（见 §1.4）
     - ❌ 其他情形不能用于普通变量声明（编译错误）
     - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）

3. **切片类型** `&[T]` 和 `&[T: N]`：切片引用类型
   - **用途**：表示数组的切片视图（指针+长度的组合）
   - **类型**：
     - `&[T]`：动态长度切片引用（胖指针：指针(4/8B) + 长度(4/8B)，平台相关；32位平台=8B，64位平台=16B）
     - `&[T: N]`：已知长度切片引用（胖指针：指针(4/8B) + 长度(4/8B)，平台相关；32位平台=8B，64位平台=16B，N 为编译期常量）
   - **创建方式**：使用切片语法 `&arr[start:len]` 或 `&arr[start:N]`
   - **内部访问**：`buf[i]` 访问切片元素（需要边界检查证明），`@len(buf)` 获取长度
   - 切片是胖指针，直接传递，无额外包装

**设计哲学一致性**：

FFI 指针设计符合"坚如磐石"哲学：
1. **显式区分**：`&T`（安全内部）vs `*T`（FFI 专用）
2. **安全强化**：FFI 指针下标访问**必须**长度约束证明
3. **编译期验证**：所有边界检查在编译期完成
4. **显式转换**：Uya 普通指针 `&T` 可以通过 `as` 显式转换为 FFI 指针类型 `*T`（仅在 FFI 调用时）
5. **C 兼容性**：支持所有 C 语言指针类型

**重要说明**：
- **FFI 调用时的指针转换**：在调用 extern 函数时，Uya 普通指针 `&T` 可以通过 `as` 显式转换为 FFI 指针类型 `*T`
- 这是 FFI 调用时的显式规则，允许 Uya 代码更方便地与 C 函数互操作
- 在其他上下文中（如普通函数调用、变量赋值等），`&T` 和 `*T` 仍然不能混用
- FFI 函数调用的格式字符串（如 `printf` 的 `"%f"`）是 C 函数的特性，不是 Uya 语言本身的特性
- Uya 语言仅提供 FFI 机制来调用 C 函数，格式字符串的语法和语义遵循 C 标准
- 字符串插值（第 17 章）是 Uya 语言本身的特性，编译期展开，与 FFI 的格式字符串不同

### 5.3 与 C 结构体互操作

**统一标准**：
- 所有 Uya `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- 所有结构体都可以直接与 C 代码互操作
- 支持所有类型（包括切片、interface、错误联合类型等）

**使用 C 结构体**：
- 可以直接在 Uya 中使用 C 结构体，无需特殊声明
- 编译器自动识别 C 结构体布局，确保 100% 兼容性

**示例**：
```uya
// Uya 结构体，可以直接传递给 C 函数
struct Point {
    x: f32,
    y: f32
}

// C 函数声明
extern draw_point(p: *Point) void;

fn main() i32 {
    const p: Point = Point{ x: 1.0, y: 2.0 };
    draw_point(&p);  // 直接传递，编译器自动处理布局
    return 0;
}
```

**FFI 指针类型 `*T`**：
- 仅用于 FFI 函数声明/调用和函数参数
- 支持所有 C 兼容类型（`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`）
- 使用规则：
  1. 仅用于 FFI 声明/调用
  2. 下标访问必须提供长度约束证明
  3. 除用字符串字面量初始化 `*byte` 外，不能用于普通变量声明（见 §1.4）
  4. 与 `&T` 严格区分

**一句话总结**：

> **统一标准：所有 struct 使用 C 内存布局，支持所有类型，可以直接与 C 互操作。**  
> **编译器自动处理布局转换，确保 100% C 兼容性。**

### 5.4 可变参数函数

#### 5.4.1 设计原则

可变参数函数在 Uya 中采用 **C 语法兼容 + 类型安全元组访问** 的设计：

1. **语法兼容**：沿用 C 语言的 `...` 语法声明可变参数函数
2. **统一访问**：使用内置变量 `@params` 将整个参数列表（包括固定参数和可变参数）作为元组访问
3. **智能优化**：编译器根据 `@params` 的使用情况自动优化，未使用时无元组打包开销
4. **ABI 兼容**：保持与 C 语言可变参数 ABI 的完全兼容

#### 5.4.2 声明语法

可变参数函数的声明语法与 C 语言一致：

```uya
// 外部 C 函数声明
extern fn printf(fmt: *byte, ...) i32;

// Uya 函数声明
fn my_print(fmt: *byte, ...) void;
fn sum_all(...) i32;
fn format_message(level: i32, fmt: *byte, ...) void;
```

**语法规则**：
- `...` 必须出现在参数列表的最后
- 固定参数与可变参数之间不能有其他分隔符
- 函数声明和定义使用相同的语法

#### 5.4.3 使用 @params 访问参数

`@params` 是内置变量，在函数体内可用，包含所有参数（固定参数 + 可变参数）的元组视图：

```uya
// 示例 1：非可变参数函数
fn add(x: i32, y: i32) i32 {
    const params = @params;  // 类型: (i32, i32)
    return params.0 + params.1;
}

// 示例 2：纯可变参数函数
fn sum_all(...) i32 {
    const args = @params;  // 类型: 根据调用点确定的元组
    var total: i32 = 0;
    for args |val| {
        total += val;
    }
    return total;
}

// 示例 3：混合参数函数
fn print_with_prefix(prefix: *byte, ...) void {
    const all_args = @params;  // 类型: (prefix: *byte, ...可变参数)
    
    // 访问固定参数
    printf("Prefix: %s\n", all_args.0);
    
    // 跳过固定参数，处理可变参数部分
    for var i: i32 = 1; i < @len(all_args); i += 1 {
        printf("%d ", all_args[i]);
    }
}
```

#### 5.4.4 参数转发

可变参数可以通过 `...` 语法转发给其他可变参数函数：

```uya
// 简单的转发包装器
fn log_error(fmt: *byte, ...) void {
    // 添加前缀后转发
    printf("ERROR: ");
    printf(fmt, ...);  // 使用 ... 转发可变参数
}

// 条件性转发
fn conditional_print(debug: bool, fmt: *byte, ...) void {
    if debug {
        printf("[DEBUG] ");
        printf(fmt, ...);
    } else {
        printf(fmt, ...);
    }
}
```

#### 5.4.4a 使用 @va_start / @va_end / @va_arg / @va_copy

**声明**：`@va_start(&ap, last)` | `@va_end(&ap)` | `@va_arg(ap, Type)` | `@va_copy(&dest, src)`

`va_list` 是编译器内置类型，用于表示可变参数列表。当需要将可变参数传递给 vprintf/vfprintf 或自行遍历时，使用这些内置函数：

**示例 1**：包装 vfprintf（传递给 C 函数）
```uya
export extern "libc" fn vfprintf(stream: *void, format: *const byte, ap: va_list) i32;

fn my_vfprintf(stream: &FILE, fmt: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, fmt);  // fmt 是最后一个命名参数
    const ret = vfprintf(stream as *void, fmt, ap);
    @va_end(&ap);
    return ret;
}
```

**示例 2**：遍历可变参数（使用 @va_arg）
```uya
fn sum_n(n: i32, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, n);
    var s: i32 = 0;
    var i: i32 = 0;
    while i < n {
        s = s + @va_arg(ap, i32);
        i = i + 1;
    }
    @va_end(&ap);
    return s;
}
// 调用: sum_n(3, 10, 20, 30) 返回 60
```

**示例 3**：接收 va_list 参数的函数
```uya
fn my_vprintf(format: &const byte, ap: va_list) i32 {
    // 可以直接使用 @va_arg
    const first: i32 = @va_arg(ap, i32);
    // ...
    return 0;
}
```

**示例 4**：复制 va_list（使用 @va_copy）
```uya
fn measure_and_print(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);

    var ap2: va_list = va_list{};
    @va_copy(&ap2, ap);  // 复制以便多次遍历

    const len: i32 = _calc_length(format, ap2);
    @va_end(&ap2);

    const ret: i32 = _do_print(format, ap);
    @va_end(&ap);

    return ret;
}
```

- `@va_start(&ap, last)`：初始化 va_list，`last` 为最后一个命名参数
- `@va_end(&ap)`：结束访问，必须与 `@va_start` 或 `@va_copy` 成对调用
- `@va_arg(ap, Type)`：按类型取下一个参数，支持 `i32`、`i64`、`&byte`、`f64` 等
- `@va_copy(&dest, src)`：复制 va_list，用于多次遍历
- 编译时展开为 C 的 `va_start`/`va_end`/`va_arg`/`va_copy` 宏
- 详见 [builtin_functions.md §@va_*](./builtin_functions.md#va_start)

#### 5.4.5 编译器优化策略

编译器根据 `@params` 的使用情况进行智能优化：

| 使用场景 | 编译器行为 | 性能影响 |
|---------|-----------|---------|
| 完全不使用 `@params` | 不生成元组打包代码，直接转发参数 | 零额外开销，与 C 代码相同 |
| 使用 `@params` 访问参数 | 生成元组打包代码，提供元组访问 | 有元组打包和访问开销 |
| 仅在部分路径使用 `@params` | 可在使用路径生成元组代码，或保守生成完整代码 | 条件性开销 |

**优化示例**：

```uya
// 优化场景 1：完全不使用 @params（最优）
fn optimized_forward(fmt: *byte, ...) i32 {
    // 仅转发，不使用 @params
    return printf(fmt, ...);  // 编译器不生成元组代码
}

// 优化场景 2：使用 @params
fn needs_tuple(...) i32 {
    const args = @params;  // 使用 @params，编译器生成元组代码
    return process_args(args);
}

// 优化场景 3：条件性使用
fn conditional_usage(flag: bool, ...) void {
    if flag {
        const args = @params;  // 仅在此分支使用
        log_tuple(args);
    }
    // 其他分支不使用 @params
}
```

#### 5.4.6 类型安全与格式串推断

对于 printf 风格的可变参数函数，当使用 `@params` 时，编译器可以根据格式串推断参数类型：

```uya
// 带类型检查的 printf 包装器
fn checked_printf(fmt: *byte, ...) i32 {
    // 编译器可根据格式串 fmt 推断 @params 的类型
    // 并检查参数类型是否匹配
    
    const args = @params;  // 类型由格式串推断
    
    // 可以添加额外验证逻辑
    if !validate_printf_args(fmt, args) {
        return -1;
    }
    
    return printf(fmt, ...);
}
```

**类型推断规则**：
1. 格式串必须是编译期常量字符串（`*byte` 字面量）
2. 编译器解析格式串中的占位符（`%d`, `%f`, `%s` 等）
3. 推断 `@params` 中对应位置的参数类型
4. 检查实际参数类型是否与占位符匹配

#### 5.4.7 限制与注意事项

1. **`@params` 是只读的**：不能修改 `@params` 的内容
2. **统一语义**：所有函数中的 `@params` 都包含所有参数，语义一致
3. **元组操作**：`@params` 支持所有元组操作（索引访问、遍历、解构等）
4. **生命周期**：`@params` 的生命周期与函数调用相同，不能逃逸
5. **C 互操作**：使用 `...` 转发参数时，必须转发给接受可变参数的函数

#### 5.4.8 示例

**完整示例 1：可变参数求和**
```uya
fn sum(...) i32 {
    const args = @params;
    var total: i32 = 0;
    
    for args |val| {
        total += val;
    }
    
    return total;
}

fn main() i32 {
    const result = sum(1, 2, 3, 4, 5);
    printf("Sum: %d\n", result);
    return 0;
}
```

**完整示例 2：带日志的可变参数打印**
```uya
extern fn printf(fmt: *byte, ...) i32;
extern fn get_timestamp() u64;

fn log_printf(fmt: *byte, ...) i32 {
    const timestamp = get_timestamp();
    const args = @params;  // 包含 fmt 和所有可变参数
    
    // 记录日志（示例）
    printf("[%llu] ", timestamp);
    
    // 转发给 printf，跳过第一个参数（fmt）
    // 注意：实际实现需要处理参数转发
    return printf(fmt, ...);
}
```

#### 5.4.9 一句话总结

> **Uya 可变参数 = C 的 `...` 语法 + `@params` 统一元组访问 + `@va_start`/`@va_end`/`@va_arg` va_list 支持 + 编译器智能优化**；  
> **保持 C 兼容性，提供类型安全选项，未使用时零开销。**

---

## 6 接口（interface）

### 6.1 设计目标

- **鸭子类型 + 动态派发**体验；  
- **零注册表 + 编译期生成**；  
- **标准内存布局 + 单条 call 指令**；  
- **无 lifetime 符号、无 new 关键字、无运行时锁**。

### 6.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#21-接口类型)

接口类型定义语法：
- `interface InterfaceName { method_sig ... }`
- 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
- 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义
- `@async_fn` 现在也可用于接口方法签名，以及结构体/联合体的方法实现；对接口而言，异步 ABI 仍由返回 `Future<!T>` 或 `!Future<T>` 表达

### 6.3 语义总览

| 项 | 内容 |
|---|---|
| 接口值 | 8/16 B 结构体（平台相关）`{ vptr: *const VTable, data: *any }`；32位平台=8B，64位平台=16B |
| VTable | **编译期唯一生成**；单元素函数指针数组；只读静态数据 |
| 装箱 | 局部变量/参数/返回值处自动生成；**无运行期注册** |
| 调用 | `call [vtable+offset]` → **单条指令**，零额外开销 |
| 生命期 | 由作用域 RAII 保证；**逃逸即编译错误**（见 6.4 节） |

### 6.4 Self 类型

- `Self` 是方法签名中的特殊占位符，代表当前结构体类型
- 在接口定义和结构体方法的方法签名中使用
- `Self` 不是一个实际类型，而是编译期的类型替换标记
- 示例：
  - 结构体方法：`Point { fn distance(self: &Self) f32 { ... } }` 中，`Self` 被替换为 `Point`
  - 接口方法：`struct Console : IWriter { fn write(self: &Self, ...) { ... } }` 中，`Self` 被替换为 `Console`
- `&Self` 表示指向当前结构体类型的指针
- 结构体方法（包括接口方法）都可以使用 `Self`，语法一致，语义清晰

### 6.5 生命周期（零语法版）

- **无 `'static`、无 `'a`**；  
- 编译器只在「赋值/返回/传参」路径检查：  
[examples/example_028.txt](./examples/example_028.txt)
- 检查失败**仅一行报错**；通过者**无额外运行时成本**。

**逃逸检查规则**：

接口值不能逃逸出其底层数据的生命周期。编译器在以下路径检查：

1. **返回接口值**：
[examples/example_5.uya](./examples/example_5.uya)

2. **赋值给外部变量**：
[examples/example_6.uya](./examples/example_6.uya)

3. **传递参数**：
[examples/use_writer.uya](./examples/use_writer.uya)

**编译器检查算法**：基于作用域层级检查，数据作用域必须 ≥ 目标作用域，否则编译错误。

**切片生命周期规则**：

切片生命周期必须 ≤ 原数据的生命周期。编译器在以下路径检查：

1. **返回切片**：
[examples/valid.uya](./examples/valid.uya)

2. **切片赋值**：
[examples/example_7.uya](./examples/example_7.uya)

3. **核心规则**：
   - 切片是原数据的视图，不拥有数据
   - 切片的生命周期自动绑定到原数据的生命周期
   - 编译器验证切片不会超过原数据的生命周期
   - 修改原数组会影响切片，切片和原数组共享同一块内存

### 6.6 接口方法调用

- 接口方法调用语法：`interface_value.method_name(arg1, arg2, ...)`
- `self` 参数自动传递，无需显式传递
- 示例：`w.write(&msg[0], 5);` 中，`w` 是接口值，`write` 方法会自动接收 `self` 参数

### 6.7 完整示例

[examples/console.uya](./examples/console.uya)

编译后生成（x86-64）：

[examples/example_035.txt](./examples/example_035.txt)

**接口方法调用说明**：
- 调用 `w.write(&msg[0], 5);` 时，`w` 是接口值（包含 vtable 和数据指针）
- 编译器自动从 vtable 中加载方法地址，并将 `w` 的数据指针作为 `self` 参数传递
- `self` 参数在调用时隐式传递，用户代码中不需要显式传递

**调用约定（ABI）**：
- 接口方法调用遵循与普通函数相同的调用约定（与目标平台的 C 调用约定一致）
- `self` 参数作为第一个参数传递（x86-64 System V ABI：`rdi` 寄存器）
- 其他参数按顺序传递（x86-64 System V ABI：`rsi`、`rdx`、`rcx`、`r8`、`r9`，然后栈）
- 返回值处理与普通函数相同（≤16 字节用寄存器，>16 字节用 sret 指针）

### 6.8 限制（保持简单）

| 限制 | 说明 |
|---|---|
| 无字段接口 | `struct S { w: IWriter }` → ❌ 编译错误（当前限制） |
| 无数组/切片接口 | `const arr: [IWriter: 3]` → ❌ |
| 无自引用 | 接口值不能指向自己 |
| 无运行时注册 | 所有 vtable 编译期生成，**零 map 零锁** |

### 6.9 与 C 互操作

- 接口值首地址 = `&vtable`，可直接当 `void*` 塞给 C；  
- C 侧回调：
[examples/example_036.c](./examples/example_036.c)

### 6.10 后端实现要点

1. **语法树收集** → 扫描所有在结构体定义中声明接口的结构体（`struct T : I { ... }`），生成唯一 vtable 常量。  
2. **类型检查** → 确保结构体方法实现了所有声明接口的全部方法签名。  
3. **装箱点** →  
   - 局部：`const iface: I = concrete;`  
   - 传参 / 返回：按值复制 16 B。  
4. **调用点** →  
   - 加载 `vptr` → 计算方法偏移 → `call [reg+offset]`。  
5. **逃逸检查** → 6.4 节生命周期规则；失败即报错。

### 6.11 迁移指南

| 旧需求（extern+函数指针） | 新做法（接口） |
|---|---|
| `extern call(f: IFunc, x: i32) i32;` | `fn use(IFunc f);` |
| 手动管理函数地址 | 编译期 vtable，无地址赋值 |
| 类型不安全 | 接口签名强制检查 |
| 需全局注册表 | 零注册，零锁 |

### 6.12 迭代器接口（用于for循环）

**设计目标**：
- 通过接口机制支持 for 循环迭代
- 编译期生成vtable
- 支持所有实现了迭代器接口的类型

**迭代器接口定义**：

由于 Uya 没有泛型，迭代器接口需要针对具体元素类型定义。以下以 `i32` 类型为例：

[examples/next.uya](./examples/next.uya)

**数组迭代器实现示例**：

[examples/arrayiteratori32.uya](./examples/arrayiteratori32.uya)

**使用示例**：

[examples/create_iterator.uya](./examples/create_iterator.uya)

**设计说明**：
- 迭代器接口遵循 Uya 接口的设计原则：编译期生成vtable
- 使用错误联合类型 `!void` 表示迭代结束，符合 Uya 的错误处理机制
- 需要为每种元素类型定义对应的迭代器接口（当前限制，泛型功能在未来版本中提供）
- for循环语法会自动使用这些接口进行迭代（[见第8章](#8-控制流)）

### 6.13 一句话总结

> **Uya 接口 = 鸭子派发 + 零注册 + 标准内存布局**；  
> **语法零新增、生命周期零符号、编译期证明**；  
> **今天就能用，明天可放开字段限制**。

---

## 7 栈式数组（零 GC）

[examples/summary_example.uya](./examples/summary_example.uya)

- **栈数组语法**：使用 `[]` 表示零初始化的栈数组，类型由左侧变量的类型注解确定。
- `[]` 不能独立使用，必须与类型注解一起使用：`var buf: [T: N] = [];`
- **数组初始化**：`[]` 返回的数组**零初始化**（所有元素初始化为 0），确保行为可预测
  - 整数类型（`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`）：所有元素初始化为 `0`
  - 浮点类型（`f32`, `f64`）：所有元素初始化为 `0.0`
  - 布尔类型（`bool`）：所有元素初始化为 `false`
  - 指针类型（`&T`, `*T`）：所有元素初始化为 `null`（空指针）
  - 结构体类型：所有元素按结构体的零初始化规则初始化（所有字段为 0）
  - 这确保了数组初始化行为的可预测性，符合 Uya "坚如磐石"的设计哲学
- **`@len` 内置函数行为**：对于空数组字面量 `[]`，`@len` 返回数组声明时的大小，而不是 0
  - 示例：`var buffer: [i32: 100] = []; const len_val: i32 = @len(buffer);` → `len_val = 100`
  - 零初始化示例：
[examples/example_041.uya](./examples/example_041.uya)
  - **重要说明**：虽然数组是零初始化的，但如果需要特定的初始值，仍应使用数组字面量（如 `[1, 2, 3]`）或显式赋值
- 数组大小 `N` 必须是**编译期常量表达式**：
  - 字面量：`64`, `100`
  - 常量变量：`const SIZE: i32 = 64;` 然后使用 `SIZE`
  - 常量算术运算：`2 + 3`, `SIZE * 2`
  - 不支持函数调用（除非是 `const fn`，暂不支持）
- **语法规则**：
  - `[]` 表示栈分配的零初始化数组
  - 数组大小由类型注解 `[T: N]` 中的 `N` 指定
  - 示例：`var buf: [f32: 64] = [];` 表示分配 64 个 `f32` 的栈数组，所有元素初始化为 `0.0`
- **多维数组初始化**：
  - **零初始化多维数组**：使用嵌套的 `[]` 语法
[examples/example_042.uya](./examples/example_042.uya)
  - **多维数组字面量**：使用嵌套的数组字面量
[examples/example_043.uya](./examples/example_043.uya)
  - **多维数组边界检查**：所有维度的索引都需要编译期证明
    - 对于 `matrix[i][j]`，必须证明 `i >= 0 && i < 3 && j >= 0 && j < 4`
    - 常量索引越界 → 编译错误
    - 变量索引无证明 → 编译错误
- 生命周期 = 所在 `{}` 块；返回上层即编译错误（逃逸检测）。
- 后端映射为 `alloca` 或机器栈数组。
- **逃逸检测规则**：`[]` 分配的对象不能：
  - 被函数返回
  - 被赋值给生命周期更长的变量
  - 被传递给可能存储引用的函数

---

## 8 控制流

[examples/control_flow.uya](./examples/control_flow.uya)

- 条件表达式必须是 `bool`（无隐式转布尔）。
- `block` 必须用大括号。
- **语句**：
  - 表达式后跟分号 `;` 构成表达式语句
  - 支持空语句：单独的 `;`
  - 支持空块：`{ }`
  - 函数调用、赋值等表达式可以作为语句使用
- **语法形式**：
  - `if` 语句：`if condition { statements } [ else { statements } ]`
  - 支持 `else if`：`if c1 { } else if c2 { } else { }`
  - `while` 语句：`while condition { statements }`
- **`break` 和 `continue`**：
  - `break;` 跳出最近的 `while` 或 `for` 循环
  - `continue;` 跳过当前循环迭代，继续下一次
  - 不支持 `break label` 或 `continue label`（未来支持）
  - `break` 和 `continue` 只能在循环体内使用

- **`for` 循环**：迭代循环，支持可迭代对象和整数范围
  - **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#81-for-循环)
  - **语法形式**：
[examples/example_045.txt](./examples/example_045.txt)
    - `range_expr`：整数范围表达式
      - `start..end`：从 `start` 到 `end-1` 的范围（左闭右开区间 `[start, end)`）
      - `start..`：从 `start` 开始的无限范围，由迭代器结束条件终止
  - **基本形式（有元素变量，只读）**：`for obj |v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、切片、迭代器）
    - `v` 是循环变量，类型由迭代器的 `value()` 方法返回类型决定
    - `v` 是只读的，不能修改
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
  - **基本形式（有元素变量，可修改）**：`for obj |&v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、切片、迭代器）
    - `&v` 是循环变量，类型是指向元素的指针（`&T`），可以修改元素
    - 在循环体中可以通过 `*v` 访问元素值，通过 `*v = value` 修改元素
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
    - 注意：只有可变数组（`var arr`）或可变切片才能使用此形式
  - **索引迭代形式**：`for obj |i| { statements }`
    - `obj` 可以是数组或切片
    - `i` 是当前元素的索引，类型为 `usize`
    - 适用于只需要索引，不需要元素值的场景
  - **整数范围形式（有元素变量）**：`for start..end |v| { statements }` 或 `for start.. |v| { statements }`
    - `start..end`：迭代从 `start` 到 `end-1` 的整数（`[start, end)`）
    - `start..`：从 `start` 开始的无限范围，由迭代器结束条件终止
    - `v` 是当前迭代的整数值
  - **丢弃元素形式**：`for obj { statements }` 或 `for start..end { statements }`
    - 不绑定元素变量，只执行循环体指定次数
    - 适用于只需要循环次数，不需要元素值的场景
  - **语义**：
    - for循环是语法糖，编译期展开为while循环（见展开规则）
    - 可迭代对象自动装箱为接口类型，使用动态派发
    - 整数范围直接展开为整数循环
    - 编译期生成vtable
  - **示例**：
[examples/example_046.uya](./examples/example_046.uya)
  - **展开规则**：for循环在编译期展开为while循环
    - **可迭代对象展开（有元素变量，只读）**：
[examples/example_047.uya](./examples/example_047.uya)
    - **可迭代对象展开（有元素变量，可修改）**：
[examples/example_048.uya](./examples/example_048.uya)
      - 注意：
        - 迭代器接口需要提供 `ptr()` 方法返回指向当前元素的指针（类型 `&T`）
        - `item` 是指针类型，需要通过 `*item` 访问和修改元素值
        - 只有可变数组（`var arr`）才能使用此形式，常量数组（`const arr`）使用此形式会编译错误
    - **展开说明**：
      - 可迭代对象：自动装箱为接口，使用迭代器接口进行迭代
      - 整数范围：直接展开为 while 循环
      - 编译器自动识别类型并选择合适的展开方式
      - 所有数组访问都有编译期证明（在当前函数内）

- **`match` 表达式/语句**：模式匹配
  - **语法形式**：`match expr { pattern1 => expr, pattern2 => expr, else => expr }`
  - **作为表达式**：match 可以作为表达式使用，所有分支返回类型必须一致
[examples/example_049.uya](./examples/example_049.uya)
  - **作为语句**：如果所有分支返回 `void`，match 可以作为语句使用
[examples/example_050.uya](./examples/example_050.uya)
  - **支持的模式类型**：
    1. **常量模式**：整数、布尔、错误类型常量
[examples/example_051.uya](./examples/example_051.uya)
    2. **变量绑定模式**：捕获匹配的值
[examples/example_052.uya](./examples/example_052.uya)
    3. **结构体解构**：匹配并解构结构体字段
[examples/example_053.uya](./examples/example_053.uya)
    4. **错误类型匹配**：匹配错误联合类型（支持预定义和运行时错误）
[examples/example_054.uya](./examples/example_054.uya)
    5. **字符串数组匹配**：匹配 `[i8: N]` 数组（字符串插值的结果）
[examples/example_055.uya](./examples/example_055.uya)
       - 编译期常量字符串：如果模式和表达式都是编译期常量，编译器在编译期比较
       - 运行时字符串：如果模式或表达式是运行时值，生成运行时字符串比较代码（调用标准库比较函数）
       - 数组长度检查：不同长度的数组不匹配（编译期检查）
  - **语义规则**：
    1. **表达式 vs 语句**：
       - 作为表达式：match 表达式的类型是所有分支返回类型的统一类型（必须完全一致）
       - 作为语句：如果所有分支返回 `void`，match 可以作为语句使用
       - 上下文决定：编译器根据上下文判断 match 是表达式还是语句
    2. **匹配顺序**：从上到下依次匹配，第一个匹配的分支执行
    3. **变量绑定作用域**：绑定的变量仅在对应的分支内有效
    4. **类型检查**：
       - 所有分支的返回类型必须完全一致（Uya 无隐式转换）
       - 如果作为表达式，所有分支必须返回相同类型
       - 如果作为语句，所有分支必须返回 `void`
    5. **编译期常量匹配**：常量模式在编译期验证，常量越界等错误在编译期捕获
    6. **else 分支**：必须放在最后，捕获所有未匹配的情况
  - **编译期检查**：
    - 常量索引越界：如果 match 的表达式是编译期常量，且所有分支都是常量模式，编译器应验证覆盖范围
    - 类型不匹配：模式类型必须与表达式类型兼容
    - 数组长度匹配：字符串数组 match 时，模式字符串的长度必须与表达式数组长度匹配（编译期检查）
  - **后端实现**：
    - 代码生成：
      - 整数/布尔常量：展开为 if-else 链或跳转表（对于密集整数常量）
      - 编译期常量字符串：编译期比较，直接展开
      - 运行时字符串：生成运行时字符串比较代码（调用标准库比较函数）
      - 结构体解构：展开为字段比较和提取
    - 编译期常量匹配直接展开，无运行时模式匹配引擎
    - 未匹配路径不生成代码
    - 字符串比较：运行时字符串比较使用标准库函数（如 `strcmp` 的等价实现）
  - **示例**：
[examples/example_056.uya](./examples/example_056.uya)

---

## 9 defer 和 errdefer

### 9.1 defer 语句

**语法**：
[examples/defer_errdefer.uya](./examples/defer_errdefer.uya)

**语义**：
- 在当前作用域结束时执行（正常返回或错误返回）
- 执行顺序：LIFO（后声明的先执行）
- 可以出现在函数内的任何位置
- 支持单语句和语句块

**defer 块内禁止控制流语句**：
- ✅ **允许**：表达式、赋值、函数调用、语句块
- ❌ **禁止**：`return`、`break`、`continue` 等控制流语句
- ✅ **替代方案**：使用变量记录状态，在 defer 外处理控制流

这种设计确保：
- **defer 语义清晰**：只做清理，不改变控制流
- **程序行为可预测**：所有返回点显式可见
- **错误处理简单**：不引入嵌套的提前返回

**示例**：
[examples/example_8.uya](./examples/example_8.uya)

### 9.2 errdefer 语句

**语法**：
[examples/errdefer_statement.uya](./examples/errdefer_statement.uya)

**语义**：
- 仅在函数返回错误时执行
- 执行顺序：LIFO（后声明的先执行）
- 必须在可能返回错误的函数中使用（返回类型为 `!T`）
- 用于错误情况下的资源清理

**errdefer 块内禁止控制流语句**：（与 defer 相同）
- ✅ **允许**：表达式、赋值、函数调用、语句块
- ❌ **禁止**：`return`、`break`、`continue` 等控制流语句
- ✅ **替代方案**：使用变量记录状态，在 errdefer 外处理控制流

**示例**：
[examples/example_9.uya](./examples/example_9.uya)

### 9.3 执行顺序

**正常返回时**：
1. `defer`（LIFO 顺序，后声明的先执行）
2. `drop`（逆序，变量声明的逆序）

**错误返回时**：
1. `errdefer`（LIFO 顺序，后声明的先执行）
2. `defer`（LIFO 顺序，后声明的先执行）
3. `drop`（逆序，变量声明的逆序）

**重要规则**：
- **defer 先于 drop 执行**：defer 中的代码可以访问作用域内的变量（变量尚未 drop）
- **defer 中不会触发 drop**：defer 执行时，变量仍然有效，不会自动 drop
- **变量在 defer 执行完成后才 drop**

**示例**：
[examples/example_10.uya](./examples/example_10.uya)

### 9.4 与 RAII/drop 的关系

- defer/errdefer **复用 drop 的代码插入机制**
- 在同一个作用域退出点，统一处理所有清理逻辑
- 编译器维护清理代码列表，按顺序执行

**使用场景**：
- **drop**：基于类型的自动清理（文件关闭、内存释放等）
- **defer**：补充清理逻辑（日志记录、状态更新等）
- **errdefer**：错误情况下的特殊清理（回滚操作、错误日志等）

**完整示例**：
[examples/process_file.uya](./examples/process_file.uya)

### 9.5 作用域规则

- defer/errdefer 绑定到当前作用域
- 嵌套作用域有独立的 defer/errdefer 栈
- 内层作用域的 defer 先于外层执行

**示例**：
[examples/nested_example.uya](./examples/nested_example.uya)

---

## 10 运算符与优先级

| 级别 | 运算符 | 结合性 | 说明 |
|----|--------|--------|------|
| 1  | `()` `.` `[]` `[start:end]` | 左 | 调用、字段、下标、切片 |
| 2  | `-` `!` `~` (一元) | 右 | 负号、逻辑非、按位取反 |
| 3  | `* / %` `*|` `*%` | 左 | 乘、除、取模、饱和乘法、包装乘法 |
| 4  | `+ -` `+|` `-|` `+%` `-%` | 左 | 加、减、饱和加法、饱和减法、包装加法、包装减法 |
| 5  | `<< >>` | 左 | 左移、右移 |
| 6  | `< > <= >=` | 左 | 比较 |
| 7  | `== !=` | 左 | 相等性 |
| 8  | `&` | 左 | 按位与 |
| 9  | `^` | 左 | 按位异或 |
| 10 | `\|` | 左 | 按位或 |
| 11 | `&&` | 左 | 逻辑与 |
| 12 | `\|\|` | 左 | 逻辑或 |
| 13 | `=` | 右 | 赋值（最低优先级）|

- 无隐式转换；两边类型必须完全一致。
- 赋值运算符 `=` 仅用于 `var` 变量。
- **饱和运算符**：
  - `+|`：饱和加法，溢出时返回类型的最大值或最小值（上溢返回最大值，下溢返回最小值）
  - `-|`：饱和减法，溢出时返回类型的最大值或最小值
  - `*|`：饱和乘法，溢出时返回类型的最大值或最小值
  - 操作数必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - 饱和运算符的操作数类型必须完全一致
  - 示例：
[examples/example_064.uya](./examples/example_064.uya)
- **包装运算符**：
  - `+%`：包装加法，溢出时返回包装后的值（模运算）
  - `-%`：包装减法，溢出时返回包装后的值（模运算）
  - `*%`：包装乘法，溢出时返回包装后的值（模运算）
  - 操作数必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - 包装运算符的操作数类型必须完全一致
  - 示例：
[examples/example_065.uya](./examples/example_065.uya)
- **位运算符**：
  - `&`：按位与，两个操作数都必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - `|`：按位或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `^`：按位异或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `~`：按位取反（一元），操作数必须是整数类型，结果类型与操作数相同
  - `<<`：左移，左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - `>>`：右移（算术右移，对于有符号数保留符号位），左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - 位运算符的操作数类型必须完全一致（移位运算符的右操作数除外，必须是 `i32`）
  - 示例：
[examples/example_066.uya](./examples/example_066.uya)
- **不支持的运算符**：
  - 自增/自减：`++`, `--`（必须使用 `i = i + 1;` 形式）
  - 复合赋值：`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`（必须使用完整形式）
  - 三元运算符：`?:`（必须使用 `if-else` 语句）
- **类型比较规则**：
  - 基础类型（整数、浮点、布尔）支持 `==` 和 `!=` 比较
  - 浮点数比较使用 IEEE 754 标准，进行精确比较（可能受浮点精度影响）
  - 错误类型支持 `==` 和 `!=` 比较
  - 不支持结构体的 `==` 和 `!=` 比较（未来支持）
  - 不支持数组的 `==` 和 `!=` 比较（未来支持）
- **表达式求值顺序**：从左到右（left-to-right）
  - 函数参数求值顺序：从左到右
  - 数组字面量元素表达式求值顺序：从左到右
  - 结构体字面量字段表达式求值顺序：从左到右（按字面量中的顺序）
  - 副作用（赋值）立即生效
- **逻辑运算符短路求值**：
  - `expr1 && expr2`：如果 `expr1` 为 `false`，不计算 `expr2`
  - `expr1 || expr2`：如果 `expr1` 为 `true`，不计算 `expr2`
- **整数溢出和除零**（强制编译期证明）：
  - **整数溢出**：
  - 常量运算溢出 → **编译错误**（编译期直接检查）
  - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
  - 证明失败 → **编译错误并给出修改建议**
  - 编译期证明安全（在当前函数内），证明失败则报编译错误并给出修改建议
  - **除零错误**：
    - 常量除零 → **编译错误**
    - 变量 → 必须证明 `y != 0`，证明失败 → **编译错误并给出修改建议**
    - 编译期证明安全（在当前函数内），证明失败则报编译错误并给出修改建议
  
  **溢出检查示例**：
[examples/add_safe.uya](./examples/add_safe.uya)

**内存安全强制**：

所有 UB 场景必须被编译期证明为安全，证明失败则报编译错误并给出修改建议：

1. **数组越界访问**：
   - 常量索引越界 → **编译错误**
   - 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误并给出修改建议**

2. **整数溢出**：
   - 常量运算溢出 → **编译错误**（编译期直接检查）
   - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
   - 证明失败 → **编译错误并给出修改建议**
   - 溢出检查模式：
     - 加法上溢：`a > 0 && b > 0 && a > MAX - b`
     - 加法下溢：`a < 0 && b < 0 && a < MIN - b`
     - 乘法上溢：`a > 0 && b > 0 && a > MAX / b`

3. **除零错误**：
   - 常量除零 → **编译错误**
   - 变量 → 必须证明 `y != 0`，证明失败 → **编译错误并给出修改建议**

4. **使用未初始化内存**：
   - 必须证明「首次使用前已赋值」或「前序有赋值路径」，证明失败 → **编译错误并给出修改建议**

5. **空指针解引用**：
   - 必须证明 `ptr != null` 或前序有 `if ptr == null { return error; }`，证明失败 → **编译错误并给出修改建议**

**安全策略**：
- **编译期证明**：所有 UB 必须被编译器证明为安全
- **证明失败处理**：证明失败则报编译错误并给出友好的修改建议
- **编译期证明**：编译器在当前函数内验证安全性，证明失败则报编译错误并给出修改建议
- **常量错误**：编译期常量错误仍然直接报错（如常量溢出、常量除零）
- **优先级示例**：
[examples/example_068.uya](./examples/example_068.uya)

---

## 11 类型转换

### 11.1 转换语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#51-转换语法)

Uya 提供两种类型转换语法：

1. **安全转换 `as`**：只允许无精度损失的转换，编译期检查
2. **强转 `as!`**：允许所有转换，包括可能有精度损失的，返回错误联合类型 `!T`

### 11.2 安全转换（as）

安全转换只允许无精度损失的转换，可能损失精度的转换会编译错误：

[examples/safe_cast_as.uya](./examples/safe_cast_as.uya)

### 11.3 强转（as!）

当确实需要进行可能有精度损失的转换时，使用 `as!` 强转语法。`as!` 返回错误联合类型 `!T`，需要使用 `try` 或 `catch` 处理可能的错误：

[examples/force_cast_as.uya](./examples/force_cast_as.uya)

`as!` 可能返回的错误类型：
- `error.PrecisionLoss`：转换导致精度损失
- `error.OverflowError`：转换导致数值溢出
- `error.InvalidConversion`：无效的类型转换（如 NaN 转换为整数）

### 11.4 转换规则表

| 源类型 | 目标类型 | `as` | `as!` | 说明 |
|--------|---------|------|-------|------|
| `f32` | `f64` | ✅ | ✅ | 扩展精度，无损失 |
| `f64` | `f32` | ❌ | ✅ | 可能损失精度 |
| `i32` | `f64` | ✅ | ✅ | f64 可精确表示所有 i32 |
| `i32` | `f32` | ❌ | ✅ | 超出 ±16,777,216 可能损失精度 |
| `i64` | `f64` | ❌ | ✅ | 大整数可能损失精度 |
| `i64` | `f32` | ❌ | ✅ | 可能损失精度 |
| `i8` | `f32` | ✅ | ✅ | 小整数，无损失 |
| `i16` | `f32` | ✅ | ✅ | 小整数，无损失 |
| `f64` | `i32` | ❌ | ✅ | 截断，可能损失 |
| `f32` | `i32` | ❌ | ✅ | 截断，可能损失 |
| `f64` | `i64` | ❌ | ✅ | 截断，可能损失 |
| `f32` | `i64` | ❌ | ✅ | 截断，可能损失 |
| `&T` | `*T` | ✅ | ✅ | 同类型指针互相转换，无精度损失 |
| `*T` | `&T` | ✅ | ✅ | 同类型指针互相转换，无精度损失 |
| `&const T` | `*const T` | ✅ | ✅ | 只读指针转换为 FFI 只读指针，无精度损失 |
| `*const T` | `&const T` | ✅ | ✅ | FFI 只读指针转换为只读指针，无精度损失 |
| `&T` | `&const T` | ✅ | ✅ | 可变指针隐式转换为只读指针（放宽约束，安全） |
| `&T` | `*const T` | ✅ | ✅ | 可变指针转换为 FFI 只读指针（放宽约束，安全） |
| `&void` | `&T` | ✅ | ✅ | 通用指针转换为具体指针类型（类型擦除恢复） |
| `&T` | `&void` | ✅ | ✅ | 具体指针转换为通用指针类型（类型擦除） |
| `&const void` | `&const T` | ✅ | ✅ | 通用只读指针转换为具体只读指针类型（类型擦除恢复） |
| `&const T` | `&const void` | ✅ | ✅ | 具体只读指针转换为通用只读指针类型（类型擦除） |

**指针类型转换说明**（0.42 更新）：
- **`&T as *T`**：Uya 可变指针转换为 FFI 可变指针类型
  - ✅ 使用 `as` 进行安全转换（无精度损失，编译期检查）
  - 仅在 FFI 函数调用时使用
  - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `&buffer[0] as *byte`
- **`&const T as *const T`**：Uya 只读指针转换为 FFI 只读指针类型（0.42 新增）
  - ✅ 使用 `as` 进行安全转换（无精度损失，编译期检查）
  - 用于标准库函数的只读参数
  - 示例：`extern strlen(s: *const byte) usize;` 调用时使用 `str as *const byte`
- **`&T` → `&const T`**：可变指针隐式转换为只读指针（0.42 新增）
  - ✅ 隐式转换（放宽约束，安全）
  - 无需 `as` 关键字，编译器自动转换
  - 示例：`var s: &byte = ...; const len = strlen(s);`（`&byte` 自动转换为 `&const byte`）
- **`&T` → `*const T`**：可变指针转换为 FFI 只读指针（0.42 新增）
  - ✅ 使用 `as` 进行安全转换（放宽约束，安全）
  - 示例：`var s: &byte = ...; const len = strlen(s as *const byte);`
- **`&T` ↔ `*T`**：同类型指针可通过 `as` 互相转换，无精度损失
- **`&const T` ↔ `*const T`**：同类型只读指针可通过 `as` 互相转换，无精度损失（0.42 新增）
- **`&void ↔ &T`**：通用指针类型与具体指针类型之间的转换
  - ✅ `&void as &T`：通用指针转换为具体指针类型（类型擦除恢复）
  - ✅ `&T as &void`：具体指针转换为通用指针类型（类型擦除）
  - 示例：`var ptr: &void = &buffer as &void; var byte_ptr: &byte = ptr as &byte;`
- **`&const void ↔ &const T`**：通用只读指针类型与具体只读指针类型之间的转换（0.42 新增）
  - ✅ `&const void as &const T`：通用只读指针转换为具体只读指针类型（类型擦除恢复）
  - ✅ `&const T as &const void`：具体只读指针转换为通用只读指针类型（类型擦除）

**精度说明**：
- `f32` 可以精确表示的整数范围：-2^24 到 2^24（-16,777,216 到 16,777,216）
- `f64` 可以精确表示的整数范围：-2^53 到 2^53（-9,007,199,254,740,992 到 9,007,199,254,740,992）
- 超出这些范围的整数转换为浮点数时可能损失精度

### 11.5 编译期常量转换

[examples/const_cast.uya](./examples/const_cast.uya)

### 11.6 错误信息示例

[examples/error_message_example.uya](./examples/error_message_example.uya)

### 11.7 设计哲学

- **默认安全**：普通 `as` 转换只允许无精度损失的转换，防止意外精度损失
- **显式强转**：`as!` 语法明确表示程序员知道可能有精度损失，意图清晰
- **安全强转**：`as!` 返回错误联合类型 `!T`，强制程序员处理可能的转换错误
- **编译期证明**：对于编译期可证明安全的转换（在当前函数内），生成单条机器指令，无错误检查
- **编译期检查**：转换安全性在编译期验证，失败即编译错误；可能有损失的转换在运行时检查

### 11.8 代码生成

#### 编译期可证明安全的转换（在当前函数内）
[examples/codegen_example.uya](./examples/codegen_example.uya)

#### 需要运行时检查的转换
[examples/convert.uya](./examples/convert.uya)

---

## 12 内存模型 & RAII

1. 编译期为每个类型 `T` 生成 `drop(T)`（空函数或用户自定义）。  
2. 离开作用域时按字段逆序插入 `drop` 调用。  
3. **递归 drop 规则**：先 drop 字段，再 drop 外层结构体；字段按声明逆序 drop。
4. **数组 drop 规则**：
   - 数组元素按索引逆序 drop（`arr[N-1]`, `arr[N-2]`, ..., `arr[0]`）
   - 然后 drop 数组本身（数组本身的 drop 是空函数，但会调用元素的 drop）
   - 如果数组元素类型有自定义 drop，会调用元素的 drop；如果元素类型是基本类型，drop 是空函数
5. **用户自定义 drop**：`fn drop(self: T) void { ... }`
   - **定义位置**：只能在**结构体内部**或**方法块**中定义，禁止顶层 `fn drop(self: T) void`（与不引入函数重载的设计一致）。
   - 允许用户为自定义类型定义清理逻辑，实现真正的 RAII 模式（文件自动关闭、内存自动释放等）。
   - 每个类型只能有一个 drop 函数。
   - 参数必须是 `self: T`（按值传递），返回类型必须是 `void`。
   - 递归调用：结构体的 drop 会先调用字段的 drop，再调用自身的 drop。

**drop 使用示例**：

[examples/point.uya](./examples/point.uya)

**用户自定义 drop 示例**：

[examples/file_2.uya](./examples/file_2.uya)

**drop 使用示例（基本类型和结构体）**：

[examples/example_basic.uya](./examples/example_basic.uya)

**重要说明**：
- `drop` 是**自动调用**的，无需手动调用
- 对于基本类型（`i32`, `f64`, `bool` 等），`drop` 是空函数，无运行时开销
- 用户可以为自定义类型定义 `drop` 函数，实现 RAII 模式
- 编译器自动插入 drop 调用，确保资源正确释放

**未来版本特性**：
- drop 标记：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能

---

## 12.5 移动语义

### 12.5.1 设计目标

- **避免不必要的拷贝**：结构体赋值时转移所有权，而非复制
- **编译期所有权转移**：移动操作在编译期完成
- **自动移动，无需显式语法**：编译器自动识别移动场景
- **与 RAII 完美配合**：移动后只有目标对象调用 drop，防止 double free
- **防止悬垂指针**：存在活跃指针时禁止移动，确保内存安全

### 12.5.2 移动语义规则

移动语义是 Uya 语言的核心机制，用于避免不必要的拷贝并保证资源安全：

1. **移动语义适用于结构体类型**：基本类型使用值语义（复制），结构体使用移动语义（转移所有权）
2. **自动移动**：编译器自动识别移动场景，无需显式语法
3. **编译期检查**：所有移动相关的检查在编译期完成（在当前函数内）
4. **严格检查机制**：存在活跃指针时禁止移动，防止悬垂指针

### 12.5.3 自动移动场景

以下场景会自动触发移动语义：

1. **赋值操作**：`const x: Struct = y;`（`y` 的所有权转移给 `x`）
2. **函数参数传递**：按值传递结构体参数时，所有权转移给函数参数
   - **例外**：方法调用 `obj.method()` 不会移动 `obj`，调用时自动传递指针（`&obj`），确保方法调用后原对象仍然可用
   - **推荐**：方法签名使用 `self: &StructName`（指针），更显式、语义一致
3. **函数返回值**：返回结构体时，所有权转移给调用者
4. **结构体字段初始化**：`Container{ field: struct_value }`（`struct_value` 的所有权转移给字段）
5. **数组元素赋值**：`arr[i] = struct_value`（`struct_value` 的所有权转移给数组元素）

### 12.5.4 移动后的变量状态

- 变量被移动后变为"已移动"状态
- 已移动的变量不能再次使用（编译错误）
- 编译器在编译期检查移动后使用错误
- 移动不会调用源对象的 drop，只有目标对象离开作用域时才调用 drop

**示例**：

[examples/file_3.uya](./examples/file_3.uya)

### 12.5.5 指针与移动语义的交互

**核心规则**：如果变量存在指向它的活跃指针（`&var`），则不能移动该变量。

- **检查时机**：在移动操作前，编译器检查是否存在指向该变量的活跃指针
- **活跃指针定义**：指针在作用域内（包括外层作用域），且可能被使用
- **检查范围**：编译器检查**所有作用域层级**（包括外层作用域），只要存在指向变量的指针，就不能移动
- **错误信息**：`错误：变量 'var' 存在活跃指针，不能移动`
- **设计原则**：采用严格检查，避免跨作用域的复杂情况和悬垂指针问题

**示例：存在活跃指针时禁止移动**：

[examples/example_11.uya](./examples/example_11.uya)

**正确的使用方式：指针离开作用域后再移动**：

[examples/example_12.uya](./examples/example_12.uya)

**错误的移动：跨作用域指针阻止移动**：

[examples/example_13.uya](./examples/example_13.uya)

**使用指针参数，不移动对象**：

[examples/process_1.uya](./examples/process_1.uya)

**函数参数指针的活跃性**：

[examples/process_2.uya](./examples/process_2.uya)

### 12.5.6 条件分支和循环中的移动

**条件分支中的移动检查**：

同一变量在不同分支中不能多次移动。编译器需要路径敏感分析，确保变量在所有可能执行路径中只移动一次。

[examples/example_14.uya](./examples/example_14.uya)

**循环中的移动检查**：

循环中的变量不能移动，因为循环可能执行多次，导致多次移动同一个变量。

[examples/example_15.uya](./examples/example_15.uya)

### 12.5.7 数组和接口值的移动

**数组移动语义**：

数组本身使用值语义（复制），但数组元素如果是结构体，则使用移动语义。

[examples/example_16.uya](./examples/example_16.uya)

**接口值移动**：

接口值是16字节结构体（vtable指针+数据指针），移动接口值只是复制16字节，不涉及底层数据的移动。底层数据的生命周期仍然由原始对象决定。

[examples/example_17.uya](./examples/example_17.uya)

### 12.5.8 嵌套结构体和字段访问

**嵌套结构体移动**：

移动外层结构体时，所有字段（包括嵌套结构体字段）一起移动。

[examples/inner_1.uya](./examples/inner_1.uya)

**字段访问与指针的区别**：

- 直接字段访问（`struct.field`）不是指针，可以移动
- 通过指针访问（`ptr.field`）意味着存在指向对象的指针，不能移动
- **自动解引用**：`ptr.field` 是语法糖，等价于 `(*ptr).field`（当 `ptr` 是指向结构体的指针类型时）
- **字段赋值**：支持 `ptr.field = value`，自动解引用后赋值（等价于 `(*ptr).field = value`）

[examples/container.uya](./examples/container.uya)

### 12.5.9 与 drop 的关系

移动语义与 RAII 和 drop 机制完美配合：

- **移动不会调用源对象的 drop**：移动只是转移所有权，不触发资源释放
- **只有目标对象离开作用域时才调用 drop**：资源在目标对象离开作用域时释放
- **防止 double free 和资源泄漏**：确保每个资源只被释放一次

**示例：堆内存安全移动（解决 double free 问题）**：

[examples/heapbuffer.uya](./examples/heapbuffer.uya)

### 12.5.10 完整示例

**基本移动示例**：

[examples/file_4.uya](./examples/file_4.uya)

**函数参数移动**：

[examples/process_file_1.uya](./examples/process_file_1.uya)

**返回值移动**：

[examples/create_file.uya](./examples/create_file.uya)

### 12.5.11 限制说明

- **移动语义仅适用于结构体类型**：基本类型始终使用值语义（复制）
- **移动后变量不能再次使用**：编译器在编译期检查移动后使用错误
- **存在活跃指针时不能移动**：检查所有作用域层级，只要存在指向变量的指针就不能移动
- **条件分支中的移动**：同一变量在不同分支中不能多次移动（编译器路径敏感分析，确保只移动一次）
- **循环中的移动**：循环中的变量不能移动（因为可能执行多次，导致多次移动）
- **数组移动**：数组本身使用值语义（复制），但数组元素如果是结构体，则使用移动语义
- **接口值移动**：接口值移动只复制16字节（vtable指针+数据指针），不移动底层数据
- **嵌套结构体移动**：移动外层结构体时，所有字段（包括嵌套结构体字段）一起移动
- **字段访问与指针**：直接字段访问（`struct.field`）不是指针，可以移动；通过指针访问（`ptr.field`）意味着存在指针，不能移动
- **函数参数指针**：传递指针给函数后，原指针变量仍然被认为是"活跃指针"，函数返回后仍然阻止移动
- **编译器在编译期检查**：所有移动相关的检查在编译期完成（在当前函数内）
- **采用严格检查机制**：避免悬垂指针问题，规则简单明确

### 12.5.12 一句话总结

> **Uya 移动语义 = 结构体自动移动 + 指针严格检查 + 编译期验证**；  
> **防止 double free 和悬垂指针，与 RAII 完美配合**；  
> **只移动结构体，基本类型值语义，数组值语义但元素可移动**。

---


## 13 原子操作

### 13.1 设计目标

- **关键字 `atomic T`** → 语言层原子类型
- **读/写/复合赋值 = 自动原子指令** → 零运行时锁
- **编译期证明（在当前函数内）**
- **失败 = 类型非 `atomic T` → 编译错误**

### 13.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#61-原子类型)

[examples/counter.uya](./examples/counter.uya)

### 13.3 语义

| 操作 | 自动生成 | 说明 |
|---|---|---|
| `const v = cnt;` | 原子 load | 读取原子类型值 |
| `cnt = val;` | 原子 store | 写入原子类型值 |
| `cnt += val;` | 原子 fetch_add | 复合赋值自动原子化（硬件支持） |
| `cnt -= val;` | 原子 fetch_sub | 复合赋值自动原子化（硬件支持） |
| `cnt *= val;` | 原子 fetch_mul | 复合赋值自动原子化（**软件实现**，使用 compare-and-swap 循环） |
| `cnt /= val;` | 原子 fetch_div | 复合赋值自动原子化（**软件实现**，使用 compare-and-swap 循环） |
| `cnt %= val;` | 原子 fetch_mod | 复合赋值自动原子化（**软件实现**，使用 compare-and-swap 循环） |

**硬件支持说明**：
- **硬件直接支持**：`+=`、`-=`（x86-64、ARM64 等主流架构直接支持）
- **软件实现**：`*=`、`/=`、`%=` 等操作需要软件实现（使用 compare-and-swap 循环，所有架构都保证原子性）
- **性能说明**：所有原子操作都保证原子性，软件实现的操作（`*=`、`/=`、`%=`）使用 compare-and-swap 循环实现，可能有更高的性能开销，但行为完全可预测

### 13.4 内存序（Memory Ordering）

- **默认内存序**：所有原子操作使用 **sequentially consistent (seq_cst)** 内存序
  - 保证所有线程看到相同的操作顺序
  - 提供最强的内存同步保证
  - 提供最强的内存同步保证
- **限制**：不支持自定义内存序（如 acquire、release、relaxed）
  - 未来可能支持显式内存序参数
- **性能考虑**：seq_cst 可能比 relaxed 内存序有更高的性能开销，但提供最强的安全性保证

### 13.5 限制

- **类型必须是 `atomic T`**：非原子类型进行原子操作 → 编译错误
- **零新符号**：无需额外的语法标记
- **自动原子指令**：所有原子操作直接生成硬件原子指令

### 13.6 一句话总结

> **Uya 原子操作 = `atomic T` 关键字 + 自动原子指令**；  
> **读/写/复合赋值自动原子化，零运行时锁。**

---

## 14 内存安全

### 14.1 设计目标

- **所有 UB 必须被编译期证明为安全**（在当前函数内）
- **证明失败则报编译错误并给出修改建议**
- **证明范围**：仅限当前函数内的代码路径
- **函数返回值**：编译器不能自动证明函数返回值的安全性，调用者必须显式处理
- **跨函数调用**：需要显式处理返回值（使用 `try`、`catch` 或显式检查）
- **证明失败机制**：编译器无法完成证明时，报编译错误并给出友好的修改建议

### 14.2 内存安全强制表

| UB 场景 | 必须证明为安全 | 失败结果 |
|---|---|---|
| 数组越界 | 常量索引越界 → 编译错误；变量索引 → 证明 `i >= 0 && i < len` | **常量错误：编译错误；变量证明失败：编译错误并给出修改建议** |
| 空指针解引用 | 证明 `ptr != null` 或前序有 `if ptr == null { return error; }` | **常量错误：编译错误；变量证明失败：编译错误并给出修改建议** |
| 使用未初始化 | 证明「首次使用前已赋值」或「前序有赋值路径」 | **常量错误：编译错误；变量证明失败：编译错误并给出修改建议** |
| 整数溢出 | 常量溢出 → 编译错误；变量 → 显式检查或编译器证明无溢出 | **常量错误：编译错误；变量证明失败：编译错误并给出修改建议** |
| 除零错误 | 常量除零 → 编译错误；变量 → 证明 `y != 0` | **常量错误：编译错误；变量证明失败：编译错误并给出修改建议** |

### 14.3 证明机制

Uya 语言的编译期证明机制采用**分层验证策略**，**证明范围仅限当前函数内**：

1. **常量折叠**（最简单）：
   - 编译期常量直接检查，溢出/越界立即报错
   - 示例：`const x: i32 = 2147483647 + 1;` → 编译错误

2. **路径敏感分析**（中等复杂度）：
   - 编译器在当前函数内跟踪所有代码路径，分析变量状态
   - 通过条件分支建立约束条件
   - 示例：`if i < 0 || i >= 10 { return error; }` 后，编译器知道 `i >= 0 && i < 10`

3. **符号执行**（复杂场景）：
   - 对于复杂表达式，编译器在当前函数内使用符号执行技术
   - 建立约束系统，验证数学关系
   - 示例：`if a > 0 && b > 0 && a > @max - b { return error; }` 后，证明 `a + b <= @max`

4. **函数返回值证明**：
   - **函数内部**：编译器可以证明返回值的安全性（在 `return` 语句之前）
   - **调用者**：编译器不能自动证明函数返回值的安全性，需要显式处理
   - **返回值类型决定处理方式**：
     - 错误联合类型 `!T`：必须使用 `try` 或 `catch` 处理
     - 指针类型 `&T`：调用者需要显式检查（如 `if ptr == null { return error; }`）
     - 数组/切片：调用者需要显式检查边界（如果使用返回值进行索引访问）
   - 示例：`const result: i32 = try divide(10, 2);` 显式处理可能的错误
   - 示例：`const ptr: &i32 = get_pointer(); if ptr == null { return error; }` 显式检查空指针

5. **跨函数调用处理**：
   - 函数调用的返回值需要显式处理（使用 `try`、`catch` 或显式检查）
   - 编译器不跨函数进行证明，确保证明范围明确
   - 调用者必须信任函数签名，但需要显式处理返回值

5. **证明失败处理**：
   - **常量错误**：编译期常量直接检查，溢出/越界立即报错（如 `const x: i32 = 2147483647 + 1;` → 编译错误）
   - **变量证明失败**：编译器无法完成证明时，报编译错误并给出友好的修改建议
   - **修改建议**：编译器会提示需要添加的安全检查代码（如 `建议：添加边界检查 if i >= 0 && i < len { ... }`）
   - **建议**：使用 `try` 关键字、饱和运算符（`+|`, `-|`, `*|`）或包装运算符（`+%`, `-%`, `*%`）简化证明

**实现说明**：
- **证明范围**：仅限当前函数内的代码路径
- **证明失败机制**：编译器无法完成证明时，报编译错误并给出友好的修改建议
- 优先实现**常量折叠**和**路径敏感分析**
- 复杂符号执行可能失败，此时编译器给出修改建议
- **跨函数调用必须显式处理**，编译器不进行跨函数证明

### 14.4 示例

[examples/safe_access_2.uya](./examples/safe_access_2.uya)

**整数溢出处理示例**：

[examples/add_safe_1.uya](./examples/add_safe_1.uya)

**溢出检查规则**：

1. **常量运算**：
   - 编译期常量运算直接检查，溢出即编译错误
   - 示例：
     - `const x: i32 = 2147483647 + 1;` → 编译错误（i32 溢出）
     - `const y: i64 = 9223372036854775807 + 1;` → 编译错误（i64 溢出）

2. **`try` 关键字和饱和运算符（最推荐）**：
   - 使用 `try` 关键字进行溢出检查，或使用饱和运算符 `+|`, `-|`, `*|` 进行溢出处理
   - 一行代码替代多行溢出检查，代码简洁
   - 编译期展开，与手写代码性能相同
   - 示例：
[examples/add_safe_2.uya](./examples/add_safe_2.uya)
   - **`try` 关键字支持的操作**：
     - `try a + b`（加法溢出检查）
     - `try a - b`（减法溢出检查）
     - `try a * b`（乘法溢出检查）
   - **饱和运算符**：
     - `a +| b`（饱和加法）
     - `a -| b`（饱和减法）
     - `a *| b`（饱和乘法）
   - **包装运算符**：
     - `a +% b`（包装加法）
     - `a -% b`（包装减法）
     - `a *% b`（包装乘法）
   - **支持的类型**：`i8`, `i16`, `i32`, `i64`
   - **编译期展开**：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码

3. **@max/@min 内置函数（备选方式）**：
   - 使用 `@max` 和 `@min` 内置函数访问类型的极值常量
   - `@max` 和 `@min` 是编译器内置的（以 `@` 开头），编译器从上下文类型自动推断极值类型
   - 适用于需要自定义溢出检查逻辑的场景
   - 示例：
[examples/example_098.uya](./examples/example_098.uya)
   - **类型推断规则**：
     - 常量定义：从类型注解推断，如 `const MAX: i32 = @max;` → `@max i32`
     - 表达式上下文：从操作数类型推断，如 `a > @max - b`（a 和 b 是 i32）→ `@max i32`
     - 函数返回：从返回类型推断，如 `return @max;`（函数返回 i32）→ `@max i32`
   - **极值对应表**：
     - `@max`（i32 上下文）：2147483647
     - `@min`（i32 上下文）：-2147483648
     - `@max`（i64 上下文）：9223372036854775807
     - `@min`（i64 上下文）：-9223372036854775808
   - **编译期常量**：这些表达式在编译期求值

4. **变量运算**：
   - 必须显式检查溢出条件，或编译器能够证明无溢出
   - 证明失败 → 编译错误并给出修改建议
   - 显式检查后，编译器可以证明后续运算安全
   - **溢出处理方式**：
     - **返回错误**：使用错误联合类型 `!T`，溢出时返回 `error.Overflow`
     - **返回饱和值**：溢出时返回类型的最大值或最小值（饱和算术）
     - **返回包装值**：溢出时返回包装后的值（包装算术，需要显式计算）

5. **溢出检查模式**（适用于所有整数类型：i8, i16, i32, i64，手动检查时使用）：
   - **加法上溢**：`a > 0 && b > 0 && a > MAX - b`
   - **加法下溢**：`a < 0 && b < 0 && a < MIN - b`
   - **乘法上溢**：`a > 0 && b > 0 && a > MAX / b`
   - **乘法下溢**：需要检查所有符号组合（正×负、负×正、负×负）
   - **类型范围**：
     - `i32`：MAX = 2,147,483,647，MIN = -2,147,483,648
     - `i64`：MAX = 9,223,372,036,854,775,807，MIN = -9,223,372,036,854,775,808
   - **示例**：
     - i32 加法上溢检查：`if a > 0 && b > 0 && a > 2147483647 - b { return error.Overflow; }`
     - i64 加法上溢检查：`if a > 0 && b > 0 && a > 9223372036854775807 - b { return error.Overflow; }`
   - **乘法下溢**：需要检查所有符号组合

6. **编译器证明**：
   - 如果编译器可以在当前函数内通过路径敏感分析证明无溢出，则编译通过
   - 例如：已知 `a < 1000 && b < 1000`，可以证明 `a + b < 2000`，无溢出
   - 如果证明失败，编译器报编译错误并给出修改建议

### 14.5 证明场景分类与优化

#### 14.5.1 需要显式 `if` 判断的场景

以下场景需要开发者编写显式的 `if` 检查，编译器验证检查的充分性：

| 场景 | 需要的证明 | 示例 |
|------|----------|------|
| 变量数组索引 | `i >= 0 && i < len` | `if i < @len(arr) { arr[i] }` |
| 指针解引用 | `ptr != null` | `if ptr != null { *ptr }` |
| 变量除法 | `divisor != 0` | `if d != 0 { n / d }` |
| 变量运算溢出 | 无溢出条件 | `if a <= @max - b { a + b }` |

**证明失败处理**：
- 如果开发者没有编写必要的 `if` 检查，编译器报编译错误并给出修改建议
- 示例：`arr[i]` 没有边界检查 → 编译错误："需要证明索引安全，建议添加 `if i >= 0 && i < @len(arr) { ... }`"

#### 14.5.2 不需要显式 `if` 判断的场景

以下场景编译器自动保证安全，开发者无需编写 `if` 检查：

| 场景 | 安全机制 | 示例 |
|------|----------|------|
| 常量数组索引 | 编译期直接验证 | `const arr = [1, 2, 3]; arr[0]` ✓ |
| 循环变量范围 | 编译器自动推导 | `for 0..@len(arr) \|i\| { arr[i] }` ✓ |
| 饱和运算符 | 溢出自动饱和 | `a +\| b` 无需检查溢出 |
| 包装运算符 | 溢出自动包装 | `a +% b` 无需检查溢出 |
| `try` 关键字 | 自动返回错误 | `try a + b` 返回 `!T` |

**循环变量范围推导**：
```uya
var arr: [i32: 10] = ...;
for 0..@len(arr) |i| {   // 编译器知道 i ∈ [0, 10)
    arr[i];               // 安全，无需边界检查
}
```

#### 14.5.3 编译器优化规则

对于开发者编写的 `if` 检查，编译器根据证明结果优化代码：

| 证明结果 | 生成的代码 |
|----------|-----------|
| 证明条件为真 | 消除 `if`，直接执行 then 块 |
| 证明条件为假 | 消除 then 块（死代码） |
| 无法证明 | 保留 `if` 运行时检查 |

**优化示例**：
```uya
fn safe_access(arr: [i32: 10], i: i32) !i32 {
    if i < 0 || i >= 10 {     // 编译器证明：此条件正确
        return error.OutOfBounds;
    }
    // 此时编译器知道 i ∈ [0, 10)
    return arr[i];            // 优化：消除边界检查
}
```

#### 14.5.4 错误联合类型 `!T`

对于可能失败的操作，使用错误联合类型 `!T` 显式处理错误：

```uya
fn safe_divide(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;
    }
    return a / b;  // 安全：编译器证明 b != 0
}

fn caller() void {
    const result: i32 = try safe_divide(10, 2);  // 显式处理错误
}
```

### 14.6 一句话总结

> **Uya 内存安全 = 所有 UB 必须被编译期证明为安全（在当前函数内）→ 证明失败则报编译错误并给出修改建议**；
> **证明范围仅限当前函数，跨函数调用需要显式处理。常量错误仍然直接报错。**

---

## 15 并发安全

### 15.1 设计目标

- **原子类型 `atomic T`** → 语言层原子
- **读/写/复合赋值 = 自动原子指令** → **零运行时锁**
- **数据竞争 = 零**（所有原子操作自动序列化）
- **零新符号**：无需额外的语法标记

### 15.2 并发安全机制

| 特性 | 实现 | 说明 |
|---|---|---|
| 原子类型 | `atomic T` 关键字 | 语言层原子类型 |
| 原子操作 | 自动生成原子指令 | 读/写/复合赋值自动原子化 |
| 数据竞争 | 零（编译期保证） | 所有原子操作自动序列化 |
| 运行时锁 | 零 | 无锁编程，直接硬件原子指令 |

### 15.3 示例

[examples/counter_1.uya](./examples/counter_1.uya)

### 15.4 限制

- **只靠原子类型**：并发安全只靠 `atomic T` + 自动原子指令

### 15.5 一句话总结

> **Uya 并发安全 = 原子类型 + 自动原子指令**；  
> **零数据竞争，零运行时锁。**

---

## 16 标准库

所有内置函数均以 `@` 开头，编译期展开，无需导入或声明。

| 内置函数 | 签名 | 说明 |
|----------|------|------|
| `@len` | `fn @len(a: [T: N]) i32` | 返回数组元素个数 `N`（编译期常量） |
| `@size_of` | `fn @size_of(T) i32` | 返回类型 `T` 的字节大小（编译期常量） |
| `@align_of` | `fn @align_of(T) i32` | 返回类型 `T` 的对齐字节数（编译期常量） |
| `@error_id` | `fn @error_id(err: error) u32` | 提取错误值的数值 ID；可用于显式错误比较或检查 `@syscall` 返回的 errno |
| `@max` | 上下文推断 | 整数类型最大值（编译期常量） |
| `@min` | 上下文推断 | 整数类型最小值（编译期常量） |
| `@va_start` | `@va_start(&ap, last)` | 可变参数函数内初始化 va_list（编译时展开为 C 宏） |
| `@va_end` | `@va_end(&ap)` | 结束 va_list 访问（编译时展开为 C 宏） |
| `@va_arg` | `@va_arg(ap, Type)` | 从 va_list 获取下一个参数，类型由 Type 指定 |
| `@va_copy` | `@va_copy(&dest, src)` | 复制 va_list（编译时展开为 C 宏） |
| `@async_fn` | 函数属性 | 标记异步函数，触发 CPS 变换 |
| `@naked_fn` | 函数属性 | 标记裸函数（无 prologue/epilogue），用于底层系统代码 |
| `@await` | 表达式 | 等待异步操作完成（仅 `@async_fn` 内） |
| `@frame` | `@frame(fn_name)` / `@frame(fn_name<T>)` | 异步帧类型构造器（v0.9.3）；暴露 `@async_fn` 的状态机帧类型；高层方法 `start/poll/stop`；pinned 语义（禁止按值移动/赋值/传参/返回） |
| `@embed` | `fn @embed("path") &[const byte]` | 编译期嵌入单个普通文件，返回只读字节切片 |
| `@embed_dir` | `fn @embed_dir("path") &[const EmbedDirEntry]` | 编译期递归嵌入目录，返回只读目录条目切片 |
| `@c_import` | `@c_import("path"[, "cflags"[, "ldflags"]]);` | 顶层构建指令：导入单个 `.c` 或递归目录内 `*.c`，并把 `cflags` / `ldflags` 纳入当前构建 |
| `@asm` | `@asm { ... }` | 内联汇编块 |
| `@vector` | `@vector(T, N)` / `@vector.splat(x)` / `@vector.load(ptr)` / `@vector.store(ptr,v)` / `@vector.select(m,a,b)` / `@vector.any(m)` / `@vector.all(m)` | SIMD 向量类型构造器与阶段 4 辅助内建 |
| `@mask` | `@mask(N)` | SIMD 掩码类型构造器 |

**`@c_import` 说明**：
- 只能在顶层使用
- 首参数可指向单个 `.c` 文件，或一个目录；目录模式会递归收集全部 `*.c`
- `cflags` 只作用于该导入展开出的 C 文件
- `ldflags` 在最终链接阶段聚合
- 若输出为单文件 `app.c`，编译器会额外生成 `app.cimports.sh`
- 若走 split-C / `--split-c-dir` 路径，导入的 C object 直接进入 Makefile，不额外生成 sidecar

**常用标准库模块（当前实现摘录）**：

| 模块 | 入口 / 接口 | 说明 |
|------|-------------|------|
| `std.string` | `strlen` / `strcmp` / `strstr` 等 | 纯 Uya 字符串与字节串工具 |
| `std.mem` | `memcpy` / `memset` / `memmove` / `memcmp` 等 | 纯 Uya 内存操作 |
| `std.encoding.base64` | Base64 / Base64URL 编解码 | 文本协议、JWT 等场景 |
| `std.http` | `types` / `parse` / `router` / `server` / `jwt` | 阻塞式 HTTP 与 JWT 辅助 |
| `std.sql` | `types` / `driver` / `db` | 数据库通用抽象；面向 SQLite / MySQL 等驱动适配 |
| `std.crypto.blake2b` | `blake2b_digest(data, digest_out)` | BLAKE2b 一次性摘要，输出 64 字节 |
| `std.crypto.blake2s` | `blake2s_digest(data, digest_out)` | BLAKE2s 一次性摘要，输出 32 字节 |
| `std.crypto.sha256` | `sha256_digest(data, digest_out)` | SHA-256 一次性摘要，输出 32 字节 |
| `std.crypto.hmac_sha256` | `hmac_sha256(key, msg, mac_out)` | HMAC-SHA256，一次性 MAC，输出 32 字节 |
| `std.crypto.md5` | `md5_digest(data, digest_out)` | MD5 一次性摘要，输出 16 字节 |
| `std.crypto.crc32` | `crc32_compute(data) -> u32` | CRC-32（IEEE / ZIP）校验和 |

> **`std.sql` 详细说明**：见 [std_sql.md](./std_sql.md)

**命名惯例**：
- 单一概念：`@len`, `@max`, `@min`（短形式）
- 复合概念：`@size_of`, `@align_of`, `@async_fn`, `@naked_fn`（下划线分隔）

> **完整内置函数列表**：详见 [builtin_functions.md](./builtin_functions.md)

**函数详细说明**：

1. **`@len(a: [T: N]) i32`**
   - 功能：返回数组的元素个数
   - 参数：`a` 是任意类型 `T` 的数组，大小为 `N`
   - 返回值：`i32` 类型，值为 `N`（编译期常量）
   - 注意：由于 `N` 是编译期常量，此函数在编译期求值
   - **空数组字面量**：对于空数组字面量 `[]`，`@len` 返回数组声明时的大小，而不是 0
     - 示例：`var buffer: [i32: 100] = []; const len_val: i32 = @len(buffer);` → `len_val = 100`
   - 示例：
[examples/example_100.uya](./examples/example_100.uya)

2. **`try` 关键字、饱和运算符**（`+|`, `-|`, `*|`）**和包装运算符**（`+%`, `-%`, `*%`）
   - 功能：提供简洁的溢出检查和处理方式，避免重复编写溢出检查代码
   - 支持的类型：`i8`, `i16`, `i32`, `i64`
   - 编译期展开：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码
   - **`try` 关键字用于溢出检查**：
     - **功能**：对算术运算（`+`, `-`, `*`）进行溢出检查，溢出时返回 `error.Overflow`
     - **语法**：`try expr`，其中 `expr` 是算术运算表达式
     - **返回类型**：`!T`（错误联合类型），需要 `catch` 处理错误
     - **可能抛出的错误**：
       - `error.Overflow`：当算术运算结果超出类型范围时抛出
       - 加法溢出：`try a + b` 在 `a + b` 超出类型范围时返回 `error.Overflow`
       - 减法溢出：`try a - b` 在 `a - b` 超出类型范围时返回 `error.Overflow`
       - 乘法溢出：`try a * b` 在 `a * b` 超出类型范围时返回 `error.Overflow`
     - **使用场景**：需要明确处理溢出错误的情况（如输入验证、关键计算）
     - **示例**：
[examples/add_safe_3.uya](./examples/add_safe_3.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果溢出，返回 `error.Overflow`
       - 必须使用 `catch` 或 `try` 处理可能的错误
       - 支持的操作：`+`（加法）、`-`（减法）、`*`（乘法）
   - **饱和运算符**（`+|`, `-|`, `*|`）：返回饱和值，溢出时返回类型的最大值或最小值
     - **功能**：执行饱和算术，溢出时返回类型的极值（最大值或最小值），而不是错误
     - **返回类型**：`T`（普通类型），不会返回错误，总是返回有效数值
     - **使用场景**：需要限制结果在类型范围内的场景（如信号处理、图形处理、游戏开发）
     - **示例**：
[examples/add_saturating.uya](./examples/add_saturating.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果上溢（超过最大值），返回类型的最大值
       - 如果运算结果下溢（小于最小值），返回类型的最小值
       - 总是返回有效数值，无需错误处理
   - **包装运算符**（`+%`, `-%`, `*%`）：返回包装值，溢出时返回包装后的值
     - **功能**：执行包装算术，溢出时返回包装后的值（模运算），而不是错误或极值
     - **返回类型**：`T`（普通类型），不会返回错误，总是返回有效数值
     - **使用场景**：需要明确的溢出行为（加密算法、循环计数器、哈希函数）
     - **示例**：
[examples/add_wrapping.uya](./examples/add_wrapping.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果溢出，返回包装后的值（模 2^n，n 为类型位数）
       - 总是返回有效数值，无需错误处理
   - **三种方式的对比**：
     | 方式 | 溢出行为 | 返回类型 | 使用场景 |
     |------|----------|----------|----------|
     | `try` 关键字 | 返回错误 | `!T` | 需要明确处理溢出错误（输入验证、关键计算） |
     | 饱和运算符（`+|`, `-|`, `*|`） | 返回极值 | `T` | 需要限制结果范围（信号处理、图形处理） |
     | 包装运算符（`+%`, `-%`, `*%`） | 返回包装值 | `T` | 需要明确的溢出行为（加密算法、循环计数器） |
     
     **选择建议**：
     - 需要错误处理时 → 使用 `try` 关键字（如 `try a + b`）
     - 需要限制范围时 → 使用饱和运算符（如 `a +| b`）
     - 需要包装行为时 → 使用包装运算符（如 `a +% b`）
   
   - **编译期展开示例**：
[examples/example_104.uya](./examples/example_104.uya)
   
   - **优势**：
     - 代码简洁：一行代码替代多行溢出检查
     - 编译期展开，与手写代码性能相同
     - 类型安全：编译器自动推断类型
     - 统一接口：所有整数类型使用相同的函数名
     - 语义清晰：函数名直接表达溢出处理方式

3. **`@size_of(T) i32`**
   - **功能**：`@size_of(T)` 返回类型 `T` 的字节大小
   - **位置**：编译器内置函数（以 `@` 开头），无需导入
   - **签名**：
[examples/sizeof.uya](./examples/sizeof.uya)
   - **使用**：
[examples/vec3_1.uya](./examples/vec3_1.uya)
   - **支持类型**：
     | 类别 | 示例 | 说明 |
     |------|------|------|
     | 基础整数 | `i8` … `i64`, `u8` … `u64` | 大小对齐 = 自身宽度 |
     | 浮点 | `f32`, `f64` | 4 B / 8 B |
     | 布尔 | `bool` | 1 B |
     | 指针 | `&T`, `*T`（FFI指针，如 `*byte`） | 平台字长（4 B 或 8 B） |
     | 数组 | `[T: N]` | 大小 = `N * @size_of(T)`，对齐 = `@align_of(T)` |
     | 结构体 | `struct S{...}` | 大小 = 各字段按 C 规则布局，对齐 = 最大字段对齐 |
     | 原子 | `atomic T` | 与 `T` 完全相同 |
   - **常量表达式**：结果可在**任何需要编译期常量**的位置使用
[examples/file_5.uya](./examples/file_5.uya)
   - **零运行时保证**：
     - 前端遇到 `@size_of(T)` **直接折叠**成常数，**不生成函数调用**
     - 失败路径（类型未定义、含泛型参数）→ **编译错误**，不生成代码
   - **常见示例**：
[examples/packet.uya](./examples/packet.uya)
   - **限制**：
     - `T` 必须是**完全已知类型**（无待填泛型参数）
     - 不支持表达式级 `@size_of(expr)`——仅对 **类型** 求值
     - 返回类型固定为 `i32`；超大结构体大小若超过 `i32` 上限 → 编译错误
   - **一句话总结**：
     > `@size_of` 是**编译器内置函数**（以 `@` 开头），编译期折叠成常数；  
     > 零关键字、编译期证明，单页纸用完。

4. **`@align_of(T) i32`**
   - **功能**：`@align_of(T)` 返回类型 `T` 的对齐字节数
   - **位置**：编译器内置函数（以 `@` 开头），无需导入
   - **签名**：
[examples/sizeof.uya](./examples/sizeof.uya)
   - **使用**：
     - 无需导入，直接使用：`@align_of(T)`
[examples/vec3_1.uya](./examples/vec3_1.uya)
   - **支持类型**：
     | 类别 | 示例 | 说明 |
     |------|------|------|
     | 基础整数 | `i8` … `i64`, `u8` … `u64` | 大小对齐 = 自身宽度 |
     | 浮点 | `f32`, `f64` | 4 B / 8 B |
     | 布尔 | `bool` | 1 B |
     | 指针 | `&T`, `*T`（FFI指针，如 `*byte`） | 平台字长（4 B 或 8 B） |
     | 数组 | `[T: N]` | 对齐 = `@align_of(T)` |
     | 结构体 | `struct S{...}` | 对齐 = 最大字段对齐 |
     | 原子 | `atomic T` | 与 `T` 完全相同 |
   - **常量表达式**：结果可在**任何需要编译期常量**的位置使用
   - **零运行时保证**：
     - 前端遇到 `@align_of(T)` **直接折叠**成常数，**不生成函数调用**
     - 失败路径（类型未定义、含泛型参数）→ **编译错误**，不生成代码
   - **限制**：
     - `T` 必须是**完全已知类型**（无待填泛型参数）
     - 返回类型固定为 `i32`

5. **SIMD 向量内建**（`@vector(T, N)` / `@mask(N)`）
   - **目标**：提供第一类 SIMD 向量与掩码类型，统一纳入 Uya 类型系统，而不是仅作为库级约定
   - **设计原则**：
     - 显式向量化：程序员显式选择 `@vector(T, N)`，编译器不承诺自动向量化
     - 类型安全：向量与掩码都是第一类值类型，参与正常的类型检查
     - 先保证语义正确：第一阶段允许标量回退 lowering，不要求立刻映射真实硬件寄存器
     - 继续复用现有平台裁枝体系：平台选择仍使用 `std.cfg(...)` / `@asm_target()`
   - **基本语法**：
   ```uya
   type Vec4f32 = @vector(f32, 4);
   type Vec8i32 = @vector(i32, 8);
   type Mask8 = @mask(8);

   fn cmp(a: @vector(i32, 4), b: @vector(i32, 4)) @mask(4) {
       return a < b;
   }
   ```
   - **类型规则**：
     - `@vector(T, N)` 中，`T` 是元素类型，`N` 是通道数
     - `@mask(N)` 表示 `N` 通道的布尔掩码类型
     - 第一阶段 `N` 必须是字面量正整数，并要求为 2 的幂
     - 第一阶段建议支持的元素类型为：`i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`f32`、`f64`
     - 第一阶段不允许 `bool`、`byte`、`usize`、指针、切片、结构体、接口、错误联合、嵌套向量作为 `@vector` 元素类型
     - `@vector(T1, N1)` 与 `@vector(T2, N2)` 仅当 `T1 == T2` 且 `N1 == N2` 时类型相等
     - `@mask(N1)` 与 `@mask(N2)` 仅当 `N1 == N2` 时类型相等
     - `@mask(N)` 不隐式转换为 `bool`
     - 向量与标量之间不存在隐式转换
   - **运算规则**：
     - 向量算术：`+`、`-`、`*`、`/` 作用于相同类型的 `@vector(T, N)`，结果类型仍为 `@vector(T, N)`；`%`（取模）仅适用于**整数元素**的相同类型 `@vector(T, N)`，按通道取模，结果类型不变；饱和运算 `+|`、`-|`、`*|` 仅适用于**有符号整数元素**的相同类型 `@vector(T, N)`，按通道语义与标量一致；包装运算 `+%`、`-%`、`*%` 适用于**整数元素**（含无符号）的相同类型 `@vector(T, N)`，按通道语义与标量一致；一元 `-` 适用于元素为整数或浮点的 `@vector(T, N)`，结果类型不变
     - 向量位运算：`&`、`|`、`^`、一元 `~`、`<<`、`>>` 仅适用于整数元素类型的 `@vector(T, N)`
     - 向量比较：`==`、`!=`、`<`、`<=`、`>`、`>=` 作用于相同类型的 `@vector(T, N)`，返回 `@mask(N)`
     - 掩码逻辑运算：`&`、`|`、`^`、`!` 作用于 `@mask(N)`
     - 第一阶段不允许把 `@mask(N)` 直接作为 `if` / `while` 条件
     - 第一阶段不支持向量与标量混合运算，也不支持不同元素类型或不同通道数向量之间的隐式转换
   - **最小内建辅助**：
     - `@vector.splat(x)`：用标量值 `x` 构造所有通道相同的向量；目标向量类型由上下文决定，上下文无法唯一确定时编译报错
     - `@vector.splat(x)` 的参数类型须与目标 `@vector(T, N)` 的元素类型 `T` **一致**或满足现有**隐式转换**规则；无后缀浮点字面量默认为 `f64`，填入 `f32` 元素向量须写 `1.0f32` 等带 `f32` 后缀的字面量（或通过已标注为 `f32` 的变量传入）
     - 目标类型除显式标注、`const`/`var` 初始化、**`return`（期望类型为函数返回的 `@vector`，或 `!T` 时成功分支载荷为 `@vector`）** 等上下文外，还可由**同一代数/比较/取模/饱和/包装表达式中的另一侧** `@vector` 操作数推断（见规范变更 0.49.3、0.49.5、0.49.6、0.49.8）
     - **`@vector.load(ptr)`**（**0.49.33**）：从 **`ptr`** 指向地址**按向量内存大小**读取 **`@vector(T, N)`**；**`ptr`** 为 **`&T`**，且 **`T`** 与目标向量元素类型一致（**`byte`/`u8`** 匹配规则与实现一致）；**不检查**剩余缓冲区长度（与 C **`memcpy`** 调用方责任一致）。目标向量类型上下文与 **`@vector.splat`** 相同。
     - **`@vector.store(ptr, v)`**（**0.49.34**）：**`v`** 为 **`@vector(T, N)`**，**`ptr`** 为 **`&T`** 且 **`T`** 与 **`v`** 的元素类型一致（**`byte`/`u8`** 规则同 **`load`**）；按向量大小将 **`v`** 写入 **`ptr`**；**`void`**；**不检查**可写范围长度（调用方责任同 **`memcpy`**）。
     - **`@vector.select(m, a, b)`**（**0.49.35**）：**`m`** 为 **`@mask(N)`**，**`a`**、**`b`** 为相同 **`@vector(T, N)`** 且 **`N`** 与 **`m`** 一致；通道 **`i`** 上 **`m`** 为真取 **`a[i]`**，否则取 **`b[i]`**；结果为 **`@vector(T, N)`**；目标类型上下文同 **`@vector.splat`** / **`load`**
     - **`@vector.reduce_add(v)`**（**0.49.36**）：**`v`** 为 **`@vector(T, N)`**，**`T`** 为 **`i8`…`u64` 或 `f32`/`f64`**；结果为标量 **`T`**，等于各通道之和（**`+`** 语义同标量）
     - `@vector.any(m)`：参数 `m` 必须是 `@mask(N)`，只要任一通道为 true 则返回 `bool true`
     - `@vector.all(m)`：参数 `m` 必须是 `@mask(N)`，仅当所有通道为 true 时返回 `bool true`
   - **示例**：
   ```uya
   const zeros: @vector(i32, 4) = @vector.splat(0);
   const ones: @vector(f32, 8) = @vector.splat(1.0f32);

   const lt: @mask(4) = a < b;
   if @vector.any(lt) {
       // 至少一个通道满足条件
   }
   ```
   - **第一阶段纳入范围**：
     - `@vector(T, N)`、`@mask(N)`
     - 基本算术、整数位运算、比较、掩码逻辑运算
     - `@vector.splat`、**`@vector.load`**、**`@vector.store`**、**`@vector.select`**、**`@vector.reduce_add`**、`@vector.any`、`@vector.all`
     - 语义正确的标量回退 lowering
     - **C99 快路径**（阶段 4 起）：**x86_64 + SSE2**（`UYA_HAVE_SIMD_X86_SSE`）或 **ARM/AArch64 + NEON**（`UYA_HAVE_SIMD_ARM_NEON`，`<arm_neon.h>`）下，对 **`i32`/`u32`/`f32`**：**2 通道**走 **`*_i32x2` / `*_u32x2` / `*_f32x2`** 等（0.49.29，低 **64 位** 或 NEON **2 宽**）；**4 通道**走 **`*_x4`**（**`i32` 向量 `/` `%`**：`uya_simd_sse_div_i32x4`、`uya_simd_sse_rem_i32x4`，0.49.22–0.49.23；**`u32` 向量 `* / %`**：`uya_simd_sse_mul_u32x4`、`uya_simd_sse_div_u32x4`、`uya_simd_sse_rem_u32x4`，0.49.20–0.49.23；**`i32`/`u32` 向量 `<<` `>>`**：`uya_simd_sse_shl_i32x4`、`uya_simd_sse_shr_i32x4`、`uya_simd_sse_shl_u32x4`、`uya_simd_sse_shr_u32x4`，0.49.24）；**`f64` 向量 `+` / `-` / `* /` / 一元 `-`**：`uya_simd_sse_add_f64x2`、`uya_simd_sse_sub_f64x2`、`uya_simd_sse_mul_f64x2`、`uya_simd_sse_div_f64x2`、`uya_simd_sse_neg_f64x2`，0.49.25–0.49.28，支持 **2×/4×** 通道；**`i16` 向量 `+` / `-` / `*` 与六种比较、一元 `-`、`splat`**：`uya_simd_sse_add_i16x4`/`x8`、`sub_*`、`mul_*`、`eq`/`ne`/`lt`/`gt`/`le`/`ge` 的 **`_i16x4_mask` / `_i16x8_mask`**、`neg_i16x4`/`x8`、`splat_i16x4`/`x8`，0.49.26–0.49.28，**4×** 为 **64 位** SIMD 块、**8×** 为 **128 位**；**`u16` 向量 `+` / `-` / `*` 与六种比较、`splat`**：`add`/`sub`/`mul`/`eq`/`ne`/`lt`/`gt`/`le`/`ge` 的 **`_u16x4` / `_u16x8`** 与 **`splat_u16x4`/`x8`**，0.49.28）；**`i8`/`u8` 向量**（**2/4/8/16/32/64** 通道）算术·位运算·六种比较·**`splat`**·一元 `-`：**`*_i8x16`/`x8`/`x4`/`x2`**、**`*_u8x*`**（0.49.30）；**`i64`/`u64` 向量**与 **掩码**、**`splat`**、一元 `-`：**`*_i64x2`**、**`*_u64x2`** 按 **2 通道** 分块（0.49.30）；**8 / 16 / 32 / 64 通道**（`i32`/`u32`/`f32`）为 **2 / 4 / 8 / 16 次** 4 通道调用（连续 `lanes` 块）。否则为该名提供逐通道标量体。表达式内**不**使用预处理器分支（见规范变更 0.49.10、0.49.16、0.49.17、0.49.18、0.49.19、0.49.20、0.49.21、0.49.22、0.49.23、0.49.24、0.49.25、0.49.26、0.49.27、0.49.28、**0.49.29**、**0.49.30**）。
   - **第一阶段暂缓**：
     - 标量广播语法糖，如 `vec + 1`
     - **`shuffle` / 其它 `reduce_*`**（**`@vector.reduce_add`** 已于 **0.49.36** 纳入；**`@vector.load` / `@vector.store` / `@vector.select`** 已分别于 **0.49.33** / **0.49.34** / **0.49.35** 纳入，见规范变更）
     - `widen/truncate/bitcast/convert`
     - 自动向量化
     - 新的目标特性查询内建
     - `extern` ABI 与跨语言 ABI 保证
     - “零成本”性能承诺
   - **错误处理**：
     - 第一阶段不把 lane 级状态接入 `try/catch`
     - 向量运算不引入新的“按 lane 抛错”语义
     - 饱和运算、包装运算与更细的错误模型留待后续阶段设计

> 更多函数通过 `extern` 直接调用 C 库即可。

---

## 17 字符串与格式化

### 17.1 设计目标
- 支持 `"hex=${x:#06x}"`、`"pi=${pi:.2f}"` 等常用格式；  
- 仍保持「编译期展开 + 定长栈数组」；  
- 无运行时解析开销，无堆分配；  
- 语法一眼看完。

### 17.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#13-字符串插值)

字符串插值语法：
- 基本形式：`"text${expr}text"`
- 格式化形式：`"text${expr:format}text"`
- 格式说明符与 C printf 保持一致

- 整体格式 **与 C printf 保持一致**，减少学习成本。  
- `width` / `precision` 必须为**编译期数字**（`*` 暂不支持）。  
- 结果类型仍为 `[i8: N]`，宽度由「格式字符串最大可能长度」常量求值得出。

### 17.3 宽度常量表

| 格式 | 最大宽度（含 NUL） | 说明 |
|----|----------------|------|
| `%d` `%u` (i32/u32) | 11 B | 32 位有符号/无符号整数 |
| `%ld` `%lu` (i64/u64) | 21 B | 64 位有符号/无符号整数 |
| `%x` `%X` (i32/u32) | 8 B | 32 位十六进制 |
| `%lx` `%lX` (i64/u64) | 17 B | 64 位十六进制 |
| `%#x` (i32/u32) | 10 B | 32 位带 `0x` 前缀 |
| `%#lx` (i64/u64) | 19 B | 64 位带 `0x` 前缀 |
| `%06x` | 8 B | 字段宽 6，32 位仍 ≤ 8 |
| `%f` `%F` (f64) | 24 B | 双精度浮点默认精度 |
| `%.2f` (f64) | 24 B | 双精度保留 2 位小数（宽度不变） |
| `%f` `%F` (f32) | 16 B | 单精度浮点默认精度 |
| `%.2f` (f32) | 16 B | 单精度保留 2 位小数（宽度不变） |
| `%e` `%E` (f64) | 24 B | 双精度科学计数法（如 `3.14e+00`） |
| `%.2e` (f64) | 24 B | 双精度科学计数法，保留 2 位小数（宽度不变） |
| `%e` `%E` (f32) | 16 B | 单精度科学计数法（如 `3.14e+00`） |
| `%.2e` (f32) | 16 B | 单精度科学计数法，保留 2 位小数（宽度不变） |
| `%g` `%G` (f64) | 24 B | 双精度自动精度 |
| `%g` `%G` (f32) | 16 B | 单精度自动精度 |
| `%a` `%A` (f64) | 32 B | C99 十六进制浮点（如 `0x1.xxxp+0`） |
| `%c` | 2 B | 单字符 |
| `%p` | 10/18 B（平台相关） | 指针：0x + 8/16 位十六进制；32位平台=10B（"0x" + 8位十六进制 + NUL），64位平台=18B（"0x" + 16位十六进制 + NUL） |

**宽度计算规则**：
- 整数类型：根据类型宽度（32位/64位）和符号计算最大字符串长度
- 浮点类型：f64 使用 24 字节，f32 使用 16 字节（包含符号、整数部分、小数点、小数部分、指数部分）
- 指针类型：32位平台使用 10 字节（"0x" + 8位十六进制 + NUL），64位平台使用 18 字节（"0x" + 16位十六进制 + NUL）
- 不同 `width` / `precision` 只选**最宽值**参与总长度计算

> 表格已内置在编译器；编译器根据表达式的实际类型选择对应的宽度值。

### 17.4 完整示例

```uya
extern printf(fmt: *byte, ...) i32;

fn main() i32 {
  const x: u32 = 255;
  const pi: f64 = 3.1415926;
  const large: f64 = 123456789.0;

  // 定点格式
  const msg1: [i8: 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";
  printf(&msg1[0]);
  
  // 科学计数法格式
  const msg2: [i8: 64] = "pi=${pi:.2e}, large=${large:.3E}\n";
  printf(&msg2[0]);
  
  return 0;
}
[examples/example_114.txt](./examples/example_114.txt)

**编译期展开过程**：

1. **编译期常量求值**：编译器根据表达式的类型和格式说明符，查表计算所需的最大缓冲区大小
   - `"hex=${x:#06x}"`：`x` 是 `u32`，格式 `#06x` 最大宽度 10 字节（包含 "0x" 前缀）
   - `"pi=${pi:.2f}"`：`pi` 是 `f64`，格式 `.2f` 最大宽度 24 字节（包含符号、整数、小数、指数部分）
   - 文本段：`"hex="` (5字节) + `", pi="` (6字节) + `"\n"` (2字节)
   - 总宽度：5 + 10 + 6 + 24 + 2 = 47 字节，向上对齐到 64 字节（方便对齐）

2. **代码生成**：编译器生成如下代码（伪代码，实际后端实现可能不同）：

```llvm
%buf = alloca [64 x i8]  ; 编译期计算大小
call memcpy(ptr %buf, ptr @str.0, i64 5)               ; "hex="
call sprintf(ptr %buf+5, "%#06x", i32 %x)              ; 0x00ff（运行时格式化）
call memcpy(ptr %buf+13, ptr @str.1, i64 6)            ; ", pi="
call sprintf(ptr %buf+19, "%.2f", double %pi)          ; 3.14（运行时格式化）
call memcpy(ptr %buf+43, ptr @str.2, i64 2)            ; "\n"
```

[examples/example_115.txt](./examples/example_115.txt)

**重要说明：编译期优化 vs 运行时执行**：

字符串插值采用**编译期优化 + 运行时格式化**的混合策略：

**编译期完成的工作**（零运行时开销）：
- ✅ 计算缓冲区大小（`[i8: N]` 中的 `N`）
- ✅ 识别文本段和插值段
- ✅ 生成格式字符串常量（如 `"%#06x"`、`"%.2f"`）
- ✅ 生成文本段的 `memcpy` 调用
- ✅ 零运行时解析开销：格式字符串在编译期确定，无需运行时解析

**运行时执行的工作**（必要的格式化操作）：
- ⚠️ 调用 `sprintf` 进行实际的格式化（将数值转换为字符串）
- ⚠️ 这是必要的，因为数值是运行时变量

**性能保证**：
- **零堆、零 GC**：缓冲区在栈上分配（`alloca`），无需堆分配
- **零解析开销**：格式字符串在编译期确定，无需运行时解析
- **性能等同**：与手写 C 代码使用 `sprintf` 的性能相同，无额外开销

**总结**：字符串插值不是"完全编译期展开"，而是"编译期优化 + 运行时格式化"。编译期完成所有可以静态确定的工作，运行时只执行必要的格式化操作。

### 17.5 后端实现要点

1. **词法** → 识别 `':' spec` 并解析为 `(flag, width, precision, type)` 四元组。  
2. **常量求值** → 根据「类型 + 格式」查表得最大字节数。  
3. **代码生成** →  
   - 文本段 = `memcpy`；  
   - 插值段 = `sprintf(buf+offset, "格式化串", 值)`；  
   - 格式串本身 = 编译期常量。  

### 17.6 限制（保持简单）

| 限制 | 说明 |
|---|---|
| `width/precision` | 必须为**编译期数字**；`*` 暂不支持 |
| 类型不匹配 | `%.2f` 但表达式是 `i32` → 编译错误 |
| 嵌套字符串 | `${"abc"}` → ❌ 表达式内不能再有字符串字面量 |
| 动态宽度 | `"%*d"` → 未来支持 |

### 17.7 字符串切片

字符串数组 `[i8: N]` 可以使用切片语法 `&text[start:len]` 创建切片视图：

```uya
type str = &[i8];  // 字符串切片别名（可选）

const text: [i8: 12] = "Hello world";
const hello: &[i8] = &text[0:5];  // "Hello" 的切片视图

// 使用字符串切片
for hello |byte| {
    printf("%c", byte);
}
```

**字符串切片特性**：
- 字符串数组 `[i8: N]` 可以使用切片语法 `&text[start:len]` 创建切片视图
- 字符串切片类型为 `&[i8]`，可以定义类型别名 `type str = &[i8]` 简化使用
- 字符串切片支持所有切片操作：for循环迭代、索引访问等
- 字符串切片是原字符串的视图，修改原字符串会影响切片
- 字符串切片的生命周期绑定到原字符串，遵循切片生命周期规则

### 17.8 一句话总结

> Uya 字符串插值 `"a=${x:#06x}"` → **编译期展开成定长栈数组**，格式与 C printf 100% 对应，**零运行时解析、零堆、零 GC**，性能 = 手写 `sprintf`。

---

## 18 异步编程

### 18.1 实现层次

异步编程的实现分为两个层次：

1. **语言核心（编译器实现）** - **必须实现**：
   - `@async_fn` 函数属性
   - `try @await` 挂起点
   - `union Poll<T>` 类型定义
   - `interface Future<T>` 接口定义
   - `struct Waker` 类型定义（至少需要类型定义，用于 `poll()` 方法签名）
   - CPS 变换和状态机生成

2. **标准库实现（基于核心类型）** - **可选，可后续实现**：
   - `std.async`：`Task<T>`, `Waker` 完整实现
   - `std.channel`：`Channel<T>`, `MpscChannel<T>`
   - `std.runtime`：`Scheduler` 事件循环
   - `std.thread`：`ThreadPool`, `async_compute<T>`

**实现顺序**：
- **第一步**：实现语言核心，包括类型定义和编译器支持
  - 可以先定义 `struct Waker` 为占位类型（空结构体），满足 `poll()` 方法签名要求
  - 实现 CPS 变换和状态机生成，使基本的异步函数可以编译和运行
- **第二步**：实现标准库，提供完整的异步运行时支持
  - 实现 `Waker` 的完整功能（`wake()` 方法等）
  - 实现 `Task<T>`、`Scheduler` 等运行时组件
  - 实现 `Channel<T>` 等异步通信原语

**最小实现**：
- 要实现基本的异步编程功能，**不需要**先实现完整的标准库
- 只需要实现语言核心和基本类型定义
- 可以编写简单的异步函数和状态机，即使没有完整的运行时支持
- 标准库可以在后续逐步实现和完善

### 18.2 设计目标

- **显式控制**：所有挂起必须 `@await`，取消必须显式检查 `is_cancelled()`
- **零成本**：状态机栈分配，无运行时堆分配，无隐式锁
- **编译期证明**：状态机安全性、Send/Sync 推导、跨线程验证编译期完成
- **类型安全**：`Poll<T>` 使用 `union`（编译期标签跟踪），非 `enum`

### 18.3 语言核心（编译器实现）

#### 18.3.1 `@async_fn` 函数属性

**语法**：

- 顶层函数：`@async_fn fn function_name(...) !Future<T> { ... }`
- 结构体/联合体方法实现：`@async_fn fn method(self: &Self, ...) !Future<T> { ... }`
- 接口方法签名：`@async_fn fn method(self: &Self, ...) Future<!T>;`

**功能**：
- 函数属性，触发 CPS（Continuation-Passing Style）变换生成显式状态机
- 状态机大小在编译期确定，递归调用编译错误

**约束**：
- **必须**返回 `Future<!T>` 或 `!Future<T>`（显式异步，无隐式包装）；两种形式均支持，`!Future<T>` 为兼容写法
- 状态机大小编译期确定，递归调用编译错误
- 接口方法签名上的 `@async_fn` 用于声明异步契约；真正生成状态机的是对应的结构体/联合体方法实现

**示例**：
```uya
@async_fn
fn fetch() !Future<&[i8]> { 
    // 异步操作
    try @await some_async_operation();
    return result;
}

@async_fn
fn bad() !void { ... }  // 错误：必须返回 Future

interface Reader {
    @async_fn
    fn read(self: &Self, n: usize) Future<!i32>;
}

struct Socket : Reader {
    fd: i32,
}

Socket {
    @async_fn
    fn read(self: &Self, n: usize) Future<!i32> {
        _ = n;
        return self.fd;
    }
}
```

#### 18.3.2 `@await` 挂起点

**语法**：`try @await expression`

**功能**：
- 唯一显式挂起点
- 挂起当前异步函数，等待异步操作完成
- 编译期展开为状态机状态转换
- 返回 `!T` 类型，需要使用 `try` 解包错误

**约束**：
- 只能在 `@async_fn` 函数内使用
- 表达式必须返回 `Future<!T>` 或 `!Future<T>` 类型
- 必须使用 `try` 关键字处理错误传播

**示例**：
```uya
@async_fn
fn fetch_data() !Future<&[i8]> {
    const result = try @await http_get("https://example.com");
    return result;
}
```

#### 18.3.3 `union Poll<T>` 异步计算结果类型

**定义**：
```uya
union Poll<T> {
    Pending: void,
    Ready: T,
    Error: error
}
```

**功能**：
- 表示异步计算的结果状态
- 使用 `union`（编译期标签跟踪），非 `enum`
- 编译期保证类型安全

**使用**：
```uya
const result: union Poll<i32> = some_future.poll(&waker);
match result {
    Pending => { /* 继续等待 */ },
    Ready(value) => { /* 使用 value */ },
    Error(err) => { /* 处理错误 */ }
}
```

#### 18.3.4 `interface Future<T>` 异步计算抽象

**定义**：
```uya
interface Future<T> {
    fn poll(self: &Self, waker: &Waker) union Poll<T>;
}
```

**功能**：
- 异步计算的抽象接口
- 所有异步操作必须实现此接口
- 编译期验证实现

**实现示例**：
```uya
struct MyFuture {
    // 状态机状态
}

MyFuture {
    fn poll(self: &Self, waker: &Waker) union Poll<i32> {
        // 实现异步逻辑
        if ready {
            return union Poll<i32> { Ready: value };
        } else {
            return union Poll<i32> { Pending: void };
        }
    }
}
```

### 18.4 函数签名约束

**必须返回 `Future<!T>` 或 `!Future<T>`**：
- `@async_fn` 函数必须显式返回 `Future<!T>` 或 `!Future<T>` 类型（两种形式均支持）
- 无隐式包装，所有异步操作显式声明
- 状态机大小编译期确定，递归调用编译错误

**返回值语义**：
- `Future<!T>` 是当前主路径：future 的 `poll()` 返回 `Poll<!T>`，`Pending` 走 `Poll.Pending`，业务错误走 `!T`
- `!Future<T>` 是兼容路径：同步错误仍可在返回 future 之前直接抛出，成功分支返回 `Future<T>`
- **返回值自动包装**：
  - 对 `Future<!T>`：`return value;` → 自动包装为 `Future<!T>` 的 Ready(ok(value))；`return error.ErrorName;` → 自动包装为 Ready(error.ErrorName)
  - 对 `!Future<T>`：`return value;` → 自动包装为 `Future<T>`，作为 `!Future<T>` 的成功分支；`return error.ErrorName;` → 直接返回错误，作为 `!Future<T>` 的错误分支

**自动包装机制**：
- 当 `@async_fn` 函数返回任何类型的值（基本类型、结构体、切片等）时，编译器通过 CPS 变换生成一个立即就绪的 Future
- 编译器生成的状态机结构体实现 `Future<T>` 接口，其 `poll()` 方法直接返回 `union Poll<T> { Ready: value }`
- 如果函数体中没有 `@await` 点，状态机只包含一个最终状态，`poll()` 首次调用即返回 `Ready(value)`
- 如果函数体中有 `@await` 点，状态机包含多个状态，最终状态返回 `Ready(value)`
- **支持的类型**：所有类型都可以自动包装，包括：
  - 基本类型：`i32`, `f64`, `bool` 等
  - 结构体：`MyStruct`, `Point`, `User` 等
  - 切片：`&[i8]`, `&[T]` 等
  - 数组：`[i32: 10]` 等
  - 指针和引用：`*T`, `&T` 等
- **实现细节**（编译器生成）：
  ```uya
  // 源代码：return 42; 或 return User{ id: 1, name: "Alice" };
  // 编译器生成的状态机（伪代码）：
  
  // 基本类型示例
  struct AsyncStateMachine_i32 {
      state: i32,
      result: i32
  }
  
  AsyncStateMachine_i32 {
      fn poll(self: &Self, waker: &Waker) union Poll<i32> {
          if self.state == COMPLETED {
              return union Poll<i32> { Ready: self.result };
          }
          self.result = 42;
          self.state = COMPLETED;
          return union Poll<i32> { Ready: self.result };
      }
  }
  
  // 结构体示例
  struct AsyncStateMachine_User {
      state: i32,
      result: User  // 状态机中保存完整的结构体值
  }
  
  AsyncStateMachine_User {
      fn poll(self: &Self, waker: &Waker) union Poll<User> {
          if self.state == COMPLETED {
              return union Poll<User> { Ready: self.result };
          }
          self.result = User{ id: 1, name: "Alice" };
          self.state = COMPLETED;
          return union Poll<User> { Ready: self.result };
      }
  }
  ```

- **示例**：
  ```uya
  // 基本类型
  @async_fn
  fn may_fail() !Future<i32> {
      if condition {
          return error.OperationFailed;  // 错误分支：直接返回 error
      }
      return 42;  // 成功分支：自动包装为 Future<i32>
  }
  
  // 结构体
  struct User {
      id: i32,
      name: &[i8]
  }
  
  @async_fn
  fn get_user() !Future<User> {
      // 异步操作后返回结构体
      // const data = try @await fetch_user_data();
      return User{ id: 1, name: "Alice" };  // 自动包装为 Future<User>
  }
  
  // 切片
  @async_fn
  fn get_data() !Future<&[i8]> {
      // const result = try @await fetch_bytes();
      return "hello";  // 自动包装为 Future<&[i8]>
  }
  ```

**错误示例**：
```uya
@async_fn
fn bad() !void { ... }  // 错误：必须返回 Future
```

**正确示例**：
```uya
@async_fn
fn fetch() !Future<&[i8]> { ... }  // 正确
```

### 18.5 标准库实现（基于核心类型）

标准库基于语言核心类型实现，提供高级异步抽象：

| 模块 | 类型 | 实现基础 |
|------|------|---------|
| `std.async` | `Task<T>`, `Waker` | 内置接口 |
| `std.channel` | `Channel<T>`, `MpscChannel<T>` | `atomic T` + `union` |
| `std.runtime` | `Scheduler` | 事件循环 |
| `std.thread` | `ThreadPool`, `async_compute<T>` | 系统线程 |

#### 18.5.1 `std.async` 模块

**`Task<T>`**：
- 异步任务的包装类型
- 实现 `Future<T>` 接口
- 提供任务生命周期管理

**`Waker`**：
- **定义**：唤醒器（Waker），用于在异步操作就绪时通知异步运行时重新调度任务
- **作用**：
  - 当异步操作（如 I/O、定时器等）就绪时，通过 `waker.wake()` 通知运行时
  - 运行时收到通知后，会重新调用 `poll()` 方法检查任务状态
  - 实现高效的异步任务调度，避免忙等待（busy-waiting）
- **使用场景**：
  - 在 `poll()` 方法中，如果返回 `Pending`，通常需要保存 `waker` 的引用
  - 当异步操作（如网络 I/O、文件 I/O）就绪时，调用 `waker.wake()` 通知运行时
  - 运行时收到通知后，会重新调度该任务，再次调用 `poll()` 方法
- **编译期验证**：
  - 编译期验证唤醒安全性（Waker 使用）
  - 确保 Waker 不会被错误使用或泄漏
- **示例**：
  ```uya
  struct MyAsyncIO {
      data: i32,
      waker: Option<&Waker>  // 保存 waker 以便后续唤醒
  }
  
  MyAsyncIO {
      fn poll(self: &Self, waker: &Waker) union Poll<i32> {
          if self.data_ready() {
              return union Poll<i32> { Ready: self.data };
          } else {
              // 保存 waker，等待 I/O 就绪时唤醒
              self.waker = Some(waker);
              // 注册到 I/O 事件循环
              register_io_callback(self, |io| {
                  io.waker.unwrap().wake();  // I/O 就绪时唤醒
              });
              return union Poll<i32> { Pending: void };
          }
      }
  }
  ```

#### 18.5.2 `std.channel` 模块

**`Channel<T>`**：
- 异步通道，用于异步任务间通信
- 基于 `atomic T` 和 `union` 实现
- 零运行时锁，编译期验证并发安全

**`MpscChannel<T>`**：
- 多生产者单消费者通道
- 基于原子操作实现
- 编译期验证 Send/Sync 约束

#### 18.5.3 `std.runtime` 模块

**`Scheduler`**：
- 异步运行时调度器
- 事件循环实现
- 零堆分配，栈分配状态机

#### 18.5.4 `std.thread` 模块

**`ThreadPool`**：
- 线程池，用于 CPU 密集型异步任务
- 当前最小实现提供 `thread_pool_new()` / `thread_pool_shutdown()`，在 Linux 上以可复用 worker 进程池承载计算
- 共享状态中已包含固定任务槽位、共享 FIFO 队列与 `worker_idx` 绑定；worker 通过 slot 索引取任务并写回结果
- 当共享槽位任务需要执行时，当前统一先进入共享 FIFO 队列；父进程负责唤醒空闲 worker 进入 drain 路径，而具体取队首 slot 与后续连续取活都由 worker 在共享队列中完成；父进程会按共享状态回刷本地 worker `busy/active_slot`；共享槽位参数/结果按 **raw bits** 传输，并由 **`task_kind`** 区分多种标量 **`T`**（含整数、`bool`、`f32`/`f64` 等）的调用路径；future 侧对 shared-slot 的提交与推进仍经池级 helper（如 **`thread_pool_submit_slot_*()`**、**`thread_pool_try_progress_slot()`**、**`thread_pool_try_kick_drain()`**），one-shot / shared-slot / bind / read-result 的大部分状态机在共享 **`ThreadAsyncComputeCore`** 中实现，再由泛型 **`AsyncComputeFuture<T>`**（及 **`AsyncComputeI32Future`** 等 typedef）把内部轮询映射为 **`Poll<!T>`**；slot 已到 **`DONE`** 后 future 仍可迟绑定 worker 结果 fd（late-poll 回归已覆盖）。队列满时回退 one-shot 子进程
- 与异步运行时集成

**`async_compute<T>`**：
- **唯一**对外入口：`async_compute<T>(pool, compute_fn, arg) -> Future<!T>`（装箱后的 **`Future<!T>`** 接口对象）；编译期按 **`T`** 分发到 **`i32`/`u32`/`usize`/`i64`/`u64`/`i16`/`u16`/`i8`/`u8`/`bool`/`f32`/`f64`** 等已支持载荷（未支持类型在编译期落入错误路径）
- **`AsyncComputeI32Future`** 等 typedef 仍为 **`AsyncComputeFuture<T>`** 的别名，便于在类型标注中使用具体 future 结构体；**不再**提供 **`async_compute_i32`** 等特化函数
- 将 CPU 密集型任务提交到线程池
- 后续：Send/Sync/跨线程验证等

### 18.6 设计哲学

#### 18.6.1 显式控制

- **所有挂起必须 `@await`**：无隐式挂起点，所有异步操作显式声明
- **取消必须显式检查**：通过 `is_cancelled()` 显式检查取消状态
- **无隐式转换**：所有异步操作显式类型，无隐式包装

#### 18.6.2 零成本

- **状态机栈分配**：所有状态机在栈上分配，无堆分配
- **无运行时锁**：基于原子操作和编译期验证，无隐式锁
- **编译期优化**：状态机大小和布局编译期确定，零运行时开销

#### 18.6.3 编译期证明

- **状态机安全性**：编译期验证状态机转换的正确性
- **Send/Sync 推导**：编译期推导类型是否满足 Send/Sync 约束
- **跨线程验证**：编译期验证跨线程使用的安全性

#### 18.6.4 类型安全

- **`Poll<T>` 使用 `union`**：编译期标签跟踪，非 `enum`
- **编译期验证**：所有异步操作类型在编译期验证
- **无运行时类型信息**：所有类型信息编译期确定

### 18.7 完整示例

```uya
// 定义异步函数
@async_fn
fn fetch_url(url: &[i8]) !Future<&[i8]> {
    // 异步操作
    const result = try @await http_get(url);
    return result;
}

// 使用异步函数
@async_fn
fn main() !Future<i32> {
    const data = try @await fetch_url("https://example.com");
    // 处理数据
    return 0;
}
```

### 18.8 限制

| 限制 | 说明 |
|------|------|
| 递归调用 | 状态机大小编译期确定，递归调用编译错误 |
| 动态状态机 | 不支持动态大小的状态机 |
| 隐式挂起 | 所有挂起必须显式使用 `@await` |

### 18.9 一句话总结

> **异步编程基础设施**：`@async_fn`/`@await` + `union Poll<T>` + `interface Future<T>`；返回必须是 `Future<!T>` 或 `!Future<T>`；状态机零分配，挂起显式，并发安全编译期证明。

---

## 19 内联汇编

### 19.1 概述

`@asm` 是一个编译期内置函数，用于直接编写内联汇编代码，替代 C99 的内联汇编语法。它是构建高性能底层库、操作系统内核、编译器基础设施的关键工具。

### 19.2 设计哲学

`@asm` 遵循 Uya 的**坚如磐石**设计哲学：

1. **显式控制**：所有汇编操作显式声明，无隐式副作用
2. **编译期证明**：在当前函数内验证汇编操作的安全性
3. **零成本**：直接生成汇编指令，无运行时包装
4. **类型安全**：寄存器、内存操作与 Uya 类型系统绑定

### 19.3 基本语法

```uya
@asm {
    // 单条指令
    "instruction template" (input1, input2, ..., -> output1, output2, ...)
        clobbers = [reg1, reg2, ..., "memory"];
    
    // 多条指令块
    "mov rax, {a}" (a, -> rax);
    "add rax, {b}" (rax, b, -> rax);
    "syscall" (rax, -> result);
}
```

**语法元素**：
- `instruction template`：汇编指令模板，使用 `{name}` 占位符
- `input_exprs`：输入表达式列表
- `output_exprs`：输出表达式列表（在 `->` 之后）
- `clobbers`：显式声明的寄存器列表和内存修改

### 19.4 类型安全机制

#### 19.4.1 寄存器类型

```uya
// 平台无关寄存器
type @asm_reg = opaque;  // 编译器分配的通用寄存器

// 平台特定寄存器（编译期平台检测）
type @asm_reg_x64 = opaque;   // x86-64 通用寄存器
type @asm_reg_x86 = opaque;   // x86 通用寄存器
type @asm_reg_arm64 = opaque; // ARM64 通用寄存器
```

#### 19.4.2 内存操作类型

```uya
// 内存操作包装
@asm_mem<T>(ptr: &T) -> asm_mem;

// 使用示例
fn atomic_add(ptr: &i32, value: i32) void {
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> ptr*);
    }
}
```

#### 19.4.3 类型检查规则

**编译器验证规则**：
1. 输入表达式类型必须与占位符类型兼容
2. 输出表达式类型必须与指令结果类型兼容
3. 寄存器约束不能与调用约定冲突
4. 内存操作必须有明确的类型标注
5. clobbers 必须显式声明所有被修改的寄存器

### 19.5 内存安全保证

#### 19.5.1 寄存器验证

```uya
// ✅ 安全：编译器自动分配临时寄存器
@asm {
    "add {tmp}, {a}" (a, -> tmp: @asm_reg);
    "add {tmp}, {b}" (tmp, b, -> result);
}

// ❌ 不安全：未声明 clobber
@asm {
    "mov rax, 1" (-> _);  // 编译错误：未声明 clobber
}

// ✅ 正确：显式声明 clobber
@asm {
    "mov rax, 1" (-> _);
} clobbers = ["rax"];
```

#### 19.5.2 内存安全验证

```uya
// ✅ 安全：有明确指针类型
fn read_u32(ptr: &u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    return value;
}

// ❌ 不安全：无类型指针（FFI 指针）
fn read_u32_unsafe(ptr: *u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (ptr, -> value);  // 编译错误
    }
    return value;
}
```

#### 19.5.3 并发安全验证

```uya
// ✅ 正确：原子操作
fn atomic_fetch_add(ptr: &atomic i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
    }
    return old;
}

// ❌ 错误：非原子类型
fn unsafe_fetch_add(ptr: &i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
        // 编译错误：ptr 不是 atomic 类型
    }
    return old;
}
```

### 19.6 平台支持

#### 19.6.1 平台检测

```uya
// 目标平台枚举
enum @asm_target {
    x86_64_linux,
    x86_64_macos,
    x86_64_windows,
    arm64_linux,
    arm64_macos,
    arm64_windows,
}

// 获取当前平台
const target: @asm_target = @asm_target();
```

#### 19.6.2 条件编译示例

```uya
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    var result: i64;  // 显式声明输出变量

    if @asm_target() == .x86_64_linux {
        @asm {
            "mov rax, 1" (-> rax);
            "mov rdi, {fd}" (fd, -> rdi);
            "mov rsi, {buf}" (buf, -> rsi);
            "mov rdx, {count}" (count, -> rdx);
            "syscall" (rax, rdi, rsi, rdx, -> result);
        } clobbers = ["rcx", "r11"];
    } else if @asm_target() == .arm64_linux {
        @asm {
            "mov x8, #64" (-> x8);
            "mov x0, {fd}" (fd, -> x0);
            "mov x1, {buf}" (buf, -> x1);
            "mov x2, {count}" (count, -> x2);
            "svc #0" (x8, x0, x1, x2, -> result);
        } clobbers = ["x16", "x17"];
    }

    if result < 0 {
        return error.SyscallFailed;
    }

    return result as! i32;  // 使用 as! 处理可能溢出的转换
}
```

#### 19.6.3 平台特定寄存器

| 平台 | 通用寄存器类型 | 特殊寄存器 |
|------|---------------|-----------|
| x86-64 | `@asm_reg_x64` | rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp, r8-r15 |
| x86 | `@asm_reg_x86` | eax, ebx, ecx, edx, esi, edi, ebp, esp |
| ARM64 | `@asm_reg_arm64` | x0-x30 |

### 19.7 使用示例

#### 19.7.1 基本算术运算

```uya
fn add_with_overflow(a: i32, b: i32) !(i32, bool) {
    var result: i32;
    var overflow: bool;
    
    @asm {
        "add {a}, {b}" (a, b, -> result, @asm_flag("overflow" -> overflow));
    }
    
    return (result, overflow);
}
```

#### 19.7.2 系统调用

```uya
fn syscall_exit(code: i32) noreturn {
    const SYS_exit: i64 = 60;
    
    @asm {
        "mov rax, {nr}" (SYS_exit, -> rax);
        "mov rdi, {code}" (code, -> rdi);
        "syscall" (rax, rdi, -> _);
    } clobbers = ["rcx", "r11"];
}
```

#### 19.7.3 CPU 特性检测

```uya
struct CPUFeatures {
    has_sse: bool,
    has_sse2: bool,
    has_avx: bool,
    has_avx2: bool,
}

fn detect_cpu_features() CPUFeatures {
    var features: CPUFeatures = {};
    
    @asm {
        // CPUID 指令
        "mov eax, 1" (-> eax);
        "cpuid" (eax, -> eax, ebx, ecx, edx);
        
        // 提取特性位
        "test edx, 1<<25" (edx, -> features.has_sse);
        "test edx, 1<<26" (edx, -> features.has_sse2);
        "test ecx, 1<<28" (ecx, -> features.has_avx);
        "test ebx, 1<<5" (ebx, -> features.has_avx2);
    }
    
    return features;
}
```

### 19.8 详细文档

完整的 API 参考、最佳实践和更多示例，请参阅：

- **[内联汇编设计文档](asm_design.md)** - 设计哲学、语法设计、类型系统
- **[内联汇编 API 参考](asm_api_reference.md)** - 完整 API 文档、使用示例
- **[内联汇编最佳实践](asm_best_practices.md)** - 性能优化、安全保证

### 19.9 一句话总结

> **@asm = 类型安全 + 跨平台 + 内存安全 + 零成本的内联汇编**

---

## 25 宏系统

### 25.1 概述

Uya 宏系统是一个**编译时元编程工具**，允许开发者在编译阶段生成、转换和验证代码。该系统严格遵循 Uya 语言"坚如磐石"的设计哲学，通过编译时的确定性与安全性，确保运行时的可靠性与零开销抽象。

### 25.2 宏定义语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#宏系统)

```
macro_decl = 'mc' ID '(' param_list ')' return_tag '{' statements '}'
param_list = param { ',' param }
param = ID ':' param_type
param_type = 'expr' | 'stmt' | 'type' | 'pattern'
return_tag = 'expr' | 'stmt' | 'struct' | 'type'
```

**说明**：
- `mc` 关键字用于声明宏
- 参数类型：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）
- 返回标签：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）

### 25.2.1 跨模块宏导出与导入

宏可以使用 `export` 关键字导出，供其他模块使用。

**导出宏**：

```uya
// macro_lib/macro_lib.uya
export mc add(a: expr, b: expr) expr {
    ${a} + ${b};
}

export mc square(x: expr) expr {
    ${x} * ${x};
}

// 未导出的宏（私有）
mc private_helper() expr {
    100;
}
```

**导入宏**：

```uya
// main.uya
use macro_lib.add;
use macro_lib.square;

fn main() i32 {
    const sum: i32 = add(10, 20);      // 30
    const sq: i32 = square(5);          // 25
    return 0;
}
```

**注意事项**：
- 未使用 `export` 标记的宏为模块私有，无法被其他模块导入
- 宏在编译时展开，因此跨模块宏导入不会引入运行时开销
- 宏的展开发生在类型检查之前，因此被导入的宏可以访问定义模块中的类型

### 25.3 宏调用语法

```
macro_call = ID '(' arg_list ')'
```

宏调用语法与普通函数调用完全一致。宏在编译时展开，调用表达式被替换为宏生成的代码片段。

### 25.3.1 宏返回值语法糖

为了简化简单宏的编写，Uya 提供了语法糖规则：

**语法糖规则**：
- 如果宏的 `return_tag` 是 `expr`，且宏体最后一条语句是表达式（不是 `@mc_code` 调用），编译器自动将其包装为 `@mc_code(@mc_ast(...))`
- 如果宏的 `return_tag` 是 `stmt`，且宏体最后一条语句是语句（不是 `@mc_code` 调用），编译器自动将其包装为 `@mc_code(@mc_ast(...))`

**示例**：

```uya
// 简化写法（使用语法糖）
mc simple() expr {
    42;  // 自动转换为 @mc_code(@mc_ast( 42 ))
}

// 等价于显式写法
mc simple_explicit() expr {
    @mc_code(@mc_ast( 42 ));
}

// 语句宏的语法糖
mc log_message(msg: expr) stmt {
    printf("Log: %s\n", ${msg});  // 自动转换为 @mc_code(@mc_ast({ ... }))
}

// 复杂宏仍需要显式使用 @mc_code
mc complex(param) expr {
    const param_ast = @mc_ast(param);
    const code_ast = @mc_ast({
        fn process_${param_ast}(self: &Self) void {
            // 复杂逻辑...
        }
    });
    @mc_code(code_ast);  // 必须显式使用
}
```

**说明**：
- 语法糖仅适用于宏体最后一条语句是简单表达式或语句的情况
- 如果宏体中使用了 `@mc_code`，则不会应用语法糖
- 复杂宏（需要构建 AST、组合代码片段等）仍需要显式使用 `@mc_code` 和 `@mc_ast`

### 25.4 编译时内置函数

#### 25.4.1 `@mc_eval(expr)`

**编译时求值函数**
- **功能**：对常量表达式进行编译时求值
- **规则**：表达式必须是编译时常量，否则引发编译错误
- **用途**：条件编译、常量计算、编译时验证

```uya
mc buffer_size(n) expr {
    const size = @mc_eval(n);
    if size > 8192 { @mc_error("缓冲区太大"); }
    @mc_code(@mc_ast( ${@mc_ast(size)} ));
}
```

#### 25.4.2 `@mc_type(expr)`

**编译时类型反射函数**
- **功能**：获取表达式或类型的完整编译时类型信息
- **返回**：`TypeInfo` 结构体

**`TypeInfo` 结构体**：
```uya
struct TypeInfo {
    // 基础信息
    name: string
    kind: TypeKind
    size: usize
    align: usize
    
    // 类型特征标志
    is_integer: bool
    is_signed: bool
    is_float: bool
    is_numeric: bool
    is_bool: bool
    is_byte: bool
    is_void: bool
    is_struct: bool
    is_union: bool
    is_enum: bool
    is_interface: bool
    is_tuple: bool
    is_array: bool
    is_slice: bool
    is_pointer: bool
    is_ref: bool
    is_ptr: bool
    is_atomic_ptr: bool
    is_void_ptr: bool
    is_atomic: bool
    is_error_union: bool
    is_func_ptr: bool
    is_generic_param: bool
    is_opaque: bool
    
    // 扩展元数据
    fields: [FieldInfo]
    variants: [VariantInfo]
    underlying_type: TypeInfo
    element_type: TypeInfo
    array_length: usize
    param_types: [TypeInfo]
    return_type: TypeInfo
    constraint: string
    method_sigs: [MethodSignature]
}
```

**`TypeKind` 枚举**：
```uya
enum TypeKind {
    // 基础标量类型
    Integer, Float, Bool, Byte, Void
    
    // 指针与引用类型
    Ref, Ptr, AtomicPtr, VoidPtr
    
    // 复合数据类型
    Struct, Union, Enum, Interface, Tuple
    
    // 集合类型
    Array, Slice, FixedSlice
    
    // 特殊类型
    Atomic, ErrorUnion, FuncPtr
    
    // 泛型与元类型
    GenericParam, TypeInfo
    
    // 外部类型
    Extern, Opaque
}
```

**关联数据结构**：
```uya
struct FieldInfo {
    name: string
    type: TypeInfo
    offset: usize
    index: usize
}

struct VariantInfo {
    name: string
    discriminant: i64
    has_payload: bool
    payload_type: TypeInfo
}

struct MethodSignature {
    name: string
    param_types: [TypeInfo]
    return_type: TypeInfo
    is_mut: bool
}
```

**当前实现（与 std.macro_typeinfo 及 codegen 一致）**：

上述为规范目标形态；**当前实现**中 TypeInfo 与 FieldInfo 的布局定义在标准库 `lib/std/macro_typeinfo.uya`，与 codegen 在未 use 该模块时自动生成的内置定义一致。**获取 fields 数组大小时请使用 `@len(info.fields)`**（不导出容量常量）。

```uya
// lib/std/macro_typeinfo.uya
export struct FieldInfo {
    name: *i8,
    type_name: *i8,
}

export struct TypeInfo {
    name: *i8,
    size: i32,
    align: i32,
    kind: i32,
    type_id: i32,
    is_integer: bool,
    is_float: bool,
    is_bool: bool,
    is_pointer: bool,
    is_array: bool,
    is_void: bool,
    field_count: i32 = 0,
    fields: [FieldInfo: 64] = [],
}
```

使用 `@mc_type` 或 `for info.fields` 时，可通过 `use std.macro_typeinfo.TypeInfo`（及 `use std.macro_typeinfo.FieldInfo`）引用；若不 use，codegen 在检测到 `@mc_type` 时会自动生成上述内置定义。宏内 `for info.fields |var|` 的循环变量 `var` 使用 **`var.name`**（标识符 AST）与 **`var.type_name`**（类型 AST）与当前实现一致。

#### 25.4.3 `@mc_ast(expr)`

**代码转抽象语法树函数**
- **功能**：将代码片段转换为抽象语法树节点
- **语法**：内部可使用 `${}` 嵌入其他 AST 节点

```uya
mc define_getter(field) struct {
    const field_ast = @mc_ast(field);
    const getter_ast = @mc_ast({
        fn get_${field_ast}(self: &Self) i32 {
            return self.${field_ast};
        }
    });
    @mc_code(getter_ast);
}
```

#### 25.4.4 `@mc_code(ast)`

**抽象语法树转代码函数**
- **功能**：将 AST 节点转换回可执行代码
- **规则**：必须与宏声明的 `return_tag` 匹配

#### 25.4.5 `@mc_source(expr)`

**编译期表达式序列化为字符串**
- **语法**：`@mc_source(expr)`
- **功能**：仅在宏内有效；在宏展开阶段将 `expr` 的 AST 序列化为字符串，结果替换为该字符串字面量（类型与其它字符串字面量一致，如 `*i8`/`&[byte]`）。
- **用途**：例如实现 `mc to_string(e: expr) expr { @mc_source(e); }`，调用 `to_string(a > 0)` 得到 `"a > 0"`；或断言失败时打印条件源码便于调试。
- **说明**：结果为“规范形式”的源码表示（如运算符两侧有空格），不保证与源文件字节完全一致。

```uya
mc to_string(e: expr) expr {
    @mc_source(e);
}
// 使用: to_string(a > 0)  =>  "a > 0"
```

#### 25.4.6 `@mc_ast` 与 `@mc_code` 使用指南

**核心区别**：

| 函数 | 输入 | 输出 | 用途 |
|------|------|------|------|
| `@mc_ast(expr)` | 代码表达式 | AST 节点 | 构建代码模板，支持 `${}` 插值 |
| `@mc_code(ast)` | AST 节点 | 生成的代码 | 宏的最终输出，必须匹配 `return_tag` |

**使用场景**：

**何时使用 `@mc_ast`**：
1. **构建代码模板**：需要创建包含 `${}` 插值的代码模板时
   ```uya
   const code_ast = @mc_ast({
       fn get_${field_ast}(self: &Self) i32 {
           return self.${field_ast};
       }
   });
   ```
2. **组合多个代码片段**：需要将多个代码片段组合成一个整体时
   ```uya
   const parts = [@mc_ast(...), @mc_ast(...)];
   const combined = @mc_ast({
       ${parts[0]};
       ${parts[1]};
   });
   ```
3. **存储 AST 供后续处理**：需要先构建 AST，然后进行修改或组合时
   ```uya
   const field_ast = @mc_ast(field);
   // 后续可以修改、组合这个 AST
   ```

**何时使用 `@mc_code`**：
1. **宏的最终输出**：宏必须使用 `@mc_code` 输出生成的代码（必须使用，或使用语法糖）
   ```uya
   @mc_code(ast);  // 显式输出
   // 或使用语法糖（简单情况）
   42;  // 自动转换为 @mc_code(@mc_ast( 42 ))
   ```
2. **简单代码直接输出**：生成简单代码时可以使用语法糖或显式写法
   ```uya
   true;  // 语法糖：自动转换为 @mc_code(@mc_ast( true ))
   // 或显式写法
   @mc_code(@mc_ast( true ));  // 一步到位
   ```
3. **条件分支的输出**：在不同条件下输出不同的代码时
   ```uya
   if condition {
       @mc_code(@mc_ast( branch1 ));
   } else {
       @mc_code(@mc_ast( branch2 ));
   }
   ```

**典型工作流程**：

```uya
mc complex_macro(param) struct {
    // 步骤1：处理参数，转换为 AST
    const param_ast = @mc_ast(param);
    
    // 步骤2：构建代码模板（使用 @mc_ast）
    const template_ast = @mc_ast({
        fn process_${param_ast}(self: &Self) void {
            // 复杂逻辑...
        }
    });
    
    // 步骤3：输出最终代码（使用 @mc_code）
    @mc_code(template_ast);
}
```

**常见模式**：

- **模式1：简单输出（使用语法糖）**
  ```uya
  mc simple() expr {
      42;  // 语法糖：自动转换为 @mc_code(@mc_ast( 42 ))
  }
  
  // 或显式写法（等价）
  mc simple_explicit() expr {
      @mc_code(@mc_ast( 42 ));  // 显式写法
  }
  ```

- **模式2：模板构建（分步）**
  ```uya
  mc template(param) struct {
      const param_ast = @mc_ast(param);      // 步骤1：转换参数
      const code_ast = @mc_ast({ ... });      // 步骤2：构建模板
      @mc_code(code_ast);                     // 步骤3：输出
  }
  ```

- **模式3：复杂组合（多步处理）**
  ```uya
  mc complex() struct {
      const parts = [];
      for items |item| {
          parts.push(@mc_ast({ ... }));       // 收集多个 AST
      }
      const combined = @mc_ast({             // 组合 AST
          ${parts[0]};
          ${parts[1]};
      });
      @mc_code(combined);                     // 最终输出
  }
  ```

**总结**：
- `@mc_ast` 用于**构建和操作**代码模板（AST），支持插值和组合
- `@mc_code` 用于**最终输出**，将 AST 转换为代码
- **语法糖**：简单宏可以直接返回表达式或语句，编译器自动包装为 `@mc_code(@mc_ast(...))`
- 一般流程：`@mc_ast` 构建模板 → `@mc_code` 输出代码
- 简单情况可以使用语法糖，复杂情况需要显式使用 `@mc_code(@mc_ast(...))`

#### 25.4.7 `@mc_error(msg)`

**编译时错误报告函数**
- **功能**：立即终止编译并显示错误信息
- **用途**：宏内断言、参数验证、约束检查

#### 25.4.8 `@mc_get_env(name)`

**编译时环境变量读取函数**
- **功能**：读取编译时环境变量值
- **参数**：`name` - 环境变量名（必须是字符串常量）
- **返回**：环境变量值的字符串表示，如果未设置则返回空字符串
- **特性**：
  - 仅在编译时可用，运行时不可用
  - 读取的值在编译期确定，可用于条件编译
  - 支持缓存：相同环境变量名在同一编译会话中返回相同值

```uya
// 使用示例（显式写法）
mc debug_mode() expr {
    const debug = @mc_get_env("DEBUG");
    if debug == "1" or debug == "true" {
        @mc_code(@mc_ast( true ));
    } else {
        @mc_code(@mc_ast( false ));
    }
}

// 使用语法糖的简化写法（等价）
mc debug_mode_simple() expr {
    const debug = @mc_get_env("DEBUG");
    if debug == "1" or debug == "true" {
        true;  // 语法糖：自动转换为 @mc_code(@mc_ast( true ))
    } else {
        false;  // 语法糖：自动转换为 @mc_code(@mc_ast( false ))
    }
}

// 配置宏
mc config_value(key: expr, default: expr) expr {
    const key_str = @mc_eval(key);
    const env_value = @mc_get_env(key_str);
    
    if env_value != "" {
        // 根据默认值类型解析环境变量
        const default_type = @mc_type(default);
        match default_type.kind {
            .Integer => {
                const int_val = @mc_parse_int(env_value);
                @mc_code(@mc_ast( ${@mc_ast(int_val)} ));
            }
            .Bool => {
                const bool_val = env_value == "true" or env_value == "1";
                @mc_code(@mc_ast( ${@mc_ast(bool_val)} ));
            }
            else => {
                @mc_code(@mc_ast( "${env_value}" ));
            }
        }
    } else {
        @mc_code(@mc_ast( ${default} ));
    }
}

// 使用
const IS_DEBUG: bool = debug_mode();
const API_URL: *byte = config_value("API_URL", "https://api.example.com");
const TIMEOUT_MS: i32 = config_value("TIMEOUT_MS", 5000);
```

### 25.5 返回值类型语义

| 返回标签 | 生成代码类型 | 调用位置 |
|---------|-------------|----------|
| `expr` | 表达式 | 需要表达式的地方 |
| `stmt` | 语句 | 语句位置 |
| `struct` | 结构体成员 | 结构体定义块内 |
| `type` | 类型标识符 | 类型注解位置 |

### 25.6 编译时控制流

宏体内可使用常规控制流，判断条件通常需在编译时可求值。

```uya
mc specialize(val) expr {
    const v = @mc_eval(val);
    if v > 10 {
        @mc_code(@mc_ast( complex_op(${@mc_ast(v)}) ));
    } else {
        @mc_code(@mc_ast( simple_op(${@mc_ast(v)}) ));
    }
}
```

#### 25.6.1 编译期 for over TypeInfo.fields

在宏体内，对 `@mc_type(T)` 得到的 TypeInfo 的 `fields` 可进行**编译期展开**的 for 循环：将 `for info.fields |field| { body }` 在宏展开阶段展开为顺序执行的块 `{ body_0; body_1; ... ; body_{n-1} }`，其中 `body_i` 为第 i 个字段对应的 body 副本，且循环变量 `field` 的成员访问在每轮中被替换为当前字段的元数据。

**语法形式**：`for expr.fields |var| { body }`

**触发条件**（须同时满足）：

- `expr` **必须为标识符**（即 `.fields` 的受体为简单变量名，如 `info`）。若受体为表达式（如 `(get_info()).fields`），则不触发编译期展开，按普通 for 语义处理，不报错。
- 该标识符在当前宏上下文中绑定到 **TypeInfo 结构体字面量**（即来自 `const info = @mc_type(T);` 的 `info`）。结构体名须与编译器生成 TypeInfo 时使用的名字一致（当前为 `"TypeInfo"`）。
- **仅宏体顶层的 for** 触发展开：只对宏体块中直接出现的 `for info.fields |var|` 做展开，不递归进 body 内部再展开内层同类 for。

**不触发**：`for 0..n |i|`（范围 for）；受体非标识符；标识符未绑定或绑定的不是 TypeInfo；非顶层 for。上述情况保持普通 for 语义。

**替换语义**：在每一轮展开的 `body_i` 中：

- `var.name`：替换为**以当前字段名为名的标识符 AST**（用于生成如 `self.$(field.name)` 的代码）。
- `var.type_name`：替换为**表示当前字段类型的类型 AST**（如 `AST_TYPE_NAMED`，仅简单类型名），用于生成类型注解或调用。

**展开结果**：原 for 语句被替换为一个块，块内为 n 条语句（n = TypeInfo.field_count），每条为 body 的一份拷贝（经上述替换）。该块作为整体参与后续宏展开；若宏的返回标签为 `stmt` 或 `struct` 且该块为「最后一个有效语句」，则**整个块**作为宏的单一输出。

**示例**（语义说明，具体实现依赖编译器支持）：

```uya
struct Point { x: i32; y: f64; }

mc gen_serialize(T: type) stmt {
    const info = @mc_type(T);
    for info.fields |f| {
        @mc_code(@mc_ast(
            buffer.write_${f.type_name}(self.${f.name});
        ));
    }
}
// 展开后等价于（Point 有两个字段时）：
// { buffer.write_i32(self.x); buffer.write_f64(self.y); }
```

### 25.7 宏与函数的区别

| 维度 | 宏 (`mc`) | 普通函数 (`fn`) |
|------|-----------|----------------|
| 执行时机 | 编译时 | 运行时 |
| 操作对象 | 代码（语法树） | 数据（值） |
| 可用函数 | 仅 `@mc_` 前缀函数 | 所有运行时函数 |
| 错误处理 | `@mc_error` 终止编译 | `catch` 运行时处理 |
| 输出 | 生成代码片段 | 返回值 |

### 25.8 缓存机制

#### 25.8.1 自动缓存

Uya 编译器自动对宏调用结果进行缓存，遵循以下规则：

1. **相同调用缓存**：相同宏名 + 完全相同参数值 → 复用上次展开结果
2. **参数值相等性**：参数必须是编译时常量，通过 `@mc_eval` 求值后比较相等性
3. **类型安全缓存**：宏的返回标签也作为缓存键的一部分

#### 25.8.2 缓存键组成

```
缓存键 = 宏名 + 参数值元组 + 返回标签 + 编译器上下文哈希
```

#### 25.8.3 缓存失效条件

1. 源代码变更（宏定义或调用位置）
2. 编译器版本变更
3. 编译器选项变更
4. 宏依赖的外部文件变更（如果宏读取了外部文件）
5. 环境变量变更（对于使用 `@mc_get_env` 的宏）

#### 25.8.4 手动缓存控制

```uya
// 使用 @mc_no_cache 标记不缓存的宏
@[no_cache]
mc dynamic_date() expr {
    // 每次展开都重新计算
    const current_date = @mc_eval_system("date +%Y%m%d");
    @mc_code(@mc_ast( ${@mc_ast(current_date)} ));
}

// 使用 @mc_cache_key 自定义缓存键
@[cache_key = "version_${VERSION}"]
mc versioned_feature() stmt {
    // 根据版本号缓存
}

// 环境变量敏感的宏会自动跟踪依赖
mc env_dependent() expr {
    const mode = @mc_get_env("MODE");  // 编译器自动跟踪此依赖
    @mc_code(@mc_ast( "${mode}" ));
}
```

#### 25.8.5 缓存性能收益

- **编译速度**：重复宏调用直接使用缓存，避免重复展开
- **内存使用**：相同展开结果共享内存表示
- **增量编译**：缓存结果可用于增量编译，加速重新编译

#### 25.8.6 缓存验证

编译器在复用缓存前进行验证：
1. 验证宏定义未更改
2. 验证宏依赖未更改（包括环境变量）
3. 验证类型上下文兼容

### 25.9 安全限制

1. **递归深度限制**：默认 32 层
2. **总展开次数限制**：默认 10,000 次
3. **嵌套层数限制**：默认 8 层
4. **环境变量访问限制**：只能访问白名单中的环境变量（可通过编译器选项配置）

超出限制立即终止编译。可通过编译器参数调整。

### 25.10 完整示例

#### 25.10.1 编译时断言宏

```uya
// 基本编译时断言
mc const_assert(cond: expr, msg: expr = "assertion failed") stmt {
    if !@mc_eval(cond) { @mc_error(@mc_eval(msg)); }
}

// 带缓存的编译时断言
mc cached_assert(cond: expr) stmt {
    // 相同cond值会被缓存
    if !@mc_eval(cond) { @mc_error("assertion failed"); }
}

// 使用示例
const_assert(@size_of(i32) == 4, "i32必须是4字节");
const_assert(1 + 1 == 2);
cached_assert(@align_of(f64) == 8);  // 相同检查会被缓存
```

#### 25.10.2 类型驱动代码生成

```uya
// 自动生成结构体序列化代码
mc generate_serializer(T: type) struct {
    const info = @mc_type(T);
    
    // 缓存键包含类型信息，相同类型T会复用生成的代码
    match info.kind {
        .Struct => {
            // 为每个字段生成序列化代码
            const fields_code = [];
            for info.fields |field| {
                const field_serializer = @mc_ast(
                    buffer.write_${field.type.name}(self.${field.name})
                );
                fields_code.push(field_serializer);
            }
            
            const method_ast = @mc_ast({
                fn serialize(self: &Self, buffer: &mut Serializer) void {
                    ${fields_code[0]};
                    ${fields_code[1]};
                    // ... 更多字段
                }
            });
            @mc_code(method_ast);
        }
        
        .Integer => {
            const method_ast = @mc_ast({
                fn serialize(self: &Self, buffer: &mut Serializer) void {
                    buffer.write_int(self);
                }
            });
            @mc_code(method_ast);
        }
        
        else => @mc_error("类型 ${info.name} 不支持序列化");
    }
}

// 使用示例
struct Point {
    x: i32,
    y: i32,
    
    // 在结构体内部调用宏
    generate_serializer(Point);  // 生成serialize方法
}

// 编译器会为每个不同的类型T缓存生成的代码
```

#### 25.10.3 编译时向量类型生成器

```uya
// 编译时生成类型安全的向量容器
mc vector_type(T: type, name: ident) type {
    const info = @mc_type(T);
    
    // 验证类型约束
    if !info.is_copy && !info.has_drop {
        @mc_error("类型 ${T} 必须实现 Copy 或 Drop");
    }
    
    // 生成向量结构体定义
    @mc_code(@mc_ast(
        struct ${name} {
            data: &${T},
            len: usize,
            cap: usize,
            
            fn new() Self {
                return ${name} {
                    data: null,
                    len: 0,
                    cap: 0,
                };
            }
            
            fn push(self: &mut Self, value: ${T}) void {
                // 自动生成增长逻辑
                if self.len >= self.cap {
                    const new_cap = if self.cap == 0 { 4 } else { self.cap * 2 };
                    const new_data = @alloc(${T}, new_cap);
                    if self.data != null {
                        @memcpy(new_data, self.data, self.len * @size_of(${T}));
                        @free(self.data);
                    }
                    self.data = new_data;
                    self.cap = new_cap;
                }
                self.data[self.len] = value;
                self.len += 1;
            }
            
            fn pop(self: &mut Self) union Option<${T}> {
                if self.len == 0 {
                    return .None;
                }
                self.len -= 1;
                return .Some(self.data[self.len]);
            }
            
            fn drop(self: Self) void {
                if self.data != null {
                    // 如果T有drop，需要调用每个元素的drop
                    if ${info.has_drop} {
                        for 0..self.len |i| {
                            self.data[i].drop();
                        }
                    }
                    @free(self.data);
                }
            }
        }
    ));
}

// 使用示例 - 相同类型参数会被缓存
vector_type(i32, IntVec);      // 生成 IntVec 类型
vector_type(f64, FloatVec);    // 生成 FloatVec 类型

const vec1: IntVec = IntVec.new();
const vec2: IntVec = IntVec.new();  // 复用缓存的 IntVec 类型定义
```

#### 25.10.4 编译时查询表生成

```uya
// 生成编译时查询表，利用缓存避免重复计算
mc lookup_table(name: ident, size: expr, generator: expr) struct {
    const table_size = @mc_eval(size);
    
    // 生成静态查找表
    const table_ast = @mc_ast(
        const ${name}: [i32: ${table_size}] = [
            ${@mc_ast(generator(0))},
            ${@mc_ast(generator(1))},
            ${@mc_ast(generator(2))},
            // ... 更多元素
        ]
    );
    
    @mc_code(table_ast);
}

// 辅助宏：生成特定函数的查找表
mc sin_table(name: ident, size: expr) struct {
    const n = @mc_eval(size);
    
    // 生成sin函数查找表
    @mc_code(@mc_ast(
        const ${name}: [f32: ${n}] = [
            ${@mc_ast(@mc_sin(0.0))},
            ${@mc_ast(@mc_sin(0.1))},
            // ... 更多值
        ]
    ));
}

// 使用示例
lookup_table(SQUARES, 10, |i| i * i);  // 生成平方表
sin_table(SIN_VALUES, 100);            // 生成sin值表

// 在代码中多次使用相同表 - 会复用缓存的展开结果
fn use_table() void {
    const x = SQUARES[5];  // 25
    const y = SIN_VALUES[42];
}
```

#### 25.10.5 错误处理宏

```uya
// 自动错误传播宏，带缓存
mc try_or_default(expr: expr, default: expr) expr {
    const result_type = @mc_type(expr);
    
    if !result_type.is_error_union {
        @mc_error("try_or_default 仅适用于返回错误联合类型的表达式");
    }
    
    const default_ast = @mc_ast(default);
    
    // 生成带错误处理的表达式
    @mc_code(@mc_ast(
        ${expr} catch {
            return ${default_ast};
        }
    ));
}

// 带错误上下文的宏
mc try_with_context(expr: expr, context: expr) expr {
    const context_str = @mc_eval(context);
    
    @mc_code(@mc_ast(
        ${expr} catch |err| {
            log_error("${context_str}: ", err);
            return err;
        }
    ));
}

// 使用示例
fn parse_config() !Config {
    const content = try_with_context(read_file("config.json"), "读取配置文件");
    const parsed = try_or_default(parse_json(content), Config.default());
    return parsed;
}
```

#### 25.10.6 编译时配置系统（使用 @mc_get_env）

```uya
// 编译时配置读取宏
mc config_value(key: expr, default: expr) expr {
    const key_str = @mc_eval(key);
    
    // 尝试从编译时环境读取
    const env_value = @mc_get_env(key_str);
    
    if env_value != "" {
        // 根据default的类型解析环境变量值
        const default_type = @mc_type(default);
        
        match default_type.kind {
            .Integer => {
                const int_val = @mc_parse_int(env_value);
                @mc_code(@mc_ast( ${@mc_ast(int_val)} ));
            }
            .Bool => {
                const bool_val = env_value == "true" or env_value == "1";
                @mc_code(@mc_ast( ${@mc_ast(bool_val)} ));
            }
            else => {
                @mc_code(@mc_ast( "${env_value}" ));
            }
        }
    } else {
        // 使用默认值
        @mc_code(@mc_ast( ${default} ));
    }
}

// 平台检测宏
mc target_platform() expr {
    const platform = @mc_get_env("TARGET_PLATFORM");
    
    match platform {
        "windows" => @mc_code(@mc_ast( .WINDOWS ));
        "linux" => @mc_code(@mc_ast( .LINUX ));
        "macos" => @mc_code(@mc_ast( .MACOS ));
        else => @mc_code(@mc_ast( .UNKNOWN ));
    }
}

// 使用示例
const DEBUG: bool = config_value("DEBUG", false);
const PORT: i32 = config_value("PORT", 8080);
const HOST: *byte = config_value("HOST", "localhost");
const PLATFORM: Platform = target_platform();

// 相同配置键会使用缓存值
const ALSO_PORT: i32 = config_value("PORT", 8080);  // 复用缓存的展开结果

// 条件编译示例
if PLATFORM == .LINUX {
    // Linux特定代码
} else if PLATFORM == .WINDOWS {
    // Windows特定代码
}
```

#### 25.10.7 功能标志宏

```uya
// 基于环境变量的功能标志
mc feature_enabled(feature: expr) expr {
    const feature_name = @mc_eval(feature);
    const env_var = @mc_get_env("FEATURE_" + feature_name);
    
    if env_var == "1" or env_var == "true" or env_var == "on" {
        @mc_code(@mc_ast( true ));
    } else {
        @mc_code(@mc_ast( false ));
    }
}

// 版本检查宏
mc version_check(min_version: expr) expr {
    const min_ver = @mc_eval(min_version);
    const current_ver = @mc_get_env("COMPILER_VERSION");
    
    if current_ver >= min_ver {
        @mc_code(@mc_ast( true ));
    } else {
        @mc_error("需要编译器版本 ${min_ver} 或更高，当前为 ${current_ver}");
    }
}

// 使用示例
const USE_AVX2: bool = feature_enabled("AVX2");
const USE_SIMD: bool = feature_enabled("SIMD");

// 编译器版本检查
version_check("0.39.0");  // 如果编译器版本低于0.39.0，编译失败

// 条件代码生成
if USE_AVX2 {
    // 生成AVX2优化的代码路径
} else if USE_SIMD {
    // 生成通用SIMD代码路径
} else {
    // 生成纯标量代码路径
}
```

### 25.11 最佳实践

#### 25.11.1 编译时断言

```uya
mc const_assert(cond: expr, msg: expr) stmt {
    if !@mc_eval(cond) { @mc_error(@mc_eval(msg)); }
}
```

#### 25.11.2 类型驱动代码生成

```uya
mc generate_serializer(T) struct {
    const info = @mc_type(T);
    match info.kind {
        .Struct => {
            // 为结构体生成序列化代码
        }
        .Integer => {
            // 为整数生成序列化代码
        }
        else => @mc_error("不支持的类型");
    }
}
```

#### 25.11.3 宏与函数协作

```uya
// 运行时函数：核心算法
fn fast_hash(data: &[u8]) u64 { ... }

// 编译时宏：生成特化调用
mc hash_string(s) expr {
    @mc_code(@mc_ast( fast_hash(${@mc_ast(s)}.as_bytes()) ));
}
```

#### 25.11.4 环境变量使用指南

1. **明确命名**：使用清晰的环境变量名，如 `DEBUG_MODE` 而不是 `DEBUG`
2. **默认值**：总是提供合理的默认值
3. **类型安全**：根据使用场景正确解析环境变量值
4. **文档化**：在项目文档中说明可用的环境变量
5. **安全限制**：生产构建中限制可访问的环境变量

### 25.12 设计原则总结

1. **编译时执行**：零运行时开销，所有宏在编译时展开
2. **缓存优化**：相同宏调用自动缓存，提升编译性能
3. **类型安全**：所有生成代码通过严格类型检查
4. **环境集成**：通过 `@mc_get_env` 支持编译时配置
5. **显式控制**：明确区分编译时与运行时操作
6. **失败快速终止**：错误在编译时立即暴露，避免运行时问题
7. **可控的元编程**：通过安全限制和缓存机制防止滥用

### 25.13 一句话总结

> **Uya 宏系统 = 编译时元编程 + 类型反射 + 智能缓存 + 环境集成**；  
> **零运行时开销，编译期确定性，坚如磐石。**

---

## 29 扩展特性

### 29.1 核心特性（计划中）
- **官方包管理器**：`uyapm`
  - 依赖管理和包分发系统
  - 支持版本管理和依赖解析

### 29.2 drop 机制增强
- **drop 标记**：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能

### 29.3 类型系统增强
- **类型推断增强**：局部类型推断
  - 函数内支持类型推断，函数签名仍需显式类型
  - 提高代码简洁性，保持可读性
  - 示例：`const x = 10;` 自动推断为 `i32`（注意：当前不支持类型推断，需要显式类型注解）
- **指针下标访问语法糖**：`ptr[i]` 是 `*(ptr + i)` 的语法糖
  - **语法**：`ptr[i]` 展开为 `*(ptr + i)`，与 C 语言一致
  - **边界检查**：与指针算术相同，需要证明 `i >= 0 && i < len`
  - **编译期展开**：编译期展开，无额外开销
  - **示例**：
[examples/example_142.uya](./examples/example_142.uya)
- **结构体方法语法糖**：`obj.method()` 语法糖
  - 允许使用 `obj.method()` 语法调用结构体相关的静态函数
  - 编译期展开为 `method(obj, ...)` 静态函数调用
  - 所有方法都是静态绑定，编译期确定，不涉及动态派发
  - **定义方式**：支持两种方式定义方法
    - **方式1：结构体内部定义**：方法定义在结构体花括号内，与字段定义并列
      - 语法：`struct StructName { field: Type, fn method(self: &Self) ReturnType { ... } }`
    - **方式2：结构体外部定义**：使用块语法在结构体定义后添加方法
      - 语法：`StructName { fn method(self: &Self) ReturnType { ... } }`
      - 可以在结构体定义之后的任何位置添加方法
    - `self` 参数必须显式声明，使用指针：`self: &Self` 或 `self: &StructName`
    - **推荐使用 `Self` 占位符**：`self: &Self` 更简洁、与接口实现语法一致，符合 Uya 的"显式控制"设计原则
      - `self: &Self`：使用 `Self` 占位符，编译期替换为具体类型（如 `self: *Point`），与接口实现语法一致（推荐）
      - `self: &StructName`：使用具体类型，语义清晰一致（也可用）
      - **不允许按值传递**：不支持 `self: StructName`，避免语义歧义（签名说按值但调用时用引用）
    - **方法调用与移动语义**：
      - 方法签名必须是 `fn method(self: &Self)` 或 `fn method(self: &StructName)`，调用时传递指针（`&obj`），不触发移动
      - 方法调用后，原对象仍然可以使用，符合常见的方法调用语义
    - 编译期将方法展开为普通函数：`Self` 占位符会被替换为具体类型，如 `fn StructName_method(self: &StructName) ReturnType { ... }`
    - 调用 `obj.method()` 展开为 `StructName_method(&obj)`（传递指针，不移动）
  - **接口方法作为结构体方法**：
    - 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
    - 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义
    - 结构体方法（包括接口方法）都使用相同的语法：`StructName { fn method(self: &Self) ReturnType { ... } }`
    - 方法签名使用 `Self` 占位符（如 `self: &Self`），编译期替换为具体类型
    - 接口方法会生成 vtable，支持动态派发
    - 普通结构体方法编译期展开为静态函数
  - **完整示例**：
[examples/point_1.uya](./examples/point_1.uya)
  - **与接口实现共存示例**（展示两者可以同时使用，无冲突）：
[examples/point_2.uya](./examples/point_2.uya)
  - **编译期展开规则**：
    - `struct A { fn method(self: &Self) void { ... } }` → `fn A_method(self: *A) void { ... }`（`Self` 替换为 `A`）
    - `A { fn method(self: &Self) void { ... } }` → `fn A_method(self: *A) void { ... }`（`Self` 替换为 `A`）
    - `obj.method()` → `A_method(&obj)`（传递指针，不移动 `obj`）
    - `obj.method(arg)` → `A_method(&obj, arg)`（传递指针，不移动 `obj`）
    - **推荐使用指针和 Self**：`self: &Self` 更简洁，符合 Uya 的"显式控制"原则
    - `Self` 是编译期占位符，会被替换为具体的结构体类型（如 `Point`）
    - 方法仍然是普通函数，可以像普通函数一样调用：`A_method(&obj)` 或 `A_method(obj)`（如果明确需要移动）
    - 如果需要移动对象，必须显式调用：`A_method(obj)`（直接传递值，会移动）
    - 接口方法作为结构体方法定义，编译器会生成 vtable 支持动态派发
- **结构体字段访问**：通过接口值访问结构体字段
  - 允许通过接口值访问底层结构体的字段（如 `interface_value.field`）
  - 需要运行时类型信息或编译期类型擦除支持
  - 示例：`const writer: IWriter = console; const fd: i32 = writer.fd;`（访问底层 Console 的 fd 字段）
- **接口组合**：接口可以组合其他接口
  - 支持接口组合语法，一个接口可以包含其他接口的方法
  - **语法**：在接口体中直接列出被组合的接口名，用分号分隔（如 `IReader; IWriter;`）
  - **编译期验证**：编译器在编译期检查结构体是否实现了所有组合接口的方法，验证失败即编译错误
  - 实现接口组合的结构体需要实现所有组合接口的方法，编译器在结构体定义时声明接口时验证
  - **vtable 生成**：组合接口的 vtable 包含所有被组合接口的方法，编译期生成
  - **编译期处理**：接口组合完全在编译期处理，运行时与普通接口相同
  - 示例：
[examples/file_6.uya](./examples/file_6.uya)

### 29.4 AI 友好性增强
- **标准库文档字符串**：注释式或结构化文档
  - 帮助 AI 理解函数用途、参数、返回值
  - 提高代码生成准确性
- **更丰富的错误信息**：详细的错误描述和修复建议
  - 类型错误、作用域错误、语法错误的详细说明
  - 提供修复建议，帮助 AI 和用户快速定位问题

### 29.5 已实现特性
以下特性已实现，详见对应章节：
- ✅ **模块系统**：第 1.5 章 - 模块系统
- ✅ **泛型**：第 24 章 - Uya 泛型增量文档
- ✅ **显式宏**：第 25 章 - Uya 显式宏（可选增量）
- ✅ **@size_of**：第 16 章 - 标准库（内置函数，以 @ 开头）
- ✅ **@align_of**：第 16 章 - 标准库（内置函数，以 @ 开头）
- ✅ **类型别名**：第 24 章 6.2 节 - 类型别名实现
- ✅ **for 循环**：第 8 章 - for 循环迭代（简化语法：`for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}`）
- ✅ **运算符简化**：第 10 章 - `try` 关键字用于溢出检查，饱和运算符（`+|`, `-|`, `*|`），包装运算符（`+%`, `-%`, `*%`）
- ✅ **测试单元**：第 28 章 - Uya 测试单元（Test Block）

---

## 附录 A. 完整示例

本附录包含各种语言特性的完整示例代码，这些示例展示了 Uya 语言在实际使用中的常见模式和最佳实践。

### A.1 结构体 + 栈数组 + FFI

[examples/a1_struct_array_ffi.uya](./examples/a1_struct_array_ffi.uya)

编译运行示例：[examples/example_146.txt](./examples/example_146.txt)

---

### A.2 错误处理 + defer/errdefer

[examples/a2_error_handling.uya](./examples/a2_error_handling.uya)

---

### A.3 默认安全并发

[examples/a3_concurrent_safe.uya](./examples/a3_concurrent_safe.uya)

---

### A.4 联合体示例

```uya
// A.4.1 基本联合体使用
union IntOrFloat {
    i: i32,
    f: f64
}

fn basic_union_example() void {
    // 创建联合体
    const int_val = IntOrFloat.i(42);
    const float_val = IntOrFloat.f(3.14159);
    
    // 模式匹配访问
    match int_val {
        .i(x) => printf("整数: %d\n", x),
        .f(x) => printf("浮点: %f\n", x)
    }
    
    // 直接访问（已知标签）
    var v: IntOrFloat = IntOrFloat.i(10);
    const x: i32 = v.i;  // ✅
    
    v = IntOrFloat.f(3.14);
    const y: f64 = v.f;  // ✅
}

// A.4.2 网络数据包示例
union NetworkPacket {
    ipv4: [byte: 4],
    ipv6: [byte: 16],
    raw: *byte,
    error: *byte
}

fn process_packet(packet: NetworkPacket) !void {
    match packet {
        .ipv4(addr) => {
            printf("IPv4: %d.%d.%d.%d\n", addr[0], addr[1], addr[2], addr[3]);
        },
        .ipv6(addr) => {
            printf("IPv6: ");
            for 0..16 |i| {
                printf("%02x", addr[i]);
                if i % 2 == 1 && i < 15 { printf(":"); }
            }
            printf("\n");
        },
        .raw(ptr) => {
            printf("原始数据: %p\n", ptr);
            // 处理原始数据
        },
        .error(msg) => {
            printf("错误包: %s\n", msg);
            return error.InvalidPacket;
        }
    }
}

// A.4.3 与 C 互操作示例
extern union CData {
    integer: i32,
    floating: f64,
    text: [i8: 32]
}

extern process_c_data(data: union CData) void;

fn ffi_example() void {
    // 创建 Uya 联合体
    const uya_data: union CData = union CData.integer(100);
    
    // 直接传递给 C 函数
    process_c_data(uya_data);
    
    // 接收 C 联合体
    extern get_c_data() union CData;
    const c_data: union CData = get_c_data();
    
    // 模式匹配处理
    match c_data {
        .integer(val) => printf("C 整数: %d\n", val),
        .floating(val) => printf("C 浮点: %f\n", val),
        .text(str) => printf("C 文本: %s\n", &str[0])
    }
}

// A.4.4 联合体方法示例
union ConfigValue {
    int_val: i32,
    float_val: f64,
    bool_val: bool,
    str_val: [i8: 64]
}

ConfigValue {
    fn to_string(self: &Self) [i8: 128] {
        match *self {
            .int_val(x) => "int=${x}",
            .float_val(x) => "float=${x:.2f}",
            .bool_val(x) => x ? "true" : "false",
            .str_val(s) => "str=${s}"
        }
    }
    
    fn is_truthy(self: &Self) bool {
        match *self {
            .int_val(x) => x != 0,
            .float_val(x) => x != 0.0,
            .bool_val(x) => x,
            .str_val(s) => @len(s) > 0
        }
    }
}

// 主函数
fn main() !i32 {
    basic_union_example();
    
    const packet1 = NetworkPacket.ipv4([192, 168, 1, 1]);
    try process_packet(packet1);
    
    const packet2 = NetworkPacket.ipv6([
        0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00,
        0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34
    ]);
    try process_packet(packet2);
    
    ffi_example();
    
    const config = ConfigValue.int_val(42);
    const str = config.to_string();
    printf("配置值: %s\n", &str[0]);
    printf("是否为真: %s\n", config.is_truthy() ? "是" : "否");
    
    return 0;
}
```

---

### A.5 其他示例

for循环、切片语法、多维数组的完整示例请参考对应章节。

---

## 附录 B. 扩展特性

### B.1 泛型语法

**语法规范**：

- **使用尖括号**：`<T>`
- **约束紧邻参数**：`<T: Ord>`
- **多约束连接**：`<T: Ord + Clone + Default>`

#### B.1.1 函数泛型

```uya
fn max<T: Ord>(a: T, b: T) T {
    if a > b { return a; }
    return b;
}

// 调用
const result: i32 = max<i32>(10, 20);
```

#### B.1.2 结构体泛型

```uya
struct Vec<T: Default> {
    data: &T,
    len: i32,
    cap: i32
}

// 实例化
const v: Vec<i32> = Vec<i32>{ data: null, len: 0, cap: 0 };
```

#### B.1.3 接口泛型

```uya
interface Iterator<T> {
    fn next(self: &Self) union Option<T>;
}
```

#### B.1.4 方法泛型（v0.47 新增）

结构体/联合体方法支持独立的泛型参数，与结构体泛型参数分离：

```uya
// 泛型结构体 + 泛型方法
struct Container<T> {
    value: T,
    
    // 泛型方法：将 T 转换为 U
    fn as_type<U>(self: &Self) U {
        return self.value as U;
    }
    
    // 非泛型方法
    fn get(self: &Self) T {
        return self.value;
    }
    
    // 多类型参数方法
    fn wrap<U>(self: &Self, other: U) Pair<T, U> {
        return Pair<T, U>{ first: self.value, second: other };
    }
}

// 调用泛型方法
const c: Container<i32> = Container<i32>{ value: 42 };
const v: i64 = c.as_type<i64>();  // 显式指定 U = i64
const p: Pair<i32, i32> = c.wrap<i32>(100);  // U = i32
```

**设计说明**：
- 泛型方法通过单态化实现，编译时生成专门函数
- 方法类型参数与结构体类型参数独立，形成二级查找
- `Self` 类型在方法内自动替换为当前结构体的单态化类型

---

## 附录 C. 交叉编译（工具链）

本节描述 **Uya 编译器所在宿主** 与 **生成代码最终运行的目标平台** 不一致时的工具链用法，属于**实现与构建说明**，不改变语言语义。更完整的命令示例、包装脚本与注意事项见 **[UYA_BUILD_RUN.md](./UYA_BUILD_RUN.md)**。

### C.1 模型

1. **Uya 编译器**始终在 **宿主（host）** 上运行，将 `.uya` 编译为 **C99**。
2. **链接与生成可执行文件**由 **C 编译器驱动**（`CC_DRIVER`）完成；交叉编译时，必须使用能针对**目标（target）** 产出对象文件与可执行文件的 C 工具链（如 `zig cc -target <triple>`、Clang `--target=…`、或专用交叉 `gcc`）。
3. 编译器内部的 **`std.host_os` / `std.host_arch`** 等对应 **目标** 平台配置（由 `TARGET_OS` / `TARGET_ARCH` 等推导），用于条件编译与 `@asm_target()` 等；**宿主**仅影响「能否运行 `uya` 二进制」本身。

### C.2 环境变量（与根目录 `Makefile`、`src/compile.sh` 一致）

| 变量 | 含义 |
|------|------|
| `HOST_OS` / `HOST_ARCH` | 运行编译器的机器；默认由 `uname` 探测（OS 名会规范为 `linux` / `macos` / `windows` 等）。 |
| `TARGET_OS` / `TARGET_ARCH` | 生成代码面向的平台；**默认等于宿主**，与宿主不同时即为交叉编译场景。 |
| `TARGET_TRIPLE` | 可选。若设置且未设置 `CC_TARGET_FLAGS`，`compile.sh` 会为 C 驱动追加 **`-target <triple>`**（适用于 `zig cc` 等）。 |
| `CC_DRIVER` | 实际调用的 C 编译器命令，可为多词（如 `zig cc`）。 |
| `CC_TARGET_FLAGS` | 传给 C 驱动的额外参数（如 `-target aarch64-linux-gnu`）；若已手动设置，则不再根据 `TARGET_TRIPLE` 自动追加 `-target`。 |
| `TOOLCHAIN` | `system`（默认 `cc`）或 `zig`（使用 `ZIG` 指向的 `zig cc`）。 |
| `ZIG` | `zig` 可执行文件路径（项目默认值仅作示例，请按本机安装路径覆盖）。 |
| `RUNTIME_MODE` | `hosted`（默认，链接 libc）或 `nostdlib`（独立运行时路径；**当前主要支持 Linux x86_64**，其余目标可能受限或未实现）。 |
| `LINK_MODE` | 如 `default` / `static`，影响 `compile.sh` 链接行为（与 hosted 路径配合）。 |

### C.3 构建 Uya 编译器自身（自举）

在源码树中构建 `bin/uya` 时，将上述变量传给 `make`，再由 `make` 传入 `src/compile.sh`：

```bash
# 示例：使用 zig cc，目标为 Windows x86_64（宿主可为 Linux）
TOOLCHAIN=zig ZIG=/path/to/zig \
TARGET_OS=windows TARGET_ARCH=x86_64 \
TARGET_TRIPLE=x86_64-windows-gnu \
make uya-hosted
```

```bash
# 示例：目标为 Apple Silicon macOS
TOOLCHAIN=zig ZIG=/path/to/zig \
TARGET_OS=macos TARGET_ARCH=arm64 \
TARGET_TRIPLE=aarch64-macos-none \
make uya-hosted
```

```bash
# 示例：目标为 Intel macOS
TOOLCHAIN=zig ZIG=/path/to/zig \
TARGET_OS=macos TARGET_ARCH=x86_64 \
TARGET_TRIPLE=x86_64-macos-none \
make uya-hosted
```

原生宿主构建仍可使用默认 `make uya` / `make uya-hosted`（系统 `cc` 或 `TOOLCHAIN=zig`）。

### C.4 编译 Uya 应用程序

使用已生成的 `bin/uya` 编译用户程序并**自动链接**时，需开启 **`-e`**（或包装脚本），使 `compile.sh` 在生成 `.c` 后调用 `CC_DRIVER`：

```bash
CC_DRIVER="/path/to/zig cc" \
CC_TARGET_FLAGS="-target aarch64-linux-gnu" \
bin/uya build main.uya -o main.c --c99 -e
```

若仅生成 C 而不链接，可不用 `-e`，再用自备的交叉工具链手动编译 `.c`。

### C.5 限制与注意

- **`@syscall`（C99 后端）**：已支持生成 **Linux x86_64**、**Linux AArch64**、**Linux ARM32（EABI）**、**macOS x86_64** 与 **macOS arm64** 的 hosted 路径；Darwin 目标当前仍以 hosted bring-up 为主，不等同于 `--nostdlib` 已完成。
- **`--nostdlib` / 静态零依赖路径**：当前实现与测试主线以 **Linux x86_64** 为主；其他目标的 `_start`、链接与 syscall 封装可能未完备，见 [UYA_BUILD_RUN.md](./UYA_BUILD_RUN.md) 与平台相关 todo 文档。
- **Darwin 真机验证**：Linux 上通过 `zig cc` 交叉产出 Mach-O 二进制，说明构建链已成立；但 `getcwd`、`stat/readdir`、`pthread`、`std.async` 等行为仍需在 macOS 真机上继续 smoke 与收口。
- **内联汇编 `@asm`**：指令与约束与目标 ISA 相关；交叉编译时需确保仅启用当前 **TARGET** 支持的指令，或使用 `@asm_target()` 等机制区分平台（见 [asm_api_reference.md](./asm_api_reference.md) 等）。
- **标准库与系统调用**：`libc` / `syscall` / 异步等模块依赖目标 OS/ABI；交叉到嵌入式或非常规环境时需自行核对链接库与运行时。

---

## 术语表

### 核心概念

- **UB (Undefined Behavior)**：未定义行为。在 Uya 语言中，所有 UB 必须被编译期证明为安全，否则编译错误。

- **RAII (Resource Acquisition Is Initialization)**：资源获取即初始化。Uya 语言通过 `drop` 机制实现 RAII，资源在作用域结束时自动释放。

- **FFI (Foreign Function Interface)**：外部函数接口。Uya 语言通过 `extern` 关键字声明和调用 C 函数，实现与 C 代码的互操作。

- **vtable (Virtual Table)**：虚函数表。接口系统使用 vtable 实现动态派发，所有 vtable 在编译期生成，零运行时注册。

### 类型系统

- **联合体（union）**：一种复合类型，可以存储多种变体中的一种，所有变体共享同一内存区域。Uya 联合体通过编译期标签跟踪确保类型安全。

- **变体（variant）**：联合体中的一种可能类型。每个变体有名称和类型，如 `IntOrFloat.i` 中的 `.i` 变体。

- **编译期标签跟踪**：Uya 编译器在编译期跟踪联合体当前活跃的变体标签，用于确保类型安全的访问。

- **模式匹配（pattern matching）**：访问联合体的主要方式，通过 `match` 表达式处理所有可能的变体。

- **标签状态（tag state）**：编译器内部跟踪的联合体标签状态，包括已知标签、未知标签或多个可能标签。

- **类型双关（type punning）**：通过一种类型写入联合体，然后通过另一种类型读取。Uya 禁止类型双关，必须通过显式模式匹配。

- **C 联合体互操作**：Uya 联合体与 C 语言 union 具有相同的内存布局，可以直接相互转换和传递。

- **错误联合类型 (`!T`)**：表示 `T | Error` 的联合类型，用于函数错误返回。`!i32` 表示返回 `i32` 或 `Error`。

- **原子类型 (`atomic T`)**：语言级原子类型，所有读/写/复合赋值操作自动生成原子指令，零运行时锁。

- **接口值**：8/16 字节结构体（平台相关），包含 vtable 指针(4/8B) 和数据指针(4/8B)，用于动态派发；32位平台=8B，64位平台=16B。

- **`usize`**：平台相关的无符号整数类型，用于表示内存地址、数组索引和大小。32位平台为 `u32`（4字节），64位平台为 `u64`（8字节）。

### 编译相关

- **编译期证明**：编译器在编译期验证代码的安全性，证明失败则报编译错误并给出修改建议。

- **路径敏感分析**：编译器跟踪所有代码路径，分析变量状态和条件分支，建立约束条件。

- **常量折叠**：编译期常量直接求值，溢出/越界立即报错。

- **单态化**：泛型函数/结构体在调用时根据具体类型生成对应的代码，零运行时派发。

### 内存管理

- **栈式数组**：使用 `var buf: [T: N] = [];` 在栈上分配数组，零 GC，生命周期由作用域决定。

- **drop**：资源清理函数，在作用域结束时自动调用，实现 RAII 模式。

- **defer/errdefer**：延迟执行语句，在作用域结束时（或错误返回时）执行清理代码。块内禁止 `return`、`break`、`continue` 等控制流语句，只做清理不改变控制流。

### 错误处理

- **`try` 关键字**：错误传播和溢出检查关键字。用于传播错误联合类型的错误，或对算术运算进行溢出检查（溢出时返回 `error.Overflow`）。

- **`catch` 语法**：错误捕获语法，用于处理错误联合类型的返回值。语法形式：`expr catch |err| { statements }` 或 `expr catch { statements }`。

- **预定义错误**：使用 `error ErrorName;` 在顶层声明的错误类型，属于全局命名空间，可在多个模块间共享。

- **运行时错误**：使用 `error.ErrorName` 语法直接创建的错误，无需预先声明，编译器在编译期自动收集。

### 并发

- **原子操作**：硬件级原子指令，保证操作的原子性，无需锁。

- **数据竞争**：多个线程同时访问同一内存位置，且至少有一个是写操作。Uya 语言通过 `atomic T` 消除数据竞争。

### 其他

- **`Self`**：接口方法签名和结构体方法签名中的特殊占位符，代表当前结构体类型。在接口定义和结构体方法的方法签名中使用。

- **`@max`/`@min` 内置函数**：访问整数类型极值的编译器内置函数（以 `@` 开头）。编译器从上下文类型自动推断极值类型，这些是编译期常量。例如：`const MAX: i32 = @max;`（`@max` 从类型注解 `i32` 推断为 i32 的最大值）。

- **饱和运算符**：`+|`（饱和加法）、`-|`（饱和减法）、`*|`（饱和乘法）。溢出时返回类型的最大值或最小值（上溢返回最大值，下溢返回最小值），而不是返回错误。

- **编译期展开**：某些操作在编译期完成。例如字符串插值的缓冲区大小计算、`try` 关键字的溢出检查展开。

- **编译期证明**：编译器在当前函数内验证安全性，证明失败则报编译错误并给出修改建议。常量错误仍然直接报错。

---
