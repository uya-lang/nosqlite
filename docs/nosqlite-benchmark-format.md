# NoSQLite Benchmark 输出格式

日期：2026-04-23

## 目标

这个格式用于固定 Phase 11 benchmark 的环境信息和结果输出，避免后续实测结果无法横向比较。

## 环境块

每次 benchmark 运行前先输出一条 `BENCH_ENV` 记录。

推荐字段：

- `version`
- `host_os`
- `host_arch`
- `kernel`
- `cpu_model`
- `cpu_count`
- `page_size`
- `build_mode`
- `durability`
- `dataset_docs`
- `dataset_avg_doc_bytes`
- `dataset_generator`
- `benchmark_mode`
- `case_name`

推荐文本格式：

```text
BENCH_ENV version=1 host_os=linux host_arch=x86_64 kernel=6.8.0 \
cpu_model="AMD Ryzen 9 7950X" cpu_count=32 page_size=4096 \
build_mode=release durability=fdatasync dataset_docs=100000 \
dataset_avg_doc_bytes=1024 dataset_generator=nosqlite/generate_bench_dataset.py \
benchmark_mode=warm-read case_name=primary_lookup
```

## 结果块

每个 benchmark case 输出一条 `BENCH_RESULT` 记录。

推荐字段：

- `version`
- `case_name`
- `benchmark_mode`
- `iterations`
- `p50_us`
- `p95_us`
- `p99_us`
- `docs_per_s`
- `mib_per_s`
- `peak_memory_kib`
- `floor_status`
- `target_status`
- `stretch_status`
- `notes`
- `ratio_pct_p50`：仅适用于相对基线类 case
- `ratio_pct_p95`：仅适用于相对基线类 case
- `ratio_pct_p99`：仅适用于相对基线类 case

推荐文本格式：

```text
BENCH_RESULT version=1 case_name=primary_lookup benchmark_mode=warm-read \
iterations=500 p50_us=81 p95_us=140 p99_us=190 docs_per_s=12345.67 \
mib_per_s=12.06 peak_memory_kib=9120 floor_status=pass target_status=pass \
stretch_status=miss notes="v0 prototype baseline"
```

相对基线类 case 示例：

```text
BENCH_RESULT version=1 case_name=long_query_concurrent_commit benchmark_mode=durable-write \
iterations=10 p50_us=18745 p95_us=19287 p99_us=19287 docs_per_s=53.29 mib_per_s=0.05 \
peak_memory_kib=29004 floor_status=pass target_status=pass stretch_status=miss \
notes="scaled prototype dataset: docs=3 < 100000" ratio_pct_p50=100 ratio_pct_p95=105 ratio_pct_p99=105
```

## 状态字段

- `floor_status` 取值：`pass`、`miss`、`skip`
- `target_status` 取值：`pass`、`miss`、`skip`
- `stretch_status` 取值：`pass`、`miss`、`skip`

当当前原型能力不足以满足设计环境前提时，必须显式输出 `skip`，不能静默省略。

## 当前说明

- 第 18 节已经明确标注为“工程预算版”，并使用 `floor / target / stretch` 三档制。
- 当前仓库的存储原型仍然带有明显的容量上限，因此大规模 benchmark 需要在能力达标后再用同一格式补实测数据。
