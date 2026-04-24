#!/usr/bin/env python3
import argparse
import json
import os
import platform
import subprocess
import time
from pathlib import Path


RUNNER = "nosqlite/tests/exec/test_stress_runtime.uya"
RUNNER_BIN = ".uyacache/a.out"
RUNNER_CFLAGS = "-std=c99 -O2 -g -fno-builtin"


def sample_rss_kib(pid: int) -> int:
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


def compile_runner(root: Path) -> None:
    subprocess.run(["rm", "-rf", ".uyacache"], cwd=root, check=True)
    subprocess.run([str(root / "uya/bin/uya"), RUNNER], cwd=root, check=True)
    subprocess.run(
        ["make", "-C", ".uyacache", "-B", "UYA_OUT=a.out", "CC=cc", f"CFLAGS={RUNNER_CFLAGS}"],
        cwd=root,
        check=True,
    )


def run_once(root: Path, iteration: int) -> dict:
    started = time.perf_counter()
    proc = subprocess.Popen(
        ["bash", "-lc", f"ulimit -s 262144 && exec {RUNNER_BIN}"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    peak_rss_kib = 0
    while proc.poll() is None:
        peak_rss_kib = max(peak_rss_kib, sample_rss_kib(proc.pid))
        time.sleep(0.01)
    stdout, stderr = proc.communicate()
    elapsed_s = time.perf_counter() - started
    rc = proc.returncode
    return {
        "iteration": iteration,
        "status": "pass" if rc == 0 else "fail",
        "exit_code": rc,
        "failure_stage_code": 0 if rc == 0 else rc,
        "run_only_elapsed_s": elapsed_s,
        "run_only_peak_rss_kib": peak_rss_kib,
        "stdout_bytes": len(stdout.encode()),
        "stderr_bytes": len(stderr.encode()),
        "stdout_tail": stdout[-4096:],
        "stderr_tail": stderr[-4096:],
    }


def write_markdown(path: Path, report: dict) -> None:
    latest = report["runs"][-1] if report["runs"] else {}
    lines = [
        "# NoSQLite 压力测试报告",
        "",
        f"日期：{time.strftime('%Y-%m-%d')}",
        "",
        "本报告由 `nosqlite/stress_runtime_report.py` 生成；机器可读结果见同名 JSON 报告。",
        "",
        "| 项目 | 结果 |",
        "| --- | --- |",
        f"| 测试入口 | `{RUNNER}` |",
        f"| JSON 报告 | `docs/nosqlite-stress-report.json` |",
        f"| 运行次数 | `{report['iterations']}` |",
        f"| 总体结论 | {report['status'].upper()} |",
        f"| 最新退出码 | `{latest.get('exit_code', 0)}` |",
        f"| 最新失败阶段码 | `{latest.get('failure_stage_code', 0)}` |",
        f"| 最新 run-only elapsed | `{latest.get('run_only_elapsed_s', 0):.6f} s` |",
        f"| 最新 run-only peak RSS | `{latest.get('run_only_peak_rss_kib', 0)} KiB` |",
        "",
        "## 覆盖场景",
        "",
        "| 场景 | 压力内容 |",
        "| --- | --- |",
        "| 填充 + checkpoint + reopen | 插入 `128` 行，周期性 `db_check`，创建索引，checkpoint，reopen 后点查 |",
        "| UPDATE / index churn | `64` 行上执行 `12` 轮 `UPDATE + indexed lookup`，每 4 轮 checkpoint |",
        "| snapshot pressure cycle | `8` 轮长读者 pin、写入、pressure 阻塞、cursor 释放清理 |",
        "| 随机 SQL 序列 | `96` 轮确定性伪随机 `INSERT / UPDATE / DELETE / SELECT / CHECKPOINT / REOPEN` 混合 |",
        "",
        "## 机器可读字段",
        "",
        "- `run_only_elapsed_s`",
        "- `run_only_peak_rss_kib`",
        "- `failure_stage_code`",
        "- soak 模式每轮结果与最大 RSS / elapsed",
        "",
        "## 规模目标",
        "",
        "- 多页 collection 布局已启用，当前运行时行容量上限为 `3072`。",
        "- 当前正式压力门已覆盖 `128` 行；下一阶段可继续把 gate 扩到 `1_000+` 行并接入 `100_000` 文档参考集。",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run NoSQLite stress gate and write machine-readable metrics.")
    parser.add_argument("--iterations", type=int, default=1, help="run-only iterations; use >1 for soak")
    parser.add_argument("--soak-seconds", type=float, default=0.0, help="repeat until this many run-only seconds elapse")
    parser.add_argument("--write-json", default="docs/nosqlite-stress-report.json")
    parser.add_argument("--write-markdown", default="docs/nosqlite-stress-report.md")
    parser.add_argument("--no-markdown", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    compile_runner(root)

    runs = []
    soak_started = time.perf_counter()
    iteration = 1
    while True:
        run = run_once(root, iteration)
        runs.append(run)
        if run["status"] != "pass":
            break
        iteration += 1
        if args.soak_seconds > 0.0:
            if time.perf_counter() - soak_started >= args.soak_seconds:
                break
        elif iteration > args.iterations:
            break

    status = "pass" if all(run["status"] == "pass" for run in runs) else "fail"
    report = {
        "version": 1,
        "runner": RUNNER,
        "host": {
            "os": platform.system().lower(),
            "arch": platform.machine(),
            "cpu_count": os.cpu_count() or 1,
        },
        "mode": "soak" if args.soak_seconds > 0.0 or args.iterations > 1 else "single",
        "iterations": len(runs),
        "requested_iterations": args.iterations,
        "requested_soak_seconds": args.soak_seconds,
        "status": status,
        "max_run_only_elapsed_s": max((run["run_only_elapsed_s"] for run in runs), default=0.0),
        "max_run_only_peak_rss_kib": max((run["run_only_peak_rss_kib"] for run in runs), default=0),
        "failure_stage_code": next((run["failure_stage_code"] for run in runs if run["status"] != "pass"), 0),
        "scale_targets": {
            "multi_page_collection_enabled": True,
            "current_fill_rows": 128,
            "current_random_rows": 24,
            "row_capacity_max": 3072,
            "next_fill_rows_min": 1000,
            "reference_dataset_docs": 100000,
            "reference_dataset_generator": "nosqlite/generate_bench_dataset.py",
        },
        "runs": runs,
    }

    json_path = root / args.write_json
    json_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    if not args.no_markdown:
        write_markdown(root / args.write_markdown, report)
    print(f"STRESS_REPORT status={status} json={args.write_json} iterations={len(runs)}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
