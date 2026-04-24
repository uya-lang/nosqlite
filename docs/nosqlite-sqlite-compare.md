# NoSQLite vs SQLite 对比 Benchmark

日期：2026-04-24

本报告用于把 NoSQLite v1.7.0 的 v0 原型 benchmark 与 SQLite JSON1 做同机横向校准。

## 运行口径

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- Python：`3.12.11`
- SQLite：`3.46.1`
- SQLite JSON1：`available`
- SQLite 表结构：`users(id INTEGER PRIMARY KEY, doc TEXT CHECK(json_valid(doc)))`
- SQLite durable 配置：`journal_mode=WAL`，`synchronous=FULL`
- NoSQLite 口径：复用 `nosqlite/benchmark_phase11.py` 的 Uya C runner（`-O2` 重链接）与 v0 原型数据集
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合
- 对比摘要中的 recovery case 固定使用 `dirty_wal_recovery_open`；NoSQLite 的 `recovery_open_with_auto_checkpoint` 只保留在原始指标里做补充观察

这不是生产级性能宣判：SQLite 是成熟 C 实现，NoSQLite 当前是 Uya/C v0 原型，且 benchmark 仍使用 `3` 文档小规模原型数据集。本报告主要用于给后续优化建立参照物。

## 摘要

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 1 | 3 | NoSQLite faster x3.00 | 2 | 4 |
| seq_scan_filter | warm-read | 1 | 4 | NoSQLite faster x4.00 | 2 | 6 |
| durable_insert | durable-write | 74 | 77 | NoSQLite faster x1.04 | 116 | 116 |
| dirty_wal_recovery_open | recovery | 83 | 148 | NoSQLite faster x1.78 | 106 | 205 |
| long_query_concurrent_commit | durable-write | 82 | 68 | SQLite faster x1.21 | 94 | 88 |

## 原始指标

| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | primary_lookup | warm-read | 10 | 1 | 2 | 2 | 909090.91 | 887.78 | 17624 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | seq_scan_filter | warm-read | 10 | 1 | 2 | 2 | 1538461.54 | 1502.40 | 17224 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | durable_insert | durable-write | 3 | 74 | 116 | 116 | 11406.84 | 11.14 | 19708 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | recovery_open_with_auto_checkpoint | recovery | 10 | 15 | 208 | 208 | 86705.20 | 84.67 | 17924 | prepare once; first sample includes recovery+checkpoint, later samples reopen the checkpointed store; scaled prototype dataset: docs=3 < 100000 |
| nosqlite | dirty_wal_recovery_open | recovery | 10 | 83 | 106 | 106 | 33707.87 | 32.92 | 21728 | each sample checkpoints the base store, then recreates one dirty WAL txn before measuring the first reopen; scaled prototype dataset: docs=3 < 100000 |
| nosqlite | long_query_concurrent_commit | durable-write | 10 | 82 | 94 | 94 | 12135.92 | 11.85 | 22696 | scaled prototype dataset: docs=3 < 100000 |
| sqlite | primary_lookup | warm-read | 10 | 3 | 4 | 4 | 312500.00 | 305.18 | 19048 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | seq_scan_filter | warm-read | 10 | 4 | 6 | 6 | 681818.18 | 665.84 | 19736 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | durable_insert | durable-write | 3 | 77 | 116 | 116 | 12000.00 | 11.72 | 19612 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | dirty_wal_recovery_open | recovery | 10 | 148 | 205 | 205 | 19960.08 | 19.49 | 19764 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; each sample checkpoints the base store, then keeps the writer connection open with one dirty WAL txn until the measured reopen |
| sqlite | long_query_concurrent_commit | durable-write | 10 | 68 | 88 | 88 | 13947.00 | 13.62 | 19756 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; writer measured while a read transaction is pinned |

## 解释边界

- NoSQLite 的 primary lookup 走通用 SQL parser/binder/planner/executor，并用主键 B+Tree 定位 row slot；SQLite 走 `INTEGER PRIMARY KEY`。
- NoSQLite 的 seq scan 走通用 `$.age` 谓词执行；SQLite 使用 `json_extract(doc, '$.age')`。
- NoSQLite durable commit 使用 WAL `fdatasync` 作为提交边界，数据页/meta 页延迟到 recovery/checkpoint 物化；这不是跳过持久化。
- NoSQLite recovery 在完整校验并回放 WAL 后执行真实 checkpoint（同步 DB、写 checkpoint meta、截断 WAL）；原始指标里额外保留 `recovery_open_with_auto_checkpoint`，用于观察 recovery 触发的后续 reopen 快路径。
- SQLite 的 dirty WAL case 先 checkpoint schema base，再用一个事务写入全部样本并保持 writer 连接不关闭，确保 prepare 结束后仍保留一条 dirty WAL txn；样本仍包含 connect、WAL/同步 PRAGMA 设置和一次 `COUNT(*)` 读。
- long query concurrent commit 在 SQLite 侧用两个连接和显式 read transaction 固定 reader snapshot。
- durable/recovery p95 保留首个冷 fdatasync/checkpoint 样本，没有剔除慢样本。
- SQLite peak RSS 是独立 Python 子进程级采样，包含 Python 解释器和 sqlite3 绑定开销。

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare.py
```
