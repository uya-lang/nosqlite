# Storage Test Group

本组覆盖：

- `MetaPage`
- `WalHeader`
- `PageHeader`
- slotted page
- pager create/open/read/write/checksum
- catalog root page、collection 元数据持久化与损坏检测
- 主索引 B+Tree 页格式、查找、分裂、顺序游标与 numeric key 编码

当前入口文件：

- `nosqlite/test_storage_page_basics.uya`
- `nosqlite/test_storage_pager_runtime.uya`
- `nosqlite/test_storage_slotted_page_runtime.uya`
- `nosqlite/test_storage_wal_runtime.uya`
- `nosqlite/test_phase13_format_upgrade.uya`
- `nosqlite/test_catalog_basics.uya`
- `nosqlite/test_index_btree.uya`
