# NoSQLite Benchmark v0

日期：2026-04-24

- 数据集文档数：`3`
- 平均文档大小：`1024` bytes
- 请求迭代数：`10`
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合。
- recovery 口径：`dirty_wal_recovery_open` 每个 sample 都先 checkpoint base store，再制造一个 dirty WAL txn；`recovery_open_with_auto_checkpoint` prepare 一次后重复 reopen，用于观察 auto-checkpoint 后快路径。
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 10 | 1 | 2 | 2 | 909090.91 | 887.78 | 17224 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| seq_scan_filter | warm-read | 10 | 2 | 2 | 2 | 1176470.59 | 1148.90 | 16380 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| durable_insert | durable-write | 3 | 99 | 145 | 145 | 8797.65 | 8.59 | 15080 | pass | pass | pass | scaled prototype dataset: docs=3 < 100000 |
| recovery_open_with_auto_checkpoint | recovery | 10 | 38 | 366 | 366 | 42016.81 | 41.03 | 21780 | pass | pass | pass | prepare once; first sample includes recovery+checkpoint, later samples reopen the checkpointed store; scaled prototype dataset: docs=3 < 100000 |
| dirty_wal_recovery_open | recovery | 10 | 78 | 118 | 118 | 34762.46 | 33.95 | 21792 | pass | pass | pass | each sample checkpoints the base store, then recreates one dirty WAL txn before measuring the first reopen; scaled prototype dataset: docs=3 < 100000 |
| long_query_concurrent_commit | durable-write | 10 | 76 | 87 | 87 | 13054.83 | 12.75 | 22652 | pass | miss | miss | scaled prototype dataset: docs=3 < 100000; ratio_p50=91% |
