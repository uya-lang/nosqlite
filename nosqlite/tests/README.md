# NoSQLite Tests

这个目录承载测试分组说明、fixtures 规划和后续 golden/corruption 数据。

当前仓库有一个现实约束：

- Uya 会按测试入口文件所在目录推导项目根目录。
- 因此可直接执行的 `.uya` 测试入口目前仍放在 `nosqlite/` 根下。
- `nosqlite/tests/` 先作为“测试组织层”，而不是直接承载可执行入口。

当前目录结构：

- `nosqlite/tests/core/`
  对应基础类型、错误码、资源模型、配置轮廓。
- `nosqlite/tests/doc/`
  对应 `DocBlob`、路径、数值语义与编码规则。
- `nosqlite/tests/sql/`
  对应 SQL token、lexer、parser、JSON path 语法与 AST pretty print。
- `nosqlite/tests/storage/`
  对应 pager、page header、meta page、WAL header、slotted page。
- `nosqlite/tests/fixtures/`
  预留给 golden、corruption、recovery 和 catalog 样本。

测试文件命名约定：

- 所有可执行测试入口统一使用 `test_*.uya`
- 复现/诊断文件使用 `repro_*.uya`
- shell 验证脚本使用 `verify_*.sh`

当前测试入口与逻辑分组映射：

- `nosqlite/test_core_foundation.uya` -> `tests/core/`
- `nosqlite/test_docblob_basics.uya` -> `tests/doc/`
- `nosqlite/test_docblob_codec.uya` -> `tests/doc/`
- `nosqlite/test_docblob_path.uya` -> `tests/doc/`
- `nosqlite/test_sql_parser.uya` -> `tests/sql/`
- `nosqlite/test_storage_page_basics.uya` -> `tests/storage/`
- `nosqlite/test_storage_pager_runtime.uya` -> `tests/storage/`
- `nosqlite/test_storage_slotted_page_runtime.uya` -> `tests/storage/`
- `nosqlite/test_storage_wal_runtime.uya` -> `tests/storage/`
- `nosqlite/test_catalog_basics.uya` -> `tests/storage/`
- `nosqlite/test_index_btree.uya` -> `tests/storage/`
