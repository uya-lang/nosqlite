# NoSQLite 版本发布说明：nosqlite-v1.6.0

日期：2026-04-24

`nosqlite-v1.6.0` 是 NoSQLite 在 `v1.5.0` 封板之后的一次性能优化发布：核心目标不是扩张功能面，而是把查询、提交、恢复和并发读写边界上的热路径压到更轻，同时继续守住 WAL、snapshot、recovery 和格式兼容的正确性约束。

项目仓库：`https://github.com/uya-lang/nosqlite`

## 发布状态

| 项目 | 状态 |
| --- | --- |
| 发布主题 | 性能优化与对标校准 |
| 基线版本 | `nosqlite-v1.5.0` |
| 完整验收入口 | `bash nosqlite/tests/verify_definition_of_done.sh` |
| SQLite 对比入口 | `python3 nosqlite/benchmark_sqlite_compare.py` |
| 发布状态 | 性能更新发布 |

## 版本重点

- 新增 SQLite JSON1 同机横向 benchmark，为 NoSQLite 建立统一的性能参照物。
- 优化查询热路径，减少 parser / binder / planner 的重复开销。
- 增加 warm read planning、查询计划缓存与结果集池化分配。
- 优化主键 B+Tree 复用与 fast accessor 路径，缩短点查和顺序扫描的热段。
- 调整 collection/row 的加载策略，支持更轻量的 header-only 读取与按需 materialize blob。
- 优化 pager session、WAL batch 提交和 open-files commit path，降低 durable write / recovery 成本。
- 补充 lazy reopen、snapshot materialization、WAL replay 匹配 tail 等稳定性覆盖。

## 当前性能摘要

以下数据来自同机 `NoSQLite vs SQLite JSON1` 对比报告，测试日期为 `2026-04-24`，数据集为 `3` 个平均 `1024` bytes 文档，请求迭代数为 `10`。

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 1 | 3 | NoSQLite faster x3.00 | 3 | 4 |
| seq_scan_filter | warm-read | 2 | 4 | NoSQLite faster x2.00 | 5 | 6 |
| durable_insert | durable-write | 61 | 58 | SQLite faster x1.05 | 277 | 82 |
| recovery_open | recovery | 91 | 103 | NoSQLite faster x1.13 | 111 | 158 |
| long_query_concurrent_commit | durable-write | 45 | 70 | NoSQLite faster x1.56 | 96 | 91 |

这组数据说明 NoSQLite 已经从 `v1.5.0` 时明显的毫秒级原型热路径，推进到关键路径微秒级/百微秒级表现；其中 warm read、recovery open 和 long query concurrent commit 在当前口径下已经跑到与 SQLite JSON1 同量级甚至更快。

## 与 v1.5.0 的关系

- `v1.5.0` 解决的是数据库内核骨架是否成立、Definition of Done 是否完整闭环。
- `v1.6.0` 解决的是在原有语义不退让的前提下，热路径是否能被真正打磨出来。
- 这不是“替代 SQLite”的宣言，而是一次把原型性能质感做出来的收束版本。

## 相关文档

- 对比 benchmark：[`nosqlite-sqlite-compare.md`](./nosqlite-sqlite-compare.md)
- v0 benchmark：[`nosqlite-benchmark-v0.md`](./nosqlite-benchmark-v0.md)
- 压力测试报告：[`nosqlite-stress-report.md`](./nosqlite-stress-report.md)
- Definition of Done：[`nosqlite-definition-of-done.md`](./nosqlite-definition-of-done.md)
- v1.5.0 封板说明：[`nosqlite-release-v1.5.0.md`](./nosqlite-release-v1.5.0.md)

## 当前边界

- 单进程嵌入式使用。
- 单写者设计。
- 当前 benchmark 仍是缩小样本，不代表生产 SLO。
- 当前 v1 原型容量仍受单页 collection 布局限制。
- 暂不包含 MVCC、聚合框架、全文检索、网络协议、GIN/HASH 索引族。

## 复现入口

```bash
bash nosqlite/tests/verify_definition_of_done.sh
python3 nosqlite/benchmark_sqlite_compare.py
```
