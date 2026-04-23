# SQL Test Group

本组覆盖：

- token 集合与保留字
- SQL lexer
- `SELECT` / `INSERT` / `CREATE COLLECTION` 解析
- 表达式优先级
- JSON path 语法解析
- AST pretty print
- Phase 14 typed SQL 静态 schema 校验

当前入口文件：

- `nosqlite/test_sql_parser.uya`
- `nosqlite/test_phase14_typed_sql.uya`

辅助验证脚本：

- `nosqlite/tests/verify_phase14_typed_sql_errors.sh`
