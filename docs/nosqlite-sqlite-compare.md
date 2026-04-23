# NoSQLite vs SQLite 对比 Benchmark

日期：2026-04-23

本报告用于把 NoSQLite v1.5.0 的 v0 原型 benchmark 与 SQLite JSON1 做同机横向校准。

## 运行口径

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- Python：`3.12.11`
- SQLite：`3.46.1`
- SQLite JSON1：`available`
- SQLite 表结构：`users(id INTEGER PRIMARY KEY, doc TEXT CHECK(json_valid(doc)))`
- SQLite durable 配置：`journal_mode=WAL`，`synchronous=FULL`
- NoSQLite 口径：复用 `nosqlite/benchmark_phase11.py` 的 Uya debug runner 与 v0 原型数据集

这不是生产级性能宣判：SQLite 是成熟 C 实现，NoSQLite 当前是 Uya debug 原型，且仍受单页 collection 容量限制。本报告主要用于给后续优化建立参照物。

## 摘要

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 19883 | 3 | SQLite faster x6627.67 | 20667 | 16 |
| seq_scan_filter | warm-read | 19122 | 4 | SQLite faster x4780.50 | 20131 | 22 |
| durable_insert | durable-write | 18736 | 56 | SQLite faster x334.57 | 22488 | 91 |
| recovery_open | recovery | 92960 | 79 | SQLite faster x1176.71 | 97602 | 117 |
| long_query_concurrent_commit | durable-write | 19263 | 65 | SQLite faster x296.35 | 19513 | 94 |

## 原始指标

| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | primary_lookup | warm-read | 10 | 19883 | 20667 | 20667 | 50.11 | 0.05 | 29940 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | seq_scan_filter | warm-read | 10 | 19122 | 20131 | 20131 | 157.13 | 0.15 | 29900 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | durable_insert | durable-write | 3 | 18736 | 22488 | 22488 | 52.26 | 0.05 | 28152 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | recovery_open | recovery | 10 | 92960 | 97602 | 97602 | 32.02 | 0.03 | 31564 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | long_query_concurrent_commit | durable-write | 10 | 19263 | 19513 | 19513 | 51.94 | 0.05 | 29388 | scaled prototype dataset: docs=3 < 100000 |
| sqlite | primary_lookup | warm-read | 10 | 3 | 16 | 16 | 222222.22 | 217.01 | 19700 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | seq_scan_filter | warm-read | 10 | 4 | 22 | 22 | 491803.28 | 480.28 | 19368 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | durable_insert | durable-write | 3 | 56 | 91 | 91 | 15228.43 | 14.87 | 19752 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | recovery_open | recovery | 10 | 79 | 117 | 117 | 34762.46 | 33.95 | 19648 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; open includes schema/count read |
| sqlite | long_query_concurrent_commit | durable-write | 10 | 65 | 94 | 94 | 14556.04 | 14.21 | 19732 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; writer measured while a read transaction is pinned |

## 解释边界

- NoSQLite 的 primary lookup 走当前主键 B+Tree 与 Uya 物化结果路径，SQLite 走 `INTEGER PRIMARY KEY`。
- NoSQLite 的 seq scan 使用 `$.age` 谓词，SQLite 使用 `json_extract(doc, '$.age')`。
- SQLite 的 recovery/open 样本包含 connect、WAL/同步 PRAGMA 设置和一次 `COUNT(*)` 读，用于避免只测 lazy connect。
- long query concurrent commit 在 SQLite 侧用两个连接和显式 read transaction 固定 reader snapshot。
- SQLite peak RSS 是独立 Python 子进程级采样，包含 Python 解释器和 sqlite3 绑定开销。

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare.py
```
