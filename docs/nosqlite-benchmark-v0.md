# NoSQLite Benchmark v0

日期：2026-04-24

- 数据集文档数：`64`
- 平均文档大小：`1024` bytes
- 请求迭代数：`200`
- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合。
- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。

| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |
|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|
| primary_lookup | warm-read | 200 | 0 | 0 | 0 | 0.00 | 0.00 | 536 | skip | skip | skip | skip: reason=collection_page_capacity requested_docs=64 page_capacity=3 avg_doc_bytes=1024 |
| seq_scan_filter | warm-read | 200 | 0 | 0 | 0 | 0.00 | 0.00 | 104 | skip | skip | skip | skip: reason=collection_page_capacity requested_docs=64 page_capacity=3 avg_doc_bytes=1024 |
| durable_insert | durable-write | 64 | 0 | 0 | 0 | 0.00 | 0.00 | 88 | skip | skip | skip | skip: reason=collection_page_capacity requested_docs=64 page_capacity=3 avg_doc_bytes=1024 |
| recovery_open | recovery | 200 | 0 | 0 | 0 | 0.00 | 0.00 | 96 | skip | skip | skip | skip: reason=collection_page_capacity requested_docs=64 page_capacity=3 avg_doc_bytes=1024 |
| long_query_concurrent_commit | durable-write | 200 | 0 | 0 | 0 | 0.00 | 0.00 | 16 | skip | skip | skip | skip: reason=collection_page_capacity requested_docs=64 page_capacity=3 avg_doc_bytes=1024 |
