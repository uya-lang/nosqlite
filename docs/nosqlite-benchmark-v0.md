# NoSQLite Benchmark v0

日期：2026-04-24

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合。
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 10 | 1 | 5 | 5 | 588235.29 | 574.45 | 17392 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| seq_scan_filter | warm-read | 10 | 3 | 14 | 14 | 731707.32 | 714.56 | 16564 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| durable_insert | durable-write | 3 | 8646 | 9804 | 9804 | 112.30 | 0.11 | 14360 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| recovery_open | recovery | 10 | 7464 | 7989 | 7989 | 400.10 | 0.39 | 14392 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| long_query_concurrent_commit | durable-write | 10 | 8300 | 8711 | 8711 | 120.38 | 0.12 | 19856 | pass | miss | miss | scaled prototype dataset: docs=3 < 100000; ratio_p50=98% |
