# Plan Test Group

本组覆盖：

- Binder：collection 存在性校验
- Binder：系统列 `_id` 与 JSON path 区分
- Binder：JSON path 编译绑定
- Binder：字面量类型归一
- Planner：`_id = literal` 的主键索引选择
- Planner：默认 `SeqScan`
- Planner：`Filter` / `Limit` 规划
- Planner：最小 `EXPLAIN` 输出

当前入口文件：

- `nosqlite/tests/plan/test_binder_planner.uya`
