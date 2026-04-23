# Uya · AI 代码生成技能（Skill）

> **用途**：指导模型编写可编译的 Uya，减少与其它语言混淆与臆造语法。  
> **自包含**：下文已写入常用规则；**不**再依赖任何外部说明文件。  
> **语言版本**：**0.49.45** · 更新 **2026-04-22**（与 [uya.md](./uya.md) 主规范同步；补充 `@c_import` 顶层构建指令、目录递归导入 `*.c`、`.cimports.sh` sidecar 语义）

---

## 1. 工作方式（必读）

1. **拿不准就收敛**：只使用下文明示的语法与内置名；未列出的能力默认**不要编造**。
2. **禁止臆造**：关键字、`@` 前缀名、类型写法须与下文一致。
3. **本语言不是**：无 lifetime；无 **`let` / `mut`**（可变绑定用 **`var x: T`**）；无 C 式 **`i++`**；无 **`?:`**；**无通用类型推断**（`const`/`var` 须**显式类型**）；`use` **仅在文件顶层**；**无** `use mod.*` 通配导入。

---

## 2. Uya 独有要点（易错）

| 主题 | 正确心智 |
|------|-----------|
| 指针 | 日常用 `&T` / `&const T`；`*T` / `*const T` 主要给 **FFI**；`&void` / `&const void` 为泛型裸指针 |
| 字符字面量 | `'`…`'` 类型是 **`byte`**（单字节），不是 Unicode 字符类型 |
| `null` | 类型为 `*byte`；可与 `*byte` 比较；能否赋给 `*byte` 变量以编译器为准 |
| 应用入口 | **`export fn main() i32`** 或 **`export fn main() !i32`**：生成 `main_main`，由运行时代理 C `main`；**`fn main() i32`** 为旧式（生成 `uya_main`）；**`export extern fn main(argc: i32, argv: &&byte) i32`** 生成标准 C `main` |
| 字符串 → 定长数组 | `[byte: N]` 初始化/赋值：`N ≥ 可见字节数 + 1`（含末尾 `\0`）；左值可为任意深度成员链（如 `a.b.c`），由**最右字段类型**决定语义 |
| 字符串 → 切片变量 | **只能** `var s: &[const byte] = "...";` / `s = "...";`；**禁止**元素可变的 **`&[byte]`** 接收字面量 `=` |
| 字面量子切片 | **`&"text"[start:len]`** 类型为 **`&[byte]`**；逻辑长度 = 可见字节数 + 1（含 `\0`）；**不可**据此把变量声明成 `&[byte]` 再 `= "..."` |
| 只读切片 | `&[const T]` **禁止** `s[i] = …` 及复合赋值 |
| C 后端注意 | `&[const byte]` 语义为元素只读；勿对指向**字面量存储**的切片做元素写（与 C 未定义行为相关） |

---

## 3. 关键字与模块

**关键字**（词法层保留）：`enum` `struct` `const` `var` `fn` `return` `extern` `true` `false` `if` `else` `while` `for` `break` `continue` `match` `defer` `errdefer` `try` `catch` `error` `null` `interface` `atomic` `union` `export` `use` `type` `mc` `test` `as`。另：**`as!`** 为独立词法单元（强转），勿拆成 `as` 与 `!`。

**类型名**（非上表关键字，出现在类型位置）：`bool` `byte` `void` `i8`…`i64` `u8`…`u64` `usize` `f32` `f64`；以及自定义 `struct`/`enum`/`union`/`interface` 名、泛型实参等。勿把「类型名」误记成可当作普通变量名的关键字。

**模块**：目录和单文件都可作为模块；同目录下所有 `.uya` 仍同属一个目录模块名（由目录路径决定，不含文件名），每个 `.uya` 文件也有包含文件名的文件模块别名。导入：`use std.io;`、`use std.io.read_file;`、`use std.io.file.read_file;`、`use std.io as io;`。调用可用完整模块前缀（如 **`std.io.printf(...)`**），或依赖已导入的单项简名（**`read_file(...)`**）。**`use std.async;` 之后**应写 **`block_on(...)`** 等**已导入的简单名**，**不要**臆造 **`async.block_on`**（没有名为 `async` 的默认模块值）。

---

## 4. 内置 `@`（按需使用；勿发明新名）

- **布局**：`@size_of` `@align_of` `@len` `@max` `@min`
- **源码位置**：`@src_name` `@src_path` `@src_line` `@src_col` `@func_name`
- **变参**：`@params` `@va_start` `@va_end` `@va_arg` `@va_copy`
- **异步**：`@async_fn` 可标在**顶层函数、结构体/联合体方法实现、接口方法签名**上，触发 CPS/状态机或声明异步契约。**返回值须为 `Future` 包装形式**：**`Future<!T>`** 或 **`!Future<T>`**（二者均合法），**不能**写成普通 **`!void`** 等非 `Future` 返回。**`@await`** 只能写在 **`@async_fn` 函数/方法实现**内；**操作数**类型须为 **`Future<!T>`** 或 **`!Future<T>`**（与编译器一致）。**不接受**「payload 为普通 `T`（非 `!U`）的裸 **`Future<T>`**」作为 `@await` 的操作数。习惯写法：**`try @await expr`**（如 **`try @await reader.read(buf, n)`**），勿把 `@await` 当成可随意臆造的库函数。**`Future` / `Poll` / `Waker` 及 `block_on` / `block_on_plain` 等**由 **`std.async`**（及关联标准模块）提供：**禁止**在用户源码中再定义同名 **`struct Future<T>`** 或虚构 **`std.async.*` API**。**`export fn main`** 一般**不是** `@async_fn`；同步等待异步结果须 **`use std.async;`** 并二选一：**`block_on<T>(f: Future<!T>) !T`**（实参须已是 **`Future<!T>`**，例如 **`const f: Future<!i32> = foo();`** 再 **`block_on<i32>(f)`**，结果为 **`!i32`**，常再 **`catch`**）；**`block_on_plain<T>(f: Future<T>) T`**（实参须为 **`Future<T>`**）。若 **`@async_fn` 的返回类型**为 **`!Future<T>`**，**调用表达式**类型为 **`!Future<T>`**，须先 **`const fut: Future<T> = try g(...);`** 再 **`block_on_plain<T>(fut)`**。**不要**把 **`!Future<T>`** 误当成 **`Future<!T>`** 直接传给 **`block_on`**。**`Future<!T>` 中 `T` 为大数组等复杂类型**时，以能否通过编译为准。**不要**发明标准库里**并无此名**的异步 API（例如 **`async_sleep`**、**`async.select`** 等）

  **骨架示例**（导入后写 **`block_on`**，**不要**写不存在的 **`async.block_on`**）：

  ```uya
  use std.async; // block_on / block_on_plain 等

  @async_fn
  fn fetch_data() Future<!i32> {
      return 42;
  }

  @async_fn
  fn compute() Future<!i32> {
      const base: i32 = try @await fetch_data();
      return base * 2;
  }

  export fn main() i32 {
      const fut: Future<!i32> = compute();
      const result: !i32 = block_on<i32>(fut);
      const val: i32 = result catch |_| {
          @println("异步计算失败");
          return 1;
      };
      @println("计算结果: ${val}");
      return 0;
  }
  ```
- **裸函数**：`@naked_fn` — 无标准序言/尾声，仅用于极底层场景，勿默认使用
- **宏编译期**：`@mc_eval` `@mc_type` `@mc_ast` `@mc_code` `@mc_error` `@mc_get_env` `@mc_source`
- **系统调用**：`@syscall(nr, arg1, …, arg6)`
- **指针与整数**：`@ptr_from_usize` `@usize_from_ptr`
- **错误**：`@error_id(expr)` → `u32`
- **调试打印**：`@print` `@println` — 可用于整数、浮点、`bool`、双引号字面量；**`byte` / `u8` / `i8`** 的 **`[T:N]`**、**`&[T]`**、**`*byte`** 等可按 C 字符串 **`%s`** 打印时，缓冲区须以 **`\0`** 结尾。**不要**写成 **`@println("a", x)`** 等多实参 C `printf` 风格；多段内容用**字符串插值** **`@println("a ${x}")`** 等
- **C 构建导入**：`@c_import("path"[,"cflags"[,"ldflags"]]);` —— **顶层构建指令**，不是表达式函数。首参数可指向**单个 `.c` 文件**，或一个目录；目录模式会**递归收集全部 `*.c`**。`cflags` 只作用于该导入展开出的 C 文件，`ldflags` 在最终链接阶段聚合。若输出为单文件 `app.c`，编译器会额外生成 `app.cimports.sh`；若走 split-C / `--split-c-dir` 路径，则由 Makefile 直接处理导入的 C object。**不要**把 `@c_import(...)` 写进表达式位置、函数体内、结构体字段初始化里
- **内联汇编**：`@asm { "模板"(输入…, -> 输出…); }`；多条指令写多个模板行。**`clobbers = [...]`** 写在 **`@asm { ... }` 闭合 `}` 之后**（若需要）。**输出变量必须在块外先声明**；**FFI 指针 `*T` 不能作为 asm 操作数**，须先转为 `&T` / `&const T` 等。指令字符串与寄存器名**随目标平台变化**，勿照搬单一体系结构示例当通用语法
- **SIMD**：`@vector(T,N)`、`@mask(N)`；常见：`@vector.splat`、`@vector.load`、`@vector.store`、`@vector.select`、`@vector.reduce_add` / `reduce_mul` / `reduce_min` / `reduce_max`、`@vector.any`、`@vector.all`。**元素类型与通道数**须满足编译器当前支持集合；**`@mask(N)` 不当作普通 `bool`**，分支判断用 `@vector.any` / `@vector.all` 等。具体是否发射 SIMD 指令依赖宿主 C 编译器与目标 CPU，语义以能通过编译的用法为准

---

## 5. 类型速写

- **标量**：`i8`–`i64` `u8`–`u64` `usize` `f32` `f64` `bool` `byte` `void`
- **复合**：`[T:N]` `[[T:N]:M]` `(T1,T2)` `struct` `union` / `extern union` `enum` `interface`
- **引用与切片**：`&T` `&const T` `&atomic T` `&[T]` `&[const T]` `&[T:N]` `&[const T:N]`
- **错误联合**：`!T`
- **函数指针**：`fn(Args...) Ret`
- **泛型**：`fn f<T: Trait1 + Trait2>(...) R`、`struct S<T> { ... }`

**`!T` 布局（概念）**：须同时容纳 `T` 与错误标记；与 `T` 之间无隐式转换，须 `try` / `catch` / `match` 等显式处理。

---

## 6. 字面量与数字

- **整数默认 `i32`**；**浮点默认 `f64`**
- **进制**：`0x`/`0X` 十六进制，`0o`/`0O` 八进制，`0b`/`0B` 二进制
- **分隔**：数字间可用 `_`；不得出现在首尾或连续；不得紧跟在进制前缀后（如 `0x_FF` 非法）
- **后缀**：整数 `i8`…`i64` `u8`…`u64` `usize`；浮点 `f32` `f64`
- **字符串 `"..."`**：C 式转义 `\n \t \r \\ \" \0`，以及 **`\xHH`**（两位十六进制字节）、**`\uXXXX`**（四位 BMP → UTF-8；**代理区 U+D800–DFFF 非法**）
- **原始字符串 `` `...` ``**：无转义，逐字节
- **字符 `'...'`**：类型 `byte`；支持上述转义，**`\uXXXX` 仅当值 ≤255**
- **数组字面量**：`[a,b,c]`、`[v: N]` 重复、`[]` 表示未初始化（仅当变量类型已固定）
- **字符串插值**：`"a=${expr}"` 等形式，结果为**定长**栈数组（常见为 **`[i8: N]`**），格式说明与 C `printf` 族一致，编译期展开
- **字符串拼接**：**没有**运算符 **`++` / `+`** 把两段字符串字面量或缓冲区拼成新串；需要时用**插值**、**定长数组逐字节写**，或 **libc/format** 等**真实已有** API，勿学 JS/Rust 的 `+`/`++` 拼串

---

## 7. 语法骨架

```uya
// 变量：仅 const / var，无 let / mut
const N: i32 = 10;
var x: i32 = 0;

// 顶层构建指令：可导入单个 .c 或目录
@c_import("vendor/sqlite3.c");
@c_import("vendor/sqlite_shims/", "-Ivendor/sqlite");

fn f(a: i32, b: i32) i32 { return a + b; }
export fn g() !i32 { return 0; }
extern printf(fmt: *byte, ...) i32;

const arr: [i32: 3] = [1, 2, 3];
const z: [i32: 100] = [0: 100];
var buf: [byte: 16] = "hello";
const sl: &[i32] = &arr[0:2];

if cond { } else { }
while cond { }
for 0..N |i| { }
for slice |v| { }
for slice |&p| { *p = *p + 1; }
match e { PAT => expr, else => expr };

error MyErr;
fn h() !i32 { return error.MyErr; }
const y: i32 = try may_fail();
const z2: i32 = may_fail() catch |err| { return 0; };

defer { cleanup(); }
errdefer { rollback(); }
```

**`match`**：`union` 须覆盖所有变体；作表达式时各分支类型须一致；**`else`** 用于兜底。

**`match` 后的分号**：作**语句**使用时，默认在 **`match … { … }` 整段之后写 `;`**。仅当**每一个**臂都是 **`=> { … }` 块**（不是单行表达式臂），且该 `match` 恰好落在「外层块结束 `}` 之前」或「下一条语句以关键字开头」等语法已允许的衔接位置时，编译器才允许**省略**该 `;`。**不确定或混用块臂与表达式臂时，始终写 `;`**，避免解析歧义。

---

## 8. 运算符（提要）

**无** C 风格自增自减 **`i++` / `i--` / `++i`**（须写 **`i = i + 1`** 等）。**无**三元 **`?:`**。**`++` 也不是字符串连接符**（见 §6）。

**优先级（高→低）**：调用/字段/下标/切片 → 一元 `- ! ~` → `* / % *| *%` → `+ - +| -| +% -%` → 移位 → 比较 → `== !=` → `&` → `^` → `|` → `&&` → `||` → `as` `as!` → 赋值与复合赋值。

**饱和**：`+|` `-|` `*|`；**包装**：`+%` `-%` `*%`。**`try expr`**：传播 `!T`；或对 **`+` `-` `*` `/`** 做**溢出**检查（失败为 `error.Overflow`，含如最小值除以 `-1` 一类边界；**除零**仍须用证明或显式判断，不是 `try` 替代）。

---

## 9. 类型转换（提要）

- **`as`**：安全、无精度损失的转换；指针 **`&T` ↔ `*T`**、**`&const T` ↔ `*const T`**；**`&T` → `&const T`** 可放宽
- **`&void` ↔ `&T`**、**`&const void` ↔ `&const T`**：恢复/擦除指针类型用 `as`
- **`as!`**：可能失败的转换，结果为 **`!目标类型`**，常配合 **`try`**
- 浮点→整数等可能损精度路径：**不要**假设 `as` 可用，改用 **`as!`** + 错误处理

---

## 10. 函数与 FFI（提要）

| 形式 | 含义（概念） |
|------|----------------|
| `fn foo(...) T { }` | 内部函数；生成 C 时多为 **`static`**，不参与全局链接（除非与同名 `extern` 声明等形成特殊关系） |
| `export fn foo(...) T { }` | 全局导出。C 符号一般为 **`前缀 + 函数名`**：`前缀` 由**源文件路径**规则推导（例如 `lib/libc/`→`libc_`，`lib/std/...`→`std_<子路径>_`，`src/...`→相对 `src` 的路径段用 `_` 连接再加 `_`）；推导不出前缀时接近**裸函数名**。若名称与 C 关键字/保留规则冲突，会再做 **`uya_` 等安全化** |
| `extern fn bar(...) T;` | 仅声明，链接外部 C |
| `extern fn bar(...) T { }` | Uya 实现，导出为**裸 C 名** `bar`（无路径前缀） |
| `export extern fn bar(...) T;` | 声明外部符号（如 libc），不生成体 |
| `export extern fn bar(...) T { }` | Uya 实现，生成**裸 C 名** `bar` |
| `extern "libc" fn bar(...) T;` | 按 libc 链接；**`byte`** 对应 C **`char`**；C 侧为**裸名** `bar` |
| `export extern "libc" fn bar(...) T { }` | Uya 实现并导出，C 侧仍为**裸名**（不加路径前缀） |

**变量**：`extern const` / `extern var` 导入 C 全局；`export const` / `export var` 导出；`export extern const` 等仅链接外部定义。

**变参**：声明用 `...`；体内可用 `@params` 等访问。

传 `*byte`：常见写法 **`&buf[0] as *byte`**，并满足长度/非空等**证明**。

---

## 11. 内存安全与证明（提要）

编译器在**当前函数内**尝试证明：数组下标、空指针解引用、除零、未初始化使用、整数溢出等。

- **常量**下标/运算：尽量在编译期判定
- **变量**下标：常用 `if i >= 0 && i < len { ... }` 等形式让证明成立
- **`for 0..@len(arr) |i|`** 等模式可帮助索引合法
- **`try a + b`** 等处理溢出；饱和/包装运算符可减少证明负担
- 证明失败时：**改条件、改类型、用 `try`/饱和/包装**，不要假设会默默插入运行时检查

---

## 12. defer / errdefer

- **`defer`**：离开作用域时执行清理
- **`errdefer`**：仅在沿 **`!T` 错误路径**返回时执行
- **顺序**：错误返回时 **`errdefer` → `defer` → `drop`**；正常返回时 **`defer` → `drop`**
- **块内**一般**禁止** `return` / `break` / `continue`；用临时变量在外部处理控制流

---

## 13. 结构体、接口、联合体（提要）

- **结构体**：`struct S { fields }`；字面量 **`S{ f: v, ... }`**；方法 `fn meth(self: &Self, ...) ...`；可实现 `struct S : I { ... }`，或在 **`S { ... }`** 块追加方法 / `drop`
- **接口**：胖指针（vtable + 数据）；通过接口值调用为动态派发
- **`union`**：标签联合体，**`match`** 穷尽变体；**`extern union`**：与 C `union` 布局一致，**无** `match`

---

## 14. 错误处理（提要）

- **`error Name;`**：顶层预定义错误（可选）
- **运行时错误**：可直接写 **`error.SomeName`**，无需预先 `error SomeName;`，由编译器收集（与预定义错误可混用、可比较）
- **`@error_id`**：同名错误在多次编译中映射稳定；哈希冲突时编译失败
- **`try`**：传播 **`!T`**；或对算术做溢出检查。对 **`try @await fut`**：若 `fut` 为 **`Future<!T>`**，成功时**整式类型已为 `T`**（错误已在 `try` 处处理或向外抛），**不能**再写其它语言里的 **`if value is T`** 之类判别
- **`catch`**：`|err| { }` 或 `{ }` 形式处理 **`!T`**

---

## 15. 测试

```uya
test "case_name" {
    try assert_eq_i32(1, 1, "msg");
}
```

测试体语义上等价于返回 **`!void`** 的用例函数；**不要**在测试文件里写 `main`，由测试运行器桥接执行。

---

## 16. 宏 `mc`

```uya
// ✅ 硬性约定：`expr` 宏体中，作为展开结果的那条表达式语句末尾带分号
export mc twice(x: expr) expr { ${x} + ${x}; }

// ❌ 易与解析/展开预期不一致，不要这样写
// export mc bad_twice(x: expr) expr { ${x} + ${x} }
```

**参数种类**：`expr` `stmt` `type` `pattern`。**返回标签**：`expr` `stmt` `struct` `type`。

- **`expr` 宏**：体**只**以**一条**表达式为展开结果；该表达式在宏体中按**表达式语句**书写，**行末硬性写 `;`**（例 **`${a} + ${b};`**，见上方代码块）。**不要**在体里先 **`@println(...)`** 再冒充「返回值」式 `expr` 宏
- **`stmt` 宏**：体为**语句序列**；嵌入 **`${block}`** 等须符合编译器对 `stmt` 参数的规则，**不要**假设可随意塞多语句块而不报错
- 体中可调用 **`@mc_*`**；**不要**发明「通用 **`stringify(expr)`**」等无法在 Uya 中落地的宏；**`@mc_error`** 会终止展开，后面再写假返回值无意义
- 调用语法同函数调用。跨模块：`export mc` + `use module.name;`

---

## 17. 勿与其它语言混淆

| 不要写成 | Uya 中应使用 |
|----------|----------------|
| `let x = 1;` / `let mut x = 1;` | **`const x: i32 = 1;`** 或 **`var x: i32 = 1;`**（无 `let`/`mut`） |
| 把 `@c_import(...)` 当普通表达式赋给变量 | **`@c_import` 只能在顶层单独成句**；它是构建指令，不产生运行时值 |
| `x++` / `x--` | `x = x + 1;` |
| `cond ? a : b` | `if cond { a } else { b }` |
| `fn foo() -> i32` | `fn foo() i32` |
| `pub fn` | `export fn` |
| `impl Trait for S` | `struct S : I { ... }` 或 `S { }` 方法块 |
| `use foo::*` | 逐项 `use` 或模块前缀 |
| 把 `&[byte]` 变量当字符串容器随便 `= "..."` | 使用 **`&[const byte]`** 或 **`[byte:N]`** |
| 只记得 `@c_import("foo.c")`，忘了目录模式 | 可直接写 **`@c_import("dir/")`**，递归导入目录下全部 **`*.c`** |
| 自写 `struct Future<T> { }`、假 `std.async.run` / `async_sleep` | **`use std.async`**，只调用**库里真实存在**的符号（如 **`block_on` / `block_on_plain`** 等）；**不要**发明 **`async.xxx`** 前缀（见 §3） |
| `"a" ++ "b"`、`@println(... ++ ...)` | **插值** `"${a}${b}"` 或定长缓冲/格式化 API；**无** `++` 拼串 |
| `if x is i32`、`if result is T` | **无**「`is` 类型分支」；用 **`match`**、**`catch`** 或显式比较 |
| `try @await` 后再假设变量仍是 `!T` 并做类型判断 | **`try` 已剥离错误联合**；失败则不会执行到后续赋值，成功则绑定为 **`T`** |
| `fn foo(err: error)` 把 `error` 当通用类型 | 用 **`!T`**、**`catch |e| { ... }`**、**`@error_id`**、**`match`** 等既有范式；**不要**臆造与 `i32` 并列的 **`error` 形参类型** |
| **`block_on(async_fn())`** 而 `async_fn` 返回 **`!Future<T>`** | 先 **`const f: Future<T> = try async_fn();`** 再 **`block_on_plain<T>(f)`**；或把异步函数改为返回 **`Future<!T>`**，用 **`block_on<T>(f)`** 得 **`!T`**（见 §4） |
| `@println("a", x)`、`@println("e", err)` | **`@println("a ${x}")`** 等插值，或分多次 **`@println`** |
| `export mc m(x: expr) expr { ${x} + 1 }` 体末无 **`;`** | **`export mc m(x: expr) expr { ${x} + 1; }`** — `expr` 宏体展开行**末尾分号硬性写上**（见 §16） |

---

## 18. 编译与验证（可选）

```bash
./bin/uya -O2 source.uya -o out.c   # -O0 … -O3 / --opt 同义
make check   # 构建自举编译器并跑测试（常用）
```

**工程根目录**：`uya` 按**输入文件所在目录**定模块根（如 `tests/foo.uya` → 根为 `tests/`）。在仓库**顶层目录**单独放只含 **`use std.*`** 的 `.uya` 再编译，可能出现 **`use` 无法解析标准库导出**等报错；示例与单文件验证宜放在 **`tests/`** 或你的应用源码目录，与仓库惯例一致。

若生成代码与编译器报错不一致，**以报错为准**修正，不要坚持臆测语法。

---

**说明**：本 skill **刻意不引用**任何其它说明文件；若规则与当前编译器行为冲突，以**实际编译结果**为准。
