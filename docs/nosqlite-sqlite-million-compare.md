# NoSQLite vs SQLite 百万条性能对比

日期：2026-05-21

本报告聚焦百万条记录量级下的装载与查询性能对比。

## 运行口径

- 数据集记录数：`1000000`
- 每批提交记录数：`48000`
- query 迭代数：`100`
- Python：`3.12.11`
- SQLite：`3.46.1`
- SQLite JSON1：`available`
- CPU：`Intel(R) Core(TM) i7-14700`
- Kernel：`6.12.65-amd64-desktop-rolling`
- 数据文档：`{"n": <id>, "bucket": <id % 100>, "active": <bool>}`
- 查询口径：`SELECT _id FROM users LIMIT 64` / `SELECT id FROM users LIMIT 64`
- NoSQLite 这里先比较“批量写入后同进程 warm query”，不包含 recovery/open 延迟。

## 摘要

| case | NoSQLite | SQLite | 对比 |
| --- | ---: | ---: | --- |
| bulk_load rows/s | 102532.42 | 724184.28 | SQLite faster x7.06 |
| limit_query p50 us | 871 | 13 | SQLite faster x67.00 |
| limit_query p95 us | 931 | 13 | SQLite faster x71.62 |

## 原始指标

| engine | load s | load rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | 9.75 | 102532.42 | 871 | 931 | 1146.39 | 4155164 | NoSQLite million-row benchmark; staged txn batches; warm SELECT _id FROM users LIMIT 64 |
| sqlite | 1.38 | 724184.28 | 13 | 13 | 76277.65 | 19644 | SQLite JSON1; journal_mode=WAL; synchronous=FULL; warm SELECT id FROM users LIMIT 64 |

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare_million.py
```
