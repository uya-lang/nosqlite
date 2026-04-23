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
| primary_lookup | warm-read | 4465 | 3 | SQLite faster x1488.33 | 4807 | 16 |
| seq_scan_filter | warm-read | 4566 | 4 | SQLite faster x1141.50 | 5015 | 23 |
| durable_insert | durable-write | 14978 | 55 | SQLite faster x272.33 | 15995 | 77 |
| recovery_open | recovery | 79728 | 84 | SQLite faster x949.14 | 84135 | 143 |
| long_query_concurrent_commit | durable-write | 15145 | 63 | SQLite faster x240.40 | 15479 | 74 |

## 原始指标

| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | primary_lookup | warm-read | 10 | 4465 | 4807 | 4807 | 222.04 | 0.22 | 28248 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | seq_scan_filter | warm-read | 10 | 4566 | 5015 | 5015 | 651.75 | 0.64 | 28284 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | durable_insert | durable-write | 3 | 14978 | 15995 | 15995 | 66.02 | 0.06 | 28216 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | recovery_open | recovery | 10 | 79728 | 84135 | 84135 | 37.47 | 0.04 | 31448 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | long_query_concurrent_commit | durable-write | 10 | 15145 | 15479 | 15479 | 65.92 | 0.06 | 29744 | scaled prototype dataset: docs=3 < 100000 |
| sqlite | primary_lookup | warm-read | 10 | 3 | 16 | 16 | 222222.22 | 217.01 | 19812 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | seq_scan_filter | warm-read | 10 | 4 | 23 | 23 | 483870.97 | 472.53 | 19616 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | durable_insert | durable-write | 3 | 55 | 77 | 77 | 16393.44 | 16.01 | 19768 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | recovery_open | recovery | 10 | 84 | 143 | 143 | 32608.70 | 31.84 | 18896 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; open includes schema/count read |
| sqlite | long_query_concurrent_commit | durable-write | 10 | 63 | 74 | 74 | 15243.90 | 14.89 | 19788 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; writer measured while a read transaction is pinned |

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
