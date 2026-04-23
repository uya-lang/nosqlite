# NoSQLite Benchmark v0

日期：2026-04-23

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，`floor/target/stretch` 暂按 `skip` 记录。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 10 | 18665 | 20108 | 20108 | 53.28 | 0.05 | 29460 | skip | skip | skip | scaled prototype dataset: docs=3 < 100000 |
| seq_scan_filter | warm-read | 10 | 18550 | 19625 | 19625 | 161.48 | 0.16 | 29300 | skip | skip | skip | scaled prototype dataset: docs=3 < 100000 |
| durable_insert | durable-write | 3 | 19220 | 22958 | 22958 | 51.36 | 0.05 | 28004 | skip | skip | skip | scaled prototype dataset: docs=3 < 100000 |
| recovery_open | recovery | 10 | 92924 | 98529 | 98529 | 32.03 | 0.03 | 31448 | skip | skip | skip | scaled prototype dataset: docs=3 < 100000 |
