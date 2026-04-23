# NoSQLite 最小 API 草案

日期：2026-04-22

## 命名总则

- 用户态数据库入口统一使用 `db_`
- 事务入口统一使用 `txn_`
- 查询游标统一使用 `cursor_`
- 文档编码入口统一使用 `doc_`
- 仅内部 pager/page helper 使用 `pager_` / `page_`

## 最小 v1 API

### 打开与关闭

```text
db_create(path: &[byte], opts: &DbOpenOptions) !DbHandle
db_open(path: &[byte], opts: &DbOpenOptions) !DbHandle
```

`DbHandle` 后续优先走 `drop` 自动释放，不以 `db_close()` 作为主路径。

### 写事务

```text
txn_begin(db: &DbHandle) !Txn
txn_commit(txn: &Txn) !void
txn_rollback(txn: &Txn) !void
```

### 查询

```text
db_query(db: &DbHandle, sql: &[byte]) !QueryResult
db_query_cursor(db: &DbHandle, sql: &[byte]) !QueryCursor
cursor_next(cursor: &QueryCursor) !bool
cursor_row(cursor: &QueryCursor) !RowRef
```

### 执行非查询语句

```text
db_exec(db: &DbHandle, sql: &[byte]) !void
```

### 显式格式升级

```text
db_upgrade_format(db: &DbHandle, plan: &PagerUpgradePlan) !PagerUpgradeReport
```

升级入口不会在普通 open/query/exec 路径中隐式触发。升级前会先执行 checkpoint，并要求 WAL 截断到 header 大小。

## 最小配置对象

```text
DbOpenOptions {
  profile
  page_size
  feature_flags
}
```

## 当前冻结的名字

- `DbHandle`
- `Txn`
- `QueryCursor`
- `QueryResult`
- `RowRef`
- `DbOpenOptions`

这几个名字从 Phase 0 起先固定，后续实现尽量围绕它们展开。
