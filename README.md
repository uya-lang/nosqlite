# NoSQLite

小数据库，硬保证，用 Uya 写到底。

NoSQLite 是一个 Uya-native 的嵌入式文档数据库：拿 JSON 的灵活性、SQL 的可读性、存储引擎的谨慎和 Uya 的显式资源模型，压成一个小而硬的数据库内核。

这个仓库已经封板到 NoSQLite v1/v1.5 里程碑：阶段任务全部完成，Definition of Done 每一项都有测试或文档证据，完整验收脚本通过。

当前里程碑版本：`nosqlite-v1.5.0`

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

## 它是什么

NoSQLite 不是一个玩具 JSON wrapper。它是一个真正带存储引擎骨架的小型数据库：

- 持久化数据库文件：版本化文件头、双 meta 页轮换、checksum、WAL redo、checkpoint、不兼容格式拒绝打开。
- 紧凑 `DocBlob` 二进制文档格式：对象 key 排序、JSON path 求值、标量比较、大整数和精确小数词素无损保留。
- SQL 风格访问：lexer、parser、binder、planner、executor、物化结果和 cursor API。
- 主键 B+Tree 点查、顺序扫描、二级索引、`ORDER BY`、`EXPLAIN`、`UPDATE`、`DELETE`。
- 快照 reader pin、retired view 统计、snapshot pressure、writer guard、`drop` 清理、错误路径 rollback。
- Typed SQL 静态校验：schema、字段、类型不一致时给出明确错误。

## 它为什么够硬

NoSQLite 的底线很直接：凡是可能导致数据损坏、静默降精度、资源泄漏或无界增长的东西，都要有测试。

当前里程碑覆盖：

- 新建数据库 -> 插入 -> 查询 -> 重启恢复全链路。
- 已提交 WAL redo，未提交 WAL 恢复后不可见。
- 损坏页、损坏 WAL 的检测、fail-fast 或安全截断。
- 长查询期间提交不会打断已有读者。
- 生产策略下 snapshot 和 WAL 资源保持有界。
- 20 行填充、checkpoint、reopen、索引 churn、snapshot pressure 循环压力门。
- 大整数和精确小数不会静默降精度。
- 文件格式兼容矩阵、升级前置条件、失败升级回滚。
- 一条命令完成 Definition of Done 验收。

## 快速开始

运行完整封板验收：

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

运行一个代表性的运行时测试：

```bash
./uya/bin/uya nosqlite/tests/exec/test_exec_runtime.uya
.uyacache/a.out
```

运行压力测试：

```bash
./uya/bin/uya nosqlite/tests/exec/test_stress_runtime.uya
.uyacache/a.out
```

压力测试报告见 [docs/nosqlite-stress-report.md](docs/nosqlite-stress-report.md)。

运行 benchmark：

```bash
python3 nosqlite/benchmark_phase11.py
```

benchmark 输出位置：

- `docs/nosqlite-benchmark-v0.md`
- `docs/nosqlite-benchmark-v0.json`

## API 预览

```uya
use lib.api.db.DbHandle;
use lib.api.db.db_exec;
use lib.api.db.db_query;
use lib.api.db.db_test_create_at_stem;
use lib.api.db.db_test_create_collection;

use lib.api.result.QueryResult;
use lib.api.result.query_result_row;
use lib.api.result.owned_row_cell_text;
use lib.api.result.owned_row_cell_u64;

fn example() !void {
    var db: DbHandle = DbHandle{};
    try db_test_create_at_stem(&db, "/tmp/nosqlite_demo");
    try db_test_create_collection(&db, "users");

    try db_exec(&db, "INSERT INTO users JSON '{\"name\":\"ann\",\"age\":25,\"score\":12.3400}';");

    const result: QueryResult = try db_query(&db, "SELECT _id, $.name FROM users WHERE _id = 1 LIMIT 1;");
    const row = try query_result_row(&result, 0u32);
    const id: u64 = try owned_row_cell_u64(row, 0u16);
    const name: &[byte] = try owned_row_cell_text(row, 1u16);

    _ = id;
    _ = name;
}
```

## SQL 片段

```sql
CREATE COLLECTION users;
INSERT INTO users JSON '{"name":"ann","age":25,"active":true}';
CREATE INDEX users_age_idx ON users ($.age);
SELECT _id, $.name FROM users WHERE $.age = 25 ORDER BY _id ASC LIMIT 10;
UPDATE users SET $.age = 26 WHERE $.name = 'ann';
DELETE FROM users WHERE $.active = FALSE;
EXPLAIN SELECT _id FROM users WHERE $.age = 26 LIMIT 1;
```

## 架构

```text
SQL Text
  -> Lexer / Parser
  -> AST
  -> Binder
  -> Planner
  -> Executor
  -> DocBlob / B+Tree / Pager / WAL
  -> Durable pages
```

代码分层是刻意收紧的：

- `nosqlite/lib/doc`：`DocBlob`、JSON path、标量比较、数字词素保真。
- `nosqlite/lib/sql`：SQL token、AST、parser、binder、typed SQL 校验。
- `nosqlite/lib/plan`：选择 scan、lookup、index plan，并输出 `EXPLAIN`。
- `nosqlite/lib/api`：数据库 handle、执行入口、cursor、结果集、事务、一致性检查。
- `nosqlite/lib/storage`：meta page、页布局、slotted page、WAL、checkpoint、recovery、格式升级。
- `nosqlite/lib/index`：索引 key 编码和 B+Tree 行为。

## 验收

顶层验收脚本会串行运行当前全部可执行 Uya 测试、Phase 12.5 async boundary 检查、Phase 14 typed SQL 静态错误检查，以及 benchmark floor 检查：
其中包含 `nosqlite/tests/exec/test_stress_runtime.uya` 压力门。

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

期望最后一行：

```text
definition of done verification ok
```

DoD 映射见 [docs/nosqlite-definition-of-done.md](docs/nosqlite-definition-of-done.md)。完整阶段清单见 [docs/nosqlite-todo.md](docs/nosqlite-todo.md)。

## 文档入口

- [详细设计](docs/nosqlite-design.md)
- [里程碑发布说明](docs/nosqlite-release-v1.5.0.md)
- [Definition of Done](docs/nosqlite-definition-of-done.md)
- [压力测试报告](docs/nosqlite-stress-report.md)
- [示例](docs/nosqlite-examples.md)
- [SQL 语法](docs/nosqlite-sql-syntax.md)
- [Typed SQL](docs/nosqlite-typed-sql.md)
- [格式兼容与升级](docs/nosqlite-format-compat.md)
- [Benchmark 输出格式](docs/nosqlite-benchmark-format.md)
- [完整文档索引](docs/README.md)

## 当前边界

这是一个已经封板的 v1/v1.5 数据库内核里程碑，但不是“替代 SQLite 或 MongoDB”的宣言。

- 单进程嵌入式使用。
- 单写者设计。
- 暂不包含 MVCC、聚合框架、全文检索、网络协议、GIN/HASH 索引族。
- 当前 benchmark 基线使用缩小数据集和 v0 floor 阈值。
- v1 原型容量仍受当前页布局限制。

## 状态

NoSQLite v1/v1.5 已经完成仓库 checklist 定义的功能和工程验收。

最短证明：

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

如果输出 `definition of done verification ok`，封板成立。
