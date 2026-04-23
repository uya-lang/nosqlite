# NoSQLite Phase 12.5 - 外围异步能力评估与落地

日期：2026-04-23

## 状态

`已完成`

本阶段的目标不是把 async 状态机打进存储内核，而是把 `@async_fn` 限定在外围包装层，并给出可以直接使用的最小异步入口。

## 本阶段结论

1. `checkpoint_async`
   已落地为 `lib.api.db_async.db_checkpoint_async`，内部只包装同步 `db_checkpoint`。
2. `vacuum_async`
   当前明确为 `fail-fast` 占位能力；`db_vacuum` / `db_vacuum_async` 直接返回 `DbVacuumUnsupported`，避免把尚未设计完成的 compaction 语义伪装成可用功能。
3. `build_index_async`
   已落地为 `lib.api.db_async.db_build_index_async`，内部包装同步 `db_build_index`。
4. 流式 query service wrapper
   已提供 `DbQueryResultStream` + `db_query_stream_open` + `db_query_stream_next_async` + `db_query_stream_current_row`。
   当前 wrapper 采用“先物化为 `QueryResult`，再按行异步推进”的保守策略，避免把 `QueryCursor` 的借用行跨 `@await` 暴露出去。
5. `@async_fn` 边界
   当前只允许出现在 [`nosqlite/lib/api/db_async.uya`](/home/winger/nosqlite/nosqlite/lib/api/db_async.uya)。
   `pager / WAL / B+Tree` 以及其他核心存储模块保持同步实现。

## 新增 API

- [`db.uya`](/home/winger/nosqlite/nosqlite/lib/api/db.uya)
  提供同步 helper：`db_checkpoint`、`db_build_index`、`db_vacuum`
- [`db_async.uya`](/home/winger/nosqlite/nosqlite/lib/api/db_async.uya)
  提供外围 async shell：`db_checkpoint_async`、`db_build_index_async`、`db_vacuum_async`
- [`db_async.uya`](/home/winger/nosqlite/nosqlite/lib/api/db_async.uya)
  提供 service wrapper：`DbQueryResultStream`、`db_query_stream_open`、`db_query_stream_next_async`、`db_query_stream_current_row`

## 验证入口

- [`test_phase12_async.uya`](/home/winger/nosqlite/nosqlite/test_phase12_async.uya)
  覆盖 `checkpoint_async`、`build_index_async`、`vacuum_async`、query stream wrapper
- [`verify_phase12_5_async_boundary.sh`](/home/winger/nosqlite/nosqlite/tests/verify_phase12_5_async_boundary.sh)
  校验 `@async_fn` 仅停留在 `lib/api/db_async.uya`

## 当前备注

当前仓库仍存在独立的 Uya codegen 老问题：

- split-C 会重复生成 `wal_header` 定义
- 集成 runner 在默认栈限制下可能崩溃

这两个问题已经记录在 [`bugreport-uya-split-c-wal-header-duplicate-and-stack-limit.md`](/home/winger/nosqlite/docs/bugreport-uya-split-c-wal-header-duplicate-and-stack-limit.md)。

因此本阶段的运行验证采用了临时 workaround：

1. 先生成 `.uyacache`
2. 手工去掉生成物里的重复 `wal_header` 段
3. 重新 `make`
4. 用放大的栈限制运行 runner

这不影响 Phase 12.5 代码与边界设计本身的结论，但它仍然是后续需要单独修复的构建链问题。
