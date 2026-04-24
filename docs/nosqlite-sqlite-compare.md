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
- NoSQLite 口径：复用 `nosqlite/benchmark_phase11.py` 的 Uya C runner（`-O2` 重链接）与 v0 原型数据集
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合

这不是生产级性能宣判：SQLite 是成熟 C 实现，NoSQLite 当前是 Uya/C v0 原型，且仍受单页 collection 容量限制。本报告主要用于给后续优化建立参照物。

## 摘要

| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| primary_lookup | warm-read | 1 | 3 | NoSQLite faster x3.00 | 3 | 4 |
| seq_scan_filter | warm-read | 2 | 4 | NoSQLite faster x2.00 | 5 | 6 |
| durable_insert | durable-write | 61 | 58 | SQLite faster x1.05 | 277 | 82 |
| recovery_open | recovery | 91 | 103 | NoSQLite faster x1.13 | 111 | 158 |
| long_query_concurrent_commit | durable-write | 45 | 70 | NoSQLite faster x1.56 | 96 | 91 |

## 原始指标

| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | primary_lookup | warm-read | 10 | 1 | 3 | 3 | 833333.33 | 813.80 | 2868 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | seq_scan_filter | warm-read | 10 | 2 | 5 | 5 | 1000000.00 | 976.56 | 16 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | durable_insert | durable-write | 3 | 61 | 277 | 277 | 7575.76 | 7.40 | 212 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | recovery_open | recovery | 10 | 91 | 111 | 111 | 30581.04 | 29.86 | 192 | scaled prototype dataset: docs=3 < 100000 |
| nosqlite | long_query_concurrent_commit | durable-write | 10 | 45 | 96 | 96 | 19920.32 | 19.45 | 5908 | scaled prototype dataset: docs=3 < 100000 |
| sqlite | primary_lookup | warm-read | 10 | 3 | 4 | 4 | 312500.00 | 305.18 | 19748 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | seq_scan_filter | warm-read | 10 | 4 | 6 | 6 | 681818.18 | 665.84 | 19396 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | durable_insert | durable-write | 3 | 58 | 82 | 82 | 15306.12 | 14.95 | 19548 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL |
| sqlite | recovery_open | recovery | 10 | 103 | 158 | 158 | 27472.53 | 26.83 | 19700 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; open includes schema/count read |
| sqlite | long_query_concurrent_commit | durable-write | 10 | 70 | 91 | 91 | 13717.42 | 13.40 | 19804 | SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL; writer measured while a read transaction is pinned |

## 解释边界

- NoSQLite 的 primary lookup 走通用 SQL parser/binder/planner/executor，并用主键 B+Tree 定位 row slot；SQLite 走 `INTEGER PRIMARY KEY`。
- NoSQLite 的 seq scan 走通用 `$.age` 谓词执行；SQLite 使用 `json_extract(doc, '$.age')`。
- SQLite 的 recovery/open 样本包含 connect、WAL/同步 PRAGMA 设置和一次 `COUNT(*)` 读，用于避免只测 lazy connect。
- long query concurrent commit 在 SQLite 侧用两个连接和显式 read transaction 固定 reader snapshot。
- durable/recovery p95 保留首个冷 fdatasync/checkpoint 样本，没有剔除慢样本。
- SQLite peak RSS 是独立 Python 子进程级采样，包含 Python 解释器和 sqlite3 绑定开销。

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare.py
```
