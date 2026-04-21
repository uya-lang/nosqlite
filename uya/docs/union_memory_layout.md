# Uya 联合体内存布局与 C 互操作指南

> 本文档从编译器代码自动生成，说明带标签类型的联合体如何工作

## 概述

Uya 提供两种联合体声明方式：

| 声明方式 | 内存布局 | C 兼容性 | 功能限制 |
|----------|----------|----------|----------|
| `union Name { ... }` | Tagged Union | 部分 | 完整功能 |
| `extern union Name { ... }` | C Union | **完全** | 有限功能 |

---

## 一、Tagged Union（带标签联合体）

### 1.1 内存布局

**普通 `union` 声明**会生成带运行时标签的结构体：

```uya
// Uya 源码
union IntOrFloat {
    i: i32,
    f: f64
}
```

**生成的 C 代码**：

```c
// 第一步：生成原始 union（存储实际数据）
union IntOrFloat {
    int i;
    double f;
};

// 第二步：生成带标签的包装结构体（仅对普通 union）
struct uya_tagged_IntOrFloat {
    int _tag;           // 运行时标签（变体索引）
    union IntOrFloat u; // 实际数据
};
```

### 1.2 标签类型系统工作原理

标签系统由三部分组成：

#### 1.2.1 构造阶段

```uya
// Uya 源码
const v = IntOrFloat.i(42);
```

**代码生成**（`src/codegen/c99/expr.uya:1975-1983`）：

```c
// 普通 union：生成带标签的结构体
((struct uya_tagged_IntOrFloat){
    ._tag = 0,  // 变体索引（i 是第一个变体，索引为 0）
    .u = (union IntOrFloat){ .i = (42) }
})

// extern union：直接构造 C union（无标签）
((union IntOrFloat){ .i = (42) })
```

#### 1.2.2 模式匹配阶段

```uya
// Uya 源码
match v {
    .i(x) => printf("int: %d\n", x),
    .f(x) => printf("float: %f\n", x)
}
```

**代码生成**（`src/codegen/c99/stmt.uya:1352-1372`）：

```c
// 运行时检查标签值
if (_uya_m._tag == 0) {
    int x = _uya_m.u.i;
    printf("int: %d\n", x);
} else if (_uya_m._tag == 1) {
    double x = _uya_m.u.f;
    printf("float: %f\n", x);
}
```

#### 1.2.3 完备性检查

编译器强制检查 match 必须覆盖所有变体（`src/checker/check_node_extra.uya:91-110`）：

```uya
// 编译错误：match 不完备
match v {
    .i(x) => handle_int(x)
    // 缺少 .f 分支
}

// 正确：覆盖所有变体
match v {
    .i(x) => handle_int(x),
    .f(x) => handle_float(x)
}

// 或使用 else 通配
match v {
    .i(x) => handle_int(x),
    else => handle_other()
}
```

---

## 二、Extern Union（C 兼容联合体）

### 2.1 声明与内存布局

**`extern union` 声明**生成与 C 完全兼容的 union：

```uya
// Uya 源码
extern union CData {
    bytes: [u8: 8],
    as_u64: u64,
    as_f64: f64
}
```

**生成的 C 代码**：

```c
// 仅生成原始 union，无包装结构体
union CData {
    unsigned char bytes[8];
    unsigned long as_u64;
    double as_f64;
};
```

### 2.2 功能限制

根据编译器实现（`src/checker/main.uya:96-99`, `src/checker/check_node_extra.uya:16-18`）：

| 功能 | 普通 union | extern union |
|------|-----------|--------------|
| 方法定义 | ✅ 支持 | ❌ 禁止 |
| 方法块 | ✅ 支持 | ❌ 禁止 |
| match 表达式 | ✅ 支持 | ❌ 禁止 |
| 变体构造 | ✅ 支持 | ✅ 支持（无标签） |
| 直接字段访问 | ❌ 禁止 | ❌ 禁止 |

**错误示例**：

```uya
extern union BadExample {
    a: i32,
    b: f32,
    
    // ❌ 编译错误：extern union 不能包含方法
    fn get_a(self: &Self) i32 {
        return self.a;  // 即使允许也无法安全实现
    }
}

// ❌ 编译错误：extern union 不支持 match
match c_data {
    .bytes(b) => process(b),
    else => {}
}
```

---

## 三、内存对齐与布局规则

### 3.1 对齐计算规则

联合体的对齐值等于最大变体的对齐值：

```uya
union AlignDemo {
    a: i8,    // 对齐 1 字节
    b: i32,   // 对齐 4 字节
    c: f64    // 对齐 8 字节
}
// 整体对齐 = max(1, 4, 8) = 8 字节
```

**C 代码生成**（`src/codegen/c99/structs.uya:235-252`）：

```c
union AlignDemo {
    char a;        // 1 字节 + 7 字节填充
    int b;         // 4 字节 + 4 字节填充
    double c;      // 8 字节（无需填充）
}; // sizeof = 8, alignof = 8
```

### 3.2 Tagged Union 内存开销

| 组件 | 大小计算 | 说明 |
|------|----------|------|
| `_tag` | `sizeof(int)` = 4 字节 | 变体索引 |
| 填充 | `alignof(union) - 4` 字节 | 对齐到 union 边界 |
| `u` | `sizeof(union)` | 实际数据 |

**示例**：

```uya
union TaggedExample {
    small: i8,     // 最大 1 字节
    big: [u8: 16]  // 16 字节
}
```

**内存布局**：

```
struct uya_tagged_TaggedExample {
    int _tag;          // 4 字节（偏移 0）
    // 12 字节填充（对齐到 16 字节边界）
    union TaggedExample u; // 16 字节（偏移 16）
}; // 总大小 = 32 字节
```

### 3.3 变体类型限制

**变体类型支持**：Union 变体**完全支持引用类型 `&T`**：

```uya
// ✅ 编译通过：引用类型变体完全合法
union IntOrRef {
    i: i32,
    r: &i32,      // 引用类型变体
}

// 使用示例
fn test_union_ref() void {
    var x: i32 = 42;
    const u: IntOrRef = IntOrRef.r(&x);
    match u {
        .i(v) => { },
        .r(v) => { },
    };
}
```

**生成的 C 代码**：
```c
union IntOrRef {
    int32_t i;
    int32_t * r;  // 引用类型映射为 C 指针
};
struct uya_tagged_IntOrRef { int _tag; union IntOrRef u; };
```

**注意**：`&T`（引用）和 `*T`（FFI 指针）的区别：
- `&T`：映射为 `const T *`（不可变指针）
- `*T`：映射为 `T *`（可变指针）

---

## 四、跨语言互操作指南

### 4.1 C 调用 Uya 函数

**Uya 定义**：

```uya
// 使用 extern union 确保 C 兼容
export extern union Packet {
    header: [u8: 4],
    cmd: u32
}

// 导出函数接受 C 兼容类型
export fn process_packet(pkt: &Packet) i32 {
    // ⚠️ 注意：不能使用 match，需要通过其他方式访问
    // extern union 不支持 match
    return pkt.cmd as i32;
}
```

**生成的 C 头文件**：

```c
// C 兼容的 union 定义
union Packet {
    unsigned char header[4];
    unsigned int cmd;
};

// 导出函数签名
int process_packet(union Packet *pkt);
```

**C 调用示例**：

```c
#include "packet.h"

int main() {
    union Packet pkt;
    pkt.cmd = 0x12345678;
    
    int result = process_packet(&pkt);
    return result;
}
```

### 4.2 Uya 调用 C 函数

**C 定义**：

```c
// c_lib.h
typedef union {
    int i;
    float f;
} CValue;

CValue create_c_value(int type);
```

**Uya 声明**：

```uya
// 使用 extern union 声明 C 定义的类型
extern union CValue {
    i: i32,
    f: f32
}

// 声明 C 函数
extern fn create_c_value(type: i32) CValue;

// 使用
fn use_c_value() void {
    const v: CValue = create_c_value(0);
    // ⚠️ extern union 不支持 match
    // 需要通过 C 函数或 FFI 指针访问
}
```

### 4.3 内存对齐注意事项

**问题场景**：不同编译器可能有不同的默认对齐策略

```c
// C 代码（GCC 默认）
#pragma pack(push, 1)  // 1 字节对齐
typedef struct {
    char a;
    int b;
} PackedStruct;
#pragma pack(pop)
```

**Uya 处理**：

```uya
// Uya 不支持 #pragma pack
// 解决方案：手动添加填充字段
struct PaddedStruct {
    a: u8,
    _pad: [u8: 3],  // 手动填充对齐
    b: i32
}

// 或使用 extern struct（需要确保 C 端也使用相同对齐）
```

---

## 五、最佳实践

### 5.1 选择正确的 Union 类型

| 场景 | 推荐类型 | 原因 |
|------|----------|------|
| Uya 内部数据处理 | `union` | 类型安全，match 完备检查 |
| 与 C 库交互 | `extern union` | 内存布局完全兼容 |
| 需要方法封装 | `union` | extern union 不支持方法 |
| 高性能场景 | `extern union` | 无标签开销 |

### 5.2 避免常见陷阱

#### 陷阱 1：混淆两种 union 的构造方式

```uya
union Normal { a: i32, b: f32 }
extern union Extern { a: i32, b: f32 }

var n = Normal.a(42);     // ✅ 返回 tagged struct
var e = Extern.a(42);     // ✅ 返回 C union（无标签）

// C 代码中的差异：
// n 的类型：struct uya_tagged_Normal
// e 的类型：union Extern
```

#### 陷阱 2：忘记 match 完备性

```uya
union Color { r: u8, g: u8, b: u8 }

// ❌ 编译错误：未覆盖所有变体
fn to_hex(c: Color) u32 {
    match c {
        .r(v) => return v as u32,
        .g(v) => return (v as u32) << 8
        // 缺少 .b 分支
    }
}

// ✅ 正确：覆盖所有变体
fn to_hex(c: Color) u32 {
    match c {
        .r(v) => return v as u32,
        .g(v) => return (v as u32) << 8,
        .b(v) => return (v as u32) << 16
    }
}
```

#### 陷阱 3：在 extern union 上使用 match

```uya
extern union CData { a: i32, b: f32 }

// ❌ 编译错误：extern union 不支持 match
fn process(d: CData) void {
    match d {
        .a(x) => handle_int(x),
        .b(x) => handle_float(x)
    }
}

// ✅ 替代方案：通过 C 函数处理
extern fn c_process_union(d: CData) void;
```

---

## 六、代码参考

### 6.1 关键源文件

| 文件 | 功能 |
|------|------|
| `src/ast.uya:174-181` | AST 节点定义 |
| `src/codegen/c99/structs.uya:221-258` | 联合体定义生成 |
| `src/codegen/c99/expr.uya:1963-1988` | 变体构造代码生成 |
| `src/codegen/c99/stmt.uya:1352-1372` | match 表达式代码生成 |
| `src/checker/check_node_extra.uya:14-110` | 语义检查规则 |

### 6.2 核心数据结构

```uya
// AST 节点（src/ast.uya:174-181）
struct ASTNode {
    // ...
    union_decl_name: &byte,
    union_decl_variants: & & ASTNode,
    union_decl_variant_count: i32,
    union_decl_methods: & & ASTNode,
    union_decl_method_count: i32,
    union_decl_is_extern: i32,  // 1 = C 兼容，0 = Tagged
    union_decl_is_export: i32,
    // ...
}
```

---

## 总结

| 特性 | `union` | `extern union` |
|------|---------|----------------|
| **内存布局** | `struct { int _tag; union U u; }` | `union U` |
| **标签开销** | 4 字节 + 填充 | 无 |
| **C 兼容性** | 需要 `uya_tagged_*` 包装 | **完全兼容** |
| **match 支持** | ✅ 完备性检查 | ❌ 不支持 |
| **方法支持** | ✅ | ❌ |
| **适用场景** | Uya 内部逻辑 | C FFI 互操作 |

**核心原则**：
1. 需要类型安全 → 使用 `union`
2. 需要 C 兼容 → 使用 `extern union`
3. 两者混用时注意内存布局差异
