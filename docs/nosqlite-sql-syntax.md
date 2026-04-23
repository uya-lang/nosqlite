# NoSQLite SQL 语法说明

日期：2026-04-23

本文档描述的是 NoSQLite 当前代码已经实现并可被 `nosqlite/lib/sql/*` 解析的 SQL 子集。

这不是“未来计划语法”，而是当前 `Phase 6` 的真实语法边界。

## 1. 范围

当前支持七类语句：

- `CREATE COLLECTION`
- `INSERT INTO ... JSON ...`
- `SELECT ... FROM ... [WHERE ...] [ORDER BY ...] [LIMIT ...]`
- `UPDATE ... SET ... [WHERE ...]`
- `DELETE FROM ... [WHERE ...]`
- `CREATE INDEX ... ON ... (...)`
- `EXPLAIN SELECT ...`

当前不支持：

- `GROUP BY`
- `JOIN`
- 子查询
- 注释语法
- 双引号标识符

## 2. 词法规则

### 2.1 空白符

以下字符会被当作空白跳过：

- 空格 ` `
- 制表符 `\t`
- 换行 `\n`
- 回车 `\r`

### 2.2 标识符

标识符规则：

- 首字符必须是字母或下划线 `_`
- 后续字符可以是字母、数字或下划线 `_`

等价正则：

```text
[A-Za-z_][A-Za-z0-9_]*
```

例子：

- `users`
- `_id`
- `user_01`

当前不支持：

- 反引号标识符
- 双引号标识符
- 带空格或连字符的标识符

### 2.3 关键字

关键字大小写不敏感。

当前保留字：

- `SELECT`
- `FROM`
- `WHERE`
- `LIMIT`
- `INSERT`
- `INTO`
- `JSON`
- `CREATE`
- `COLLECTION`
- `AND`
- `OR`
- `NOT`
- `IS`
- `NULL`
- `TRUE`
- `FALSE`

因为关键字在词法阶段优先识别，所以这些词不能直接当普通标识符使用。

例如下面当前会解析失败：

```sql
CREATE COLLECTION SELECT;
```

### 2.4 数字字面量

当前支持两类数值 token：

- `INT`
- `NUMBER`

支持的形式：

- 整数：`18`
- 小数：`18.5`
- 指数：`1e3`、`1.25E-2`

当前规则：

- 小数点后必须至少有一位数字
- 指数部分后必须至少有一位数字
- 前导负号不是数值 token 的一部分，而是通过一元运算符 `-` 解析

因此：

- `-18` 合法，按一元负号 + `18` 解析
- `+18` 当前不合法，虽然 `+` 会被词法识别，但 parser 不接受
- `1.` 当前不合法

### 2.5 字符串字面量

字符串使用单引号：

```sql
'hello'
```

单引号转义使用双单引号：

```sql
'it''s ok'
```

当前不支持：

- 双引号字符串
- 反斜杠转义

### 2.6 标点与操作符

当前支持的标点：

- `,`
- `;`
- `.`
- `$`
- `[`
- `]`
- `(`
- `)`

当前支持的比较操作符：

- `=`
- `!=`
- `<`
- `<=`
- `>`
- `>=`

当前 lexer 还能识别：

- `+`
- `-`

但 parser 里只有一元负号 `-expr` 被真正支持，`+` 暂未进入表达式语法。

## 3. 总体语法

语句末尾分号 `;` 是可选的。

等价 EBNF：

```ebnf
stmt              := create_collection_stmt
                   | insert_stmt
                   | select_stmt

create_collection_stmt
                  := "CREATE" "COLLECTION" ident [";"]

insert_stmt       := "INSERT" "INTO" ident "JSON" string_literal [";"]

select_stmt       := "SELECT" select_item { "," select_item }
                     "FROM" ident
                     [ "WHERE" expr ]
                     [ "LIMIT" int_literal ]
                     [";"]

select_item       := expr
```

## 4. `CREATE COLLECTION`

语法：

```ebnf
"CREATE" "COLLECTION" ident
```

例子：

```sql
CREATE COLLECTION users;
CREATE COLLECTION events
```

## 5. `INSERT`

语法：

```ebnf
"INSERT" "INTO" ident "JSON" string_literal
```

这里的 JSON 文档当前以 SQL 字符串字面量形式出现。

例子：

```sql
INSERT INTO users JSON '{"name":"ann","age":25}';
INSERT INTO events JSON '{"kind":"login","ok":true}';
```

说明：

- 这里 parser 只检查 SQL 语法，不负责验证字符串内容是不是合法 JSON
- JSON 本体通常使用双引号，外层 SQL 字符串使用单引号

## 6. `SELECT`

语法：

```ebnf
"SELECT" select_item { "," select_item }
"FROM" ident
[ "WHERE" expr ]
[ "LIMIT" int_literal ]
```

例子：

```sql
SELECT _id FROM users;

SELECT _id, $.name, $.age
FROM users
WHERE $.age >= 18
LIMIT 10;

SELECT $.user.scores[1] FROM users;
```

### 6.1 选择项

当前 `SELECT` 列表里的每一项都是一个表达式。

最常见的选择项：

- `_id`
- `$.path`
- 常量表达式

例如：

```sql
SELECT _id, $.name, TRUE FROM users;
```

### 6.2 `FROM`

当前 `FROM` 后只能跟一个 collection 名称：

```sql
FROM users
```

不支持：

- 多表
- 别名
- `AS`

### 6.3 `WHERE`

`WHERE` 后接布尔表达式。

例如：

```sql
WHERE $.age >= 18
WHERE NOT $.deleted IS NULL
WHERE $.active = TRUE OR $.score >= 10
```

### 6.4 `LIMIT`

`LIMIT` 后当前只接受无符号整数字面量：

```sql
LIMIT 10
```

不支持：

- `LIMIT -1`
- `LIMIT 1 + 2`
- `OFFSET`

## 7. 表达式语法

当前表达式节点类型：

- 系统列 `_id`
- JSON path
- 字面量
- 二元逻辑/比较表达式
- 一元表达式
- `IS NULL`

等价 EBNF：

```ebnf
expr              := or_expr

or_expr           := and_expr { "OR" and_expr }

and_expr          := not_expr { "AND" not_expr }

not_expr          := "NOT" not_expr
                   | comparison_expr

comparison_expr   := prefix_expr
                     [ ( "=" | "!=" | "<" | "<=" | ">" | ">=" ) prefix_expr
                     | "IS" "NULL"
                     ]

prefix_expr       := "-" prefix_expr
                   | primary_expr

primary_expr      := "_id"
                   | path_expr
                   | literal
                   | "(" expr ")"
```

### 7.1 支持的字面量

支持：

- `NULL`
- `TRUE`
- `FALSE`
- 整数
- 小数
- 指数字面量
- 单引号字符串

例子：

```sql
NULL
TRUE
FALSE
18
18.5
1e-3
'ann'
```

### 7.2 比较

支持：

- `=`
- `!=`
- `<`
- `<=`
- `>`
- `>=`
- `IS NULL`

例子：

```sql
$.age >= 18
_id = 42
$.name != 'ann'
$.deleted IS NULL
```

当前不支持：

- `IS NOT NULL`
- `LIKE`
- `IN`
- `BETWEEN`

### 7.3 一元表达式

支持：

- `NOT expr`
- `-expr`

例子：

```sql
NOT $.active = TRUE
-1
$.score >= -10
```

### 7.4 运算符优先级

当前优先级从低到高如下：

1. `OR`
2. `AND`
3. 比较与 `IS NULL`
4. `NOT`
5. 一元负号 `-`
6. 主表达式

注意：

- 当前 `NOT a < b` 会按 `NOT (a < b)` 解析
- pretty print 会按当前优先级补最少必要括号

## 8. JSON Path 语法

当前 SQL 里的 path 语法与 `lib/doc/path.uya` 保持一致。

语法：

```ebnf
path_expr         := "$" path_step { path_step }

path_step         := "." ident
                   | "[" int_literal "]"
```

例子：

```sql
$.name
$.user.name
$.user.scores[1]
$.items[0].price
```

当前限制：

- path 必须以 `$` 开头
- `.` 后只能跟标识符风格字段名
- `[]` 里只能是十进制整数
- 不支持 quoted key
- 不支持 `[*]`
- 不支持 `..`
- 不支持切片
- 不支持 filter path

因此下面当前不支持：

```sql
$                 -- 只有根，没有 step
$.user."full-name"
$['name']
$.items[*]
$.a..b
```

## 9. Pretty Print 规则

当前 `sql_stmt_pretty_print(...)` 输出的是规范化 SQL 形式，规则如下：

- 关键字统一大写
- 布尔与 `NULL` 统一大写
- 使用单个空格分隔主要语法片段
- 输出语句末尾统一带 `;`
- 按当前优先级补最少必要括号

例如输入：

```sql
select _id, $.name from users where $.age >= 18 and $.active = true limit 10
```

pretty print 输出：

```sql
SELECT _id, $.name FROM users WHERE $.age >= 18 AND $.active = TRUE LIMIT 10;
```

## 10. 实现限制

这是当前 parser/AST 的实现上限，不只是语法偏好：

- 最多 `256` 个 token
- 最多 `16` 个 `SELECT` item
- 最多 `128` 个表达式节点
- collection 标识符最大长度 `64`
- path 最大长度 `128`
- 字面量文本最大长度 `2048`

## 11. 错误示例

以下语句当前会报语法错误：

```sql
SELECT $ FROM users;
SELECT $.a.[0] FROM users;
CREATE COLLECTION SELECT;
INSERT users JSON '{}';
SELECT _id FROM users LIMIT -1;
SELECT _id FROM users WHERE $.age IS NOT NULL;
```

## 12. 当前支持的完整示例

```sql
CREATE COLLECTION users;

INSERT INTO users JSON '{"name":"ann","age":25,"active":true}';

SELECT _id, $.name, $.age
FROM users
WHERE NOT $.age < 18 AND $.active = TRUE OR $.score >= 10
LIMIT 5;
```
