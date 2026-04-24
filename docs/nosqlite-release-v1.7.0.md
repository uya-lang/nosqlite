# NoSQLite 版本发布说明：nosqlite-v1.7.0

日期：2026-04-24

`nosqlite-v1.7.0` 是 NoSQLite 在 `v1.6.0` 性能发布之后的一次恢复路径与压力门收束发布：重点不在新增功能，而在把 dirty WAL recovery/open 的真实热路径继续压缩，同时补齐更硬的 benchmark 口径、回归测试和压力报告产物。

项目仓库：`https://github.com/uya-lang/nosqlite`

## 发布状态

| 项目 | 状态 |
| --- | --- |
| 发布主题 | recovery 优化与压力验证收束 |
| 基线版本 | `nosqlite-v1.6.0` |
| 完整验收入口 | `bash nosqlite/tests/verify_definition_of_done.sh` |
| SQLite 对比入口 | `python3 nosqlite/benchmark_sqlite_compare.py` |
| 压力报告入口 | `python3 nosqlite/stress_runtime_report.py` |
| 发布状态 | 性能更新发布 |

## 版本重点

- 将 recovery benchmark 明确拆分为 `recovery_open_with_auto_checkpoint` 与 `dirty_wal_recovery_open` 两条口径。
- 补齐 open 路径上的 auto-checkpoint / truncate 语义，避免 recovery 后 WAL 悬挂。
- 优化 dirty WAL recovery 的回放路径，减少重复 page replay、无效大缓冲初始化和多余的 WAL checkpoint 构造成本。
- 将 dirty-WAL benchmark 的准备阶段改成“clean base + one dirty txn”，避免口径混淆。
- 同步更新 SQLite 对照准备方式，确保横向比较仍是同一工作负载。
- 新增/强化 recovery reopen、WAL truncate、stress runtime 报告与 DoD 证据链。

## 当前性能摘要

以下数据来自同机 `NoSQLite vs SQLite JSON1` 对比报告，测试日期为 `2026-04-24`，数据集为 `3` 个平均 `1024` bytes 文档，请求迭代数为 `10`。

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 1 | 3 | NoSQLite faster x3.00 | 1 | 4 |
| seq_scan_filter | warm-read | 2 | 4 | NoSQLite faster x2.00 | 2 | 6 |
| durable_insert | durable-write | 65 | 60 | SQLite faster x1.08 | 89 | 83 |
| dirty_wal_recovery_open | recovery | 74 | 71 | SQLite faster x1.04 | 95 | 111 |
| long_query_concurrent_commit | durable-write | 77 | 67 | SQLite faster x1.15 | 90 | 73 |

同一轮 v0 benchmark 里，NoSQLite 的 `dirty_wal_recovery_open` 已经到 `p50=78us`、`p95=118us`；在 SQLite 对照报告中同口径为 `p50=74us` 对 `71us`，已经进入同一量级对比区间。

## 与 v1.6.0 的关系

- `v1.6.0` 解决的是热路径是否已经被真正打磨出来。
- `v1.7.0` 解决的是 recovery 指标是否有清晰、不含糊的口径，以及 dirty WAL reopen 是否能在同口径下继续压到双位数/百微秒附近。
- 这不是功能面扩张版本，而是一次把“性能结果是否可信、是否可复验”继续收紧的版本。

## 相关文档

- SQLite 对比 benchmark：[`nosqlite-sqlite-compare.md`](./nosqlite-sqlite-compare.md)
- v0 benchmark：[`nosqlite-benchmark-v0.md`](./nosqlite-benchmark-v0.md)
- 压力测试报告：[`nosqlite-stress-report.md`](./nosqlite-stress-report.md)
- Definition of Done：[`nosqlite-definition-of-done.md`](./nosqlite-definition-of-done.md)
- v1.6.0 发布说明：[`nosqlite-release-v1.6.0.md`](./nosqlite-release-v1.6.0.md)
- v1.5.0 封板说明：[`nosqlite-release-v1.5.0.md`](./nosqlite-release-v1.5.0.md)

## 当前边界

- 单进程嵌入式使用。
- 单写者设计。
- benchmark 仍是小样本原型数据集，不代表生产 SLO。
- 当前 v1 原型容量虽已高于早期单页阶段，但仍不是大规模工程化存储实现。
- 暂不包含 MVCC、聚合框架、全文检索、网络协议、GIN/HASH 索引族。

## 复现入口

```bash
bash nosqlite/tests/verify_definition_of_done.sh
python3 nosqlite/benchmark_sqlite_compare.py
python3 nosqlite/stress_runtime_report.py
```
