# NoSQLite vs SQLite 百万条性能对比

日期：2026-05-21

本报告聚焦百万条记录量级下的装载、查询、批量更新，以及区分 logical delete / physical delete 后的删除性能对比。

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
- `logical_delete` 口径：fresh preload 并 checkpoint 后按 `batch_rows` 头到尾执行 durable range delete；NoSQLite 会命中 prefix metadata delete 快路径，SQLite 仍执行物理 DELETE，因此该项只用于能力说明，不作为公平主结论。
- `physical_delete` 口径：fresh preload 并 checkpoint 后按 `batch_rows` 尾到头执行 durable range delete；两侧都执行 `DELETE ... WHERE id >= start AND id < end`，同时显式避开 NoSQLite prefix logical delete 快路径，作为公平 delete 主对比。
- limit_query 计时范围：从开始执行查询到完整取回 64 行结果，两侧统一口径。
- 更新、logical_delete、physical_delete 各自使用独立 fresh preload 数据集，预装载不计入该 case 计时，避免 load/query cache 污染后续结果。

## 摘要

| case | NoSQLite | SQLite | 对比 |
| --- | ---: | ---: | --- |
| bulk_load rows/s | 1511905.50 | 689114.81 | NoSQLite faster x2.19 |
| limit_query p50 us | 0.79 | 13.27 | NoSQLite faster x16.82 |
| limit_query p95 us | 0.8 | 14.03 | NoSQLite faster x17.47 |
| bulk_update rows/s | 2509202.50 | 1237138.40 | NoSQLite faster x2.03 |
| physical_delete rows/s | 2139897.97 | 6594914.00 | SQLite faster x3.08 |

## Delete 语义拆分

| case | NoSQLite | SQLite | 说明 |
| --- | ---: | ---: | --- |
| logical_delete rows/s | 548245614.04 | 6040982.02 | 非同口径。NoSQLite 为 durable logical prefix delete，SQLite 仍是 physical DELETE，仅作参考。 |
| physical_delete rows/s | 2139897.97 | 6594914.00 | 公平主口径。两侧都按尾到头分段删除，显式避开 NoSQLite prefix logical delete 快路径。 |

## 原始指标

| engine | load s | load rows/s | update s | update rows/s | physical_delete s | physical_delete rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.66 | 1511905.50 | 0.40 | 2509202.50 | 0.47 | 2139897.97 | 0.79 | 0.8 | 1256881.43 | 1617384 | NoSQLite million-row benchmark; fresh preloaded dataset; durable range batches; UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end; NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable tail-to-head range delete; prefix logical delete fast path intentionally bypassed to force physical page updates |
| sqlite | 1.45 | 689114.81 | 0.81 | 1237138.40 | 0.15 | 6594914.00 | 13.27 | 14.03 | 73818.99 | 38876 | SQLite JSON1; fresh preloaded million-row dataset; durable BEGIN/COMMIT range batches; UPDATE users SET doc = json_set(doc, '$.age', ?) WHERE id >= ? AND id < ?; SQLite JSON1; fresh preloaded and checkpointed million-row dataset; durable tail-to-head range DELETE; physical row delete semantics |

## Delete 明细

| engine | logical_delete s | logical_delete rows/s | physical_delete s | physical_delete rows/s | notes |
| --- | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.00 | 548245614.04 | 0.47 | 2139897.97 | NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable head-to-tail prefix delete; commits deleted-through metadata boundary; logical delete semantics; NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable tail-to-head range delete; prefix logical delete fast path intentionally bypassed to force physical page updates |
| sqlite | 0.17 | 6040982.02 | 0.15 | 6594914.00 | SQLite JSON1 reference; fresh preloaded and checkpointed million-row dataset; durable head-to-tail range DELETE; physical row delete semantics; SQLite JSON1; fresh preloaded and checkpointed million-row dataset; durable tail-to-head range DELETE; physical row delete semantics |

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare_million.py
```
