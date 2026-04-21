# Uya 语言正式语法规范（Formal BNF）

> **版本**：与 [uya.md](./uya.md) 0.49.45 同步（2026-04-16）

本文档包含 Uya 语言的完整、无歧义的 BNF 语法定义，用于：
- 编译器/解析器实现
- 语言标准化参考
- 语法形式化验证

> **注意**：本文档是 [uya.md](./uya.md) 的补充，详细语法说明请参考主文档。  
> 对于日常开发和快速参考，请使用 [grammar_quick.md](./grammar_quick.md)。

---

## 完整语法汇总

### 程序结构

```
program        = { declaration }
declaration    = fn_decl | struct_decl | struct_method_block | union_decl | union_method_block
               | interface_decl | enum_decl | const_decl | error_decl | extern_decl | export_decl
               | import_stmt | test_stmt | macro_decl
```

### 函数声明

```
async_fn_attr  = '@async_fn'
fn_decl        = [ async_fn_attr ] [ ( 'export' 'extern' | 'extern' 'export' | 'export' | 'extern' [ STRING ] ) ] 'fn' ID [ '<' type_param_list '>' ] '(' [ param_list ] ')' type [ '{' statements '}' | ';' ]
param_list     = param { ',' param }
param          = ID ':' type
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- **函数可见性**（0.43 新增 `extern "libc"`）：
  - `fn name(...) type { ... }`：内部函数，生成的 C 代码添加 `static`
  - `export fn name(...) type { ... }`：导出函数，生成的 C 代码不添加 `static`，带 `uya_` 前缀
  - `extern fn name(...) type;`：外部 C 函数声明（无函数体，分号结尾）
  - `extern fn name(...) type { ... }`：Uya 实现的 C 兼容函数，生成的 C 代码为 `void foo(void) { ... }`（不带 `uya_` 前缀）
  - `export extern fn name(...) type;`（无函数体）：不生成代码，链接到 C 标准库
  - `export extern fn name(...) type { ... }`（有函数体）：Uya 实现，生成的 C 代码为 `void foo(void) { ... }`（不带 `uya_` 前缀）
  - **`extern "libc" fn`**（0.43 新增）：显式声明 C 标准库函数，`byte` 映射为 `char`
- **泛型函数语法**：`fn max<T: Ord>(a: T, b: T) T { ... }`
- 类型参数列表可选，使用尖括号 `<T>` 或 `<T: Constraint>`
- 多约束使用 `+` 连接：`<T: Ord + Clone + Default>`

### 结构体声明

```
struct_decl    = 'struct' ID [ '<' type_param_list '>' ] [ ':' interface_list ] '{' struct_body '}'
interface_list = ID { ',' ID }
struct_body    = ( field_list | method_list | field_list method_list )
field_list     = field { ',' field }
field          = ID ':' type
method_list    = method_decl { method_decl }
method_decl    = [ async_fn_attr ] 'fn' ID [ '<' type_param_list '>' ] '(' [ param_list ] ')' type '{' statements '}'  # self 参数必须为 &Self 或 &StructName

# 结构体外部方法定义（方式2）
struct_method_block = ID '{' method_list '}'
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- **接口声明**：结构体定义时可以声明实现的接口，语法为 `struct StructName : InterfaceName1, InterfaceName2 { ... }`
  - 接口声明是可选的，如果结构体不实现接口，可以不声明
  - 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义
- **方式1：结构体内部定义**：方法定义在结构体花括号内，与字段定义并列
  - 语法：`struct StructName : InterfaceName { field: Type, fn method(self: &Self) ReturnType { ... } }`
- **方式2：结构体外部定义**：使用块语法在结构体定义后添加方法
  - 语法：`StructName { fn method(self: &Self) ReturnType { ... } }`
- 方法实现允许使用可选前缀 `@async_fn`
- `self` 参数必须显式声明，使用指针：`self: &Self` 或 `self: *StructName`
- 推荐使用 `Self` 占位符：`self: &Self` 更简洁
- 详细语法说明见 [uya.md](./uya.md#29-扩展特性) 结构体方法部分

### 接口声明

```
interface_decl = 'interface' ID [ '<' type_param_list '>' ] '{' (method_sig | interface_name)+ '}'  # 方法签名或组合接口名
method_sig     = [ async_fn_attr ] 'fn' ID '(' [ param_list ] ')' type ';'
interface_name = ID ';'  # 组合接口名，用分号分隔
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- `method_sig+` 表示一个或多个方法签名（BNF 扩展语法，等价于 `method_sig { method_sig }`）
- `interface_name` 表示接口组合，在接口体中直接列出被组合的接口名，用分号分隔
- 接口必须至少包含一个方法签名或组合接口名
- 接口实现：结构体在定义时声明接口（`struct StructName : InterfaceName { ... }`），接口方法作为结构体方法定义
- 接口方法签名允许使用可选前缀 `@async_fn`；对接口而言，异步 ABI 仍由返回 `Future<!T>` / `!Future<T>` 表达
- 详细语法说明见 [uya.md](./uya.md#6-接口interface)

### 联合体声明

```
union_decl     = 'union' ID [ ':' interface_list ] '{' union_body '}'
union_body     = ( field_list | method_list | field_list method_list )
union_method_block = ID '{' method_list '}'  # 联合体外部方法定义（同结构体方式2）
```

**说明**：
- 联合体语法与结构体类似，但所有变体共享同一内存区域
- 变体命名遵循标识符规则，创建语法：`UnionName.variant(expr)`
- 访问必须通过模式匹配（`match`）或编译器可证明的已知标签直接访问
- 详细语法说明见 [uya.md](./uya.md#45-联合体union)

### 枚举声明

```
enum_decl      = 'enum' ID [ ':' underlying_type ] '{' enum_variant_list '}'
underlying_type = base_type  # 底层类型，必须是整数类型（i8, i16, i32, i64, u8, u16, u32, u64）
enum_variant_list = enum_variant { ',' enum_variant }
enum_variant   = ID [ '=' NUM ]  # 枚举变体，可选显式赋值
```

**说明**：
- 枚举声明在顶层（与函数、结构体定义同级）
- 默认底层类型为 `i32`（如果未指定）
- 枚举变体可以显式指定值（使用 `=` 后跟整数常量）
- 枚举值在编译期确定，类型安全
- 详细语法说明见 [uya.md](./uya.md#2-类型系统) 枚举类型部分

### 类型系统

```
type           = base_type | pointer_type | array_type | slice_type 
               | struct_type | union_type | interface_type | enum_type | tuple_type
               | atomic_type | error_union_type | function_pointer_type | extern_type
               | vector_type | mask_type | frame_type

base_type      = 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'u16' | 'u32' | 'u64'
               | 'f32' | 'f64' | 'bool' | 'byte' | 'void' | 'usize'
pointer_type   = '&' [ 'const' ] type | '*' [ 'const' ] type  # 0.42 新增 &const T 和 *const T
array_type     = '[' type ':' NUM ']'
slice_type     = '&[' [ 'const' ] type ']' | '&[' [ 'const' ] type ';' NUM ']'  # 0.49.43：元素只读 & [ const T ]（如 &[const byte]）
struct_type    = ID [ '<' type_arg_list '>' ]
union_type     = ID [ '<' type_arg_list '>' ] | 'union' ID  # 联合体类型；'union' ID 用于外部 C 联合体
interface_type = ID [ '<' type_arg_list '>' ]
type_arg_list  = type { ',' type }
enum_type      = ID  # 枚举类型，通过枚举声明定义
tuple_type     = '(' type { ',' type } ')'  # 元组类型，如 (i32, f64)
atomic_type    = 'atomic' type
error_union_type = '!' type  # 错误联合类型，表示 T | Error
function_pointer_type = 'fn' '(' [ param_type_list ] ')' type  # 函数指针类型
param_type_list = type { ',' type }  # 函数指针类型的参数类型列表（无参数名）
vector_type    = '@vector' '(' type ',' NUM ')'
mask_type      = '@mask' '(' NUM ')'
frame_type     = '@frame' '(' ID [ '<' type_arg_list '>' ] ')'
```

**说明**：
- **`&[const T]`**（**0.49.43**）：切片元素只读；字符串字面量赋给切片类型时须为 **`&[const byte]`**（或带长度形参的 **`&[const byte: N]`**），见 uya.md 规范变更 0.49.43
- `@vector(T, N)` 表示元素类型为 `T`、通道数为 `N` 的向量类型
- `@mask(N)` 表示 `N` 通道的掩码类型
- `@frame(fn_name)` 或 `@frame(fn_name<T>)` 表示 async 函数 `fn_name` 的状态机帧类型
- 第一阶段 `N` 仅允许字面量正整数
- 第一阶段 `N` 必须为 2 的幂，建议限制为 `2`、`4`、`8`、`16`、`32`、`64`
- `vector_type` 在语法层允许任意 `type` 作为第一个参数；语义层会进一步限制 `T` 必须为数值标量类型
- `@frame` 的语义层要求 `fn_name` 必须是 `@async_fn`；若带泛型参数，则必须为 concrete 类型
- 第一阶段不引入 `@vector<T>(N)`、`Vector(T, N)`、通用 const generics 或新的目标特性查询语法

### 变量声明

```
var_decl       = ('const' | 'var') ID ':' type '=' expr ';'
const_decl     = 'const' ID ':' type '=' expr ';'
```

### 语句

```
statement      = expr_stmt | var_decl | return_stmt | if_stmt | while_stmt
               | for_stmt | break_stmt | continue_stmt | defer_stmt | errdefer_stmt
               | block_stmt | match_stmt | test_stmt

expr_stmt      = expr ';'
return_stmt    = 'return' [ expr ] ';'
if_stmt        = 'if' expr '{' statements '}' [ 'else' '{' statements '}' ]
while_stmt     = 'while' expr '{' statements '}'
for_stmt       = 'for' expr '|' ID '|' '{' statements '}'           # 值迭代（只读）
               | 'for' expr '|' '&' ID '|' '{' statements '}'        # 引用迭代（可修改）
               | 'for' range '|' ID '|' '{' statements '}'           # 整数范围，有元素变量
               | 'for' expr '{' statements '}'                       # 丢弃元素，只循环次数
               | 'for' range '{' statements '}'                      # 整数范围，丢弃元素

# 详细说明：
# - expr：可迭代对象（数组、切片、迭代器等）
# - range：整数范围表达式，如 0..10 或 0..（无限范围）
# - |ID|：值迭代（只读），绑定元素值
# - |&ID|：引用迭代（可修改），绑定元素指针
# - 省略变量绑定：丢弃元素，只循环次数
# 详细语法说明见 [uya.md](./uya.md#8-控制流)
break_stmt     = 'break' ';'
continue_stmt  = 'continue' ';'
defer_stmt     = 'defer' ( statement | '{' statements '}' )
errdefer_stmt  = 'errdefer' ( statement | '{' statements '}' )

# defer/errdefer 块内禁止：return、break、continue 等控制流语句
# 允许：表达式、赋值、函数调用、语句块
# 替代方案：使用变量记录状态，在 defer/errdefer 外处理控制流
block_stmt     = '{' statements '}'
match_stmt     = match_expr
match_expr     = 'match' expr '{' pattern_list '}'
test_stmt      = 'test' STRING '{' statements '}'
```

### 表达式

```
expr           = assign_expr
assign_expr    = or_expr [ ('=' | '+=' | '-=' | '*=' | '/=' | '%=') assign_expr ]
or_expr        = xor_expr { '||' xor_expr }
xor_expr       = and_expr { '^' and_expr }
and_expr       = bitand_expr { '&&' bitand_expr }
bitand_expr    = eq_expr { '&' eq_expr }
eq_expr        = rel_expr { ('==' | '!=') rel_expr }
rel_expr       = shift_expr { ('<' | '>' | '<=' | '>=') shift_expr }
shift_expr     = add_expr { ('<<' | '>>') add_expr }
add_expr       = mul_expr { ('+' | '-' | '+|' | '-|' | '+%' | '-%') mul_expr }
mul_expr       = unary_expr { ('*' | '/' | '%' | '*|' | '*%') unary_expr }
unary_expr     = ('!' | '-' | '~' | '&' | '*' | 'try') unary_expr | cast_expr
cast_expr      = postfix_expr [ ('as' | 'as!') type ]
postfix_expr   = primary_expr { '.' (ID | NUM) | '[' expr ']' | '(' arg_list ')' | slice_op | catch_op }
                # '.' NUM 用于元组字段访问，如 tuple.0, tuple.1
                # 0.49.41：STRING 为 primary_expr 时，可接 '[' expr ']'（下标）或 slice_op（与数组字面量、标识符一致），如 "hello"[0:3]、&"hello"[0:3]
catch_op       = 'catch' [ '|' ID '|' ] '{' statements '}'
primary_expr   = ID | NUM | STRING | CHAR | 'true' | 'false' | 'null'
               | builtin_expr
               | struct_literal | array_literal | tuple_literal | enum_literal | union_literal
               | match_expr | '(' expr ')'
builtin_expr   = '@' ('sizeof' | 'alignof' | 'len' | 'max' | 'min' | 'params' | 'va_start' | 'va_end' | 'va_arg' | 'va_copy' | 'asm')
               | '@' ('mc_type' | 'mc_eval' | 'mc_ast' | 'mc_code' | 'mc_error' | 'mc_get_env' | 'mc_source') '(' expr_list ')'
               | vector_builtin_expr
               # @size_of(T)、@align_of(T)、@len(expr) 为调用形式；@max、@min 为值形式；@params 为函数体内参数元组；@va_start(&ap,last)、@va_end(&ap)、@va_arg(ap,Type)、@va_copy(&dest,src) 为可变参数栈访问（uya.md §5.4）；@asm 为内联汇编块（uya.md §19）
               # 宏系统内置（uya.md §25）：@mc_type(expr) 返回 TypeInfo；@mc_eval(expr) 编译时求值；@mc_ast(code)、@mc_code(ast)、@mc_error(msg)、@mc_get_env(name)；@mc_source(expr) 编译期将表达式序列化为字符串
vector_builtin_expr
               = '@vector' '.' 'splat' '(' expr ')'
               | '@vector' '.' 'load'  '(' expr ')'
               | '@vector' '.' 'store' '(' expr ',' expr ')'
               | '@vector' '.' 'select' '(' expr ',' expr ',' expr ')'
               | '@vector' '.' 'reduce_add' '(' expr ')'
               | '@vector' '.' 'any'   '(' expr ')'
               | '@vector' '.' 'all'   '(' expr ')'
union_literal  = ID '.' ID '(' expr ')'  # 联合体创建，如 IntOrFloat.i(42)、NetworkPacket.ipv4([...])
```

### SIMD 语义规则（第一阶段）

- `@vector(T, N)` 与 `@vector(U, M)` 仅当 `T == U` 且 `N == M` 时类型相等
- `@mask(N)` 与 `@mask(M)` 仅当 `N == M` 时类型相等
- `@mask(N)` 不隐式转换为 `bool`
- `@vector(T, N)` 不与标量类型隐式互转
- 算术运算 `+`、`-`、`*`、`/` 可用于相同类型的 `@vector(T, N)`，结果类型保持不变；`%` 仅可用于**整数元素**的相同类型 `@vector(T, N)`，按通道取模，结果类型保持不变；饱和运算 `+|`、`-|`、`*|` 仅可用于**有符号整数元素**的相同类型 `@vector(T, N)`；包装运算 `+%`、`-%`、`*%` 可用于**整数元素**的相同类型 `@vector(T, N)`（按通道，语义与标量一致）
- 位运算 `&`、`|`、`^`、`<<`、`>>` 与一元 `~` 仅适用于整数元素类型的 `@vector(T, N)`；一元 `-` 适用于整数或浮点元素类型的 `@vector(T, N)`
- 比较运算 `==`、`!=`、`<`、`<=`、`>`、`>=` 可用于相同类型的 `@vector(T, N)`，结果类型为 `@mask(N)`
- 掩码运算 `&`、`|`、`^`、`!` 可用于 `@mask(N)`
- `@vector.splat(x)` 通过上下文目标类型构造向量值；参数类型须与元素类型 `T` 一致或可隐式转换；无后缀浮点字面量为 `f64`，`f32` 向量须使用 `f32` 后缀（如 `1.0f32`）；目标类型还可由同一代数/比较/取模/饱和/包装表达式中另一侧的 `@vector` 操作数推断
- **`@vector.load(ptr)`**（**0.49.33**）：**`ptr`** 为 **`&T`**，与目标 **`@vector(T,N)`** 的元素类型匹配（**`byte`/`u8`** 互通规则同实现）；从 **`ptr`** 按向量大小装入向量值；目标类型上下文与 **`@vector.splat`** 相同；**不检查**缓冲区剩余长度
- **`@vector.store(ptr, v)`**（**0.49.34**）：**`v`** 为 **`@vector(T,N)`**，**`ptr`** 为 **`&T`** 且与 **`v`** 元素类型匹配（**`byte`/`u8`** 规则同 **`load`**）；将 **`v`** 按向量大小写入 **`ptr`**；**`void`**；**不检查**可写范围长度
- **`@vector.select(m, a, b)`**（**0.49.35**）：**`m`** 为 **`@mask(N)`**，**`a`**、**`b`** 为相同 **`@vector(T,N)`** 且 **`N`** 与 **`m`** 一致；通道 **`i`** 上 **`m`** 为真取 **`a`** 的分量，否则取 **`b`** 的分量；结果为 **`@vector(T,N)`**；目标类型上下文同 **`@vector.splat`** / **`load`**
- **`@vector.reduce_add(v)`**（**0.49.36**）：**`v`** 为 **`@vector(T,N)`**，元素类型 **`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，为各通道之和（**`+`** 语义同标量）
- `@vector.any(m)` 与 `@vector.all(m)` 接受 `@mask(N)` 并返回 `bool`
- 第一阶段不允许把 `@mask(N)` 直接作为 `if` / `while` 条件
- 第一阶段不引入 **`shuffle`**；**`reduce_*`** 中仅纳入 **`@vector.reduce_add`**（**0.49.36**），其它 **`reduce_*`** 仍暂缓

### 内联汇编

```
asm_stmt       = '@asm' '{' { asm_instruction } '}' [ 'clobbers' '=' '[' STRING { ',' STRING } ']' ]
asm_instruction = STRING '(' [ expr_list ] [ '->' expr_list ] ')' [ 'clobbers' '=' '[' STRING { ',' STRING } ']' ] ';'
```

**说明**：
- **@asm 块**：内联汇编语句块，包含一条或多条汇编指令
- **指令模板**：字符串字面量，使用 `{name}` 作为占位符
- **输入列表**：指令的输入操作数，多个用逗号分隔
- **输出列表**：指令的输出操作数，使用 `->` 分隔
- **clobbers 声明**：显式声明被修改的寄存器列表
- **内存修改**：使用 `"memory"` 字符串声明内存被修改

**示例**：
```uya
// 单条指令
@asm {
    "add {a}, {b}" (a, b, -> result);
}

// 多条指令
@asm {
    "mov rax, 1" (-> _);
    "syscall" (rax, rdi, rsi, rdx, -> result);
} clobbers = ["rcx", "r11", "memory"];

// 原子操作
@asm {
    "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
}
```

**寄存器类型**：
```uya
type @asm_reg = opaque;       // 编译器自动分配的通用寄存器
type @asm_reg_x64 = opaque;   // x86-64 专用寄存器
type @asm_reg_x86 = opaque;   // x86 专用寄存器
type @asm_reg_arm64 = opaque; // ARM64 专用寄存器
```

**内存操作类型**：
```uya
type @asm_mem<T> = opaque;    // 类型安全的内存操作包装
```

**平台检测**：
```uya
enum @asm_target {
    x86_64_linux,
    x86_64_macos,
    x86_64_windows,
    arm64_linux,
    arm64_macos,
    arm64_windows,
}

const target: @asm_target = @asm_target();
```

**详细说明**：见 [uya.md](./uya.md#19-内联汇编) 内联汇编章节

### 特殊表达式

```
range          = expr '..' [ expr ]
slice_op       = '[' expr ':' expr ']'  // 切片操作；典型为 &base[start:len]；base 可为标识符、数组字面量或 STRING（0.49.41）
struct_literal = ID '{' field_init_list '}'
field_init_list = [ field_init { ',' field_init } ]
field_init     = ID ':' expr
array_literal  = '[' expr_list ']' | '[' expr ':' expr ']'  # 数组字面量；重复形式 [value: N] 与类型 [T: N] 一致；空列表 [] 表示未初始化（仅当变量类型已明确时可用）
tuple_literal  = '(' expr_list ')'  # 元组字面量，如 (10, 20, 30)
enum_literal   = ID '.' ID  # 枚举字面量，如 Color.RED, HttpStatus.OK
expr_list      = [ expr { ',' expr } ]  # 表达式列表，可以为空（空数组字面量 []）
arg_list       = [ expr { ',' expr } [ ',' '...' ] ]  # 可变参数转发：末尾 ... 表示转发剩余参数
pattern_list   = pattern '=>' expr { ',' pattern '=>' expr } [ ',' 'else' '=>' expr ]
pattern        = literal | ID | '_' | struct_pattern | tuple_pattern | enum_pattern
               | union_pattern | error_pattern
struct_pattern = ID '{' field_pattern_list '}'
field_pattern_list = [ field_pattern { ',' field_pattern } ]
field_pattern  = ID ':' (literal | ID | '_')
tuple_pattern  = '(' tuple_pattern_list ')'  # 元组模式，如 (x, _, z)
tuple_pattern_list = pattern { ',' pattern }  # 用于元组模式的模式列表
enum_pattern   = ID '.' ID  # 枚举模式，如 Color.RED, HttpStatus.OK
union_pattern  = '.' ID [ '(' (ID | '_') ')' ]  # 联合体模式，如 .i(x)、.f(_)
error_pattern  = 'error' '.' ID
literal        = NUM | STRING | CHAR | 'true' | 'false' | 'null'
```

### 模块系统

```
export_decl    = 'export' (fn_decl | struct_decl | union_decl | interface_decl | enum_decl
               | const_decl | error_decl | extern_decl)
import_stmt    = 'use' module_path [ 'as' ID ] ';'
module_path    = ID { '.' ID }
```

**说明**：
- **导出语法**：使用 `export` 关键字标记可导出的项
  - `export fn public_function() i32 { ... }`
  - `export struct PublicStruct { ... }`
  - `export interface PublicInterface { ... }`
  - `export const PUBLIC_CONST: i32 = 42;`
  - `export error PublicError;`
  - `export extern printf(fmt: *byte, ...) i32;`（导出外部 C 函数声明，无函数体，链接到 C 标准库）
  - `export extern strcmp(s1: &const byte, s2: &const byte) i32 { ... }`（Uya 实现，以裸函数名导出）
- **导入语法**：
  - 导入整个模块：`use std.io;`（使用时需要模块前缀：`std.io.read_file()`）
  - 导入特定项：`use std.io.read_file;`（直接使用：`read_file()`）
  - 导入并重命名：`use std.io as io_module;`（使用别名：`io_module.read_file()`）
- **模块路径**：使用 `.` 分隔，相对于项目根目录
  - 项目根目录：`main` 模块
  - 子目录：`std/io/` → `std.io`
- **同目录文件合并规则**：
  - 同一目录下的所有 `.uya` 文件都属于同一个模块
  - 模块路径由目录路径决定，不包含文件名
  - 例如：`std/io/file.uya` 和 `std/io/stream.uya` 都属于 `std.io` 模块
  - 编译器会自动收集同一目录下的所有 `.uya` 文件，合并为一个模块
- 详细说明见 [uya.md](./uya.md#15-模块系统)

### 外部函数接口（FFI）

```
extern_decl    = 'extern' [ STRING ] 'fn' ID '(' [ param_list ] ')' type (';' | '{' statements '}')
               | 'extern' 'union' ID '{' field_list '}'  # 外部 C 联合体声明
               | 'extern' ( 'const' | 'var' ) ID ':' type ';'  # 外部 C 变量声明（0.43 新增）
```

**说明**（0.43 新增 `extern "libc"` 和 `extern` 变量）：
- `extern fn name(...) type;` - 声明外部 C 函数（导入，供 Uya 调用）
- `extern "libc" fn name(...) type;` - 声明 C 标准库函数（与 `extern fn` 等价）
- `extern fn name(...) type { ... }` - 导出 Uya 函数为 C 函数（导出，供 C 调用）
  - 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
  - 函数必须使用 C 兼容的类型（FFI 指针类型 `*T`、基本类型等）
- **byte 类型映射规则**（0.43 新增）：`byte` → `char`（C 字符类型，与 C 标准库兼容）
- **extern 变量支持**（0.43 新增）：
  - `extern const name: type;` - 导入只读 C 全局变量，生成 `extern const type name;`
  - `extern var name: type;` - 导入可变 C 全局变量，生成 `extern type name;`
  - 示例：`extern const errno: i32;` `extern var optind: i32;` `extern const stdout: *void;`
- 所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- 结构体可以包含所有类型（包括切片、interface 等），编译器自动生成对应的 C 兼容布局

### 错误处理

```
error_decl     = 'error' ID ';'                              # 预定义错误声明（可选）
error_type     = 'error' '.' ID                              # 错误类型引用（预定义或运行时错误）
```

**说明**：
- **预定义错误**（可选）：使用 `error ErrorName;` 在顶层声明，属于全局命名空间
- **运行时错误**：使用 `error.ErrorName` 语法直接创建，无需预先声明
- 两种错误类型在语法上使用相同的引用形式 `error.ErrorName`
- **error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同 `error_id`；hash 冲突时编译器报错
- 详细说明见 [uya.md](./uya.md#2-类型系统) 错误类型部分

### 字符串插值

```
string_interp  = '"' { segment } '"'
segment        = TEXT | '${' expr [ ':' spec ] '}'
spec           = flag* width? precision? type
flag           = '#' | '0' | '-' | ' ' | '+'
width          = NUM | '*'
precision      = '.' NUM | '.*'
type           = 'd' | 'u' | 'x' | 'X' | 'f' | 'F' | 'e' | 'E' | 'g' | 'G' | 'c' | 'p'
```

### 注释

```
line_comment   = '//' .* '\n'
block_comment  = '/*' .* '*/'
```

### 词法规则

```
identifier     = [A-Za-z_][A-Za-z0-9_]*
NUM            = integer | float
integer        = decimal_integer | hex_integer | octal_integer | binary_integer
decimal_integer = [0-9] ( [0-9] | '_' )* [ int_suffix ]?
hex_integer    = '0' [xX] [0-9a-fA-F] ( [0-9a-fA-F] | '_' )* [ int_suffix ]?
octal_integer  = '0' [oO] [0-7] ( [0-7] | '_' )* [ int_suffix ]?
binary_integer = '0' [bB] [01] ( [01] | '_' )* [ int_suffix ]?
float          = [0-9] ( [0-9] | '_' )* '.' [0-9] ( [0-9] | '_' )* [ exponent ]? [ float_suffix ]?
               | [0-9] ( [0-9] | '_' )* exponent [ float_suffix ]?

int_suffix     = 'i8' | 'i16' | 'i32' | 'i64'
               | 'u8' | 'u16' | 'u32' | 'u64'
               | 'usize'

float_suffix   = 'f32' | 'f64'
exponent       = [eE] [+-]? [0-9] ( [0-9] | '_' )*
STRING         = '"' { string_char } '"' | '`' { character } '`'
string_char    = [^"\\] | escape_sequence
escape_sequence = '\\' ( 'n' | 'r' | 't' | '\\' | '"' | '0' | 'x' HEX HEX | 'u' HEX HEX HEX HEX )
CHAR           = '\'' ( [^'\\] | escape_sequence_char ) '\''
escape_sequence_char = '\\' ( 'n' | 'r' | 't' | '\\' | '\'' | '0' | '"' | 'x' HEX HEX | 'u' HEX HEX HEX HEX )
HEX            = [0-9a-fA-F]
TEXT           = [^${}]+
```

**说明**：
- 整数字面量默认类型为 `i32`，浮点字面量默认类型为 `f64`
- 下划线 `_` 可出现在任意两个数字之间，不能出现在开头、结尾或连续出现
- 下划线不能紧跟在进制前缀之后（如 `0x_FF` 非法）
- 字符串字面量包括普通字符串 `"..."` 和原始字符串 `` `...` ``（无转义）；语义上自动带 `\0` 结尾；可初始化/赋值给 `[byte: N]`、**`&[const byte]`**（**0.49.43**）、`&byte`、`*byte`（详见 uya.md 文件与词法·字符串字面量）；**赋值语句左值**可为标识符或**成员访问链**（**`a.b.c = "..."`**）
- **`escape_sequence` / `escape_sequence_char`**（**0.49.42**）：**`\x`** 后须恰好两个 **`HEX`**；**`\u`** 后须恰好四个 **`HEX`**，按 UTF-8 展开（字符串）或要求值 **≤255**（字符，见 uya.md §1.4）
- 字符字面量 `'x'` 类型为 `byte`，可赋值给 `byte`

### 可选特性（泛型和宏）

**泛型语法说明**：
- 泛型语法已整合到主要声明中（见[函数声明](#函数声明)、[结构体声明](#结构体声明)、[接口声明](#接口声明)）
- 使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`
- **函数泛型示例**：`fn max<T: Ord>(a: T, b: T) T { ... }`
- **结构体泛型示例**：`struct Vec<T: Default> { ... }`
- **接口泛型示例**：`interface Iterator<T> { ... }`
- **方法泛型示例**（0.47 新增）：
  ```uya
  struct Container<T> {
      value: T,
      fn as_type<U>(self: &Self) U { return self.value as U; }
  }
  // 调用：c.as_type<i64>()
  ```
- **类型参数使用示例**：`Vec<i32>`, `Iterator<String>`

**显式宏语法（可选特性）**：
```
macro_decl     = [ 'export' ] 'mc' ID '(' [ param_list ] ')' return_tag '{' statements '}'
param_list     = param { ',' param }
param          = ID ':' param_type [ '=' default_value ]
param_type     = 'expr' | 'stmt' | 'type' | 'pattern' | 'ident'
return_tag     = 'expr' | 'stmt' | 'struct' | 'type'
macro_call     = ID '(' arg_list ')'
```

**说明**：
- `mc` 关键字用于声明宏
- `export mc` 可导出宏供其他模块使用
- 参数类型：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）、`ident`（标识符）
- 返回标签：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）
- 参数默认值：支持为参数指定默认值，语法与函数参数默认值相同
- 宏调用语法与普通函数调用完全一致
- 跨模块宏导入：`use module.macro_name;`
- 详细说明见 [uya.md](./uya.md#25-宏系统)

**编译时类型反射（@mc_type 与 TypeInfo）**：
- `@mc_type(expr)` 为内置函数，参数为类型或表达式，返回 `TypeInfo` 结构体（编译时求值）。
- **TypeInfo**（由标准库 `lib/std/macro_typeinfo.uya` 定义或 codegen 自动生成）：包含 `name`（*i8）、`size`、`align`、`kind`、`is_integer`、`is_float`、`is_bool`、`is_pointer`、`is_array`、`is_void`、`field_count`、`fields`（固定长度数组）；**获取 fields 大小请用 `@len(info.fields)`**（不导出容量常量），用于宏内类型查询与 `for info.fields` 编译期展开。
- **FieldInfo**（同上）：包含 `name`（*i8）、`type_name`（*i8）；在 `for info.fields |var|` 展开时，`var.name` 替换为当前字段名的标识符 AST，`var.type_name` 替换为当前字段类型的类型 AST。详见 [uya.md §25.4.2](./uya.md#2542-mc_typeexpr) 当前实现小节。
- **宏展开期对 `for info.fields |var|` 的特殊处理**（语义规则，BNF 不变）：在宏体内，当 `for` 的集合表达式为 `expr.fields` 且 **`expr` 为标识符**、该标识符绑定到 `@mc_type(...)` 得到的 TypeInfo 结构体字面量时，在宏展开阶段将该 for **展开为顺序块**（即 `{ body_0; body_1; ... }`，n = field_count）；循环变量 `var` 的 **`var.name`** 在每轮替换为当前字段名的标识符 AST，**`var.type_name`** 替换为当前字段类型的类型 AST。仅对**宏体顶层**的此类 for 触发展开；受体非标识符或未绑定到 TypeInfo 时保持普通 for 语义，不报错。详见 [uya.md §25.6.1](./uya.md#2561-编译期-for-over-typeinfofields)。

**函数返回类型**：
- `type` 在 `fn_decl` 中作为返回类型，可为任意类型产生式，包括 `slice_type`、`error_union_type` 及其组合。
- 合法示例：`fn f() &[byte]`、`fn g() !&[byte]`、`fn h() !i32`。切片与错误联合作为返回值时，语义与 codegen 需支持返回切片结构体（如 `struct { ptr; len; }`）及错误联合的 payload 为切片的情形。


---

## 参考

- [uya.md](./uya.md) - 完整语言规范
- [grammar_quick.md](./grammar_quick.md) - 语法速查手册
- [comparison.md](./comparison.md) - 与其他语言的对比
