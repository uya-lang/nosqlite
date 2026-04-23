# NoSQLite 压力测试报告

日期：2026-04-23

本报告记录 `nosqlite/test_stress_runtime.uya` 当前压力门的覆盖范围、执行结果和边界说明。它是封板验收的稳定性压力门，不是吞吐 benchmark；吞吐指标仍以 `docs/nosqlite-benchmark-v0.*` 为准。

## 运行命令

```bash
./uya/bin/uya nosqlite/test_stress_runtime.uya
.uyacache/a.out
```

完整 DoD 验收也会运行该压力门：

```bash
bash nosqlite/tests/verify_definition_of_done.sh
```

## 本次结果

| 项目 | 结果 |
| --- | --- |
| 测试入口 | `nosqlite/test_stress_runtime.uya` |
| 退出码 | `0` |
| run-only elapsed | `4.384787 s` |
| run-only user time | `4.308895 s` |
| run-only sys time | `0.074998 s` |
| run-only peak RSS | `82608 KiB` |
| stdout / stderr | `0 / 0 bytes` |
| 总体结论 | PASS |

注：上表只统计已编译二进制 `.uyacache/a.out` 的运行阶段，不包含 Uya 编译和 C 链接耗时。

## 覆盖场景

| 场景 | 压力内容 | 通过条件 |
| --- | --- | --- |
| 填充 + checkpoint + reopen | 插入 `20` 行，周期性 `db_check`，创建二级索引，主键点查，checkpoint，重新打开后再查 | 插入 doc id 连续；中途和 checkpoint 后 `row_count` 正确；reopen 后数据和主键点查仍正确 |
| UPDATE / index churn | 插入 `16` 行，创建 `$.age` 二级索引，执行 `12` 轮 `UPDATE + indexed lookup`，每 4 轮 checkpoint | 每轮按新 age 精确查到 1 行；checkpoint 后 `row_count` 不变 |
| snapshot pressure cycle | 初始插入 2 行，执行 `8` 轮“长读者 pin + 写入 + pressure 阻塞 + cursor 释放清理” | pin 期间 retired view/bytes 达到压力状态；额外写入被拒绝；cursor 退出后 pressure 归零；最终可查询到 10 行 |

## 规模解释

当前压力门刻意选用 `20` / `16` 行，而不是把 `DB_MAX_ROWS_PER_COLLECTION = 64` 直接打满，原因是当前 v1 原型仍是单页 collection 布局，实际可容纳行数取决于 encoded DocBlob 大小和 slotted page 剩余空间。

本压力门使用的 JSON 文档包含：

- `name`
- `age`
- `score`
- `active`

它比 benchmark 中的极小样本更接近真实行宽，因此 `20` 行已经能触达当前页布局的实际压力边界，同时保持测试稳定。

## 与 benchmark 的区别

- 压力测试关注“反复操作后状态是否仍正确”。
- benchmark 关注 `p50/p95/p99`、`docs/s`、`MiB/s`、`peak_memory` 等性能指标。
- 压力测试当前不输出逐操作耗时，也不作为第 18 节性能门槛来源。

## 当前边界

- 该压力门仍受单页 collection 布局限制。
- 尚未覆盖 `100_000` 文档参考数据集。
- 尚未做随机化 fuzz 或长时间 soak。
- 尚未并行化真实多线程读写；当前验证的是单进程内的长读者 pin 与提交交错。

## 后续升级方向

- 解除单页 collection 限制后，把压力门扩展到 `1_000+` 行和 `100_000` 文档参考集。
- 增加随机 SQL 序列：`INSERT / UPDATE / DELETE / SELECT / CHECKPOINT / REOPEN` 混合。
- 增加长时间 soak 模式，并输出独立 JSON 报告。
- 将压力测试的 run-only RSS、elapsed、失败阶段码纳入机器可读报告。
