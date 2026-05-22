# NoSQLite vs SQLite 百万条性能对比

日期：2026-05-22

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
| bulk_load rows/s | 1030519.88 | 671522.22 | NoSQLite faster x1.53 |
| limit_query p50 us | 0.89 | 13.4 | NoSQLite faster x15.09 |
| limit_query p95 us | 0.94 | 14.13 | NoSQLite faster x15.08 |
| bulk_update rows/s | 1431163.88 | 1171275.64 | NoSQLite faster x1.22 |
| physical_delete rows/s | 4293301.16 | 5545911.83 | SQLite faster x1.29 |

## 本次复测备注

- `2026-05-22` 这版主表已经切到最新一次 full rerun 结果：`physical_delete = 232921 us / 1,000,000 rows = 4,293,301.16 rows/s`。
- 相比上一版正文里的 `242111 us / 4,130,336.91 rows/s`，当前 fair `physical_delete` 主口径提升约 `3.95%`。
- 定向 delete-only profiling 的收益更明显：`nosqlite/tests/exec/test_physical_delete_only_runtime.uya` 当前测得 `222408 us / 1,000,000 rows`。相较本轮优化前的本地基线 `318707 us`，删除耗时下降约 `30.2%`；相较更早记录在文档里的 `452311 us`，耗时下降约 `50.8%`。
- 结论上，bulk delete 的页落盘路径确实继续变快了，但 full million fair compare 里 SQLite 仍在 `physical_delete` 上领先 `x1.29`；说明下一阶段瓶颈已经不只是 commit payload copy。

## Delete 语义拆分

| case | NoSQLite | SQLite | 说明 |
| --- | ---: | ---: | --- |
| logical_delete rows/s | 414593698.18 | 4987133.20 | 非同口径。NoSQLite 为 durable logical prefix delete，SQLite 仍是 physical DELETE，仅作参考。 |
| physical_delete rows/s | 4293301.16 | 5545911.83 | 公平主口径。两侧都按尾到头分段删除，显式避开 NoSQLite prefix logical delete 快路径。 |

## 原始指标

| engine | load s | load rows/s | update s | update rows/s | physical_delete s | physical_delete rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.97 | 1030519.88 | 0.70 | 1431163.88 | 0.23 | 4293301.16 | 0.89 | 0.94 | 1101345.84 | 1617388 | NoSQLite million-row benchmark; fresh preloaded dataset; durable range batches; UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end; NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable tail-to-head range delete; prefix logical delete fast path intentionally bypassed to force physical page updates |
| sqlite | 1.49 | 671522.22 | 0.85 | 1171275.64 | 0.18 | 5545911.83 | 13.4 | 14.13 | 73625.94 | 39000 | SQLite JSON1; fresh preloaded million-row dataset; durable BEGIN/COMMIT range batches; UPDATE users SET doc = json_set(doc, '$.age', ?) WHERE id >= ? AND id < ?; SQLite JSON1; fresh preloaded and checkpointed million-row dataset; durable tail-to-head range DELETE; physical row delete semantics |

## Delete 明细

| engine | logical_delete s | logical_delete rows/s | physical_delete s | physical_delete rows/s | notes |
| --- | ---: | ---: | ---: | ---: | --- |
| nosqlite | 0.00 | 414593698.18 | 0.23 | 4293301.16 | NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable head-to-tail prefix delete; commits deleted-through metadata boundary; logical delete semantics; NoSQLite million-row benchmark; fresh preloaded and checkpointed dataset; durable tail-to-head range delete; prefix logical delete fast path intentionally bypassed to force physical page updates |
| sqlite | 0.20 | 4987133.20 | 0.18 | 5545911.83 | SQLite JSON1 reference; fresh preloaded and checkpointed million-row dataset; durable head-to-tail range DELETE; physical row delete semantics; SQLite JSON1; fresh preloaded and checkpointed million-row dataset; durable tail-to-head range DELETE; physical row delete semantics |

## 当前结论

- 以百万条主口径看，NoSQLite 目前仍然在 `load`、`limit_query`、`bulk_update` 上占优，但 `physical_delete` 还没有反超 SQLite，更远未达到 `10x` 目标。
- `logical_delete` 仍然保持极强吞吐，但它依赖 prefix metadata delete 快路径，不能拿来替代公平 physical delete 结论。
- 如果后续继续冲 delete 主口径，更值得优先看的将是 full million run 中剩余的页扫描、query/result materialization 与非 delete case 波动，而不是只盯单次 WAL append 开销。

## 复现命令

```bash
python3 nosqlite/benchmark_sqlite_compare_million.py
```
