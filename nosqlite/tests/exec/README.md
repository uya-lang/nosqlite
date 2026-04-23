# Exec Test Group

本组覆盖：

- `CommitView`
- `CommitViewPin`
- `QueryCursor`
- `RowRef`
- `QueryResult` / `OwnedRow`
- `SeqScan`
- `PrimaryLookup`
- `Filter`
- `Project`
- `Limit`
- `db_query_cursor`
- `db_query`
- `CursorExpired`
- `SnapshotPressure`
- 快照绑定 / retired view 回收
- 长查询 + 并发提交

当前入口文件：

- `nosqlite/test_exec_runtime.uya`
