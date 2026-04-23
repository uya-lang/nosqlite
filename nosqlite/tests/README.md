# NoSQLite Tests

这个目录承载测试分组说明、fixtures 规划和后续 golden/corruption 数据。

当前仓库有一个 Uya 模块根约束：

- Uya 会按测试入口文件所在目录推导项目根目录。
- 因此每个分类目录都包含一个 `lib -> ../../lib` 符号链接，让移动后的测试仍能使用 `use lib...` 模块路径。
- 可执行 `.uya` 测试入口现在按分类直接放在 `nosqlite/tests/<group>/` 下。

当前目录结构：

- `nosqlite/tests/core/`
  对应基础类型、错误码、资源模型、配置轮廓。
- `nosqlite/tests/doc/`
  对应 `DocBlob`、路径、数值语义与编码规则。
- `nosqlite/tests/sql/`
  对应 SQL token、lexer、parser、JSON path 语法与 AST pretty print。
- `nosqlite/tests/plan/`
  对应 Binder、Planner、索引选择、Filter/Limit 规划与 EXPLAIN。
- `nosqlite/tests/exec/`
  对应执行层、流式 cursor、物化结果、投影、过滤、Limit 与执行期错误。
- `nosqlite/tests/storage/`
  对应 pager、page header、meta page、WAL header、slotted page。
- `nosqlite/tests/fixtures/`
  预留给 golden、corruption、recovery 和 catalog 样本。

测试文件命名约定：

- 所有可执行测试入口统一使用 `test_*.uya`
- 复现/诊断文件使用 `repro_*.uya`
- shell 验证脚本使用 `verify_*.sh`

当前测试入口与逻辑分组映射：

- `nosqlite/tests/core/test_core_foundation.uya`
- `nosqlite/tests/doc/test_docblob_basics.uya`
- `nosqlite/tests/doc/test_docblob_codec.uya`
- `nosqlite/tests/doc/test_docblob_path.uya`
- `nosqlite/tests/sql/test_sql_parser.uya`
- `nosqlite/tests/sql/test_phase14_typed_sql.uya`
- `nosqlite/tests/plan/test_binder_planner.uya`
- `nosqlite/tests/exec/test_exec_runtime.uya`
- `nosqlite/tests/exec/test_phase12_async.uya`
- `nosqlite/tests/exec/test_phase12_features.uya`
- `nosqlite/tests/exec/test_stress_runtime.uya`
- `nosqlite/tests/storage/test_storage_page_basics.uya`
- `nosqlite/tests/storage/test_storage_pager_runtime.uya`
- `nosqlite/tests/storage/test_storage_slotted_page_runtime.uya`
- `nosqlite/tests/storage/test_storage_wal_runtime.uya`
- `nosqlite/tests/storage/test_phase13_format_upgrade.uya`
- `nosqlite/tests/storage/test_catalog_basics.uya`
- `nosqlite/tests/storage/test_index_btree.uya`
- `nosqlite/tests/storage/test_phase11_stability.uya`
- `nosqlite/tests/verify_phase12_5_async_boundary.sh` -> Phase 12.5 async boundary verification
- `nosqlite/tests/verify_phase14_typed_sql_errors.sh` -> Phase 14 typed SQL static-error verification
- `nosqlite/tests/verify_definition_of_done.sh` -> Definition of Done verification
