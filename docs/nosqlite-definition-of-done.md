# NoSQLite Definition of Done 验收矩阵

日期：2026-04-23

本页把 `docs/nosqlite-todo.md` 中的 Definition of Done 映射到明确测试、验证脚本或文档证据。

一键验证入口：

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

## 功能验收

| DoD 项 | 证据 |
| --- | --- |
| 新建数据库、插入、查询、重启恢复全链路可跑通 | `nosqlite/test_exec_runtime.uya` 的 autocommit insert/query 与 reopen persistence；`nosqlite/test_phase12_features.uya` 的 Phase 12 reopen 查询 |
| `_id` 主键查找明显快于全表扫描 | `nosqlite/test_binder_planner.uya` 验证 `_id = literal` 规划为 `PrimaryLookup`；`docs/nosqlite-benchmark-v0.json` 中 `primary_lookup` 与 `seq_scan_filter` 均达到 `floor` |
| 未提交事务不会在恢复后可见 | `nosqlite/test_exec_runtime.uya` 的 `run_txn_uncommitted_invisible_then_commit` 与 `run_txn_rollback_and_drop_abort`；`nosqlite/test_storage_wal_runtime.uya` 的 uncommitted WAL tail recovery |
| 已提交事务在断电恢复后可见 | `nosqlite/test_storage_wal_runtime.uya` 的 committed redo；`nosqlite/test_exec_runtime.uya` 的 reopen persistence |
| 长查询执行期间提交不会打断已有读者 | `nosqlite/test_exec_runtime.uya` 的 commit view / retired view tests；`docs/nosqlite-benchmark-v0.json` 中 `long_query_concurrent_commit` 达到 `floor` |
| 同时具备 `db_query` 和 `db_query_cursor` | `nosqlite/test_exec_runtime.uya` 同时覆盖物化结果和流式 cursor；`docs/nosqlite-api-draft.md` 固定两个 API 名称 |
| 点查、顺扫、写入、恢复四类 benchmark 至少达到第 18 节 `floor` | `docs/nosqlite-benchmark-v0.json`：`primary_lookup`、`seq_scan_filter`、`durable_insert`、`recovery_open` 的 `floor_status` 均为 `pass` |
| 大整数与精确小数无静默降精度 | `nosqlite/test_docblob_codec.uya` 的 round-trip；`nosqlite/test_phase11_stability.uya` 的 numeric precision/order contract |
| 快照与 WAL 资源在生产策略下保持有界 | `nosqlite/test_storage_page_basics.uya` 的 snapshot pressure/checkpoint policy；`nosqlite/test_storage_wal_runtime.uya` 的 checkpoint truncate 和 soft-limit checkpoint；`nosqlite/test_exec_runtime.uya` 的 hard pressure cleanup |
| 文件格式升级/拒绝打开不兼容版本行为经过验证 | `nosqlite/test_phase13_format_upgrade.uya`；`docs/nosqlite-format-compat.md` |

## 工程约束验收

| DoD 项 | 证据 |
| --- | --- |
| 核心资源类型完成 `drop` 封装 | `nosqlite/test_core_foundation.uya` 资源模型；`nosqlite/test_storage_page_basics.uya` guard/pin drop；`nosqlite/test_exec_runtime.uya` cursor/query result/txn drop tracking |
| 核心错误路径完成 `errdefer` 回滚 | `nosqlite/lib/storage/pager.uya` 与 `nosqlite/lib/api/db.uya` 的 core errdefer paths；`nosqlite/test_storage_wal_runtime.uya`、`nosqlite/test_exec_runtime.uya`、`nosqlite/test_phase13_format_upgrade.uya` 覆盖回滚/恢复 |
| 锁与 pin 完成 guard 化 | `WriterLockGuard`、`PagePin`、`CommitViewPin` 与 `QueryCursor`；`nosqlite/test_storage_page_basics.uya`、`nosqlite/test_exec_runtime.uya` |
| 每个完成的能力项都能对应到明确的测试文件或测试组 | 本页矩阵；`nosqlite/tests/README.md` |
| 所有核心模块至少有单元测试 | `nosqlite/tests/README.md` 覆盖 core/doc/sql/plan/exec/storage 分组 |
| 至少有一组故障恢复测试 | `nosqlite/test_storage_wal_runtime.uya`；`nosqlite/test_phase11_stability.uya` corruption/recovery checks |
| 文档与示例可以独立指导使用 | `docs/README.md`、`docs/nosqlite-api-draft.md`、`docs/nosqlite-examples.md`、`docs/nosqlite-format-compat.md`、`docs/nosqlite-typed-sql.md` |

## 验证范围

`verify_definition_of_done.sh` 会串行运行全部当前可执行 Uya 测试入口，并执行 Phase 12.5 / Phase 14 的辅助验证脚本。脚本还会检查 `docs/nosqlite-benchmark-v0.json` 中 DoD 相关 benchmark case 的 `floor_status`。
