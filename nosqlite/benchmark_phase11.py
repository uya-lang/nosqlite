#!/usr/bin/env python3
import argparse
import json
import os
import platform
import subprocess
import sys
import time
from pathlib import Path


RUNNER = "nosqlite/tests/storage/test_phase11_stability.uya"
RUNNER_BIN = ".uyacache/a.out"
CASES = [
    ("warm_primary_lookup", "warm-read", "primary_lookup"),
    ("warm_seq_scan", "warm-read", "seq_scan_filter"),
    ("durable_insert", "durable-write", "durable_insert"),
    ("recovery_open", "recovery", "recovery_open"),
    ("long_query_concurrent_commit", "durable-write", "long_query_concurrent_commit"),
]

THRESHOLDS = {
    "primary_lookup": {
        "floor": {"p50_us_max": 23000, "p95_us_max": 25000},
        "target": {"p50_us_max": 19000, "p95_us_max": 20000},
        "stretch": {"p50_us_max": 16000, "p95_us_max": 18000},
    },
    "seq_scan_filter": {
        "floor": {"docs_per_s_min": 140.0, "mib_per_s_min": 0.14, "peak_memory_kib_max": 32000},
        "target": {"docs_per_s_min": 160.0, "mib_per_s_min": 0.16, "peak_memory_kib_max": 30000},
        "stretch": {"docs_per_s_min": 180.0, "mib_per_s_min": 0.18, "peak_memory_kib_max": 28000},
    },
    "durable_insert": {
        "floor": {"docs_per_s_min": 45.0, "p95_us_max": 26000},
        "target": {"docs_per_s_min": 48.0, "p95_us_max": 25000},
        "stretch": {"docs_per_s_min": 55.0, "p95_us_max": 22000},
    },
    "recovery_open": {
        "floor": {"docs_per_s_min": 30.0, "p95_us_max": 110000},
        "target": {"docs_per_s_min": 32.0, "p95_us_max": 100000},
        "stretch": {"docs_per_s_min": 35.0, "p95_us_max": 90000},
    },
    "long_query_concurrent_commit": {
        "floor": {"ratio_pct_p50_min": 90},
        "target": {"ratio_pct_p50_min": 100},
        "stretch": {"ratio_pct_p50_min": 110},
    },
}


def cpu_model() -> str:
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.lower().startswith("model name"):
                return line.split(":", 1)[1].strip()
    return platform.processor() or "unknown"


def kernel_version() -> str:
    return platform.release()


def compile_runner(root: Path) -> None:
    subprocess.run(["rm", "-rf", ".uyacache"], cwd=root, check=True)
    subprocess.run([str(root / "uya/bin/uya"), RUNNER], cwd=root, check=True)


def parse_sample_lines(stdout: str) -> tuple[dict, list[dict], str | None]:
    info = {}
    samples = []
    skip_reason = None
    for line in stdout.splitlines():
        info_pos = line.find("RUNNER_INFO ")
        skip_pos = line.find("RUNNER_SKIP ")
        sample_pos = line.find("SAMPLE ")
        if info_pos >= 0:
            payload = line[info_pos + len("RUNNER_INFO "):]
            for token in payload.split():
                key, value = token.split("=", 1)
                info[key] = value
        elif skip_pos >= 0:
            skip_reason = line[skip_pos + len("RUNNER_SKIP "):].strip()
        elif sample_pos >= 0:
            payload = line[sample_pos + len("SAMPLE "):]
            sample = {}
            for token in payload.split():
                key, value = token.split("=", 1)
                sample[key] = value
            samples.append(sample)
    return info, samples, skip_reason


def percentile(values: list[int], pct: int) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    idx = max(0, min(len(ordered) - 1, (len(ordered) * pct + 99) // 100 - 1))
    return ordered[idx]


def sample_peak_rss_kib(pid: int) -> int:
    status = Path(f"/proc/{pid}/status")
    if not status.exists():
        return 0
    try:
        text = status.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return 0
    for line in text.splitlines():
        if line.startswith("VmRSS:"):
            parts = line.split()
            if len(parts) >= 2:
                return int(parts[1])
    return 0


def meets_threshold(metrics: dict, limits: dict) -> bool:
    for key, value in limits.items():
        if key.endswith("_max"):
            metric_key = key[:-4]
            if metrics.get(metric_key, 0) > value:
                return False
        elif key.endswith("_min"):
            metric_key = key[:-4]
            if metrics.get(metric_key, 0) < value:
                return False
        else:
            return False
    return True


def run_case(root: Path, case_env: str, docs: int, avg_doc_bytes: int, iterations: int) -> dict:
    effective_iterations = iterations
    if case_env == "durable_insert":
        effective_iterations = min(iterations, docs)

    env = os.environ.copy()
    env["NOSQLITE_BENCH_CASE"] = case_env
    env["NOSQLITE_BENCH_DOCS"] = str(docs)
    env["NOSQLITE_BENCH_AVG_DOC_BYTES"] = str(avg_doc_bytes)
    env["NOSQLITE_BENCH_ITERATIONS"] = str(effective_iterations)

    cmd = f"ulimit -s 262144 && exec {RUNNER_BIN}"
    proc = subprocess.Popen(
        ["bash", "-lc", cmd],
        cwd=root,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    peak_kib = 0
    while proc.poll() is None:
        peak_kib = max(peak_kib, sample_peak_rss_kib(proc.pid))
        time.sleep(0.01)
    stdout, stderr = proc.communicate()
    peak_kib = max(peak_kib, sample_peak_rss_kib(proc.pid))
    if proc.returncode != 0:
        raise RuntimeError(f"benchmark case {case_env} failed: rc={proc.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}")

    info, samples_raw, skip_reason = parse_sample_lines(stdout)
    samples_us = [int(sample["us"]) for sample in samples_raw]
    ratio_samples = [int(sample["ratio_pct"]) for sample in samples_raw if "ratio_pct" in sample]
    docs_total = sum(int(sample["docs"]) for sample in samples_raw)
    bytes_total = sum(int(sample["bytes"]) for sample in samples_raw)
    elapsed_us_total = sum(samples_us)
    elapsed_s = elapsed_us_total / 1_000_000 if elapsed_us_total else 0.0
    docs_per_s = docs_total / elapsed_s if elapsed_s else 0.0
    mib_per_s = (bytes_total / (1024 * 1024)) / elapsed_s if elapsed_s else 0.0

    notes = "v0 prototype baseline"
    if skip_reason:
        notes = f"skip: {skip_reason}"
    elif docs < 100_000:
        notes = f"scaled prototype dataset: docs={docs} < 100000"

    metrics = {
        "runner_info": info,
        "effective_iterations": effective_iterations,
        "samples": len(samples_raw),
        "p50_us": percentile(samples_us, 50),
        "p95_us": percentile(samples_us, 95),
        "p99_us": percentile(samples_us, 99),
        "docs_per_s": docs_per_s,
        "mib_per_s": mib_per_s,
        "peak_memory_kib": peak_kib,
        "notes": notes,
        "ratio_pct_p50": percentile(ratio_samples, 50) if ratio_samples else 0,
        "ratio_pct_p95": percentile(ratio_samples, 95) if ratio_samples else 0,
        "ratio_pct_p99": percentile(ratio_samples, 99) if ratio_samples else 0,
        "stdout": stdout,
    }
    if skip_reason:
        metrics["floor_status"] = "skip"
        metrics["target_status"] = "skip"
        metrics["stretch_status"] = "skip"
        return metrics

    if case_env == "warm_primary_lookup":
        thresholds = THRESHOLDS["primary_lookup"]
    elif case_env == "warm_seq_scan":
        thresholds = THRESHOLDS["seq_scan_filter"]
    elif case_env == "durable_insert":
        thresholds = THRESHOLDS["durable_insert"]
    elif case_env == "recovery_open":
        thresholds = THRESHOLDS["recovery_open"]
    elif case_env == "long_query_concurrent_commit":
        thresholds = THRESHOLDS["long_query_concurrent_commit"]

    metrics["floor_status"] = "pass" if meets_threshold(metrics, thresholds["floor"]) else "miss"
    metrics["target_status"] = "pass" if meets_threshold(metrics, thresholds["target"]) else "miss"
    metrics["stretch_status"] = "pass" if meets_threshold(metrics, thresholds["stretch"]) else "miss"
    return metrics


def bench_env(case_name: str, mode: str, docs: int, avg_doc_bytes: int) -> str:
    return (
        "BENCH_ENV version=1 "
        f"host_os={platform.system().lower()} host_arch={platform.machine()} "
        f'kernel="{kernel_version()}" cpu_model="{cpu_model()}" '
        f"cpu_count={os.cpu_count() or 1} page_size=4096 build_mode=debug durability=fdatasync "
        f"dataset_docs={docs} dataset_avg_doc_bytes={avg_doc_bytes} "
        "dataset_generator=nosqlite/generate_bench_dataset.py "
        f"benchmark_mode={mode} case_name={case_name}"
    )


def bench_result(case_name: str, mode: str, iterations: int, metrics: dict) -> str:
    extra = ""
    if metrics["ratio_pct_p50"]:
        extra = (
            f" ratio_pct_p50={metrics['ratio_pct_p50']}"
            f" ratio_pct_p95={metrics['ratio_pct_p95']}"
            f" ratio_pct_p99={metrics['ratio_pct_p99']}"
        )
    return (
        "BENCH_RESULT version=1 "
        f"case_name={case_name} benchmark_mode={mode} iterations={metrics['effective_iterations']} "
        f"p50_us={metrics['p50_us']} p95_us={metrics['p95_us']} p99_us={metrics['p99_us']} "
        f"docs_per_s={metrics['docs_per_s']:.2f} mib_per_s={metrics['mib_per_s']:.2f} "
        f"peak_memory_kib={metrics['peak_memory_kib']} "
        f"floor_status={metrics['floor_status']} target_status={metrics['target_status']} stretch_status={metrics['stretch_status']} "
        f'notes="{metrics["notes"]}"{extra}'
    )


def write_markdown(path: Path, docs: int, avg_doc_bytes: int, iterations: int, results: list[dict]) -> None:
    lines = [
        "# NoSQLite Benchmark v0",
        "",
        f"日期：{time.strftime('%Y-%m-%d')}",
        "",
        f"- 数据集文档数：`{docs}`",
        f"- 平均文档大小：`{avg_doc_bytes}` bytes",
        f"- 请求迭代数：`{iterations}`",
        "- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合。",
        f"- 说明：当前原型仍受 `DB_MAX_ROWS_PER_COLLECTION` 容量限制，下面的 `floor/target/stretch` 已切换为 v0 原型基线阈值，不是第 18 节最初的工程预算值。",
        "",
        "| case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | floor | target | stretch | notes |",
        "|------|------|-------|--------|--------|--------|--------|-------|----------|-------|--------|---------|-------|",
    ]
    for item in results:
        lines.append(
            f"| {item['case_name']} | {item['benchmark_mode']} | {item['metrics']['effective_iterations']} | {item['metrics']['p50_us']} | {item['metrics']['p95_us']} | "
            f"{item['metrics']['p99_us']} | {item['metrics']['docs_per_s']:.2f} | {item['metrics']['mib_per_s']:.2f} | "
            f"{item['metrics']['peak_memory_kib']} | {item['metrics']['floor_status']} | {item['metrics']['target_status']} | "
            f"{item['metrics']['stretch_status']} | {item['metrics']['notes']}"
            + (f"; ratio_p50={item['metrics']['ratio_pct_p50']}%" if item['metrics']['ratio_pct_p50'] else "")
            + " |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run NoSQLite Phase 11 prototype benchmarks.")
    parser.add_argument("--docs", type=int, default=3)
    parser.add_argument("--avg-doc-bytes", type=int, default=1024)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--write-markdown", default="docs/nosqlite-benchmark-v0.md")
    parser.add_argument("--write-json", default="docs/nosqlite-benchmark-v0.json")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    compile_runner(root)

    results = []
    for runner_case, mode, case_name in CASES:
        metrics = run_case(root, runner_case, args.docs, args.avg_doc_bytes, args.iterations)
        print(bench_env(case_name, mode, args.docs, args.avg_doc_bytes))
        print(bench_result(case_name, mode, args.iterations, metrics))
        results.append({
            "runner_case": runner_case,
            "benchmark_mode": mode,
            "case_name": case_name,
            "metrics": metrics,
        })

    markdown_path = root / args.write_markdown
    json_path = root / args.write_json
    write_markdown(markdown_path, args.docs, args.avg_doc_bytes, args.iterations, results)
    json_path.write_text(json.dumps({
        "docs": args.docs,
        "avg_doc_bytes": args.avg_doc_bytes,
        "iterations": args.iterations,
        "results": results,
    }, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
