# NoSQLite Typed SQL 静态校验

日期：2026-04-23

Phase 14 增加一层轻量静态 SQL/schema 校验，用来在 SQL 字符串进入执行器前发现明显错误。

## Schema 描述格式

静态 schema 使用简单文本描述：

```text
collection.path:type; collection.nested.path:type
```

当前支持的类型：

- `string`
- `number`
- `bool`
- `null`
- `any`

示例：

```text
users.name:string; users.age:number; users.active:bool; users.profile.name:string
```

路径写 schema 时不带 `$.` 前缀；SQL 中仍使用 `$.path`。

## API

```uya
use lib.sql.typed.TypedSqlValidationCode;
use lib.sql.typed.TypedSqlValidationResult;
use lib.sql.typed.typed_sql_validate;

const result: TypedSqlValidationResult = typed_sql_validate(
    "SELECT $.name FROM users WHERE $.age >= 18;",
    "users.name:string; users.age:number",
);
```

`typed_sql_validate` 只检查静态字段和字面量类型：

- collection 是否在 schema 中声明
- SQL 引用的 JSON path 是否在对应 collection 下声明
- `= != < <= > >=` 两侧字段类型与字面量类型是否兼容
- `WHERE` / `AND` / `OR` 等表达式是否符合布尔语义

`typed_sql(sql, schema)` 是用户侧宏入口，返回原 SQL 字符串，便于调用处保持声明式写法：

```uya
const q: &[const byte] = typed_sql(
    "SELECT $.name FROM users;",
    "users.name:string; users.age:number",
);
```

当前 Uya 宏系统不会执行宏体内的条件控制流，因此 Phase 14 的错误校验由 `typed_sql_validate` 和 `nosqlite/tests/verify_phase14_typed_sql_errors.sh` 覆盖；宏入口先固定 API 路径，等待编译器支持条件化 `@mc_error` 后可无缝升级成真正的宏期失败。

## 边界

静态 schema 不是运行时事实源。执行期仍以 catalog、真实文档内容、索引和存储层为准；Phase 14 只用于提前发现字符串级别的字段与类型错误。

测试覆盖：

- `nosqlite/tests/sql/test_phase14_typed_sql.uya`
- `nosqlite/tests/verify_phase14_typed_sql_errors.sh`
