# NoSQLite TODO

日期：2026-04-21

## 全局开发规则

### TDD 默认启用

- [ ] 所有新功能默认遵循 `Red -> Green -> Refactor`
- [ ] 先写失败测试，再写最小实现，再做重构
- [ ] 修复任何 bug 时，必须先补回归测试，再修实现
- [ ] 磁盘格式、WAL、恢复逻辑变更时，必须先补 golden / corruption / recovery 测试
- [ ] 页布局、索引顺序、数值比较规则变更时，必须先补对照测试
- [ ] 在一个 TODO 子项被勾选完成前，对应测试必须已存在且能稳定通过

### TDD 执行约束

- [ ] 优先写纯单元测试，再写集成测试，最后写压力/故障测试
- [ ] 每个 Phase 至少先完成 1 个失败测试用例，再开始对应实现
- [ ] `Definition of Done` 里的能力项，必须能映射到明确测试文件或测试组
- [ ] 不接受“代码先写完，最后统一补测试”的开发方式

## Phase 0 - 项目骨架

- [x] 创建 `nosqlite/lib` 目录结构
- [x] 创建 `nosqlite/tests` 目录结构
- [x] 约定测试文件命名：`test_*.uya`
- [x] 定义统一错误码与错误分类
- [x] 定义基础类型：`DocId`、`PageId`、`TxnId`、`Lsn`
- [x] 定义 Uya-native 资源模型：owning type / borrow type / guard type
- [x] 定义生产配置轮廓：开发 / 量产
- [x] 定义公共测试入口和最小 smoke test
- [x] 写一份 TDD 执行说明，约定每个模块先测后写
- [x] 约定数据库文件扩展名与目录布局
- [x] 写一份最小 API 草案并固定命名

## Phase 1 - 文档编码层

- [x] 先写 `DocBlob` 失败测试：节点头、数值词素、对象 key 排序
- [x] 定义 `DocBlob` 二进制格式
- [x] 定义 `NodeHeader`
- [x] 定义 `INT64/NUMBER_TEXT/STRING/ARRAY/OBJECT` 节点布局
- [x] 定义对象 `ObjectEntry` 与排序规则
- [x] 定义类型标签与长度编码规则
- [x] 定义 `NUMBER_TEXT` 的无损词素存储规则
- [x] 定义 decimal / bigint 比较接口
- [x] 实现从 `std.json.JsonValue` 到 `DocBlob` 的转码
- [x] 实现 `DocBlob` 的对象字段查找
- [x] 实现 `DocBlob` 的数组索引访问
- [x] 实现 JSON path 编译到 `PathProgram`
- [x] 实现 `PathProgram` 在 `DocBlob` 上求值
- [x] 为标量比较实现统一比较规则
- [x] 编写大整数 / 精确小数 round-trip 测试
- [x] 补全文档编码单元测试
- [x] 补全路径求值单元测试

## Phase 2 - Pager 与文件头

- [x] 先写失败测试：`MetaPage`、`WalHeader`、`PageHeader`、`Slot`、free space helper
- [x] 定义 `MetaPage`
- [x] 定义 `format_version`
- [x] 定义 `min_reader_version`
- [x] 定义 `feature_flags`
- [x] 定义双 Meta 页轮换规则
- [x] 定义 `active_meta_slot` 语义
- [x] 定义通用 `PageHeader`
- [x] 定义 `WriterLockGuard`
- [x] 定义 `PagePin`
- [x] 实现数据库新建流程
- [x] 实现数据库打开与头校验
- [x] 实现 Meta A / Meta B 选择逻辑
- [x] 实现页读取
- [x] 实现页写回
- [x] 实现页校验和
- [x] 定义 page table 抽象
- [x] 实现已发布页帧只读规则
- [x] 实现私有脏页副本
- [x] 为锁与 pin 路径补 `drop` 自动释放
- [x] 定义 `SnapshotPressurePolicy`
- [x] 定义 cursor lease 语义
- [x] 实现 snapshot pressure 对写侧的 backpressure
- [x] 实现空闲页链表
- [x] 实现 slotted page 插入
- [x] 实现 slotted page 读回
- [x] 补充分页、插槽、校验测试

## Phase 3 - WAL 与恢复

- [x] 先写失败测试：WAL 头校验、已提交事务 redo、坏记录截断
- [x] 增加 `fsync/fdatasync` OS 封装
- [x] 定义 WAL 文件头
- [x] 在 WAL 文件头中加入 `format_version/min_reader_version/feature_flags`
- [x] 定义 `BEGIN/PAGE_WRITE/COMMIT/CHECKPOINT` 记录
- [x] 定义 `WalCommit` 中的数据库级元数据
- [x] 定义 `WalBatch`
- [x] 定义 `CheckpointPolicy`
- [x] 实现 WAL 追加写
- [x] 实现事务提交时的 WAL 刷写顺序
- [x] 实现 `fdatasync(wal)` durability barrier
- [x] 实现 `fdatasync(db)` durability barrier
- [x] 为 open/commit/recovery 路径补 `errdefer`
- [x] 固定 checksum 算法与覆盖范围
- [x] 实现启动恢复扫描
- [x] 实现仅重放已提交事务
- [x] 实现 `meta.commit_lsn` 之后的 redo
- [x] 实现基于 `page_lsn` 的 redo 判定
- [x] 实现 checkpoint
- [x] 实现 WAL 截断
- [x] 实现 `wal_soft_limit_bytes` 触发 checkpoint
- [x] 实现 `wal_hard_limit_bytes` 强制 checkpoint
- [x] 编写断电恢复测试
- [x] 编写 WAL 截断损坏测试

## Phase 4 - Catalog

- [x] 先写失败测试：catalog 持久化/加载/损坏检测
- [x] 定义 `CollectionMeta`
- [x] 定义 `CatalogRoot`
- [x] 定义 `IndexMeta`
- [x] 为 `CollectionMeta` 增加名称与索引偏移布局
- [x] 实现 `CREATE COLLECTION`
- [x] 实现 collection 元数据持久化
- [x] 实现 collection 元数据加载
- [x] 实现 collection 名称查找
- [x] 实现 `next_doc_id` 分配
- [x] 为 catalog 增加启动一致性检查

## Phase 5 - 主索引 B+Tree

- [x] 先写失败测试：查找、分裂、顺序游标、数值索引键排序
- [x] 定义 B+Tree 内部页格式
- [x] 定义 B+Tree 叶子页格式
- [x] 定义 canonical numeric index key encoding
- [x] 实现叶子查找
- [x] 实现叶子插入
- [x] 实现叶子分裂
- [x] 实现根分裂
- [x] 实现游标顺序遍历
- [x] 实现 `_id -> RecordPointer` 查找
- [x] 编写随机插入对照测试
- [x] 编写顺序扫描对照测试

## Phase 6 - SQL Lexer / Parser

- [x] 先写失败测试：关键字、路径、表达式优先级、错误语法
- [x] 定义 token 集合
- [x] 实现 SQL lexer
- [x] 实现 `SELECT` 解析
- [x] 实现 `INSERT` 解析
- [x] 实现 `CREATE COLLECTION` 解析
- [x] 实现表达式解析
- [x] 实现 JSON path 语法解析
- [x] 实现 AST pretty print
- [x] 编写语法错误测试
- [x] 编写保留字测试

## Phase 7 - Binder / Planner

- [x] 先写失败测试：路径绑定、字面量归一、索引选择
- [x] 实现 collection 存在性校验
- [x] 实现系统列绑定
- [x] 实现 JSON path 绑定
- [x] 实现字面量类型归一
- [x] 实现 `_id = literal` 的索引选择
- [x] 实现默认 `SeqScan`
- [x] 实现 `Filter` 下推
- [x] 实现 `Limit` 规划
- [x] 实现最小 `EXPLAIN` 输出

## Phase 8 - Executor v1

- [x] 先写失败测试：`SeqScan`、`PrimaryLookup`、`Filter`、`Project`、`Limit`
- [x] 定义 `CommitViewPin`
- [x] 定义 `QueryCursor`
- [x] 定义 `RowRef`
- [x] 定义拥有所有权的 `QueryResult`
- [x] 定义 `OwnedRow` / 结果编码格式
- [x] 为 `QueryCursor` 和 `CommitViewPin` 定义 `drop`
- [x] 实现 `SeqScan`
- [x] 实现 `PrimaryLookup`
- [x] 实现 `Filter`
- [x] 实现 `Project`
- [x] 实现 `Limit`
- [x] 实现表达式求值器
- [x] 实现结果集收集
- [x] 实现 `db_query_cursor`
- [x] 实现 `db_query` 物化包装层
- [x] 明确 `db_query_cursor` 不得借用语句级 arena
- [x] 实现 `CursorExpired`
- [x] 实现 `SnapshotPressure`
- [x] 实现 `SELECT _id, $.path ...`
- [x] 编写查询结果正确性测试
- [x] 编写空结果与错误路径测试

## Phase 9 - 快照读与提交视图

- [ ] 先写失败测试：旧读者不中断、retired 资源回收、cursor 过期
- [ ] 定义 `CommitView`
- [ ] 将 `page_table_gen` 纳入 `CommitView`
- [ ] 实现 reader pin / unpin
- [ ] 实现不可变 page table
- [ ] 实现提交后原子切换当前视图
- [ ] 实现 retired view 延迟回收
- [ ] 实现 retired page frame 延迟回收
- [ ] 实现查询开始时绑定快照
- [ ] 用 guard + `drop` 封装 view pin 生命周期
- [ ] 实现 `soft_retired_bytes` 监控
- [ ] 实现 `hard_retired_bytes` 限流/拒绝策略
- [ ] 实现 cursor lease 到期失效
- [ ] 确认提交期间旧读者不中断
- [ ] 验证 hard snapshot pressure 下写侧会 backpressure
- [ ] 编写“长查询 + 并发提交”测试

## Phase 10 - 写路径 v1

- [ ] 先写失败测试：插入、主键可见性、未提交不可见、重启后可见
- [ ] 定义 `Txn`
- [ ] 定义 `DocBlobBuilder`
- [ ] 实现 `INSERT INTO ... JSON ...`
- [ ] 将输入 JSON 解析并编码为 `DocBlob`
- [ ] 将记录写入数据页
- [ ] 将 `_id` 写入主索引
- [ ] 将写路径接入 WAL
- [ ] 按“WAL -> page cache publish -> data file -> meta page”顺序提交
- [ ] 为 `Txn` 定义 `drop`：未提交时自动 abort
- [ ] 为 `DocBlobBuilder` 定义 `drop`：释放 scratch / reset arena
- [ ] 实现事务提交与回滚骨架
- [ ] 编写插入后查询测试
- [ ] 编写重启持久化测试

## Phase 11 - v1 稳定化

- [ ] 先写失败测试：损坏页、损坏 WAL、checkpoint、snapshot pressure、数值精度
- [ ] 做页损坏检测
- [ ] 做 WAL 损坏检测
- [ ] 做断电恢复验证
- [ ] 输出人类可读错误信息
- [ ] 增加 `db_check` 一致性检查工具
- [ ] 将当前第 18 节性能门槛标注为“工程预算版”
- [ ] 将第 18 节改成 `floor / target / stretch` 三档制
- [ ] 定义 benchmark 环境信息输出格式
- [ ] 固定参考数据集生成器：`100_000` 文档、平均 `1 KiB`
- [ ] 增加 `warm-read` benchmark
- [ ] 增加 `durable-write` benchmark
- [ ] 增加 `recovery` benchmark
- [ ] 产出 v0 实测性能基线
- [ ] 用 v0 实测数据替换第 18 节预算数字
- [ ] 统计并输出 `p50/p95/p99`
- [ ] 统计并输出 `docs/s`、`MiB/s`
- [ ] 统计并输出 `peak_memory`
- [ ] 验证所有 v1 benchmark 至少达到 `floor`
- [ ] 记录 `_id` 点查的 `target/stretch` 达成情况
- [ ] 记录顺扫过滤的 `target/stretch` 达成情况
- [ ] 记录 durable write 的 `target/stretch` 达成情况
- [ ] 记录 recovery 的 `target/stretch` 达成情况
- [ ] 记录“长查询 + 并发提交”相对基线保持率的 `target/stretch` 达成情况
- [ ] 验证 snapshot pressure 触发后资源仍保持有界
- [ ] 验证 checkpoint 策略能把 WAL 控制在策略阈值内
- [ ] 验证大整数 / 精确小数不会发生静默降精度
- [ ] 验证数值索引顺序与执行器比较语义一致
- [ ] 验证 WAL/header/page checksum 失败时 fail-fast 或安全截断
- [ ] 增加文档示例
- [ ] 增加 API 使用示例
- [ ] 完成 v1 里程碑验收

## Phase 12 - v1.5 功能扩展

- [ ] 先写失败测试：`UPDATE`、`DELETE`、二级索引、`ORDER BY`
- [ ] 实现 `UPDATE`
- [ ] 实现 `DELETE`
- [ ] 实现 tombstone 读取过滤
- [ ] 实现 `CREATE INDEX`
- [ ] 实现单列二级索引
- [ ] 实现 `IndexScan`
- [ ] 实现简单 `ORDER BY`
- [ ] 增强 `EXPLAIN`

## Phase 12.5 - 外围异步能力

- [ ] 评估 `checkpoint_async`
- [ ] 评估 `vacuum_async`
- [ ] 评估 `build_index_async`
- [ ] 评估流式 query service wrapper
- [ ] 明确 `@async_fn` 不进入 pager / WAL / B+Tree 核心路径

## Phase 13 - 格式兼容与升级

- [ ] 先写失败测试：不兼容版本拒绝打开、未知 feature flag 拒绝、失败升级回滚
- [ ] 定义文件格式兼容矩阵
- [ ] 实现不兼容 `format_version` fail-fast
- [ ] 实现未知必需 `feature_flags` fail-fast
- [ ] 设计显式 upgrade 路径
- [ ] 验证升级前必须 checkpoint 并截断 WAL
- [ ] 验证失败升级后的回滚流程

## Phase 14 - 编译期增强

- [ ] 先写失败测试：字段不存在、类型不匹配、schema 与 SQL 不一致
- [ ] 定义静态 schema 描述格式
- [ ] 设计 `typed_sql(sql, schema)` 接口
- [ ] 只做静态字段与类型校验
- [ ] 不把编译期 schema 当成运行时事实源
- [ ] 为宏路径增加回归测试
- [ ] 输出清晰的编译期错误信息

## Definition of Done

- [ ] 新建数据库、插入、查询、重启恢复全链路可跑通
- [ ] `_id` 主键查找明显快于全表扫描
- [ ] 未提交事务不会在恢复后可见
- [ ] 已提交事务在断电恢复后可见
- [ ] 长查询执行期间提交不会打断已有读者
- [ ] 同时具备 `db_query` 和 `db_query_cursor`
- [ ] 点查、顺扫、写入、恢复四类 benchmark 至少达到设计文档第 18 节 `floor`
- [ ] 大整数与精确小数无静默降精度
- [ ] 快照与 WAL 资源在生产策略下保持有界
- [ ] 文件格式升级/拒绝打开不兼容版本行为经过验证
- [ ] 核心资源类型完成 `drop` 封装
- [ ] 核心错误路径完成 `errdefer` 回滚
- [ ] 锁与 pin 完成 guard 化
- [ ] 每个完成的能力项都能对应到明确的测试文件或测试组
- [ ] 所有核心模块至少有单元测试
- [ ] 至少有一组故障恢复测试
- [ ] 文档与示例可以独立指导使用
