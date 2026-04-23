# NoSQLite 示例

日期：2026-04-23

## 1. 运行一致性检查

```bash
nosqlite/db_check.sh /tmp/mydb
```

成功时示例输出：

```text
db_check: OK stem=/tmp/mydb pages=4 checked_pages=4 collections=1 rows=2 wal_bytes=12464 wal_records=6 committed_wal_txns=2
```

失败时示例输出：

```text
db_check: FAIL stem=/tmp/mydb code=2005 name=FORMAT_WAL_RECORD_INVALID message=WAL record stream is truncated, corrupt, or out of order
```

## 2. 生成固定 benchmark 数据集

```bash
python3 nosqlite/generate_bench_dataset.py \
  --docs 100000 \
  --avg-bytes 1024 \
  --output /tmp/nosqlite-bench.jsonl
```

脚本会把摘要写到 `stderr`，例如：

```json
{"docs":100000,"seed":11,"avg_bytes":1024.0,"min_bytes":1024,"max_bytes":1024}
```

## 3. 运行 v0 benchmark

```bash
python3 nosqlite/benchmark_phase11.py
```

当前原型会输出：

- `BENCH_ENV`
- `BENCH_RESULT`
- `docs/nosqlite-benchmark-v0.md`
- `docs/nosqlite-benchmark-v0.json`

当前基线使用缩小数据集，`floor/target/stretch` 会按 `docs/nosqlite-benchmark-v0.json` 中的 v0 阈值判定；DoD 要求的四类 benchmark 当前均为 `floor=pass`。

## 4. 最小 Uya API 用法

```uya
use lib.api.db.DbHandle;
use lib.api.db.db_exec;
use lib.api.db.db_query;
use lib.api.db.db_test_create_at_stem;
use lib.api.db.db_test_create_collection;

use lib.api.result.QueryResult;
use lib.api.result.query_result_row;
use lib.api.result.owned_row_cell_u64;
use lib.api.result.owned_row_cell_text;

fn example() !void {
    var db: DbHandle = DbHandle{};
    try db_test_create_at_stem(&db, "/tmp/example_db");
    try db_test_create_collection(&db, "users");

    try db_exec(&db, "INSERT INTO users JSON '{\"name\":\"ann\",\"age\":25,\"active\":true}';");

    const result: QueryResult = try db_query(&db, "SELECT _id, $.name FROM users WHERE _id = 1 LIMIT 1;");
    const row = try query_result_row(&result, 0u32);
    const id: u64 = try owned_row_cell_u64(row, 0u16);
    const name: &[byte] = try owned_row_cell_text(row, 1u16);

    _ = id;
    _ = name;
}
```

## 5. 当前边界

- benchmark 默认基线当前是缩小数据集，不代表未来生产参考环境的大规模实测。
- `INSERT ... JSON ...` 现在已经能无损保留大整数和精确小数词素，但整体容量仍受 v1 原型页布局限制。
