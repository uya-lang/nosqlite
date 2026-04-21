# NoSQLite 详细设计

日期：2026-04-21

## 1. 目标

NoSQLite 是一个面向生产环境量产部署的嵌入式文档数据库，面向以下场景：

- 单进程内嵌使用
- 文档以 JSON 为逻辑模型
- 查询语言采用 SQL 风格
- 在 Uya 的零 GC、显式内存和系统接口能力上实现

v1 目标不是替代 SQLite，也不是一步到位支持 MongoDB 级文档能力。v1 的目标是交付一个“可持久化、可恢复、可查询、可扩展、可演进、可量产部署”的数据库内核。

### 1.1 生产原则

既然目标是生产量产，设计需要优先满足下面几类约束：

- 不允许静默数据损坏
- 不允许无界资源增长
- 崩溃恢复时间必须可预测
- 文件格式必须可版本化、可升级、可拒绝不兼容版本
- 生产发布要区分“工程预算指标”和“客户可承诺 SLO”

## 2. 非目标

v1 不包含以下内容：

- 编译期 SQL 校验作为默认执行路径
- 多写者并发
- MVCC
- 全量聚合框架
- 全文检索
- GIN/HASH 多索引类型
- 网络服务端协议

## 3. v1 范围

v1 支持：

- `CREATE COLLECTION`
- `INSERT`
- `SELECT`
- `WHERE`
- `LIMIT`
- `_id` 主键查询
- 顺序扫描
- 主键 B+Tree
- redo-only WAL
- 崩溃恢复

v1.5 支持：

- `UPDATE`
- `DELETE`
- `CREATE INDEX`
- 二级索引扫描
- `ORDER BY`
- `EXPLAIN`

## 4. 顶层架构

```text
SQL Text
  -> Lexer
  -> Parser
  -> AST
  -> Binder
  -> Planner
  -> Exec Plan
  -> Executor
  -> Storage / Index / WAL
```

模块分层如下：

1. 前端层
   负责 SQL 词法、语法、语义绑定。
2. 规划层
   负责选择 `SeqScan` 或 `IndexScan`，并组合 `Filter`、`Project`、`Limit`。
3. 执行层
   负责逐行拉取、谓词求值、路径提取和结果编码。
4. 存储层
   负责 pager、页布局、WAL、B+Tree、catalog。
5. 文档层
   负责 JSON 入口解析和内部二进制文档编码。

## 5. 模块划分

建议未来代码目录：

```text
nosqlite/
  lib/
    core/
      types.uya
      error.uya
      status.uya
    doc/
      value.uya
      codec.uya
      path.uya
      compare.uya
    sql/
      token.uya
      lexer.uya
      ast.uya
      parser.uya
      binder.uya
    plan/
      expr.uya
      plan.uya
      planner.uya
      cost.uya
    exec/
      exec_node.uya
      seq_scan.uya
      index_scan.uya
      filter.uya
      project.uya
      limit.uya
      eval.uya
    storage/
      header.uya
      pager.uya
      wal.uya
      recovery.uya
      page.uya
      slotted_page.uya
    index/
      key.uya
      btree.uya
      btree_page.uya
      cursor.uya
    catalog/
      catalog.uya
      collection.uya
      schema.uya
    api/
      db.uya
      txn.uya
      result.uya
```

## 6. 核心设计决策

### 6.1 文档内部表示

NoSQLite 不直接持久化 `std.json.JsonValue`。原因是当前 `std.json` 更适合做入口解析，而不是长期存活的数据格式。

数据库内部文档格式定义为 `DocBlob`，它是一个紧凑的二进制编码。

v1 不直接存储原始 JSON 文本，默认存储“规范化二进制 JSON”。

建议编码：

- `type_tag: u8`
- 标量类型采用定长或变长长度前缀
- `array` 采用 `count + offsets + payload`
- `object` 采用 `count + entry_table + payload`

对象条目建议结构：

```text
ObjectEntry {
  key_hash: u32
  key_off:  u32
  val_off:  u32
}
```

对象内 key 按 `key_hash + key_bytes` 排序，允许：

- 二分查找
- 更稳定的编码
- 索引提取时更少分支

#### 6.1.1 `DocBlob` 具体格式

每个值节点都以统一头开始：

```text
NodeHeader {
  tag:      u8
  flags:    u8
  rsv:      u16
  size:     u32   // 含 header 在内的总字节数
}
```

v1 标签：

- `NULL`
- `FALSE`
- `TRUE`
- `INT64`
- `NUMBER_TEXT`
- `STRING`
- `ARRAY`
- `OBJECT`

标量编码：

```text
Int64Node {
  hdr:      NodeHeader
  value:    i64
}

StringNode {
  hdr:      NodeHeader
  byte_len: u32
  bytes:    [byte: byte_len]   // UTF-8，无 '\0'
}

NumberTextNode {
  hdr:          NodeHeader
  number_class: u8             // DECIMAL / EXPONENT / BIGINT
  rsv:          [byte: 3]
  byte_len:     u32
  bytes:        [byte: byte_len]   // 原始 JSON 数字词素，逐字节保留
}
```

数组编码：

```text
ArrayNode {
  hdr:      NodeHeader
  count:    u32
  offsets:  [u32: count]       // 相对 ArrayNode 起始偏移
  children: ...
}
```

对象编码：

```text
ObjectEntry {
  key_hash: u32
  key_len:  u16
  rsv:      u16
  key_off:  u32                // 相对 ObjectNode 起始偏移
  val_off:  u32                // 相对 ObjectNode 起始偏移
}

ObjectNode {
  hdr:      NodeHeader
  count:    u32
  entries:  [ObjectEntry: count]
  key_area: ...
  values:   ...
}
```

对象内 key 以 `(key_hash, key_bytes)` 排序，查询时流程为：

1. 先按 `key_hash` 做二分收缩范围。
2. 对同 hash 冲突项按 `key_bytes` 做精确比较。
3. 命中后跳到 `val_off` 读取子节点。

额外规则：

- 所有偏移都相对当前容器节点起始地址，便于拷贝与页内移动。
- 节点按 8 字节对齐，减少未对齐读取分支。
- 仅当源数字是“无小数点、无指数、且可安全落入 `i64`”时，才存为 `INT64`。
- 其余所有 JSON 数字一律存为 `NUMBER_TEXT`，并保留原始词素。
- v1 不保留对象字段原始顺序，但必须无损保留 JSON 数值语义。

这意味着 NoSQLite v1 的 JSON 存储格式是“自定义 binary JSON”，而不是 BSON、MessagePack，也不是原始 JSON 文本；其中数字采用“`INT64` 快路径 + `NUMBER_TEXT` 无损路径”。

#### 6.1.2 数值语义与比较规则

生产环境下，JSON 数值不能以 `f64` 作为唯一持久化表示。

v1 约束：

1. 持久化层禁止把任意 JSON 数字一律降为 `FLOAT64`
2. 查询比较不得以 `f64` 作为唯一权威比较路径
3. 对于 `NUMBER_TEXT`，必须走无损 decimal / bigint 比较路径

比较顺序：

1. `INT64` vs `INT64`
   直接整数比较
2. `INT64` vs `NUMBER_TEXT`
   先将 `INT64` 视为十进制整数，再与无损数值比较器比较
3. `NUMBER_TEXT` vs `NUMBER_TEXT`
   走无损 decimal / bigint 比较器

说明：

- v1 的 SQL 主要支持筛选、排序、索引键比较；不要求先实现完整数学表达式系统
- 若未来加入算术表达式，可在执行层引入 `EvalNumber`，但不得改变持久化层的无损约束

### 6.2 JSON 输入路径

写入流程：

1. 用 `std.json.parser` 校验输入 JSON。
2. 将解析结果转码为 `DocBlob`。
3. 对 `DocBlob` 做规范化校验。
4. 写入页存储。
5. 根据索引定义提取索引键并写入 B+Tree。

这样做的好处：

- 入口解析可复用现有仓库能力。
- 存储层不依赖可变 DOM。
- 查询路径提取可以直接在 `DocBlob` 上进行。

### 6.3 SQL 字段访问语义

v1 采用两类字段：

- 系统字段：`_id`、`_created_at`、`_updated_at`
- 文档路径：`$.name`、`$.age`、`$.address.city`

示例：

```sql
SELECT _id, $.name, $.age
FROM users
WHERE $.age >= 18
LIMIT 10;
```

这样比“裸字段名自动映射 JSON path”更稳，因为：

- 不会和系统列冲突
- 语法含义明确
- 后续扩展到嵌套路径更自然

### 6.4 事务模型

v1 事务模型：

- 单进程
- 单写者
- 多读者
- 提交模型基于 redo-only WAL
- 读操作看到“语句开始时”的最近一次成功提交快照

v1 不实现文档级 MVCC。理由：

- 简化恢复逻辑
- 简化页回收
- 简化索引一致性维护
- 更适合先把存储引擎打稳

但为了满足“多读者不中断”，v1 仍引入数据库级快照视图，而不是文档级版本链。

#### 6.4.1 `CommitView`

每次成功提交后，数据库会生成一个新的只读 `CommitView`：

```text
CommitView {
  generation:      u64
  commit_lsn:      u64
  catalog_root:    u32
  page_count:      u32
  freelist_head:   u32
  page_table_gen:  u64
}
```

读语句开始时：

1. 原子读取当前 `CommitView`
2. 增加该视图的 reader pin
3. 整个查询期间都只从这个视图读取
4. 查询结束后释放 pin

写事务提交时：

1. 在私有脏页副本上修改
2. 生成新的 `CommitView`
3. 原子切换全局当前视图
4. 旧视图等到 reader pin 清零后再回收

这不是 MVCC，因为：

- 不保存文档级历史版本
- 不支持任意历史点读取
- 只保留有限个“仍被读者持有”的提交视图

但它足以支持“读者不中断、写者独占提交”。

#### 6.4.2 Page Cache 与视图关系

为了让旧读者在提交后继续读取旧页版本，NoSQLite v1 的 pager 必须遵守“发布后页帧不可原地修改”的规则。

核心规则：

1. 已被某个 `CommitView` 发布的页帧是只读的。
2. 写事务修改页面时，必须先复制出私有页帧副本。
3. 提交时不替换旧 `CommitView` 内部的页映射，而是构造一份新的不可变 page table。
4. 新 `CommitView.page_table_gen` 指向这份新的 page table。
5. 旧 `CommitView` 仍引用旧 page table；只要还有 reader pin，就不能回收旧页帧。

可以把它理解成：

- `CommitView` 决定“这个查询看到哪一套页版本”
- `page_table_gen` 决定“page_id -> page frame” 的不可变映射

这样即使写者已经提交：

- 新读者通过新 `CommitView` 读取新页
- 旧读者仍通过旧 `CommitView` 读取旧页

直到最后一个旧读者释放 pin，旧 page table 和旧页帧才进入 retired 队列并被回收。

#### 6.4.3 快照压力控制

为了避免长时间游标导致 retired page table / page frame 无界增长，生产配置下必须启用快照压力控制。

```text
SnapshotPressurePolicy {
  soft_retired_bytes:   u64
  hard_retired_bytes:   u64
  max_retired_views:    u32
  cursor_lease_ms:      u64
}
```

建议生产默认值：

- `soft_retired_bytes = 256 MiB`
- `hard_retired_bytes = 1 GiB`
- `max_retired_views = 64`
- `cursor_lease_ms = 30_000`

行为规则：

1. 超过 `soft_retired_bytes`
   立即上报指标，并调度优先 checkpoint / 回收扫描
2. 超过 `hard_retired_bytes` 或 `max_retired_views`
   新建流式 cursor 可以失败并返回 `error.SnapshotPressure`
3. 超过 `cursor_lease_ms`
   `QueryCursor.next()` 可返回 `error.CursorExpired`
4. 超过 `hard_retired_bytes`
   新写事务不得继续无限制提交；实现必须选择“阻塞等待回收”或返回 `error.SnapshotPressure`

写侧规则：

- 生产配置下，`hard_retired_bytes` 是写路径硬约束，不只是读路径告警
- 当 retired 资源超过 hard limit 时，写者必须被 backpressure，而不是继续制造更多 retired 页面
- 只有 checkpoint / 回收让 retired 资源回落到安全区后，普通写事务才可恢复

设计意图：

- `db_query_cursor` 是高效流式接口，但不是无限寿命租约
- 需要无限寿命结果时，应改用 `db_query` 物化结果
- 写路径不能因单个卡死 cursor 而无限期积压 retired 页面

### 6.5 索引模型

v1 只保证一个强制主索引：

- `_id` -> `RecordPointer`

其中 `RecordPointer`：

```text
RecordPointer {
  page_id:  u32
  slot_id:  u16
}
```

v1.5 增加二级索引：

- `path` -> `_id`

不在 v1 实现：

- 覆盖索引
- 复合索引
- GIN
- HASH

#### 6.5.1 数值索引键规范

二级索引上的数值排序和等值判断，必须与执行器里的无损数值比较规则一致。

因此，v1.5 若支持对数值 path 建索引，必须先定义 canonical numeric key encoding。

```text
IndexKey {
  key_kind:    u8        // NULL / BOOL / STRING / NUMBER / ...
  payload_len: u32
  payload:     [byte: payload_len]
}
```

对于 `NUMBER`：

```text
NumericKeyPayload {
  sign:        u8        // 0 = negative, 1 = zero, 2 = positive
  scale:       i32       // 10 进制小数位偏移
  ndigits:     u32
  digits:      [byte: ndigits]   // 规范化十进制数字串，无前导零
}
```

规范化规则：

1. `INT64`
   转成十进制整数后再进入 canonical encoding
2. `NUMBER_TEXT`
   解析为无损十进制 / bigint 表示，再进入 canonical encoding
3. `1`、`1.0`、`1e0`
   若语义相等，则必须产生相同的 `NumericKeyPayload`

这保证：

- 索引等值查找和执行器等值比较一致
- 数值 `ORDER BY` 的索引顺序与执行器排序一致
- 不会因为 `INT64` / `NUMBER_TEXT` 双表示而出现语义分叉

### 6.6 Uya 特性落地策略

NoSQLite 不只是“用 Uya 写出来”，还应尽量采用 Uya 原生的资源与控制流模型。

设计原则：

- 类型级资源清理优先使用 `drop`
- 作用域级收尾优先使用 `defer`
- 错误路径回滚优先使用 `errdefer`
- 拥有资源的结构体按值移动，避免隐式复制
- 核心存储路径默认同步；`@async_fn` 只用于外围异步能力和后台任务

这节定义实现时必须遵守的风格约束。

#### 6.6.1 `drop` 负责类型级资源释放

根据 Uya 的 RAII 语义，拥有资源的结构体应通过 `drop` 自动释放资源，而不是要求调用者手工调用 `close/free/unpin`。

适合定义 `drop` 的核心类型：

1. `DbHandle`
   持有 fd、page cache、catalog cache、active view 表；`drop` 时关闭 fd、释放缓存和 retired 队列。
2. `Txn`
   持有 writer lock、私有脏页、WAL batch；若事务未提交，`drop` 时自动 abort 并丢弃临时状态。
3. `QueryCursor`
   持有 `CommitView` pin、当前 page pin、执行器状态；`drop` 时自动释放所有 pin。
4. `PagePin`
   表示单个已 pin 的页帧；`drop` 时自动 `unpin`。
5. `WriterLockGuard`
   表示 writer 锁拥有权；`drop` 时自动 unlock。
6. `DocBlobBuilder`
   持有临时 arena / scratch buffer；`drop` 时自动 reset 或释放 scratch。

约束：

- 任何“忘记调用 cleanup 就会泄漏或卡死”的对象，都必须优先考虑 `drop`。
- 对外 API 应尽量返回拥有型结构体，而不是返回裸句柄和配套的手工释放函数。

#### 6.6.2 `defer` 负责作用域级收尾

`defer` 适合放置“不是对象固有资源，但当前作用域退出时必须执行”的逻辑。

典型场景：

1. `txn_commit`
   用 `defer` 确保统计计数、trace、状态标志恢复一定执行。
2. recovery/checkpoint
   用 `defer` 确保临时标记位、进度状态、debug trace 收尾。
3. benchmark / admin command
   用 `defer` 确保计时器结束、日志落盘、结果汇总输出。

推荐风格：

```text
- `drop` 管对象
- `defer` 管当前作用域必须补做的事
```

不要把本应由 `drop` 负责的资源释放长期写成散落的 `defer`。

#### 6.6.3 `errdefer` 负责错误路径回滚

数据库代码最容易出错的地方是“成功路径很清楚，错误路径漏清理”。这里应刻意发挥 Uya 的 `errdefer`。

典型场景：

1. `db_open`
   打开 fd 成功后，`errdefer` 关闭 fd；初始化 page cache 成功后，`errdefer` 销毁 cache。
2. `txn_begin`
   获得 writer lock 后，`errdefer` 自动 unlock。
3. `txn_commit`
   分配 WAL batch、私有脏页、new page table 后，用 `errdefer` 回收这些尚未发布的临时对象。
4. `db_query`
   物化结果时若中途出错，`errdefer` 释放 `QueryResult` 已分配内容。
5. `catalog load`
   局部加载成功但整体校验失败时，`errdefer` 清理半成品内存结构。

推荐风格：

```text
- 成功后长期存活的资源 -> 交给拥有型结构体 + `drop`
- 仅在当前函数构造中途产生的半成品 -> 用 `errdefer`
```

#### 6.6.4 移动语义驱动拥有型 API

Uya 的移动语义适合用来表达数据库里的“唯一拥有者”。

应设计成按值拥有的类型：

- `Txn`
- `QueryCursor`
- `QueryResult`
- `DocBlobBuilder`
- `WalBatch`
- `PageFrame`
- `CommitViewHandle`

设计规则：

1. 这些类型默认按值拥有资源。
2. 方法大多使用 `self: &Self`，避免不必要 move。
3. 创建函数返回拥有型对象，依赖 move 返回。
4. 禁止在持有活跃内部指针时移动这些对象。
5. 不长期暴露指向它们内部缓冲区的裸引用。

这会自然形成下面的分层：

- `RowRef`
  借用型，短生命周期，只在 cursor 活着时有效。
- `QueryResult`
  拥有型，move 后交给调用方长期持有。
- `Txn`
  独占型，不应被随意复制或共享。

#### 6.6.5 Guard 类型优先于裸状态位

数据库内核里，锁、pin、snapshot、temporary install 这些状态如果只靠布尔位管理，很容易漏释放。

优先设计 guard 类型：

```text
WriterLockGuard
PagePin
CommitViewPin
CatalogWriteGuard
```

这些类型的作用：

- 构造成功即代表已持有资源
- `drop` 自动释放
- 通过 move 显式转移拥有权

这样可以避免：

- 忘记解锁
- 忘记 unpin
- 查询结束后 view pin 泄漏
- recovery 中半安装状态遗留

#### 6.6.6 Arena 与拥有型结果分层

NoSQLite 当前设计里已经区分了语句级 arena 和结果级缓冲，但还需要明确 Uya 风格的所有权边界。

规则：

1. 语句级 arena 只承载 AST、计划和短生命周期临时对象。
2. `db_query_cursor` 返回的借用结果可以引用 page cache，但不能引用语句级 arena。
3. `db_query` 返回的 `QueryResult` 必须把结果复制进拥有型缓冲，完全脱离 page cache 和语句 arena。
4. `DocBlobBuilder` 可以借助 arena 做构造，但最终落盘对象必须是独立可持久化的字节串。

#### 6.6.7 `@async_fn` 的适用边界

`@async_fn` 是 Uya 的重要特性，但 NoSQLite 不应为“用了 async”而 async。

v1 核心同步路径：

- pager
- WAL append / commit
- recovery
- B+Tree 查找与插入
- SQL 执行器

这些路径优先保持同步，原因是：

- 降低状态机复杂度
- 减少 pinned / borrowed 状态交错
- 更容易先把 durability 和一致性做对

更适合 `@async_fn` 的外围能力：

1. `checkpoint_async`
2. `vacuum_async`
3. `build_index_async`
4. 微容器模式下的 query service wrapper
5. 通过 socket / pipe 输出 `db_query_cursor` 的流式结果
6. benchmark runner / admin task

也就是说：

- sync core first
- async shell around core

#### 6.6.8 建议的 Uya-native 核心类型

建议最小拥有型/借用型类型集合如下：

```text
DbHandle            // drop: close + free caches
Txn                 // drop: auto-abort if not committed
WriterLockGuard     // drop: unlock
CommitViewPin       // drop: unpin view
PagePin             // drop: unpin page
QueryCursor         // drop: release view/page pins
QueryResult         // owning materialized result
DocBlobBuilder      // drop: release scratch
WalBatch            // drop: release temp WAL buffers
```

这组类型一旦确定，后面的模块设计应围绕它们展开，而不是围绕全局状态位和手工 cleanup 展开。

#### 6.6.9 实现验收要求

实现阶段需要明确检查下面几点：

- 核心资源类型是否都定义了 `drop`
- 错误路径是否使用 `errdefer` 回滚半成品
- 锁与 pin 是否都被 guard 类型封装
- `db_query` 与 `db_query_cursor` 的所有权边界是否清晰
- 是否把 `@async_fn` 限制在外围能力，而非过早侵入 pager core

## 7. 文件格式

数据库使用两个文件：

- `name.nsq`
- `name.wal`

理由：

- 比“单文件尾部附 WAL”更易调试
- 恢复流程清晰
- 便于故障注入测试

### 7.1 主文件布局

```text
Page 0   : Meta Page A
Page 1   : Meta Page B
Page 2+  : Catalog / Data / BTree / Free pages
```

页大小：

- 默认 `4096`
- 允许后续扩展到 `8192`

### 7.2 Meta Page

为了满足断电可恢复，主文件头采用双 Meta 页轮换写入。

```text
MetaPage {
  magic:            [byte: 4]   // "NSQL"
  format_version:   u32
  min_reader_version: u32
  feature_flags:    u64
  page_size:        u32
  generation:       u64
  commit_lsn:       u64
  checkpoint_lsn:   u64
  page_count:       u32
  catalog_root:     u32
  freelist_head:    u32
  active_meta_slot: u32
  checksum:         u32
}
```

启动时读取 A/B 两页：

1. 丢弃校验失败的页
2. 在剩余页中选择 `generation` 最大的一页
3. 将它作为当前 durable meta

这样即使断电发生在 meta 更新中，也总能回退到上一份完整头信息。

#### 7.2.1 格式兼容契约

既然项目目标是量产，文件格式版本必须有明确契约。

规则：

1. `format_version`
   表示主文件与 WAL 的磁盘格式版本
2. `min_reader_version`
   表示能安全打开该文件的最小 reader 版本
3. `feature_flags`
   表示可选能力位；未知且必需的位必须导致启动拒绝

兼容策略：

- patch 版本发布不得改变磁盘格式
- 兼容性增强可通过 `feature_flags` 增加，但旧二进制若不理解必需位，必须 fail fast
- 不兼容的磁盘格式变更必须 bump `format_version`
- 一旦 bump `format_version`，必须要求升级前先 checkpoint 并截断 WAL
- 不支持“打开后偷偷改写旧格式再继续运行”

升级/回滚策略：

- 兼容升级：原文件原地打开
- 不兼容升级：必须通过显式 upgrade 路径完成
- 不兼容升级后的降级不保证可行；回滚依赖升级前备份/快照

### 7.2.2 校验和协议

量产格式必须固定 checksum 协议，避免不同实现各自解释。

v1 统一规则：

- 算法：`CRC32`（IEEE），直接复用 `std.crypto.crc32`
- 适用对象：`MetaPage`、`PageHeader + page body`、`WalHeader`、`WalPageWrite`、`WalCommit`、`CatalogRoot`
- 校验时：对象内 `checksum` 字段先置零，再对其余字节做 CRC32
- 校验失败：默认 fail-fast；不得静默忽略并继续运行

策略：

1. `MetaPage` 校验失败
   尝试另一份 meta；若两份都失败，则拒绝打开
2. WAL 记录校验失败
   启动恢复时截断到最后一条完整且已校验通过的记录边界
3. 数据页校验失败
   查询直接返回数据损坏错误，不得伪造空结果

### 7.3 通用页头

```text
PageHeader {
  page_type:      u16
  flags:          u16
  page_lsn:       u64
  lower:          u16
  upper:          u16
  checksum:       u32
}
```

页类型：

- `META`
- `CATALOG`
- `DATA`
- `BTREE_INTERNAL`
- `BTREE_LEAF`
- `FREE`

### 7.4 数据页

数据页使用 slotted page：

```text
| PageHeader | Slot Directory -> ... free space ... <- Cell Area |
```

槽项：

```text
Slot {
  off:   u16
  len:   u16
  flags: u16
}
```

Cell 内容：

```text
RecordCell {
  doc_id:       u64
  created_at:   u64
  updated_at:   u64
  doc_len:      u32
  doc_blob:     [byte: doc_len]
}
```

删除记录先打 tombstone，不在 v1 做页内压缩回收。

## 8. WAL 与恢复

### 8.1 WAL 记录类型

v1 WAL 采用 redo-only after-image。

WAL 文件头：

```text
WalHeader {
  magic:              [byte: 4]   // "NSWL"
  format_version:     u32
  min_reader_version: u32
  feature_flags:      u64
  page_size:          u32
  header_checksum:    u32
}
```

打开数据库时必须同时校验：

1. 主文件 `MetaPage.format_version`
2. `WalHeader.format_version`
3. 两者 `page_size` 一致
4. 两者的必需 `feature_flags` 都被当前二进制支持

若不满足以上条件，必须 fail-fast，禁止“尽量恢复”。

记录类型：

- `BEGIN`
- `PAGE_WRITE`
- `COMMIT`
- `CHECKPOINT`

`PAGE_WRITE` 结构：

```text
WalPageWrite {
  txn_id:      u64
  page_id:     u32
  page_lsn:    u64
  page_size:   u32
  checksum:    u32
  payload:     [byte: page_size]
}
```

`COMMIT` 记录除了 `txn_id` 与 `commit_lsn`，还必须携带形成新 `CommitView` 所需的数据库级元数据：

```text
WalCommit {
  txn_id:           u64
  commit_lsn:       u64
  catalog_root:     u32
  page_count:       u32
  freelist_head:    u32
  checksum:         u32
}
```

不在 v1 使用 old/new 双页镜像。原因：

- 日志体积过大
- 对嵌入式预算不友好
- 恢复路径可以先靠 redo-only + page_lsn 解决

### 8.1.1 生产 checkpoint 策略

checkpoint 在生产配置下不是可选优化，而是强制维护机制。

```text
CheckpointPolicy {
  wal_soft_limit_bytes:      u64
  wal_hard_limit_bytes:      u64
  wal_vs_db_ratio:           f64
  max_checkpoint_interval_ms: u64
}
```

建议生产默认值：

- `wal_soft_limit_bytes = 64 MiB`
- `wal_hard_limit_bytes = 256 MiB`
- `wal_vs_db_ratio = 0.25`
- `max_checkpoint_interval_ms = 60_000`

触发规则：

1. `wal_bytes >= wal_soft_limit_bytes`
   调度后台 checkpoint
2. `wal_bytes >= wal_hard_limit_bytes`
   进入强制 checkpoint，必要时短暂阻塞新写事务
3. `wal_bytes >= db_file_size * wal_vs_db_ratio`
   提前触发 checkpoint，避免恢复时间漂移
4. 距上次 checkpoint 超过 `max_checkpoint_interval_ms` 且存在持续写入
   触发 checkpoint

成功 checkpoint 后必须：

1. 刷写主文件
2. 更新 `checkpoint_lsn`
3. 截断或重建 WAL
4. 释放已不再被任何快照引用的 retired 页面

### 8.2 提交流程

写事务提交步骤：

1. 获取 writer lock
2. 基于当前 `CommitView` 创建私有脏页副本
3. 为所有脏页生成 `PAGE_WRITE`
4. 追加 `COMMIT`
5. 对 WAL 执行 `fdatasync`
6. 构建新的不可变 page table，并把新页版本安装到 page cache
7. 基于新 page table 构建新的 `CommitView`
8. 原子切换全局当前视图，使后续读者看到新快照
9. 将旧 page table 和旧页帧挂入 retired 队列，等待 reader pin 清零
10. 将脏页回写主文件
11. 对主文件执行 `fdatasync`
12. 将新的 `MetaPage` 写入 A/B 中“非活动”的那一页
13. 再次对主文件执行 `fdatasync`
14. 释放 writer lock

说明：

- 步骤 5 之前不能宣告提交成功，否则无法满足断电可恢复。
- 步骤 8 之后新读者可以无阻塞地看到新视图；旧读者继续使用旧视图。
- 步骤 12 到 13 失败时，重启后仍可从 WAL redo 到最新已提交状态。

### 8.3 恢复流程

启动恢复：

1. 读取 Meta A / Meta B，选出最新有效 `MetaPage`
2. 顺序扫描 WAL
3. 忽略无 `COMMIT` 的事务
4. 仅重放 `commit_lsn > meta.commit_lsn` 的已提交事务
5. 对 `page_lsn` 落后的页执行 redo
6. 重建最新 page table
7. 重建最新 `CommitView`
8. 将所有 retired 队列初始化为空
9. 按 `CheckpointPolicy` 决定是否立即做 checkpoint；若达到 hard limit，则必须执行

## 9. Catalog 设计

catalog 负责维护：

- collection 列表
- collection id
- 主索引根页
- 二级索引列表
- 路径 schema 提示

v1 collection 元数据：

```text
CollectionMeta {
  collection_id:      u32
  name_len:           u16
  flags:              u16
  next_doc_id:        u64
  primary_root_page:  u32
  secondary_index_count: u16
  rsv:                u16
  name_off:           u32
  indexes_off:        u32
}
```

`CollectionMeta` 只是 catalog blob 中的定长头，实际布局还包含名字区和索引定义区。

#### 9.1 Catalog Blob 布局

```text
CatalogRoot {
  collection_count:   u32
  collections_off:    u32
  string_pool_off:    u32
  checksum:           u32
}

IndexMeta {
  index_id:           u32
  root_page:          u32
  flags:              u16
  path_segment_count: u16
  name_off:           u32
  path_off:           u32
}
```

持久化规则：

1. `CatalogRoot.collections_off` 指向 `CollectionMeta[]`
2. `CollectionMeta.name_off` 指向 catalog blob 内部字符串池中的集合名
3. `CollectionMeta.indexes_off` 指向该集合的 `IndexMeta[]`
4. `IndexMeta.name_off` 指向索引名
5. `IndexMeta.path_off` 指向路径段数组，例如 `["address", "city"]`

这样数据库重启时可以仅通过主文件恢复出：

- collection 名称
- `next_doc_id`
- 主索引根页
- 二级索引根页
- 索引对应的 JSON path

v1 catalog 查找可以先用顺序数组缓存，不强依赖通用 HashMap。

## 10. B+Tree 设计

### 10.1 主索引

主索引键：

```text
PrimaryKey = u64  // _id
```

值：

```text
PrimaryValue = RecordPointer
```

### 10.2 页结构

叶子页：

- 有序键数组
- 对应值数组
- `next_leaf`

内部页：

- 分隔键数组
- 子页指针数组

### 10.3 操作范围

v1 需要实现：

- 查找
- 插入
- 叶子分裂
- 根分裂
- 顺序游标

v1 不实现：

- 删除合并
- 页借位
- 在线重平衡优化

删除策略采用：

- 逻辑删除
- 后台 `VACUUM` 作为未来能力

## 11. SQL 前端

### 11.1 v1 语法子集

```sql
CREATE COLLECTION users;

INSERT INTO users JSON '{"name":"张三","age":25}';

SELECT _id, $.name, $.age
FROM users
WHERE $.age >= 18
LIMIT 10;
```

支持表达式：

- 比较：`= != < <= > >=`
- 逻辑：`AND OR NOT`
- `IS NULL`

v1 不支持：

- `JOIN`
- 子查询
- 聚合
- `GROUP BY`
- `HAVING`
- 窗口函数

### 11.2 AST

核心 AST：

- `Stmt`
- `SelectStmt`
- `InsertStmt`
- `CreateCollectionStmt`
- `Expr`
- `PathExpr`
- `LiteralExpr`
- `BinaryExpr`
- `UnaryExpr`

### 11.3 Binder

Binder 的职责：

- 校验 collection 是否存在
- 区分系统列与 JSON path
- 为 path 分配 `PathProgram`
- 标准化字面量类型

`PathProgram` 是路径字节码，例如：

```text
SEG_KEY("address")
SEG_KEY("city")
END
```

## 12. 查询规划

v1 规划器规则：

1. `_id = literal` 走主键索引
2. 否则默认 `SeqScan`
3. `WHERE` 下推到 `Filter`
4. `LIMIT` 放到最上层

v1.5 增加：

1. `path = literal` 可命中单列二级索引
2. `ORDER BY` 能复用索引顺序时避免显式排序

## 13. 执行引擎

执行模型采用火山模型迭代器：

- `SeqScan`
- `PrimaryLookup`
- `IndexScan`
- `Filter`
- `Project`
- `Limit`

统一输出行：

```text
RowRef {
  doc_id:      u64
  record_ptr:  RecordPointer
  doc_blob:    &[byte]
}
```

执行器默认不把整份文档反序列化成 DOM。

#### 13.1 双返回模型

NoSQLite 同时支持“游标流式消费”和“物化结果”。

底层统一原语是 `QueryCursor`：

```text
QueryCursor {
  snapshot:    CommitView
  plan:        ExecPlan
  state:       ...
}
```

`QueryCursor` 每次 `next()` 返回一个 `RowRef`。`RowRef.doc_blob` 依赖：

- cursor 持有的 `CommitView`
- 相关 page pin

因此它只在 cursor 生命周期内有效。

面向上层的两种 API：

1. `db_query_cursor(...)`
   返回 `QueryCursor`，适合大结果集、边读边处理。
2. `db_query(...)`
   内部 drain cursor，把投影结果复制到拥有所有权的 `QueryResult` 中返回。

`QueryResult` 中的每一行不再借用 page cache，而是拥有自己的结果缓冲。

建议结果表示：

```text
QueryResult {
  column_count:   u16
  row_count:      u32
  columns:        [ColumnMeta]
  rows:           [OwnedRow]
}

OwnedRow {
  result_blob:    [byte]
}
```

`OwnedRow.result_blob` 可以直接复用一份“结果编码”格式，不需要与底层 `DocBlob` 完全相同，但必须满足：

- 生命周期独立于 cursor
- 生命周期独立于 page cache
- 生命周期独立于语句级 arena

流式接口的生产约束：

- `db_query_cursor` 默认受 `cursor_lease_ms` 约束
- 需要长时间持有结果的业务应使用 `db_query`
- 任何跨线程、跨请求、跨事务边界持有 `RowRef` 都是不被允许的

表达式求值规则：

- 系统列直接从 `RecordCell` 读取
- JSON path 通过 `doc/path.uya` 在 `DocBlob` 上解析
- 比较时先做类型归一
- `NULL` 遵循三值逻辑的简化版

## 14. 内存模型

NoSQLite 采用三层内存：

### 14.1 进程长期内存

- catalog cache
- page cache
- B+Tree cursor state
- `CommitView` 表
- reader pin / retired view 队列

### 14.2 语句级 arena

- SQL token 缓冲
- AST
- 执行计划
- 临时行对象

### 14.3 结果级缓冲

- 结果集序列化输出
- 调试 explain 字符串

原则：

- 不把长期对象放进短生命周期 arena
- 不让查询结果依赖输入 SQL 缓冲区
- 任何对外返回的数据都要有明确所有权

## 15. API 设计

建议公开 API：

```text
db_open(path)
db_close(db)

db_exec(db, sql)
db_query(db, sql)             // 物化结果
db_query_cursor(db, sql)      // 流式结果

txn_begin(db)
txn_exec(txn, sql)
txn_query(txn, sql)
txn_query_cursor(txn, sql)
txn_commit(txn)
txn_rollback(txn)
```

其中：

- `db_exec` 用于 DDL 和不返回行的 DML
- `db_exec` / `db_query` / `db_query_cursor` 都运行在隐式 auto-commit 事务中
- `db_query` 返回拥有所有权的 `QueryResult`
- `db_query_cursor` 返回流式 `QueryCursor`
- `txn_query` / `txn_query_cursor` 与 `db_*` 语义一致，但绑定到显式事务
- `txn_*` 在 v1 内部仍走单写者模型

## 16. 与 Uya 宏系统的集成策略

v1 不把 `mc` 宏当成必须条件。

后续可选增强：

```uya
const q = typed_sql(
    "SELECT $.name FROM users WHERE $.age >= 18",
    AppSchema
);
```

这里的 `AppSchema` 不是数据库实时 schema，而是：

- 项目内声明的静态 schema 镜像
- 或根据迁移文件生成的结构体定义

也就是说，编译期 SQL 是“静态约束层”，不是数据库事实源。

## 17. 测试策略

### 17.1 单元测试

- lexer
- parser
- path evaluator
- doc codec
- B+Tree split
- pager checksum
- WAL encode/decode

### 17.2 集成测试

- 打开数据库
- 创建 collection
- 插入文档
- 查询返回正确行
- 重启后数据仍在
- 崩溃恢复正确

### 17.3 故障注入

- `COMMIT` 前断电
- `COMMIT` 后主文件未落盘
- 部分页损坏
- WAL 截断

### 17.4 对照测试

- 用 `std.json` 对照文档路径读取结果
- 用线性数组对照 B+Tree 插入/查找结果

### 17.5 性能测试口径

性能验收必须绑定统一测试口径，否则数字没有意义。

#### 17.5.0 指标性质说明

第 18 节中的性能数字目前是“首版工程预算目标”，不是基于 NoSQLite 真实实现跑出来的实测基线。

它们的用途是：

- 在设计阶段约束架构不要走向明显低效的实现
- 为 benchmark 框架提供第一版 pass/fail 门槛
- 让后续实现阶段知道性能关注点优先级

它们不是：

- 当前仓库已有代码的测量结果
- 已校准的客户对外 SLO

一旦项目进入可运行原型阶段，第 18 节数字必须按下面流程重新校准：

1. 先产出 benchmark harness 与固定数据集
2. 在参考环境上跑出 v0 实测基线
3. 用 v0 基线替换“工程预算目标”
4. 后续版本只允许在该实测基线附近做相对回归约束

#### 17.5.1 参考环境

v1 的绝对性能指标只在“参考环境”上作为强验收条件：

- Linux x86_64
- release 构建
- 本地 SSD / NVMe 文件系统
- 单机本地进程，不经过网络
- 默认 `page_size = 4096`
- durability 打开，即提交路径包含 `fdatasync`

如果不是参考环境：

- 仍然要跑同一套 benchmark
- 但绝对值只作记录
- 是否达标以“相对回归不得超过 10%”为主

#### 17.5.2 参考数据集

v1 基准数据集定义如下：

- 单 collection：`users`
- 文档数：`100_000`
- 平均 `DocBlob` 大小：约 `1 KiB`
- 字段包含：
  - 顶层标量：`name`、`age`、`score`、`active`
  - 嵌套路径：`address.city`
  - 小数组：`tags`
- `_id` 为连续递增 `u64`

#### 17.5.3 测试模式

所有 benchmark 至少分三类口径：

1. `warm-read`
   数据库已打开，预热一轮后开始计时。
2. `durable-write`
   每次提交都走完整 `fdatasync` 路径。
3. `recovery`
   从干净关闭后的主文件 + 指定大小 WAL 启动恢复。

每个 case 统一输出：

- `p50`
- `p95`
- `p99`
- `throughput`
- `peak_memory`
- 基本环境信息：CPU、页大小、构建模式、文档数、平均文档大小

#### 17.5.4 预算推导原则

第 18 节中的初始数字主要来自几条简单预算，而不是精确实测：

1. 顺扫过滤目标
   `50_000 docs/s * 1 KiB ~= 50 MiB/s`
   这相当于把 v1 顺扫目标设在“明显低于现代内存带宽、但足以排除低效实现”的保守区间。

2. durable auto-commit 插入目标
   目标不是追求极致吞吐，而是确保在 `fdatasync` 打开的情况下，单条提交仍处于“毫秒级而不是百毫秒级”。

3. 批量事务插入目标
   目标基于“单次 durability 成本被批量摊销后，吞吐应显著高于 auto-commit”，所以门槛故意比单条提交高一个数量级以上。

4. 恢复吞吐目标
   `32 MiB/s` 也是保守预算，目的是避免 redo 实现落到“明显异常慢”的量级。

5. 点查与路径提取延迟目标
   这些数字本质上是在约束：
   B+Tree 查找、页命中、路径提取、结果编码这几步不能引入明显多余的拷贝和分配。

因此，这些值不是“拍脑袋随便写”，但也不是“已经被数据证明”。更准确地说，它们是 back-of-the-envelope performance budget。

## 18. 性能验收标准（工程预算版，待实测校准）

第 18 节统一采用三档制：

- `floor`
  最低可接受。v1 要想宣告通过性能验收，至少必须达到这一档。
- `target`
  目标值。代表一版健康实现应尽量达到的水平。
- `stretch`
  理想值。代表优化良好时希望逼近的上限，不作为 v1 出货硬门槛。

这些三档指标的角色是：

- `floor`
  当前版本的出货硬门槛
- `target`
  量产配置的建议门槛
- `stretch`
  持续优化目标

### 18.1 点查

在参考环境、`warm-read` 模式下，针对 `SELECT _id, $.name FROM users WHERE _id = ? LIMIT 1`：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| `db_query_cursor` 首行返回 `p50` | `<= 150 us` | `<= 100 us` | `<= 70 us` |
| `db_query_cursor` 首行返回 `p95` | `<= 500 us` | `<= 300 us` | `<= 200 us` |
| `db_query` 单行物化返回 `p95` | `<= 800 us` | `<= 500 us` | `<= 300 us` |

说明：

- 这是首版预算门槛，不是已验证基线。
- 第一版可运行原型落地后，应以真实 benchmark 结果替换。

### 18.2 顺序扫描与过滤

在参考环境、`warm-read` 模式下，针对 `SELECT _id FROM users WHERE $.age >= 18`：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| `db_query_cursor` 顺扫过滤吞吐 | `>= 30_000 docs/s` | `>= 50_000 docs/s` | `>= 80_000 docs/s` |
| 等效字节吞吐 | `>= 30 MiB/s` | `>= 50 MiB/s` | `>= 80 MiB/s` |

针对相同查询：

- `db_query_cursor` 的额外峰值内存不得随总行数线性增长

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| 除 page cache 外的峰值运行内存 | `<= 768 KiB` | `<= 512 KiB` | `<= 256 KiB` |

说明：

- `50_000 docs/s` 是按 `100_000` 文档、平均 `1 KiB` 文档体积折算出的保守目标。

### 18.3 路径提取

在参考环境、`warm-read` 模式下：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| 顶层路径 `$.age` 提取 `p95` | `<= 2 us` | `<= 1 us` | `<= 0.5 us` |
| 三段嵌套路径 `$.address.city` 提取 `p95` | `<= 4 us` | `<= 2 us` | `<= 1 us` |

这里的计时对象是文档已定位后的单次路径求值，不包含 B+Tree 查找时间。

### 18.4 持久化写入

在参考环境、`durable-write` 模式下：

1. 单条 auto-commit 插入
   `INSERT INTO users JSON ...`

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| sustained throughput | `>= 150 rows/s` | `>= 300 rows/s` | `>= 600 rows/s` |
| 单条提交 `p95` | `<= 20 ms` | `<= 10 ms` | `<= 5 ms` |

2. 批量事务插入
   每个事务 `1000` 条文档

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| sustained throughput | `>= 4_000 rows/s` | `>= 8_000 rows/s` | `>= 15_000 rows/s` |
| 平均单条摊销提交成本 | `<= 2 ms` | `<= 1 ms` | `<= 0.5 ms` |

说明：

- 这组指标的核心目的是验证“批量提交必须明显优于 auto-commit”，而不是在设计阶段声称已经达到某个最优吞吐。

### 18.5 恢复时间

在参考环境、`recovery` 模式下：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| `64 MiB` WAL 恢复完成时间 | `<= 4 s` | `<= 2 s` | `<= 1 s` |
| `256 MiB` WAL 恢复完成时间 | `<= 12 s` | `<= 8 s` | `<= 4 s` |

等价要求：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| redo 恢复吞吐 | `>= 16 MiB/s` | `>= 32 MiB/s` | `>= 64 MiB/s` |

说明：

- 这是为了避免恢复流程设计出现明显低效的实现；后续应由真实恢复基线替换。

### 18.6 并发读写稳定性

在参考环境下运行“长查询 + 并发 durable insert”场景：

- 长查询期间不得出现 reader 中断、悬垂引用、崩溃或校验错误

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| 存在长时间 `db_query_cursor` 读者时，写入吞吐相对无读者基线 | `>= 50%` | `>= 70%` | `>= 85%` |

### 18.7 内存上界

在参考环境、`100_000` 文档数据集下：

| 指标 | floor | target | stretch |
|------|-------|--------|---------|
| 简单 `_id` 点查除 page cache 外的额外峰值内存 | `<= 96 KiB` | `<= 64 KiB` | `<= 32 KiB` |
| `db_query_cursor` 顺扫过滤除 page cache 外的额外峰值内存 | `<= 768 KiB` | `<= 512 KiB` | `<= 256 KiB` |
| `db_query` 物化结果峰值内存 | `<= 最终结果大小 + 2 MiB scratch` | `<= 最终结果大小 + 1 MiB scratch` | `<= 最终结果大小 + 512 KiB scratch` |

### 18.8 生产发布附加门槛

即使通过第 18 节的 `floor`，要宣告“可量产发布”，还必须满足：

1. 文件格式兼容矩阵已冻结并文档化
2. 升级、拒绝打开不兼容版本、失败升级回滚路径都已验证
3. checkpoint 与 snapshot pressure 在压力测试下能保持资源有界
4. 断电恢复、WAL 损坏、catalog 损坏都有明确 fail-fast 或修复策略

## 19. 里程碑验收标准

### M1

- 能创建数据库文件
- 能创建 collection
- 能插入 JSON 文档
- 能按 `_id` 读回

### M2

- 能 `SELECT ... WHERE ... LIMIT`
- 能顺序扫描并做路径过滤

### M3

- 能通过 WAL 从未完成写入中恢复
- 能通过主键索引加速查找

### M4

- 能建立单列二级索引
- 能做基本 `UPDATE/DELETE`

达到 v1 里程碑还需要同时满足第 18 节中的性能验收标准，其中：

- `floor` 为硬门槛
- `target` 为建议达成值
- `stretch` 为优化追踪值
- 量产发布还必须额外满足第 `18.8` 节

## 20. 后续增强路线

后续可以逐步加回你原方案里最有价值的高级特性：

- 编译期 SQL 包装层
- 更强的 cost model
- 统计信息与索引建议
- Snapshot 读
- 真正的 MVCC
- 微容器模式内存预算优化

这样既不丢掉项目野心，也不会在第一阶段被架构复杂度拖住。
