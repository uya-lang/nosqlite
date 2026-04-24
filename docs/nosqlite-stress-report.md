# NoSQLite 压力测试报告

日期：2026-04-24

本报告由 `nosqlite/stress_runtime_report.py` 生成；机器可读结果见同名 JSON 报告。

| 项目 | 结果 |
| --- | --- |
| 测试入口 | `nosqlite/tests/exec/test_stress_runtime.uya` |
| JSON 报告 | `docs/nosqlite-stress-report.json` |
| 运行次数 | `1` |
| 总体结论 | PASS |
| 最新退出码 | `0` |
| 最新失败阶段码 | `0` |
| 最新 run-only elapsed | `0.197893 s` |
| 最新 run-only peak RSS | `31860 KiB` |

## 覆盖场景

| 场景 | 压力内容 |
| --- | --- |
| 填充 + checkpoint + reopen | 插入 `128` 行，周期性 `db_check`，创建索引，checkpoint，reopen 后点查 |
| UPDATE / index churn | `64` 行上执行 `12` 轮 `UPDATE + indexed lookup`，每 4 轮 checkpoint |
| snapshot pressure cycle | `8` 轮长读者 pin、写入、pressure 阻塞、cursor 释放清理 |
| 随机 SQL 序列 | `96` 轮确定性伪随机 `INSERT / UPDATE / DELETE / SELECT / CHECKPOINT / REOPEN` 混合 |

## 机器可读字段

- `run_only_elapsed_s`
- `run_only_peak_rss_kib`
- `failure_stage_code`
- soak 模式每轮结果与最大 RSS / elapsed

## 规模目标

- 多页 collection 布局已启用，当前运行时行容量上限为 `3072`。
- 当前正式压力门已覆盖 `128` 行；下一阶段可继续把 gate 扩到 `1_000+` 行并接入 `100_000` 文档参考集。
