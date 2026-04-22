# Uya 内置函数使用文档

> 版本：v0.49.45（2026-04-22）  
> 此文档为 uya.md 的详细补充说明  
> 语言规范：0.49.45  
> 所有内置函数均以 `@` 开头，由编译器识别，无需导入或声明；其实现阶段与运行时开销以各章节说明为准。`@c_import` 也是 `@` 前缀的编译器内建能力，但它是**顶层构建指令**，不是表达式函数

---

## 目录

- [1. 类型反射函数](#1-类型反射函数)
  - [@size_of](#size_of)
  - [@align_of](#align_of)
  - [@len](#len)
- [2. 整数极值函数](#2-整数极值函数)
  - [@max](#max)
  - [@min](#min)
- [3. 源代码位置函数](#3-源代码位置函数)
  - [@src_name](#src_name)
  - [@src_path](#src_path)
  - [@src_line](#src_line)
  - [@src_col](#src_col)
  - [@func_name](#func_name)
  - [@embed](#embed)
  - [@embed_dir](#embed_dir)
  - [@c_import](#c_import)
- [4. 可变参数函数](#4-可变参数函数)
  - [@params](#params)
  - [@va_start](#va_start)
  - [@va_end](#va_end)
  - [@va_arg](#va_arg)
  - [@va_copy](#va_copy)
- [5. 宏编译时函数](#5-宏编译时函数)
  - [@mc_eval](#mc_eval)
  - [@mc_type](#mc_type)
  - [@mc_ast](#mc_ast)
  - [@mc_code](#mc_code)
  - [@mc_error](#mc_error)
  - [@mc_get_env](#mc_get_env)
- [6. 错误处理函数](#6-错误处理函数)
  - [@error_id](#error_id)
- [7. 调试打印函数](#7-调试打印函数)
  - [@print](#print)
  - [@println](#println)
- [8. 异步编程函数](#8-异步编程函数)
  - [@async_fn](#async_fn)
  - [@await](#await)
  - [@frame](#frame)
- [9. 裸函数属性](#9-裸函数属性)
  - [@naked_fn](#naked_fn)
- [10. 内联汇编函数](#10-内联汇编函数)
  - [@asm](#asm)
- [11. SIMD 向量内建](#11-simd-向量内建)
  - [@vector](#vector)
  - [@mask](#mask)

---

## 1. 类型反射函数

### @size_of

**函数签名**：
```uya
fn @size_of(Type) i32
fn @size_of(expr) i32
```

**功能描述**：
返回类型的字节大小（编译期常量）。支持传入类型名或表达式。

**参数**：
- `Type`：任意类型名（基础类型、数组、结构体、切片等）
- `expr`：任意表达式（从表达式推断类型）

**返回值**：
- `i32` 类型，表示类型的字节大小
- 编译期常量，零运行时开销

**使用示例**：
```uya
// 基础类型
const size_i32: i32 = @size_of(i32);        // 4
const size_i64: i32 = @size_of(i64);        // 8
const size_f32: i32 = @size_of(f32);        // 4
const size_bool: i32 = @size_of(bool);      // 1

// 数组类型
const size_arr: i32 = @size_of([i32: 10]);  // 40 (10 * 4)

// 结构体类型
struct Point {
    x: i32,
    y: i32
}
const size_point: i32 = @size_of(Point);    // 8 (4 + 4)

// 切片类型
const size_slice: i32 = @size_of(&[i32]);   // 8/16（32位/64位平台）

// 表达式
var x: i32 = 10;
const size_x: i32 = @size_of(x);            // 4

// 指针类型
const size_ptr: i32 = @size_of(&i32);       // 4/8（32位/64位平台）
```

**注意事项**：
- 对齐规则与 C99 一致
- 结构体大小包含填充字节
- 切片类型大小 = 指针大小 + 长度字段大小（平台相关）

---

### @align_of

**函数签名**：
```uya
fn @align_of(Type) i32
fn @align_of(expr) i32
```

**功能描述**：
返回类型的对齐字节数（编译期常量）。

**参数**：
- `Type`：任意类型名
- `expr`：任意表达式（从表达式推断类型）

**返回值**：
- `i32` 类型，表示类型的对齐字节数
- 编译期常量，零运行时开销

**使用示例**：
```uya
// 基础类型
const align_i8: i32 = @align_of(i8);        // 1
const align_i16: i32 = @align_of(i16);      // 2
const align_i32: i32 = @align_of(i32);      // 4
const align_i64: i32 = @align_of(i64);      // 8
const align_f64: i32 = @align_of(f64);      // 8

// 结构体类型
struct Mixed {
    a: i8,      // 对齐 1
    b: i32,     // 对齐 4
    c: i16      // 对齐 2
}
const align_mixed: i32 = @align_of(Mixed);  // 4（取最大对齐）

// 数组类型（与元素类型对齐相同）
const align_arr: i32 = @align_of([i32: 10]); // 4

// 指针类型
const align_ptr: i32 = @align_of(&i32);     // 4/8（平台相关）
```

**注意事项**：
- 对齐规则与 C99 一致
- 结构体对齐 = max(所有字段对齐)
- 数组对齐 = 元素类型对齐

---

### @len

**函数签名**：
```uya
fn @len(array: [T: N]) i32
fn @len(slice: &[T]) i32
fn @len(slice: &[T: N]) i32
```

**功能描述**：
返回数组或切片的元素个数。对于数组是编译期常量，对于切片是运行时值。

**参数**：
- `array`：固定大小数组
- `slice`：切片引用

**返回值**：
- `i32` 类型
- 对于数组：编译期常量 `N`
- 对于切片：运行时值（访问切片的 `.len` 字段）

**使用示例**：
```uya
// 固定数组（编译期常量）
var arr: [i32: 10] = [];
const len1: i32 = @len(arr);                // 10

// 空数组字面量（从声明获取大小）
var buffer: [i32: 100] = [];
const len2: i32 = @len(buffer);             // 100（不是 0！）

// 多维数组
var matrix: [[i32: 5]: 3] = [];
const rows: i32 = @len(matrix);             // 3
const cols: i32 = @len(matrix[0]);          // 5

// 切片（运行时值）
fn process(data: &[i32]) void {
    const count: i32 = @len(data);          // 运行时访问 data.len
    // ...
}

// 已知长度的切片
fn process_fixed(data: &[i32: 10]) void {
    const count: i32 = @len(data);          // 10（编译期常量）
}
```

**注意事项**：
- **空数组字面量**：`var x: [T: N] = [];` 时，`@len(x)` 返回 `N`，不是 0
- 对于切片，等价于访问 `.len` 字段
- 对于数组，在编译期求值，零运行时开销

---

## 2. 整数极值函数

### @max

**函数签名**：
```uya
@max  // 类型从上下文推断
```

**功能描述**：
返回整数类型的最大值（编译期常量）。类型从赋值上下文自动推断。

**参数**：
- 无参数，类型通过上下文推断

**返回值**：
- 推断出的整数类型
- 编译期常量，零运行时开销

**使用示例**：
```uya
// 有符号整数
const max_i8: i8 = @max;        // 127
const max_i16: i16 = @max;      // 32767
const max_i32: i32 = @max;      // 2147483647
const max_i64: i64 = @max;      // 9223372036854775807

// 无符号整数
const max_u8: u8 = @max;        // 255
const max_u16: u16 = @max;      // 65535
const max_u32: u32 = @max;      // 4294967295
const max_u64: u64 = @max;      // 18446744073709551615

// 在表达式中使用
fn clamp(value: i32, min_val: i32, max_val: i32) i32 {
    if value < min_val {
        return min_val;
    }
    if value > max_val {
        return max_val;
    }
    return value;
}

// 边界检查
fn safe_add(a: i32, b: i32) !i32 {
    if b > 0 && a > (@max - b) {
        return error.Overflow;
    }
    return a + b;
}
```

**注意事项**：
- 必须有明确的类型上下文（变量声明、函数参数等）
- 仅支持整数类型（i8, i16, i32, i64, u8, u16, u32, u64）
- 如果类型无法推断，会产生编译错误

---

### @min

**函数签名**：
```uya
@min  // 类型从上下文推断
```

**功能描述**：
返回整数类型的最小值（编译期常量）。类型从赋值上下文自动推断。

**参数**：
- 无参数，类型通过上下文推断

**返回值**：
- 推断出的整数类型
- 编译期常量，零运行时开销

**使用示例**：
```uya
// 有符号整数
const min_i8: i8 = @min;        // -128
const min_i16: i16 = @min;      // -32768
const min_i32: i32 = @min;      // -2147483648
const min_i64: i64 = @min;      // -9223372036854775808

// 无符号整数
const min_u8: u8 = @min;        // 0
const min_u16: u16 = @min;      // 0
const min_u32: u32 = @min;      // 0
const min_u64: u64 = @min;      // 0

// 在表达式中使用
fn abs(value: i32) i32 {
    if value == @min {
        // 特殊处理：i32 最小值的绝对值无法表示为 i32
        return @max;
    }
    if value < 0 {
        return -value;
    }
    return value;
}
```

**注意事项**：
- 必须有明确的类型上下文
- 仅支持整数类型
- 无符号类型的 `@min` 总是 0

---

## 3. 源代码位置函数

### @src_name

**函数签名**：
```uya
fn @src_name() &[i8]
```

**功能描述**：
返回当前源文件的文件名（不包含路径），编译期展开为字符串常量。

**参数**：
- 无参数

**返回值**：
- `&[i8]` 类型（字节切片）
- 编译期字符串常量，零运行时开销

**使用示例**：
```uya
extern printf(fmt: *byte, ...) i32;

fn debug_info() void {
    const filename: &[i8] = @src_name;
    printf("File: %s\n" as *byte, filename);
}

fn main() i32 {
    debug_info();  // 输出：File: main.uya
    return 0;
}
```

**注意事项**：
- 仅包含文件名，不包含路径
- 编译期展开为字符串常量
- 字符串常量自动收集并生成到输出文件中

---

### @src_path

**函数签名**：
```uya
fn @src_path() &[i8]
```

**功能描述**：
返回当前源文件的完整路径，编译期展开为字符串常量。

**参数**：
- 无参数

**返回值**：
- `&[i8]` 类型（字节切片）
- 编译期字符串常量，零运行时开销

**使用示例**：
```uya
extern printf(fmt: *byte, ...) i32;

fn log_location() void {
    const path: &[i8] = @src_path;
    const line: i32 = @src_line;
    printf("Location: %s:%d\n" as *byte, path, line);
}

fn main() i32 {
    log_location();  // 输出：Location: /path/to/main.uya:10
    return 0;
}
```

**注意事项**：
- 包含完整的文件路径（编译时的路径）
- 路径格式取决于编译环境（Unix: `/`, Windows: `\`）

---

### @src_line

**函数签名**：
```uya
fn @src_line() i32
```

**功能描述**：
返回当前代码所在的行号，编译期展开为整数常量。

**参数**：
- 无参数

**返回值**：
- `i32` 类型
- 编译期整数常量，零运行时开销

**使用示例**：
```uya
extern printf(fmt: *byte, ...) i32;

fn assert_impl(condition: bool, msg: *byte, line: i32) void {
    if !condition {
        printf("Assertion failed at line %d: %s\n" as *byte, line, msg);
        // 触发断言失败处理
    }
}

// 自定义断言宏（伪代码，实际需要宏系统）
fn main() i32 {
    const x: i32 = 10;
    
    // 手动传递行号
    if !(x > 0) {
        assert_impl(false, "x must be positive" as *byte, @src_line);
    }
    
    printf("Current line: %d\n" as *byte, @src_line);  // 输出当前行号
    return 0;
}
```

**注意事项**：
- 行号从 1 开始
- 每次调用 `@src_line` 都会展开为调用处的行号

---

### @src_col

**函数签名**：
```uya
fn @src_col() i32
```

**功能描述**：
返回当前代码所在的列号，编译期展开为整数常量。

**参数**：
- 无参数

**返回值**：
- `i32` 类型
- 编译期整数常量，零运行时开销

**使用示例**：
```uya
extern printf(fmt: *byte, ...) i32;

fn main() i32 {
    const line: i32 = @src_line;
    const col: i32 = @src_col;
    
    printf("Position: line %d, column %d\n" as *byte, line, col);
    return 0;
}
```

**注意事项**：
- 列号从 1 开始
- 指向 `@src_col` 标记的起始位置

---

### @func_name

**函数签名**：
```uya
fn @func_name() &[i8]
```

**功能描述**：
返回当前函数的名称，编译期展开为字符串常量。仅能在函数体内使用。

**参数**：
- 无参数

**返回值**：
- `&[i8]` 类型（字节切片）
- 编译期字符串常量，零运行时开销

**使用示例**：
```uya
extern printf(fmt: *byte, ...) i32;

fn trace_enter() void {
    const func: &[i8] = @func_name;
    const line: i32 = @src_line;
    printf("Entering %s at line %d\n" as *byte, func, line);
}

fn process_data(data: &[i32]) void {
    const func: &[i8] = @func_name;
    printf("Function: %s\n" as *byte, func);  // 输出：Function: process_data
    // ...
}

fn main() i32 {
    const func: &[i8] = @func_name;
    printf("Main function: %s\n" as *byte, func);  // 输出：Main function: main
    
    trace_enter();     // 输出：Entering trace_enter at line ...
    process_data(null);
    return 0;
}
```

**注意事项**：
- **仅能在函数体内使用**，在函数外使用会产生编译错误
- 返回的是函数的原始名称（不包含修饰符）
- 对于 `main` 函数，返回 `"main"`

**错误示例**：
```uya
// 编译错误：@func_name 只能在函数体内使用
const global_func: &[i8] = @func_name;  // ❌ 错误！

fn valid_usage() void {
    const local_func: &[i8] = @func_name;  // ✓ 正确
}
```

---

### @embed

**函数签名**：
```uya
fn @embed(path: string_literal) &[const byte]
```

**功能描述**：
编译期读取单个普通文件，并将其原始字节直接嵌入到最终输出中。

**参数**：
- `path`：字符串字面量路径；相对路径相对于当前源文件所在目录解析

**返回值**：
- `&[const byte]` 只读切片

**使用示例**：
```uya
const cert: &[const byte] = @embed("assets/cert.der");

fn main() i32 {
    if @len(cert) == 0 {
        return 1;
    }
    return cert.ptr[0] as i32;
}
```

**注意事项**：
- 参数必须是字符串字面量
- 内容不追加结尾 `0`
- 支持二进制零字节
- 目标必须是普通文件，目录会报错

---

### @embed_dir

**函数签名**：
```uya
fn @embed_dir(path: string_literal) &[const EmbedDirEntry]
```

**功能描述**：
编译期递归读取目录中的普通文件，返回目录条目切片。

**内建条目结构**：
```uya
struct EmbedDirEntry {
    path: &[const byte],
    data: &[const byte],
}
```

**参数**：
- `path`：字符串字面量目录路径；相对路径相对于当前源文件所在目录解析

**返回值**：
- `&[const EmbedDirEntry]` 只读切片

**使用示例**：
```uya
const assets: &[const EmbedDirEntry] = @embed_dir("assets");

fn main() i32 {
    if @len(assets) == 0 {
        return 1;
    }
    return assets.ptr[0].data.ptr[0] as i32;
}
```

**注意事项**：
- 目录递归遍历
- 条目按相对路径字典序排序
- `path` 使用 `/` 作为分隔符
- 目录中的 symlink 和特殊文件会报错

---

### @c_import

**指令签名**：
```uya
@c_import(path: string_literal);
@c_import(path: string_literal, cflags: string_literal);
@c_import(path: string_literal, cflags: string_literal, ldflags: string_literal);
```

**功能描述**：
顶层构建指令。把外部 C 源文件纳入当前程序构建图，或把某个目录下递归收集到的全部 `*.c` 纳入构建图。

**参数**：
- `path`：字符串字面量；可指向单个 `.c` 文件，或一个目录
- `cflags`：可选；只作用于该导入展开出的 C 文件
- `ldflags`：可选；只在最终链接阶段聚合

**使用示例**：
```uya
@c_import("fixtures/c_import/add_impl.c");
@c_import("fixtures/c_import/dir");
@c_import("fixtures/c_import/flag_impl.c", "-DC_IMPORT_MAGIC=7");

extern fn add_i32(a: i32, b: i32) i32;
extern fn add_magic_i32(x: i32) i32;
```

**目录模式规则**：
- 递归收集目录下全部 `*.c`
- 结果按相对路径字典序稳定排序
- 允许 symlink，只要最终 target 是 regular `.c`
- 若目录中没有任何 `*.c`，编译报错

**输出与构建行为**：
- `uya build/run/test -o app`：编译器会自动编译这些 C translation unit 并参与最终链接
- `uya build -o app.c --c99`：除主 `app.c` 外，还会生成 `app.cimports.sh`
- `--split-c-dir` / 默认 split-C：Makefile 直接包含额外 C object 规则，不会额外生成 sidecar

**注意事项**：
- 只能在顶层使用
- 参数必须是字符串字面量
- 它不自动导入 C 声明；仍需手写 `extern fn` / `extern struct`
- `cflags`/`ldflags` 在实现上按 ASCII 空白做 token 化，不支持依赖 shell quoting 的复杂写法

---

## 4. 可变参数函数

### @params

**函数签名**：
```uya
@params  // 在可变参数函数内部使用
```

**功能描述**：
在可变参数函数内部访问可变参数列表。这是一个特殊的内置标识符，表示 `va_list` 类型的参数。

**使用场景**：
- 用于实现类似 `printf` 的可变参数函数
- 与 FFI 的 `va_start`、`va_arg`、`va_end` 配合使用

**使用示例**：
```uya
// 外部 C 函数声明
extern va_start(ap: &void, last_param: &void) void;
extern va_arg(ap: &void, type_size: i32) i32;
extern va_end(ap: &void) void;
extern printf(fmt: *byte, ...) i32;

// Uya 可变参数函数
fn my_printf(fmt: *byte, ...) void {
    // @params 代表可变参数列表
    var ap: &void = @params;
    
    // 使用 C 的 va_* 函数处理
    printf(fmt, ap);
}

fn sum_ints(count: i32, ...) i32 {
    var result: i32 = 0;
    var ap: &void = @params;
    
    var i: i32 = 0;
    while i < count {
        const value: i32 = va_arg(ap, @size_of(i32));
        result = result + value;
        i = i + 1;
    }
    
    return result;
}

fn main() i32 {
    my_printf("Hello, %s!\n" as *byte, "World" as *byte);
    
    const total: i32 = sum_ints(3, 10, 20, 30);
    printf("Total: %d\n" as *byte, total);  // 输出：Total: 60
    
    return 0;
}
```

**注意事项**：
- 仅在声明为 `...` 的可变参数函数内有效
- 需要配合 `@va_start`、`@va_end` 或 C 的 `va_*` 函数使用
- 类型安全需要手动保证（与 C 可变参数相同）

---

#### @va_* 声明汇总

| 内置 | 声明 | C 等价 | 说明 |
|------|------|--------|------|
| `@va_start` | `@va_start(&ap, last)` | `va_start(ap, last)` | 初始化 va_list，`last` 为最后一个命名参数 |
| `@va_end` | `@va_end(&ap)` | `va_end(ap)` | 结束 va_list 访问，必须与 `@va_start` 成对 |
| `@va_arg` | `@va_arg(ap, Type)` | `va_arg(ap, type)` | 按类型获取下一个参数，如 `@va_arg(ap, i32)` |
| `@va_copy` | `@va_copy(&dest, src)` | `va_copy(dest, src)` | 复制 va_list（新增） |

**完整用法示例**（纯 Uya 实现 vprintf 包装）：
```uya
extern "libc" fn vfprintf(stream: *void, format: *const byte, ap: *void) i32;

fn my_fprintf(stream: &FILE, fmt: &const byte, ...) i32 {
    var ap: [byte: 32] = [];
    @va_start(&ap[0] as &void, fmt);
    const ret: i32 = vfprintf(stream as *void, fmt, &ap[0] as &void);
    @va_end(&ap[0] as &void);
    return ret;
}
```

**遍历可变参数示例**（使用 @va_arg）：
```uya
fn sum_n(n: i32, ...) i32 {
    var ap: [byte: 32] = [];
    @va_start(&ap[0] as &void, n);
    var s: i32 = 0;
    var i: i32 = 0;
    while i < n {
        s = s + @va_arg(&ap[0] as &void, i32);
        i = i + 1;
    }
    @va_end(&ap[0] as &void);
    return s;
}
// 调用: sum_n(3, 10, 20, 30) → 60
```

---

### @va_start

**声明**：`@va_start(&ap, last)`  
**函数签名**：
```uya
@va_start(ap: &va_list, last: &T) void
```

**功能描述**：
在可变参数函数内初始化 va_list。编译时展开为 C 的 `va_start(ap, last)` 宏。

**使用场景**：
- 实现类似 printf 的可变参数包装
- 将可变参数传递给 vfprintf、vsnprintf 等接受 va_list 的 C 函数

**使用示例**：
```uya
export extern "libc" fn vfprintf(stream: *void, format: &const byte, ap: va_list) i32;

fn my_vfprintf(stream: &FILE, format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);  // format 是最后一个命名参数
    const ret: i32 = vfprintf(stream as *void, format, ap);
    @va_end(&ap);
    return ret;
}
```

**注意事项**：
- 仅在可变参数函数（形参含 `...`）内有效
- `ap` 是 `va_list` 类型变量，`&ap` 传递其地址
- `last` 必须为最后一个命名参数（如 format）
- 与 `@va_end` 成对使用，确保每个 `@va_start` 都有对应 `@va_end`

---

### @va_end

**声明**：`@va_end(&ap)`  
**函数签名**：
```uya
@va_end(ap: &va_list) void
```

**功能描述**：
结束对 va_list 的访问。编译时展开为 C 的 `va_end(ap)` 宏。必须与 `@va_start` 或 `@va_copy` 成对调用。

**使用示例**：
```uya
fn process_varargs(fmt: &const byte, ...) void {
    var ap: va_list = va_list{};
    @va_start(&ap, fmt);
    // 使用 va_list 传递给 vprintf 等...
    @va_end(&ap);
}
```

**注意事项**：
- 每个 `@va_start` 或 `@va_copy` 必须有对应的 `@va_end`
- 在函数返回前必须调用 `@va_end`，包括所有返回路径

---

### @va_arg

**声明**：`@va_arg(ap, Type)`，如 `@va_arg(ap, i32)`、`@va_arg(ap, &byte)`  
**函数签名**：
```uya
@va_arg(ap: va_list, Type) T
```

**功能描述**：
从 va_list 获取下一个参数，类型由第二个参数指定。编译时展开为 C 的 `va_arg(ap, type)` 宏。

**参数**：
- `ap`：`va_list` 类型（由 `@va_start` 初始化或作为参数传入）
- `Type`：期望的参数类型（如 `i32`、`i64`、`&byte`、`f64` 等）

**返回值**：
- 类型与 `Type` 一致
- 每次调用会推进 va_list 到下一个参数

**使用场景**：
1. 在可变参数函数内（与 `@va_start` 配合）
2. 在接收 `va_list` 参数的函数内

**使用示例**：
```uya
// 场景1：可变参数函数
fn sum_ints(count: i32, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, count);
    var total: i32 = 0;
    var i: i32 = 0;
    while i < count {
        const val: i32 = @va_arg(ap, i32);
        total = total + val;
        i = i + 1;
    }
    @va_end(&ap);
    return total;
}

// 场景2：接收 va_list 参数的函数
fn my_vprintf(format: &const byte, ap: va_list) i32 {
    // 可以直接使用 @va_arg
    const first_arg: i32 = @va_arg(ap, i32);
    // ...
    return 0;
}
```

**支持的类型**：
- `i32`、`i64`、`usize`：整数类型
- `&byte`、`&void`：指针类型
- `f64`：双精度浮点（C 可变参数中 float 提升为 double）

**注意事项**：
- 类型必须与实际传入参数一致，否则未定义行为（与 C 相同）
- 可变参数默认提升：`char`/`short` → `int`，`float` → `double`

---

### @va_copy

**声明**：`@va_copy(&dest, src)`  
**函数签名**：
```uya
@va_copy(dest: &va_list, src: va_list) void
```

**功能描述**：
复制 va_list，用于多次遍历同一组可变参数。编译时展开为 C 的 `va_copy(dest, src)` 宏。

**使用示例**：
```uya
fn measure_and_print(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);
    
    // 复制 va_list 以便多次遍历
    var ap_copy: va_list = va_list{};
    @va_copy(&ap_copy, ap);
    
    // 第一次遍历：计算需要的长度
    const needed: i32 = _calc_length(format, ap_copy);
    @va_end(&ap_copy);
    
    // 第二次遍历：实际输出
    const result: i32 = _do_output(format, ap);
    @va_end(&ap);
    
    return result;
}
```

**注意事项**：
- 每个 `@va_copy` 必须有对应的 `@va_end`
- 复制的 va_list 独立于原 va_list，可以独立遍历

---

## 5. 宏编译时函数

> **状态**：语法解析已实现，CPS 变换和求值引擎待实现  
> **参考**：规范 §25 宏系统

### @mc_eval

**函数签名**：
```uya
fn @mc_eval(expr) T  // 编译时求值
```

**功能描述**：
在编译时对表达式求值，返回求值结果。仅能在宏定义 (`mc`) 内部使用。

**参数**：
- `expr`：任意编译期可求值的表达式

**返回值**：
- 表达式的求值结果
- 类型由表达式决定

**使用示例**：
```uya
// 编译时计算斐波那契数
mc fib(n: i32) i32 {
    if n <= 1 {
        return n;
    }
    const a: i32 = @mc_eval(fib(n - 1));
    const b: i32 = @mc_eval(fib(n - 2));
    return a + b;
}

fn main() i32 {
    const fib10: i32 = fib(10);  // 编译时计算，结果 55
    return fib10;
}
```

**注意事项**：
- 仅在宏定义内使用
- 表达式必须在编译期可求值
- 递归求值受编译器递归深度限制

---

### @mc_type

**函数签名**：
```uya
fn @mc_type(expr) TypeInfo
```

**功能描述**：
在编译时获取表达式的类型信息，返回 `TypeInfo` 结构体。

**返回值**：`TypeInfo` 结构体，定义见标准库 `lib/std/macro_typeinfo.uya`（未 use 时由 codegen 自动生成同构内置定义）；**获取 fields 数组大小请用 `@len(info.fields)`**（不导出容量常量）：

```uya
struct FieldInfo { name: *i8; type_name: *i8; }
struct TypeInfo { ...; fields: [FieldInfo: 64]; }
```

**使用示例**：
```uya
mc print_type_info(expr) void {
    const info: TypeInfo = @mc_type(expr);
    @mc_eval(printf("Type: %s, Size: %d, Align: %d\n" as *byte, 
                     info.name, info.size, info.align));
}

fn main() i32 {
    var x: i32 = 10;
    print_type_info(x);  // 输出：Type: i32, Size: 4, Align: 4
    return 0;
}
```

---

### @mc_ast

**函数签名**：
```uya
fn @mc_ast(code) ASTNode
```

**功能描述**：
将代码片段转换为抽象语法树（AST）。

**使用示例**：
```uya
mc generate_getter(field_name) code {
    const ast: ASTNode = @mc_ast({
        fn get_field() i32 {
            return self.field_name;
        }
    });
    return @mc_code(ast);
}
```

---

### @mc_code

**函数签名**：
```uya
fn @mc_code(ast: ASTNode) code
```

**功能描述**：
将抽象语法树转换为代码。

---

### @mc_source

**函数签名**：
```uya
fn @mc_source(expr) *i8
```

**功能描述**：
在宏内、编译期将表达式序列化为源码形式字符串（与字符串字面量类型一致，如 `*i8`；字符串字面量可赋值给 `[byte: N]`、`&byte`、`*byte`，自动带 `\0` 结尾，见 uya.md §1.4）。结果为规范表示（如运算符两侧有空格），不保证与源文件字节完全一致。

**使用示例**：
```uya
mc to_string(e: expr) expr {
    @mc_source(e);
}
// to_string(a > 0)  =>  "a > 0"
```

---

### @mc_error

**函数签名**：
```uya
fn @mc_error(msg: *byte) void
```

**功能描述**：
在编译时报告错误。

**使用示例**：
```uya
mc check_positive(n: i32) void {
    if n <= 0 {
        @mc_error("Value must be positive");
    }
}
```

---

### @mc_get_env

**函数签名**：
```uya
fn @mc_get_env(key: *byte) *byte
```

**功能描述**：
在编译时获取环境变量。

**使用示例**：
```uya
mc get_build_env() *byte {
    return @mc_get_env("BUILD_ENV");
}
```

---

## 6. 错误处理函数

### @error_id

**函数签名**：
```uya
fn @error_id(err: error) u32
```

**功能描述**：
提取错误值的数值 ID。对语言级错误值（如 `error.NamedFailure`）返回编译器分配的错误 ID；对 `@syscall` 失败路径捕获到的错误值，返回底层 errno 数值。

**参数**：
- `err`：`error` 类型表达式

**返回值**：
- `u32` 类型，表示错误值的数值 ID

**使用示例**：
```uya
use libc.ENOENT;

error NamedFailure;

const SYS_open: i64 = 2;
const O_RDONLY: i64 = 0;

fn open_missing_file_errno() !u32 {
    const path: *byte = "/nonexistent";
    const result: !i64 = @syscall(SYS_open, path as i64, O_RDONLY, 0);
    _ = result catch |err| {
        return @error_id(err);
    };
    return 0;
}

fn main() i32 {
    const named_id: u32 = @error_id(error.NamedFailure);
    const errno_id: u32 = open_missing_file_errno() catch { return 1; };

    if named_id == 0 || errno_id != ENOENT as u32 {
        return 2;
    }
    return 0;
}
```

**注意事项**：
- 参数必须是 `error` 类型，不能直接传 `!T`；若手里是错误联合值，需先 `catch |err|` 或 `match` 取出错误值
- 当参数是 `error.NamedFailure` 这类错误字面量时，可直接用于记录或比较对应 ID
- 当参数来自 `@syscall` 的错误路径时，可直接与 `libc.EAGAIN`、`libc.ENOENT` 等 errno 常量比较

---

## 7. 调试打印函数

### @print

**函数签名**：
```uya
fn @print(expr) i32
```

**功能描述**：
将表达式值打印到标准输出（不换行）。编译时展开为 `printf` 调用，返回 `printf` 的返回值（输出的字符数，负值表示错误）。

**参数**：
- `expr`：要打印的表达式，支持以下类型：
  - 整数类型：`i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`usize`
  - 浮点类型：`f32`、`f64`
  - 布尔类型：`bool`
  - **C 风格字节串**（**0.49.41** 与实现对齐）：元素为 **`i8` / `u8` / `byte`** 的 **`&[T]`**、**`[T: N]`**；**`*byte`**（及指向 **`i8`** 的 FFI 指针，与现有规则一致）；字面量 **`"..."`**。其中 **`[byte: N]`**、**`&[byte]`** 变量以 **`%s`** 打印（需以 **`\\0`** 结尾的缓冲区行为与 C 一致）。并且在**字符串插值段** `${...}` 中，**`&const byte`** 与 **`&[const byte]`** 也按 **`%s`** 作为 C 字符串输出（同样要求包含结尾 **`\\0`**）。
  - 字符串插值：`"text${expr}text"`

**返回值**：
- `i32` 类型，表示 `printf` 返回的字符数
- 负值表示输出错误

**使用示例**：
```uya
fn main() i32 {
    // 整数
    @print(42);           // 输出: 42
    @print(-100);         // 输出: -100
    
    // 浮点数
    @print(3.14);         // 输出: 3.14
    
    // 布尔值
    @print(true);         // 输出: 1
    @print(false);        // 输出: 0
    
    // 字符串
    @print("Hello");      // 输出: Hello
    
    // 变量
    const x: i32 = 100;
    @print(x);            // 输出: 100
    
    // 表达式
    @print(x + 50);       // 输出: 150
    
    // 字符串插值
    const name: &byte = "Uya";
    @print("Hello, ${name}!");  // 输出: Hello, Uya!
    
    return 0;
}
```

**格式化输出**：
```uya
fn main() i32 {
    const x: i32 = 10;
    const y: i32 = 20;
    
    // 手动格式化
    @print("x = ");
    @print(x);
    @print(", y = ");
    @print(y);
    @println("");  // 换行
    // 输出: x = 10, y = 20
    
    // 使用字符串插值
    @println("x = ${x}, y = ${y}");  // 更简洁
    
    return 0;
}
```

**类型转换打印**：
```uya
fn main() i32 {
    // 指定整数类型
    @println(42 as i64);     // 按 i64 格式打印
    @println(42 as u32);     // 按无符号格式打印
    
    // 十六进制输出（通过插值格式）
    const hex_val: i32 = 255;
    @println("hex = ${hex_val:#x}");  // 输出: hex = ff
    @println("HEX = ${hex_val:#X}");  // 输出: HEX = FF
    
    return 0;
}
```

**注意事项**：
- 不支持自定义结构体、联合体等复合类型
- 不换行，如需换行请使用 `@println` 或手动打印 `"\n"`
- 返回值可用于检测输出错误

---

### @println

**函数签名**：
```uya
fn @println(expr) i32
```

**功能描述**：
将表达式值打印到标准输出并换行。等同于 `@print(expr)` 后输出换行符。

**参数**：
- `expr`：要打印的表达式，支持类型与 `@print` 相同

**返回值**：
- `i32` 类型，表示 `printf` 返回的字符数（含换行符）

**使用示例**：
```uya
fn main() i32 {
    // 基础用法
    @println(42);              // 输出: 42\n
    @println("Hello");         // 输出: Hello\n
    @println(true);            // 输出: 1\n
    
    // 浮点数
    @println(3.14159);         // 输出: 3.14159\n
    
    // 字符串插值
    const name: &byte = "World";
    @println("Hello, ${name}!");  // 输出: Hello, World!\n
    
    // 格式化输出
    const x: i32 = 10;
    const y: i32 = 20;
    @println("sum = ${x + y}");   // 输出: sum = 30\n
    
    // 浮点格式化
    const pi: f64 = 3.14159;
    @println("pi = ${pi:.2f}");   // 输出: pi = 3.14\n
    
    return 0;
}
```

**支持的插值格式**：
```uya
fn main() i32 {
    const num: i32 = 255;
    const f: f64 = 3.14159;
    const flag: bool = true;
    
    // 整数格式
    @println("decimal: ${num}");      // 十进制: 255
    @println("hex: ${num:#x}");       // 十六进制(小写): ff
    @println("HEX: ${num:#X}");       // 十六进制(大写): FF
    @println("octal: ${num:#o}");     // 八进制: 377
    
    // 浮点格式
    @println("default: ${f}");        // 默认: 3.14159
    @println("no decimal: ${f:.0f}"); // 无小数: 3
    @println("2 decimals: ${f:.2f}"); // 2位小数: 3.14
    @println("4 decimals: ${f:.4f}"); // 4位小数: 3.1416
    
    // 布尔值
    @println("flag = ${flag}");       // 输出: flag = 1
    
    return 0;
}
```

**错误处理**：
```uya
fn main() i32 {
    // 返回值检测
    const result: i32 = @println("Hello");
    if result < 0 {
        // 输出错误处理
        return 1;
    }
    
    // 不支持的类型会编译错误
    struct Point { x: i32, y: i32 }
    const p: Point = Point { x: 1, y: 2 };
    // @println(p);  // ❌ 编译错误：该类型不支持 @print/@println
    
    return 0;
}
```

**注意事项**：
- 与 `@print` 支持相同的类型
- 自动在末尾添加换行符 `\n`
- 自定义类型需手动实现打印逻辑

---

## 8. 异步编程函数

> **状态**：最小闭环已实现（`@async_fn` / `@await`、`Poll/Future/Waker`、`block_on`、最小 `Scheduler`）；状态机大小编译期布局与完整运行时待完善  
> **参考**：规范 §18 异步编程

### @async_fn

**函数签名**：
```uya
@async_fn fn function_name(...) !Future<T>
```

**功能描述**：
标记异步入口，触发编译器进行 CPS 变换，生成显式状态机。当前可用于顶层函数、结构体/联合体的方法实现，以及接口方法签名。

**使用示例**：
```uya
@async_fn fn fetch_data(url: *byte) !Future<i32> {
    const conn: Connection = try @await connect(url);
    const data: i32 = try @await read_data(conn);
    return data;
}

interface Reader {
    @async_fn
    fn read(self: &Self, n: usize) Future<!usize>;
}

Socket {
    @async_fn
    fn read(self: &Self, n: usize) Future<!usize> {
        _ = n;
        return 0;
    }
}
```

**注意事项**：
- 必须返回 `Future<!T>` 或 `!Future<T>` 类型
- 函数体内可以使用 `@await`
- 编译器会自动生成状态机代码
- 接口方法签名上的 `@async_fn` 只声明异步契约；真正的状态机生成发生在对应实现上

---

### @await

**函数签名**：
```uya
try @await future_expr
```

**功能描述**：
唯一的显式挂起点，等待异步操作完成。仅能在 `@async_fn` 函数内使用。

**使用示例**：
```uya
@async_fn fn process() !Future<void> {
    // 等待异步 I/O
    const data: &[byte] = try @await read_file("config.txt");
    
    // 等待异步计算
    const result: i32 = try @await compute_heavy_task(data);
    
    // 等待异步写入
    try @await write_file("output.txt", result);
}
```

**注意事项**：
- 必须配合 `try` 使用（处理错误）
- 仅在 `@async_fn` 函数内有效
- 每个 `@await` 是一个挂起点，状态机会在此处保存/恢复

---

### @frame

**类型构造器签名**：
```uya
@frame(async_function_name)
@frame(generic_async_function<ConcreteType>)
```

**功能描述**：
暴露 `@async_fn` 的状态机帧类型。`@frame(foo)` 是一个**类型构造器**（不是值构造器），只暴露帧类型本身；分配仍由变量声明位置（栈、全局、池）决定。

**当前公开的高层方法**：
- `frame.start(args...)`：启动或重启一次 caller-owned frame 运行
- `frame.poll(&waker)`：推进当前运行，返回 `Poll<T>` / `Poll<!T>`
- `frame.stop()`：停止当前运行并清理内部子 future / 子 frame，但不释放 frame 自身 storage

**使用示例**：
```uya
@async_fn
fn worker(n: i32) Future<!i32> {
    return n + 1;
}

fn uses_frame_ref(f: &@frame(worker)) i32 {
    _ = f;
    return 1;
}

fn drive_frame() i32 {
    var frame: @frame(worker);   // 允许无初始化
    const w: Waker = Waker{};

    frame.start(41);
    const p: Poll<!i32> = frame.poll(&w);
    frame.stop();

    _ = uses_frame_ref(&frame);
    match p {
        .Ready(v) => { return v catch { return -1; }; },
        .Pending(_) => { return -2; },
    }
}
```

**注意事项**：
- `@frame` 的操作数必须是 `@async_fn` 标识符
- 对泛型 async 函数，类型参数必须是 **concrete**（如 `@frame(foo<i32>)`）；未解析的 `@frame(foo<T>)` 会报错
- `@frame` 类型是 **pinned**：禁止按值移动、整体赋值、按值传参、按值返回
- 允许通过 `&frame` 按引用传递
- 当前公开的高层方法只有 `start` / `poll` / `stop`；不要把 `drop` / `release` / `reset` 当成 `@frame` API
- 父结构体若包含 `@frame` 字段，也会被视为 pinned aggregate

---

## 9. 裸函数属性

### @naked_fn

**函数签名**：
```uya
@naked_fn fn function_name(...) ReturnType {
    @asm {
        // 仅能使用内联汇编
    }
}
```

**功能描述**：
标记函数为裸函数（naked function），编译器不会生成函数 prologue（序言）和 epilogue（尾声）代码。裸函数必须完全由内联汇编实现。

**使用场景**：
- 实现操作系统内核代码
- 实现 `setjmp`/`longjmp` 等底层控制流操作
- 实现自定义调用约定
- 性能关键的内联汇编函数

**约束**：
- 函数体必须只包含 `@asm` 块
- 不能有常规 Uya 代码（变量声明、表达式等）
- 必须使用内联汇编正确处理参数和返回值
- 需要手动保存/恢复调用者保存寄存器（如需要）

**使用示例**：
```uya
// setjmp 实现 - 保存执行上下文
export @naked_fn fn setjmp(env: &jmp_buf) i32 {
    @asm {
        // 保存 callee-saved 寄存器
        "movq %%rbx, 0(%0)" (env as usize);
        "movq %%rbp, 8(%0)" (env as usize);
        "movq %%r12, 16(%0)" (env as usize);
        "movq %%r13, 24(%0)" (env as usize);
        "movq %%r14, 32(%0)" (env as usize);
        "movq %%r15, 40(%0)" (env as usize);
        "movq %%rsp, 48(%0)" (env as usize);
        // 保存返回地址
        "leaq 0(%%rip), %%rax" ();
        "movq %%rax, 56(%0)" (env as usize);
        // 返回 0
        "xorl %%eax, %%eax" ();
        "ret" ();
    } clobbers = ["memory"];
}

// longjmp 实现 - 恢复执行上下文
export @naked_fn fn longjmp(env: &jmp_buf, val: i32) void {
    @asm {
        // val 为 0 时返回 1，否则返回 val
        "testl %%esi, %%esi" ();
        "movl $1, %%eax" ();
        "cmovzl %%eax, %%esi" ();
        "movl %%esi, %%eax" ();
        // 恢复 callee-saved 寄存器
        "movq 0(%%rdi), %%rbx" ();
        "movq 8(%%rdi), %%rbp" ();
        "movq 16(%%rdi), %%r12" ();
        "movq 24(%%rdi), %%r13" ();
        "movq 32(%%rdi), %%r14" ();
        "movq 40(%%rdi), %%r15" ();
        "movq 48(%%rdi), %%rsp" ();
        // 跳转到保存的地址
        "movq 56(%%rdi), %%rax" ();
        "jmpq *%%rax" ();
    } clobbers = ["memory"];
}
```

**C 代码生成**：
```c
// @naked_fn 生成 __attribute__((naked))
__attribute__((naked)) int32_t setjmp(jmp_buf* env) {
    __asm__ volatile (
        "movq %%rbx, 0(%0)\n\t"
        "movq %%rbp, 8(%0)\n\t"
        // ...
        "ret"
        :
        : "r"(env)
        : "memory"
    );
}
```

**x86-64 调用约定说明**：
- **参数传递**：前 6 个整数/指针参数在 `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`
- **返回值**：整数返回值在 `rax`
- **Callee-saved 寄存器**：`rbx`, `rbp`, `r12`, `r13`, `r14`, `r15`（必须保存）
- **Caller-saved 寄存器**：`rax`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`, `r9`, `r10`, `r11`（可自由使用）

**注意事项**：
- 裸函数是高级特性，需要深入了解目标平台的 ABI
- 错误使用可能导致未定义行为或程序崩溃
- 建议仅在实现底层系统代码时使用
- 与 `@asm` 块配合使用，所有指令必须在单个 `@asm` 块中

---

## 10. 内联汇编函数

> **状态**：设计完成，实现中  
> **参考**：规范 §19 内联汇编

### @asm

**函数签名**：
```uya
@asm {
    "instruction template" (input1, input2, ..., -> output1, output2, ...)
        clobbers = [reg1, reg2, ..., "memory"];
}
```

**功能描述**：
编译期内置函数，用于直接编写内联汇编代码。提供类型安全、内存安全的汇编操作，替代 C99 的内联汇编语法。

**参数**：
- `instruction template`：汇编指令模板（字符串字面量）
- `input_exprs`：输入表达式列表
- `output_exprs`：输出表达式列表（在 `->` 之后）
- `clobbers`：被修改的寄存器列表（可选）

**返回值**：
- 无返回值（输出通过输出参数返回）

**使用示例**：
```uya
// 基本算术运算
fn add_with_asm(a: i32, b: i32) i32 {
    var result: i32;
    
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    
    return result;
}

// 系统调用
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 1;
    var result: i64;  // 显式声明输出变量

    @asm {
        "mov rax, {nr}" (SYS_write, -> rax);
        "mov rdi, {fd}" (fd, -> rdi);
        "mov rsi, {buf}" (buf, -> rsi);
        "mov rdx, {count}" (count, -> rdx);
        "syscall" (rax, rdi, rsi, rdx, -> result);
    } clobbers = ["rcx", "r11", "memory"];

    if result < 0 {
        return error.SyscallFailed;
    }

    return result as! i32;  // 使用 as! 处理可能溢出的转换
}

// 原子操作
fn atomic_fetch_add(ptr: &atomic i32, value: i32) i32 {
    var old: i32;
    
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
    }
    
    return old;
}

// 平台条件编译
fn platform_add(a: i32, b: i32) i32 {
    var result: i32;
    
    if @asm_target() == .x86_64_linux {
        @asm {
            "add {a}, {b}" (a, b, -> result);
        }
    } else if @asm_target() == .arm64_linux {
        @asm {
            "add {a}, {b}, {result}" (a, b, -> result);
        }
    } else {
        result = a + b;
    }
    
    return result;
}
```

**寄存器类型**：
```uya
// 平台无关寄存器（编译器自动分配）
type @asm_reg = opaque;

// 平台特定寄存器
type @asm_reg_x64 = opaque;   // x86-64
type @asm_reg_x86 = opaque;   // x86
type @asm_reg_arm64 = opaque; // ARM64

// 使用示例
fn auto_reg(a: i32, b: i32) i32 {
    var temp: @asm_reg;
    var result: i32;
    
    @asm {
        "mov {temp}, {a}" (a, -> temp);
        "add {temp}, {b}" (temp, b, -> result);
    }
    
    return result;
}
```

**内存操作类型**：
```uya
// 类型安全的内存操作
type @asm_mem<T> = opaque;

// 使用示例
fn read_u32(ptr: &u32) u32 {
    var value: u32;
    
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    
    return value;
}

fn write_u32(ptr: &u32, value: u32) void {
    @asm {
        "mov [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
    }
}
```

**平台检测**：
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

**安全约束**：
1. **类型检查**：输入/输出类型必须匹配
2. **寄存器验证**：寄存器约束不能与调用约定冲突
3. **内存安全**：内存操作必须有明确类型
4. **并发安全**：原子操作必须使用 `atomic T` 类型
5. **clobber 声明**：必须声明所有被修改的寄存器

**错误示例**：
```uya
// ❌ 错误：类型不匹配
@asm {
    "mov {dst}, {src}" (src: f64, -> dst: i32);  // 编译错误
}

// ❌ 错误：未声明 clobber
@asm {
    "mov rax, 1" (-> _);  // 编译错误：未声明 clobber
}

// ✅ 正确：显式声明 clobber
@asm {
    "mov rax, 1" (-> _);
} clobbers = ["rax"];

// ❌ 错误：非原子类型的原子操作
fn unsafe_fetch_add(ptr: &i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
        // 编译错误：ptr 不是 atomic 类型
    }
    return old;
}
```

**注意事项**：
- 编译期展开，零运行时开销
- 输出变量必须在 `@asm` 块外显式声明
- 平台相关代码使用 `@asm_target()` 进行条件编译
- 详细的 API 参考和最佳实践见 [asm_api_reference.md](asm_api_reference.md)

---

## 11. SIMD 向量内建

> **状态**：规范已定稿；编译器已实现第一阶段（含 C99 标量回退、结构体字段上的向量/掩码成员访问代码生成）  
> **参考**：规范 §16 内置函数、`docs/uya.md`

### @vector

**语法**：
```uya
@vector(T, N)
@vector.splat(x)
@vector.load(ptr)
@vector.store(ptr, v)
@vector.select(m, a, b)
@vector.any(m)
@vector.all(m)
```

**功能描述**：
- `@vector(T, N)`：SIMD 向量类型构造器，表示元素类型为 `T`、通道数为 `N` 的向量类型
- `@vector.splat(x)`：用标量值 `x` 构造所有通道都相同的向量值
- `@vector.load(ptr)`（**0.49.33**）：从 **`ptr`**（**`&T`**，与向量元素类型一致；**`byte`/`u8`** 匹配见 `uya.md`）按 **`sizeof(@vector(T,N))`** 读取内存得到向量；目标 **`@vector(T,N)`** 须由上下文确定；**调用方**须保证可读范围足够
- `@vector.store(ptr, v)`（**0.49.34**）：将 **`v`**（**`@vector(T,N)`**）按 **`sizeof(@vector(T,N))`** 写入 **`ptr`**（**`&T`**，**`T`** 与 **`v`** 元素类型一致；**`byte`/`u8`** 同 **`load`**）；**结果为 `void`**；**调用方**须保证可写范围足够
- `@vector.select(m, a, b)`（**0.49.35**）：**`m`** 为 **`@mask(N)`**，**`a`**、**`b`** 为**完全相同**的 **`@vector(T,N)`**，且 **`N`** 与掩码通道数一致；逐通道 **`m` 为真取 `a`，否则取 `b`**；结果为 **`@vector(T,N)`**；目标向量类型须由上下文确定（与 **`splat`** / **`load`** 相同）
- `@vector.reduce_add(v)`（**0.49.36**）：**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；返回标量 **`T`**，为 **`v`** 各通道之和（**`+`** 与标量同语义，含整数包装/溢出）
- `@vector.any(m)`：掩码任一通道为 true 时返回 `bool true`
- `@vector.all(m)`：掩码所有通道为 true 时返回 `bool true`

**第一阶段语义**：
- `T` 建议限制为 `i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`f32`、`f64`
- `N` 第一阶段仅允许字面量正整数，且必须为 2 的幂
- `@vector(T, N)` 不与标量类型隐式互转
- 第一阶段支持向量算术（含整数元素的按通道 `%`）、**有符号整数元素**向量的饱和运算 `+|`/`-|`/`*|`、**整数元素**向量的包装运算 `+%`/`-%`/`*%`、整数向量位运算、向量比较；一元 `-` 可用于整数/浮点元素向量，一元 `~` 仅用于整数元素向量
- 比较结果类型为 `@mask(N)`
- 第一阶段不支持标量广播语法糖，如 `vec + 1`

**使用示例**：
```uya
type Vec4f32 = @vector(f32, 4);
type Vec8i32 = @vector(i32, 8);

const zeros: @vector(i32, 4) = @vector.splat(0);
const ones: @vector(f32, 8) = @vector.splat(1.0f32);

const lt: @mask(4) = a < b;
if @vector.any(lt) {
    // 至少一个通道满足条件
}
```

**注意事项**：
- `@vector.splat(x)` 的参数类型须与目标向量元素类型一致或可隐式转换；无后缀浮点字面量为 `f64`，填入 `f32` 向量须使用 `f32` 后缀（如 `1.0f32`）
- `@vector.splat(x)` 的目标向量类型必须能由上下文唯一确定（含与同一代数/比较表达式中另一侧 `@vector` 操作数对齐推断，以及 **`return` 与函数返回 `@vector` / `!@vector` 成功载荷** 对齐推断，见 uya.md 0.49.8、0.49.9）
- 第一阶段允许标量回退 lowering，不承诺立刻映射真实硬件寄存器
- **`@vector.load` / `@vector.store` / `@vector.select`** 已于 **0.49.33** / **0.49.34** / **0.49.35** 纳入；**`@vector.reduce_add`** 已于 **0.49.36** 纳入；第一阶段仍不引入 **`shuffle`** 及其它 **`reduce_*`**

---

### @mask

**语法**：
```uya
@mask(N)
```

**功能描述**：
表示 `N` 通道的布尔掩码类型，主要用于向量比较结果与掩码逻辑运算。

**第一阶段语义**：
- `@mask(N)` 与 `@mask(M)` 仅当 `N == M` 时类型相等
- `@mask(N)` 不隐式转换为 `bool`
- 掩码逻辑运算 `&`、`|`、`^`、`!` 作用于 `@mask(N)`
- 第一阶段不允许把 `@mask(N)` 直接作为 `if` / `while` 条件

**使用示例**：
```uya
type Mask8 = @mask(8);

const lt: @mask(4) = a < b;
const eq: @mask(4) = a == b;
const both: @mask(4) = lt & eq;
```

---

## 12. 内置函数分类总结

| 分类 | 函数 | 编译期 | 运行时 | 状态 |
|------|------|--------|--------|------|
| **类型反射** | `@size_of` | ✓ | - | ✅ 已实现 |
| | `@align_of` | ✓ | - | ✅ 已实现 |
| | `@len` (数组) | ✓ | - | ✅ 已实现 |
| | `@len` (切片) | - | ✓ | ✅ 已实现 |
| **整数极值** | `@max` | ✓ | - | ✅ 已实现 |
| | `@min` | ✓ | - | ✅ 已实现 |
| **源码位置** | `@src_name` | ✓ | - | ✅ 已实现 |
| | `@src_path` | ✓ | - | ✅ 已实现 |
| | `@src_line` | ✓ | - | ✅ 已实现 |
| | `@src_col` | ✓ | - | ✅ 已实现 |
| | `@func_name` | ✓ | - | ✅ 已实现 |
| **嵌入资源** | `@embed` | ✓ | - | ✅ 已实现 |
| | `@embed_dir` | ✓ | - | ✅ 已实现 |
| **构建导入** | `@c_import` | ✓ | - | ✅ 已实现（顶层构建指令） |
| **可变参数** | `@params` | - | ✓ | ✅ 已实现 |
| | `@va_start` | ✓ | - | 📋 规范支持 |
| | `@va_end` | ✓ | - | 📋 规范支持 |
| | `@va_arg` | ✓ | - | 📋 规范支持 |
| | `@va_copy` | ✓ | - | 📋 规范支持 |
| **宏系统** | `@mc_eval` | ✓ | - | 🚧 语法解析完成 |
| | `@mc_type` | ✓ | - | 🚧 语法解析完成 |
| | `@mc_ast` | ✓ | - | 🚧 语法解析完成 |
| | `@mc_code` | ✓ | - | 🚧 语法解析完成 |
| | `@mc_error` | ✓ | - | 🚧 语法解析完成 |
| | `@mc_get_env` | ✓ | - | 🚧 语法解析完成 |
| **错误处理** | `@error_id` | ✓ | ✓ | ✅ 已实现 |
| **调试打印** | `@print` | - | ✓ | ✅ 已实现 |
| | `@println` | - | ✓ | ✅ 已实现 |
| **异步编程** | `@async_fn` | ✓ | ✓ | 🚧 最小闭环已实现 |
| | `@await` | ✓ | ✓ | 🚧 最小闭环已实现 |
| **裸函数** | `@naked_fn` | ✓ | - | ✅ 已实现 |
| **内联汇编** | `@asm` | ✓ | - | 📋 规范支持 |
| **SIMD 向量** | `@vector` | ✓ | - | 📋 规范支持 |
| | `@mask` | ✓ | - | 📋 规范支持 |
| | `@vector.splat` | ✓ | ✓ | 📋 规范支持 |
| | `@vector.load` | ✓ | ✓ | 📋 规范支持（0.49.33） |
| | `@vector.store` | ✓ | ✓ | 📋 规范支持（0.49.34） |
| | `@vector.select` | ✓ | ✓ | 📋 规范支持（0.49.35） |
| | `@vector.reduce_add` | ✓ | ✓ | 📋 规范支持（0.49.36） |
| | `@vector.any` | ✓ | ✓ | 📋 规范支持 |
| | `@vector.all` | ✓ | ✓ | 📋 规范支持 |

---

## 13. 命名惯例

Uya 内置函数遵循以下命名惯例：

1. **单一概念**：使用短形式
   - `@len`, `@max`, `@min`

2. **复合概念**：使用 snake_case（下划线分隔）
   - `@size_of`, `@align_of`, `@error_id`, `@async_fn`
   - `@va_start`, `@va_end`, `@va_arg`, `@va_copy`（可变参数栈访问）
   - `@src_name`, `@src_path`, `@src_line`, `@src_col`, `@func_name`
   - `@mc_eval`, `@mc_type`, `@mc_ast`, `@mc_code`, `@mc_error`, `@mc_get_env`
   - `@vector`（类型构造器与最小 SIMD 辅助内建）

3. **前缀约定**：
   - `@mc_*`：宏编译时函数（Macro Compile-time）
   - `@src_*`：源代码位置相关（Source）

---

## 14. 性能保证

所有内置函数遵循 Uya 的零成本抽象原则：

| 类别 | 性能保证 |
|------|----------|
| **编译期展开** | `@size_of`, `@align_of`, `@len(数组)`, `@max`, `@min`, `@src_*`, `@func_name`, `@va_start`, `@va_end`, `@va_arg`, `@va_copy`, `@error_id(error.X)` |
| **零运行时开销** | 上述函数在编译时完全求值或展开为 C 宏 |
| **运行时访问** | `@len(切片)` → 访问切片的 `.len` 字段；`@error_id(err)` → 读取错误值的 `.error_id` 字段 |
| **可变参数** | `@params` → 零抽象开销，直接映射到 C va_list；`@va_start`/`@va_end`/`@va_arg`/`@va_copy` → 展开为 C 宏 |
| **SIMD 向量** | `@vector` / `@mask` 在语义层由编译器识别；第一阶段允许标量回退 lowering，先保证语义正确 |

---

## 15. 常见使用模式

### 15.1 调试和日志

```uya
extern printf(fmt: *byte, ...) i32;

fn log(level: *byte, msg: *byte) void {
    printf("[%s] %s:%d in %s(): %s\n" as *byte,
           level,
           @src_name,
           @src_line,
           @func_name,
           msg);
}

fn main() i32 {
    log("INFO" as *byte, "Application started" as *byte);
    // 输出：[INFO] main.uya:15 in main(): Application started
    return 0;
}
```

### 15.2 断言实现

```uya
extern printf(fmt: *byte, ...) i32;
extern exit(code: i32) void;

fn assert(condition: bool, msg: *byte, file: *byte, line: i32, func: *byte) void {
    if !condition {
        printf("Assertion failed: %s\n" as *byte, msg);
        printf("  at %s:%d in %s()\n" as *byte, file, line, func);
        exit(1);
    }
}

fn main() i32 {
    const x: i32 = 10;
    
    if !(x > 0) {
        assert(false, 
               "x must be positive" as *byte,
               @src_name,
               @src_line,
               @func_name);
    }
    
    return 0;
}
```

### 15.3 泛型容器大小计算

```uya
struct Buffer<T> {
    data: [T: 1024],
    count: i32
}

fn buffer_info<T>() void {
    const elem_size: i32 = @size_of(T);
    const total_size: i32 = @size_of(Buffer<T>);
    const capacity: i32 = @len(Buffer<T>.data);
    
    printf("Element size: %d\n" as *byte, elem_size);
    printf("Buffer size: %d\n" as *byte, total_size);
    printf("Capacity: %d\n" as *byte, capacity);
}
```

---

## 16. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.49.45 | 2026-04-22 | 新增顶层构建指令 `@c_import("path", cflags?, ldflags?)` 文档；同步单文件 `.c + .cimports.sh`、目录递归导入 `*.c`、split-C Makefile 集成与测试入口说明 |
| v0.49.43 | 2026-03-26 | 与 **uya.md 0.49.43** 同步：字符串字面量赋 **`[byte:N]`** / **`&[const byte]`**、成员访问链左值、**`&[const T]`** 切片语法说明（见主文档规范变更 **0.49.43**）；内置函数条目无增删 |
| v0.49.42 | 2026-03-22 | 与 **uya.md 0.49.42** 同步：词法 **`\\xHH`** / **`\\uXXXX`**（见主文档 §1.4）；内置函数条目无增删 |
| v0.49.41 | 2026-03-22 | 与 **uya.md 0.49.41** 同步：**`@print` / `@println`** 明确支持 **`byte` / `u8` / `i8`** 的 **`&[T]`**、**`[T:N]`**、**`*byte`** 及字面量 **`"..."`**；**`[byte:N]`** / **`&[byte]`** 以 **`%s`** 打印（与 C 以 **`\\0`** 结尾的缓冲区语义一致） |
| v0.49.40 | 2026-03-22 | 与 **uya.md 0.49.40** 同步：**`std.thread`** 仅保留 **`async_compute<T>`** 入口（移除 **`async_compute_i32`** 等 12 个特化导出）；内置函数条目无增删 |
| v0.49.39 | 2026-03-20 | SIMD：**`@vector.reduce_min(v)`** / **`@vector.reduce_max(v)`**（阶段 4）；**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，分别为各通道最小值 / 最大值；C99 全部 **`while` 循环** scalar 回退；规范 **0.49.39** |
| v0.49.38 | 2026-03-20 | SIMD：**`@vector.reduce_mul(v)`**（阶段 4）；**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，语义为 **`v.lanes[0] * ... * v.lanes[N-1]`**；C99 **`i32`/`u32`/`f32`** **`×2`/`×4`** 发射 **`uya_simd_*_reduce_mul_*`** 助手（SSE2 `_mm_mul_*`，i32/u32 ×4 用 SSE4.1，无 SSE4.1 回退标量）；其余类型标量循环；规范 **0.49.38** |
| v0.49.36 | 2026-03-20 | **`@vector.reduce_add(v)`**（水平求和 → 标量 **`T`**；C99 语句表达式 + 循环）；`test_simd_vector_reduce_add.uya`、`error_simd_vector_reduce_add_not_vector.uya`；规范 **0.49.36** |
| v0.49.35 | 2026-03-20 | **`@vector.select(m,a,b)`**（逐通道混合；C99 标量逐通道）；`test_simd_vector_select.uya`、`error_simd_vector_select_mask_lanes.uya`；规范 **0.49.35** |
| v0.49.34 | 2026-03-20 | **`@vector.store(ptr,v)`**（**`__uya_memcpy`** 写回内存；**`void`**）；`test_simd_vector_store.uya`、`error_simd_vector_store_pointee_mismatch.uya`；规范 **0.49.34** |
| v0.49.33 | 2026-03-20 | **`@vector.load`**（**`__uya_memcpy`** 装入向量）；**`std.json` `skip_ws`** **`@vector(u8,16)`** 块路径；`test_simd_vector_load.uya`、`error_simd_vector_load_pointee_mismatch.uya` |
| v0.49.30 | 2026-03-19 | C99 SIMD：**`i8`/`u8`/`i64`/`u64`** 向量·掩码·**`splat`**·一元 `-`（`*_i8x16`/`x8`/`x4`/`x2`、`*_u8x*`、`*_i64x2`、`*_u64x2`）；`test_simd_i8_u8_i64_sse.uya` |
| v0.49.29 | 2026-03-19 | C99 SIMD：**`2×i32`/`u32`/`f32`** 与 **`@mask(2)`** 快路径（`*_x2`）；`test_simd_vec2_i32_u32_f32.uya`、NEON 夹具 |
| v0.49.28 | 2026-03-19 | C99 SIMD：**`f64` `+`/`-`/一元`-`**；**`i16` 六比较/一元`-`/`splat`（**4×** `*_i16x4*`）**`u16` 向量与掩码、`splat`**；`test_simd_u16_basic`、`test_simd_i16_add`、NEON 夹具 |
| v0.49.27 | 2026-03-20 | C99 SIMD：**4×/8×`i16` 向量 `-` / `*`** → `sub_i16x8` / `mul_i16x8`；`test_simd_i16_add`、NEON 夹具 |
| v0.49.26 | 2026-03-19 | C99 SIMD：**4×/8×`i16` 向量 `+` / `==`** → `add_i16x8` / `eq_i16x8_mask`（SSE2 `__m128i` / NEON `int16x8_t` / 标量；4× 复用 8×）；`test_simd_i16_add` |
| v0.49.25 | 2026-03-19 | C99 SIMD：**2×/4×`f64` 向量 `*` `/`** → `mul_f64x2` / `div_f64x2`（SSE2 `__m128d` / NEON `float64x2_t` / 标量；4× 为两次 2×）；`test_simd_f64_mul_div` |
| v0.49.24 | 2026-03-19 | C99 SIMD：**4×`i32`/`u32` 向量 `<<` `>>`** → `shl_i32x4` / `shr_i32x4` / `shl_u32x4` / `shr_u32x4`（逐通道）；`test_simd_mask_bitwise_shift`、NEON 夹具 |
| v0.49.23 | 2026-03-19 | C99 SIMD：**4×`i32`/`u32` 向量 `%`** → `rem_i32x4` / `rem_u32x4`；`test_simd_u32_basic`、NEON 夹具 |
| v0.49.22 | 2026-03-19 | C99 SIMD：**4×`i32` 向量 `/`** → `uya_simd_sse_div_i32x4`；`test_simd_div_f32_i32`、`simd_c99_neon` 夹具 |
| v0.49.21 | 2026-03-19 | C99 SIMD：**4×`u32` 向量 `/`** → `uya_simd_sse_div_u32x4`（逐通道）；`test_simd_u32_basic` 增补 `7/2→3` |
| v0.49.20 | 2026-03-19 | C99 SIMD：**4×`u32` 向量 `*`** → `uya_simd_sse_mul_u32x4`；`test_simd_u32_basic` 增补高位乘 |
| v0.49.19 | 2026-03-19 | C99 SIMD：**32×/64×** `i32`/`u32`/`f32` 与 `@mask(32|64)` 通过**八/十六次** `*x4` 助手；`test_simd_vec32_sse_chain`、`test_simd_vec64_sse_chain` |
| v0.49.18 | 2026-03-19 | C99 SIMD：**16×** `i32`/`u32`/`f32` 与 `@mask(16)` 通过**四次** `*x4` 助手；`test_simd_vec16_sse_chain` |
| v0.49.17 | 2026-03-19 | C99 SIMD：**8×** `i32`/`u32`/`f32` 与 `@mask(8)` 通过**两次** `*x4` 助手；`test_simd_vec8_sse_chain` |
| v0.49.16 | 2026-03-19 | C99 SIMD：**ARM NEON** 分支（`UYA_HAVE_SIMD_ARM_NEON` + `arm_neon.h`），与 SSE 同名 `uya_simd_sse_*`；`verify_simd_c99_neon.sh` |
| v0.49.15 | 2026-03-19 | C99 SIMD：4×`u32` **`<` `>` `<=` `>=`** → 掩码，`uya_simd_sse_{lt,gt,le,ge}_u32x4_mask`（SSE / `#else` 标量）；`test_simd_sse_compare_ops` 增补绕序用例 |
| v0.49.14 | 2026-03-19 | C99 `@syscall`：`uya_syscall*` 增加 **Linux ARM32 EABI**（`svc 0`，r7 + r0–r5）；`verify_syscall_c99_cross.sh`（含 AArch64 全文件与 ARM 片段 `zig cc`） |
| v0.49.13 | 2026-03-19 | C99 `@syscall`：`uya_syscall*` 增加 **Linux AArch64**（`svc 0`）；交叉 `aarch64-linux-gnu` 可编译；验证脚本现统一为 `verify_syscall_c99_cross.sh` |
| v0.49.12 | 2026-03-19 | C99 SIMD：4×i32/f32 向量六种关系比较 → 掩码（SSE/标量）；4×u32 仅 `==`/`!=` 快路径；测试 `test_simd_sse_compare_ops` |
| v0.49.11 | 2026-03-19 | 与 uya.md 同步：规范版本号；交叉编译见主文档 [附录 C](./uya.md#附录-c-交叉编译工具链) |
| v0.49.10 | 2026-03-19 | C99 SIMD：x86_64+GCC/Clang+SSE2 下 4 宽向量部分运算 lowering 至 `uya_simd_sse_*`（`#else` 标量）；`@vector.splat`/一元 `-`（i32/f32×4）；测试 `test_simd_sse_lower_i32x4` |
| v0.49.9 | 2026-03-19 | C99：`catch` 反推载荷为向量类型别名时用 `typedef` 名；收集阶段预注册 `@mask(N)`（含仅出现在 `@vector.all(==)` 中的比较）；测试 `test_simd_return_splat_binary`（`catch`+`!Vec4i32`）、`test_simd_mask_inline_compare` |
| v0.49.8 | 2026-03-19 | SIMD：`return`/`!T` 载荷为向量时类型检查绑定 splat；C99 `err_union` 输出含向量/掩码别名载荷；测试 `test_simd_return_splat_binary` |
| v0.49.7 | 2026-03-19 | SIMD C99：`@vector.splat` 目标类型可从 expected_type / 返回类型 / 对侧向量解析；测试 `test_simd_splat_binary_context` |
| v0.49.6 | 2026-03-19 | SIMD：有符号整数向量 `+|`/`-|`/`*|`，整数向量 `+%`/`-%`/`*%`；splat 推断；测试 `test_simd_vector_sat_wrap_i32`；负例 `error_simd_float_vector_plus_pipe`、`error_simd_u32_vector_plus_pipe` |
| v0.49.5 | 2026-03-19 | SIMD：整数向量按通道 `%`；`@vector.splat` 可与取模表达式对侧向量对齐推断；测试 `test_simd_vector_mod_i32`；负例 `error_simd_float_vector_mod` |
| v0.49.4 | 2026-03-19 | SIMD 一元 `-` / `~` 与向量规则在规范中写清；测试 `test_simd_unary_ops` |
| v0.49.3 | 2026-03-19 | SIMD：`@vector.splat` 可与同一代数/比较表达式中另一侧 `@vector` 对齐推断目标类型 |
| v0.49.2 | 2026-03-19 | 浮点 `f32`/`f64` 后缀在 `TOKEN_FLOAT` 路径的解析修复；SIMD `@vector.splat` 与 `f32` 示例勘误；内置文档状态与实现阶段对齐 |
| v0.49.1 | 2026-03-19 | 语法规范版本更新为 0.49.1；同步 `@vector(T, N)` / `@mask(N)` 的第一阶段语义与文档口径 |
| v0.49 | 2026-03-17 | 新增 SIMD 向量内建：`@vector(T, N)`、`@mask(N)`、`@vector.splat`、`@vector.any`、`@vector.all`；第一阶段支持向量算术、整数位运算、比较与掩码逻辑 |
| v0.48 | 2026-03-17 | 新增错误处理内置函数：`@error_id`；同步异步与 errno 读取说明 |
| v0.47 | 2026-03-03 | 新增裸函数属性：`@naked_fn` |
| v0.46 | 2026-02-19 | 新增调试打印函数：`@print`、`@println` |
| v0.45 | 2026-02-15 | 与 uya.md 同步，添加详细函数说明 |
| v0.43 | 2026-02-14 | 与 uya.md 同步，添加详细函数说明 |
| v0.42 | 2026-02-04 | 新增源代码位置函数：`@src_name`, `@src_path`, `@src_line`, `@src_col`, `@func_name` |
| v0.40 | 2026-02-04 | 初始版本：`@size_of`, `@align_of`, `@len`, `@max`, `@min`, `@params`, 宏系统函数（语法），异步函数（语法） |

---

## 17. 参考文档

- [Uya 语言规范](uya.md) - 完整语言规范
- [语法速查](grammar_quick.md) - 语法速查手册
- [Uya Mini 规范](compiler-c-spec/UYA_MINI_SPEC.md) - 当前实现的子集规范
- [发行说明](releases/RELEASE_v0.1.0.md) - v0.1.0 版本说明

---

**本文档由 Uya 编译器团队维护，最后更新：2026-04-22（0.49.45）**
