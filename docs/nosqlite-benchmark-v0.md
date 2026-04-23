# NoSQLite Benchmark v0

日期：2026-04-23

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 10 | 4629 | 5055 | 5055 | 214.18 | 0.21 | 28232 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| seq_scan_filter | warm-read | 10 | 4708 | 5042 | 5042 | 628.40 | 0.61 | 28240 | pass | pass | miss | scaled prototype dataset: docs=3 < 100000 |
| durable_insert | durable-write | 3 | 14887 | 16404 | 16404 | 65.17 | 0.06 | 28300 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| recovery_open | recovery | 10 | 79252 | 84257 | 84257 | 37.53 | 0.04 | 31528 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| long_query_concurrent_commit | durable-write | 10 | 15158 | 15338 | 15338 | 65.90 | 0.06 | 29804 | pass | pass | miss | scaled prototype dataset: docs=3 < 100000; ratio_p50=100% |
