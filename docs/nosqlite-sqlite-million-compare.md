# NoSQLite vs SQLite 百万条性能对比

日期：2026-05-21

本报告聚焦百万条记录量级下的装载、查询、批量更新与批量删除性能对比。

## 运行口径

- 数据集记录数：`1000000`
- 每批提交记录数：`48000`
- query 迭代数：`100`
- Python：`3.12.11`
- SQLite：`3.46.1`
- SQLite JSON1：`available`
- CPU：`Intel(R) Core(TM) i7-14700`
- Kernel：`6.12.65-amd64-desktop-rolling`
- 数据文档：`{"n": <id>, "bucket": <id % 100>, "age": <18 + (id % 41)>, "active": <bool>}`
- 查询口径：`SELECT _id FROM users LIMIT 64` / `SELECT id FROM users LIMIT 64`
- 更新口径：fresh preload 后按 `batch_rows` 分段执行 durable range update；NoSQLite 执行 `UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end`，SQLite 执行 `UPDATE users SET doc = json_set(doc, '$.age', 30) WHERE id >= start AND id < end`。
- 删除口径：fresh preload 后按 `batch_rows` 分段执行 durable range delete；NoSQLite 执行 `DELETE FROM users WHERE _id >= start AND _id < end`，SQLite 执行 `DELETE FROM users WHERE id >= start AND id < end`。
- limit_query 计时范围：从开始执行查询到完整取回 64 行结果，两侧统一口径。
- 更新/删除各自使用独立 fresh preload 数据集，预装载不计入该 case 计时，避免 load/query cache 污染后续结果。

## 摘要

| case | NoSQLite | SQLite | 对比 |
| --- | ---: | ---: | --- |
| bulk_load rows/s | 1408553.87 | 678102.18 | NoSQLite faster x2.08 |
| limit_query p50 us | 0.8 | 13.4 | NoSQLite faster x16.83 |
| limit_query p95 us | 0.81 | 14.8 | NoSQLite faster x18.18 |
| bulk_update rows/s | 2119295.12 | 1220607.77 | NoSQLite faster x1.74 |
| bulk_delete rows/s | 510725229.83 | 5834271.68 | NoSQLite faster x87.54 |

## 原始指标

| engine | load s | load rows/s | update s | update rows/s | delete s | delete rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.71 | 1408553.87 | 0.47 | 2119295.12 | 0.00 | 510725229.83 | 0.8 | 0.81 | 1245438.58 | 521728 | NoSQLite million-row benchmark; fresh preloaded dataset; durable range batches; UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end; NoSQLite million-row benchmark; fresh preloaded dataset; durable range batches; DELETE FROM users WHERE _id >= start AND _id < end |
| sqlite | 1.47 | 678102.18 | 0.82 | 1220607.77 | 0.17 | 5834271.68 | 13.4 | 14.8 | 73158.83 | 38920 | SQLite JSON1; fresh preloaded million-row dataset; durable BEGIN/COMMIT range batches; UPDATE users SET doc = json_set(doc, '$.age', ?) WHERE id >= ? AND id < ?; SQLite JSON1; fresh preloaded million-row dataset; durable BEGIN/COMMIT range batches; DELETE FROM users WHERE id >= ? AND id < ? |

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare_million.py
```
