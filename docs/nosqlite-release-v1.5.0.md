# NoSQLite 里程碑发布说明：nosqlite-v1.5.0

日期：2026-04-23

`nosqlite-v1.5.0` 是 NoSQLite v1/v1.5 的封板里程碑：Phase 0 - Phase 14 已全部完成，Definition of Done 每一项都有测试或文档证据，完整验收脚本通过。

## 发布状态

| 项目 | 状态 |
| --- | --- |
| 阶段任务 | Phase 0 - Phase 14 全部完成 |
| Definition of Done | 全部完成并有测试/文档证据 |
| 完整验收入口 | `bash nosqlite/tests/verify_definition_of_done.sh` |
| 压力测试入口 | `./uya/bin/uya nosqlite/tests/exec/test_stress_runtime.uya && .uyacache/a.out` |
| 发布状态 | 封板 |

## 核心能力

- `DocBlob` 二进制文档格式：对象 key 排序、JSON path 求值、标量比较、大整数和精确小数词素无损保留。
- 存储内核：pager、meta page、WAL redo、checkpoint、checksum、recovery、不兼容格式拒绝打开。
- Catalog 与 collection 生命周期：创建、打开、行号分配、drop 清理、重启恢复。
- 主键 B+Tree：主键点查、顺序扫描、checksum 校验、损坏检测。
- SQL 链路：lexer、parser、binder、planner、executor、结果集和 cursor API。
- v1.5 查询能力：`UPDATE`、`DELETE`、二级索引、`ORDER BY`、`EXPLAIN`。
- 稳定性能力：snapshot reader pin、commit view、cursor lease、snapshot pressure、writer guard、错误路径 rollback。
- 格式演进：版本兼容矩阵、升级前置条件、升级失败回滚。
- Typed SQL：schema、字段、collection、类型不匹配的静态校验。

## 验收命令

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

期望最后一行：

```text
definition of done verification ok
```

完整 DoD 映射见 [nosqlite-definition-of-done.md](./nosqlite-definition-of-done.md)。

## 测试布局

当前测试已按模块归档到 `nosqlite/tests`：

- `core`：基础语言/运行时能力。
- `doc`：`DocBlob`、codec、path、数字保真。
- `sql`：SQL parser、typed SQL、静态错误样例。
- `plan`：binder 与 planner。
- `exec`：执行器、async boundary、v1.5 功能、压力测试。
- `storage`：pager、WAL、catalog、B+Tree、checkpoint、recovery、格式升级。

各分类目录保留 `lib -> ../../lib` 模块根链接，确保直接编译分类测试时 `use lib...` 路径稳定。

## 性能基线

当前 benchmark 是 v0 原型基线，不是生产 SLO。数据集为 `3` 个平均 `1024` bytes 文档，请求迭代数为 `10`，持久化插入迭代数为 `3`。

| case | p50 us | p95 us | docs/s | MiB/s | peak KiB | floor | target | stretch |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| primary_lookup | 18583 | 19668 | 53.53 | 0.05 | 29388 | pass | pass | miss |
| seq_scan_filter | 18251 | 22201 | 159.69 | 0.16 | 29352 | pass | miss | miss |
| durable_insert | 18918 | 23079 | 50.03 | 0.05 | 28168 | pass | pass | miss |
| recovery_open | 96121 | 100922 | 30.97 | 0.03 | 31400 | pass | miss | miss |
| long_query_concurrent_commit | 19452 | 20217 | 51.35 | 0.05 | 29128 | pass | miss | miss |

汇总：`5/5` floor 通过，`2/5` target 通过，`0/5` stretch 通过。

详细输出见 [nosqlite-benchmark-v0.md](./nosqlite-benchmark-v0.md) 与 [nosqlite-benchmark-v0.json](./nosqlite-benchmark-v0.json)。

## 压力测试

压力门入口：

```bash
./uya/bin/uya nosqlite/tests/exec/test_stress_runtime.uya
.uyacache/a.out
```

本次压力测试结论为 `PASS`：

| 项目 | 结果 |
| --- | --- |
| run-only elapsed | `4.384787 s` |
| run-only user time | `4.308895 s` |
| run-only sys time | `0.074998 s` |
| run-only peak RSS | `82608 KiB` |

覆盖场景包括 20 行填充、checkpoint、reopen、主键点查、16 行 update/index churn，以及 8 轮 snapshot pressure cycle。

详细报告见 [nosqlite-stress-report.md](./nosqlite-stress-report.md)。

## 当前边界

- 单进程嵌入式使用。
- 单写者设计。
- 暂不包含 MVCC、聚合框架、全文检索、网络协议、GIN/HASH 索引族。
- 当前 benchmark 基线使用缩小数据集和 v0 floor 阈值，不代表生产 SLO。
- 当前 v1 原型容量仍受单页 collection 布局限制。

## 发布产物

- Git tag：`nosqlite-v1.5.0`
- 根 README：项目定位、快速开始、验收、边界和文档入口。
- 文档索引：`docs/README.md`
- DoD 验收矩阵：`docs/nosqlite-definition-of-done.md`
- 压力测试报告：`docs/nosqlite-stress-report.md`
- 示例、SQL 语法、Typed SQL、格式兼容、benchmark 输出格式文档。

## 后续建议

- 解除单页 collection 容量限制后，将压力门扩展到 `1_000+` 行和 `100_000` 文档参考集。
- 将压力测试输出升级为机器可读 JSON，并纳入持续 benchmark 趋势。
- 如果需要远端发布，推送 commit 后再推送 `nosqlite-v1.5.0` 标签。
