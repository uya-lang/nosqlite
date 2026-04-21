# NoSQLite 方案评审

日期：2026-04-21

## 结论

这个方案的方向是对的：`SQL over JSON documents + 嵌入式 + Uya 零 GC` 组合非常有特色，也确实适合做成系统级项目。

但按当前草案直接实现，范围明显过大，而且有几处设计和当前 Uya 仓库能力并不完全对齐。结论不是“不能做”，而是“需要先收敛到一个可交付的 v1”。

建议采用下面的总体策略：

- v1 先做运行时 SQL 解析，不把编译期 SQL 宏作为主路径。
- v1 先做单进程、单写者、redo-only WAL，不把完整 MVCC 作为首发能力。
- v1 先做自定义二进制文档编码，不直接把 `std.json` 的解析树当持久化格式。
- v1 先把主索引、过滤、投影、限制、简单排序跑通，再扩展二级索引、聚合、事务隔离。

## 主要问题

### 1. 编译期 SQL 验证不能作为核心路径

原方案把 `mc` 宏、`@mc_eval`、`@mc_type` 当成核心前端能力，用来在编译期验证表、字段和类型。这在“静态 schema + 静态查询”的世界里成立，但 NoSQLite 的核心对象是 JSON 文档集合，字段天然是运行时演化的。

当前仓库里，`@mc_type` 能提供的是静态类型反射，而不是运行时数据库模式反射，见 [builtin_functions.md](/home/winger/nosqlite/uya/docs/builtin_functions.md#L950)；同时宏编译时函数章节仍标注“语法解析已实现，CPS 变换和求值引擎待实现”，见 [builtin_functions.md](/home/winger/nosqlite/uya/docs/builtin_functions.md#L903)。这说明宏能力可以利用，但不适合承载数据库前端的主实现路径。

评审意见：

- `typed_sql(sql, Schema)` 应该保留，但定位为“可选的静态包装层”。
- 查询主路径应该是运行时 SQL 解析器 + catalog/schema 元数据校验。
- 如果后续要做编译期增强，应该基于显式 schema 文件或 Uya 结构体镜像，而不是直接假定数据库里的 JSON 集合在编译期可见。

### 2. JSON 内存模型与当前 `std.json` 不一致

当前仓库里的 JSON 值模型是一个 tagged union，字符串是 `ptr + len` 视图，对象是线性 `pairs` 数组，不是你草案里的“字符串池 + 对象哈希表 + 引用计数”，见 [value.uya](/home/winger/nosqlite/uya/lib/std/json/value.uya#L1)。

同时当前解析器明确是“零拷贝字符串 + arena 分配”，也就是解析结果会直接引用输入缓冲区，见 [parser.uya](/home/winger/nosqlite/uya/lib/std/json/parser.uya#L1) 和 [parser.uya](/home/winger/nosqlite/uya/lib/std/json/parser.uya#L195)。Arena 也是简单 bump allocator，只支持极有限的原地 `realloc`，并不适合承载长期存活、碎片化更新的数据结构，见 [arena.uya](/home/winger/nosqlite/uya/lib/std/mem/arena.uya#L1)。

这意味着：

- 不能直接把当前 `std.json` 解析树当作数据库的持久化内部表示。
- 也不应在 v1 就上“引用计数字符串池 + 可变 DOM”这类重对象模型。

评审意见：

- `std.json` 适合做“入口解析器”和测试对照器。
- 存储层应该定义自己的二进制文档编码 `DocBlob`。
- 查询执行优先围绕 `DocBlob` 做路径提取，不依赖长期存活的 JSON DOM。

### 3. `mmap + 整文件原地改写 + old/new 双页 WAL + MVCC` 组合过重

当前仓库已经有文件打开、读写、`mmap/munmap` 能力，见 [file.uya](/home/winger/nosqlite/uya/lib/std/io/file.uya#L37) 和 [osal.uya](/home/winger/nosqlite/uya/lib/osal/osal.uya#L164)。但现成接口主要覆盖 `open/read/write/seek/mmap/munmap` 这些基础能力，没有现成的数据库级 page cache、checkpoint、页校验、崩溃一致性骨架。

而原方案一次性引入：

- 整文件内存映射
- B+Tree 页管理
- 页分裂/合并
- 双页 old/new image WAL
- MVCC 版本链
- 乐观并发控制
- 崩溃恢复

这几项叠加后，工程复杂度会远超一个“轻量级嵌入式数据库”的 v1 范围。

评审意见：

- v1 用 pager + redo-only WAL + 单写者锁。
- v1 页面更新仍可以通过页缓存完成，不必要求整文件长期 `mmap`。
- `mmap` 可以先用于只读优化或测试模式，不作为第一阶段前提。
- MVCC 推迟到 v2/v3，再讨论版本链、旧版本回收和 snapshot read。

### 4. 元数据容器依赖了仓库里尚不存在的泛型集合能力

草案里大量使用了类似 `HashMap<[i8: 64], Collection>` 这样的类型，但当前仓库中的 `std.collections.hashmap` 实现实际上是“字符串键 + `i32` 值”的专用表，而不是泛型 `HashMap<K, V>`，见 [hashmap.uya](/home/winger/nosqlite/uya/lib/std/collections/hashmap.uya#L1) 和 [hashmap.uya](/home/winger/nosqlite/uya/lib/std/collections/hashmap.uya#L188)。

这不是说做不了，而是意味着：

- catalog 层不能建立在“标准库里已经有通用泛型哈希表”这个假设上。
- v1 更稳妥的方式是：catalog 先用顺序数组 + 名字查找，必要时为字符串键单独做一个项目内专用 map。

### 5. 部分类型写法目前更像概念草图，不是 Uya-ready 接口

几个例子：

- `chars: [byte: 0]` 在当前仓库里更接近“零长度数组”，不是文档化的 C flexible array member 语义。
- `extern union` 虽然支持 C 兼容布局，但不支持方法和 `match`，见 [union_memory_layout.md](/home/winger/nosqlite/uya/docs/union_memory_layout.md#L119)。
- `union Option<&Document>` 这类写法和当前 `Option<T>` 的实际定义不一致，当前核心库里是 `Option<T>.Some / None`，见 [option.uya](/home/winger/nosqlite/uya/lib/std/core/option.uya#L1)。

评审意见：

- 详细设计里要把“概念类型”和“实际 Uya API 形状”分开。
- 所有核心接口都应改成接近现有 Uya 风格的定义，避免把语言设计和数据库实现同时做掉。

## 推荐的收敛版路线

### v1 必做

- 单文件数据库 + 单独 `.wal` 文件
- 运行时 SQL lexer/parser
- 文档写入、按 `_id` 查询、全表扫描
- `WHERE` 过滤
- `SELECT` 投影
- `LIMIT`
- 主键 B+Tree
- redo-only WAL
- 单写者事务

### v1.5 建议做

- 二级索引
- `ORDER BY` 利用索引
- `UPDATE` / `DELETE`
- `CREATE INDEX`
- 基础 `EXPLAIN`

### v2 再做

- 聚合
- `GROUP BY`
- 更完整的代价模型
- 查询计划缓存
- 自适应索引建议

### v3 再做

- 编译期 SQL 包装层
- 静态 schema 绑定
- snapshot/MVCC
- GIN/全文索引

## 最终判断

这个项目值得做，而且很有辨识度。

真正的风险不在“Uya 能不能做数据库”，而在于原方案把太多高级特性堆进了第一版。只要我们把目标改成“先做一个稳定、可恢复、可查询的 JSON 文档数据库内核”，这件事是完全可以拆开推进的。
