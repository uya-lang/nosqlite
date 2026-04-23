# NoSQLite 格式兼容与升级

日期：2026-04-23

## 当前 reader 能力

当前二进制的磁盘格式 reader 版本为 `1`，只支持 v1 文件格式。

兼容矩阵：

| 字段 | 当前支持范围 | 不满足时行为 |
| --- | --- | --- |
| `format_version` | `1` | fail-fast，返回 `PagerIncompatibleFormat` |
| `min_reader_version` | `1 <= min_reader_version <= 1` | fail-fast，返回 `PagerIncompatibleFormat` |
| `feature_flags` | `0x0` | fail-fast，返回 `PagerUnknownFeatureFlags` |
| `page_size` | `4096` 或 `8192` | fail-fast，视为无有效 meta/page |

打开数据库时必须同时校验主文件 `MetaPage` 与 WAL `WalHeader`：

- 两者 `format_version` 必须一致且被当前 reader 支持。
- 两者 `min_reader_version` 必须一致且不高于当前 reader。
- 两者 `feature_flags` 必须一致，且所有位都已知。
- 两者 `page_size` 必须一致。
- checksum 必须有效；checksum 损坏不参与兼容降级。

## feature flag 规则

v1 暂不定义任何可打开的 feature flag，因此当前支持 mask 为 `0x0`。

任何非零 `feature_flags` 都表示当前二进制不能安全解释该文件，必须拒绝打开。后续版本如果增加兼容能力，必须先扩展支持 mask 和测试矩阵。

## 显式升级路径

格式升级只能通过显式入口执行：

- pager 层：`pager_upgrade_at_stem(stem, plan)`
- db 层：`db_upgrade_format(db, plan)`

升级流程：

1. 校验目标 `format_version/min_reader_version/feature_flags` 是否被当前二进制支持。
2. 打开数据库并完成 WAL recovery。
3. 在任何格式字段改写前执行 checkpoint。
4. 确认 WAL 已截断到 `WalHeader` 大小。
5. 只有在 checkpoint 成功后，才允许改写 WAL header 与 meta page。

当前 v1 到 v1 的升级是 no-op，但仍会执行 checkpoint 与 WAL 截断，用于固定未来不兼容升级的安全边界。

## 失败回滚契约

升级失败后必须满足：

- 原 store 仍可用当前 reader 打开。
- `format_version/min_reader_version/feature_flags` 不出现半升级状态。
- 如果失败发生在 checkpoint 之后，checkpoint 成果允许保留，因为它不改变文件格式语义。
- WAL 必须处于可恢复或已截断状态，不允许留下部分格式升级记录。

覆盖测试：

- `nosqlite/test_storage_page_basics.uya`：核心格式兼容矩阵。
- `nosqlite/test_phase13_format_upgrade.uya`：不兼容版本拒绝、未知 feature flag 拒绝、升级前 checkpoint/WAL 截断、失败升级回滚。
