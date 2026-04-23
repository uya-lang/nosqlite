# Exec Test Group

本组覆盖：

- `CommitView`
- `CommitViewPin`
- `Txn`
- `DocBlobBuilder`
- `QueryCursor`
- `RowRef`
- `QueryResult` / `OwnedRow`
- `SeqScan`
- `PrimaryLookup`
- `Filter`
- `Project`
- `Limit`
- `db_exec`
- `db_query_cursor`
- `db_query`
- `CursorExpired`
- `SnapshotPressure`
- 快照绑定 / retired view 回收
- 长查询 + 并发提交
- auto-commit `INSERT`
- 显式事务提交 / 回滚 / drop abort
- reopen 后可见性

当前入口文件：

- `nosqlite/test_exec_runtime.uya`
