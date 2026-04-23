# NoSQLite Benchmark v0

日期：2026-04-23

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 10 | 18583 | 19668 | 19668 | 53.53 | 0.05 | 29388 | pass | pass | miss | scaled prototype dataset: docs=3 < 100000 |
| seq_scan_filter | warm-read | 10 | 18251 | 22201 | 22201 | 159.69 | 0.16 | 29352 | pass | miss | miss | scaled prototype dataset: docs=3 < 100000 |
| durable_insert | durable-write | 3 | 18918 | 23079 | 23079 | 50.03 | 0.05 | 28168 | pass | pass | miss | scaled prototype dataset: docs=3 < 100000 |
| recovery_open | recovery | 10 | 96121 | 100922 | 100922 | 30.97 | 0.03 | 31400 | pass | miss | miss | scaled prototype dataset: docs=3 < 100000 |
| long_query_concurrent_commit | durable-write | 10 | 19452 | 20217 | 20217 | 51.35 | 0.05 | 29128 | pass | miss | miss | scaled prototype dataset: docs=3 < 100000; ratio_p50=98% |
