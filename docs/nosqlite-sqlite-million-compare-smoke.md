# NoSQLite vs SQLite 百万条性能对比

日期：2026-05-20

本报告聚焦百万条记录量级下的装载与查询性能对比。

## 运行口径

- 数据集记录数：`1000`
- 每批提交记录数：`300`
- query 迭代数：`10`
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
| bulk_load rows/s | 47458.59 | 735835.17 | SQLite faster x15.50 |
| limit_query p50 us | 1103 | 13 | SQLite faster x84.85 |
| limit_query p95 us | 1649 | 14 | SQLite faster x117.79 |

## 原始指标

| engine | load s | load rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.02 | 47458.59 | 1103 | 1649 | 839.28 | 816 | NoSQLite million-row benchmark; staged txn batches; warm SELECT _id FROM users LIMIT 64 |
| sqlite | 0.00 | 735835.17 | 13 | 14 | 75187.97 | 19164 | SQLite JSON1; journal_mode=WAL; synchronous=FULL; warm SELECT id FROM users LIMIT 64 |

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare_million.py
```
