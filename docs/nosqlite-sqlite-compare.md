# NoSQLite vs SQLite 对比 Benchmark

日期：2026-04-24

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
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合

这不是生产级性能宣判：SQLite 是成熟 C 实现，NoSQLite 当前是 Uya debug 原型，且仍受单页 collection 容量限制。本报告主要用于给后续优化建立参照物。

## 摘要

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 1 | 3 | NoSQLite faster x3.00 | 9 | 4 |
| seq_scan_filter | warm-read | 4 | 4 | SQLite faster x1.00 | 9 | 5 |
| durable_insert | durable-write | 6660 | 59 | SQLite faster x112.88 | 8249 | 88 |
| recovery_open | recovery | 7367 | 83 | SQLite faster x88.76 | 7593 | 144 |
| long_query_concurrent_commit | durable-write | 5846 | 69 | SQLite faster x84.72 | 6075 | 81 |

## 原始指标

| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | primary_lookup | warm-read | 10 | 1 | 9 | 9 | 434782.61 | 424.59 | 16676 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | seq_scan_filter | warm-read | 10 | 4 | 9 | 9 | 625000.00 | 610.35 | 13876 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | durable_insert | durable-write | 3 | 6660 | 8249 | 8249 | 140.81 | 0.14 | 13620 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | recovery_open | recovery | 10 | 7367 | 7593 | 7593 | 405.93 | 0.40 | 13672 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | long_query_concurrent_commit | durable-write | 10 | 5846 | 6075 | 6075 | 171.50 | 0.17 | 19052 | scaled prototype dataset: docs=3 < 100000 |
| sqlite | primary_lookup | warm-read | 10 | 3 | 4 | 4 | 312500.00 | 305.18 | 19480 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | seq_scan_filter | warm-read | 10 | 4 | 5 | 5 | 714285.71 | 697.54 | 19456 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | durable_insert | durable-write | 3 | 59 | 88 | 88 | 15151.52 | 14.80 | 19080 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | recovery_open | recovery | 10 | 83 | 144 | 144 | 32017.08 | 31.27 | 19748 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; open includes schema/count read |
| sqlite | long_query_concurrent_commit | durable-write | 10 | 69 | 81 | 81 | 14367.82 | 14.03 | 19716 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; writer measured while a read transaction is pinned |

## 解释边界

- NoSQLite 的 primary lookup 走通用 SQL parser/binder/planner/executor，并用主键 B+Tree 定位 row slot；SQLite 走 `INTEGER PRIMARY KEY`。
- NoSQLite 的 seq scan 走通用 `$.age` 谓词执行；SQLite 使用 `json_extract(doc, '$.age')`。
- SQLite 的 recovery/open 样本包含 connect、WAL/同步 PRAGMA 设置和一次 `COUNT(*)` 读，用于避免只测 lazy connect。
- long query concurrent commit 在 SQLite 侧用两个连接和显式 read transaction 固定 reader snapshot。
- SQLite peak RSS 是独立 Python 子进程级采样，包含 Python 解释器和 sqlite3 绑定开销。

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare.py
```
