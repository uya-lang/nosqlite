#!/usr/bin/env python3
import argparse
import json
import os
import platform
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import benchmark_phase11 as bench_common


RUNNER = "nosqlite/tests/exec/test_million_benchmark_runtime.uya"
RUNNER_BIN = ".uyacache/a.out"
RUNNER_CFLAGS = os.environ.get("NOSQLITE_MILLION_RUNNER_CFLAGS", "-std=c99 -O3 -g -fno-builtin")


def cpu_model() -> str:
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.lower().startswith("model name"):
                return line.split(":", 1)[1].strip()
    return platform.processor() or "unknown"


def kernel_version() -> str:
    return platform.release()


def percentile(values: list[int], pct: int) -> int:
    return bench_common.percentile(values, pct)


def elapsed_us(start_ns: int) -> int:
    return max(1, (time.perf_counter_ns() - start_ns) // 1000)


def aggregate_query_samples(samples_ns: list[int]) -> dict:
    total_ns = sum(samples_ns)
    total_s = total_ns / 1_000_000_000 if total_ns else 0.0
    qps = len(samples_ns) / total_s if total_s else 0.0
    return {
        "samples": len(samples_ns),
        "p50_ns": percentile(samples_ns, 50),
        "p95_ns": percentile(samples_ns, 95),
        "p99_ns": percentile(samples_ns, 99),
        "p50_us": percentile(samples_ns, 50) / 1000.0,
        "p95_us": percentile(samples_ns, 95) / 1000.0,
        "p99_us": percentile(samples_ns, 99) / 1000.0,
        "qps": qps,
    }


def format_us(value: float) -> str:
    text = f"{value:.2f}"
    return text.rstrip("0").rstrip(".")


def sqlite_json1_available() -> bool:
    conn = sqlite3.connect(":memory:")
    try:
        row = conn.execute("select json_extract('{\"a\":2}', '$.a')").fetchone()
        return row is not None and row[0] == 2
    except sqlite3.DatabaseError:
        return False
    finally:
        conn.close()


def compile_runner(root: Path) -> None:
    subprocess.run(["rm", "-rf", ".uyacache"], cwd=root, check=True)
    subprocess.run([str(root / "uya/bin/uya"), RUNNER], cwd=root, check=True)
    subprocess.run(
        [
            "make",
            "-C",
            ".uyacache",
            "-B",
            "UYA_OUT=a.out",
            "CC=cc",
            f"CFLAGS={RUNNER_CFLAGS}",
        ],
        cwd=root,
        check=True,
    )


def cleanup_sqlite_path(path: Path) -> None:
    for candidate in [path, Path(str(path) + "-wal"), Path(str(path) + "-shm")]:
        try:
            candidate.unlink()
        except FileNotFoundError:
            pass


def sqlite_connect(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(path), isolation_level=None)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=FULL")
    conn.execute("PRAGMA temp_store=MEMORY")
    conn.execute("PRAGMA wal_autocheckpoint=1000")
    return conn


def sqlite_create_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        "CREATE TABLE users ("
        "id INTEGER PRIMARY KEY, "
        "doc TEXT NOT NULL CHECK(json_valid(doc))"
        ")"
    )


def build_json_doc(doc_id: int) -> str:
    bucket = doc_id % 100
    active = "true" if doc_id % 2 == 0 else "false"
    return f'{{"n":{doc_id},"bucket":{bucket},"active":{active}}}'


def run_sqlite_case_inline(docs: int, batch_rows: int, query_iters: int) -> dict:
    path = Path(tempfile.gettempdir()) / f"nosqlite_sqlite_compare_million_{os.getpid()}.db"
    cleanup_sqlite_path(path)
    conn = sqlite_connect(path)
    try:
        sqlite_create_schema(conn)
        start_ns = time.perf_counter_ns()
        inserted = 0
        while inserted < docs:
            current_batch = min(batch_rows, docs - inserted)
            conn.execute("BEGIN")
            try:
                for doc_id in range(inserted + 1, inserted + current_batch + 1):
                    conn.execute(
                        "INSERT INTO users(id, doc) VALUES (?, ?)",
                        (doc_id, build_json_doc(doc_id)),
                    )
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
            inserted += current_batch
        load_us = elapsed_us(start_ns)

        warm_rows = conn.execute("SELECT id FROM users LIMIT 64").fetchall()
        if not warm_rows:
            raise RuntimeError("sqlite limit query warmup returned no rows")

        query_samples_ns: list[int] = []
        for _ in range(query_iters):
            start_ns = time.perf_counter_ns()
            rows = conn.execute("SELECT id FROM users LIMIT 64").fetchall()
            ns = max(1, time.perf_counter_ns() - start_ns)
            if not rows:
                raise RuntimeError("sqlite limit query returned no rows")
            query_samples_ns.append(ns)

        return {
            "engine": "sqlite",
            "docs": docs,
            "batch_rows": batch_rows,
            "load": {
                "rows": docs,
                "load_us": load_us,
                "rows_per_s": docs / (load_us / 1_000_000),
            },
            "limit_query": aggregate_query_samples(query_samples_ns),
            "notes": "SQLite JSON1; journal_mode=WAL; synchronous=FULL; warm SELECT id FROM users LIMIT 64; full fetch timed",
        }
    finally:
        conn.close()
        cleanup_sqlite_path(path)


def run_sqlite_child(docs: int, batch_rows: int, query_iters: int) -> int:
    result = run_sqlite_case_inline(docs, batch_rows, query_iters)
    print(json.dumps(result, separators=(",", ":")))
    return 0


def parse_nosqlite_output(stdout: str, docs: int) -> dict:
    load_us = 0
    query_samples_ns: list[int] = []
    info = {}
    for line in stdout.splitlines():
        if line.startswith("BENCH_INFO "):
            for token in line[len("BENCH_INFO "):].split():
                key, value = token.split("=", 1)
                info[key] = int(value)
        elif line.startswith("RESULT "):
            payload = {}
            for token in line[len("RESULT "):].split():
                key, value = token.split("=", 1)
                payload[key] = value
            if payload.get("case") == "bulk_load":
                load_us = int(payload["us"])
        elif line.startswith("SAMPLE "):
            payload = {}
            for token in line[len("SAMPLE "):].split():
                key, value = token.split("=", 1)
                payload[key] = value
            if payload.get("case") == "limit_query":
                if "ns" in payload:
                    query_samples_ns.append(int(payload["ns"]))
                elif "us" in payload:
                    query_samples_ns.append(int(payload["us"]) * 1000)
        elif line.startswith("BENCH_ERROR "):
            raise RuntimeError(line)

    if load_us <= 0 or not query_samples_ns:
        raise RuntimeError(f"nosqlite million benchmark output incomplete:\n{stdout}")

    return {
        "engine": "nosqlite",
        "docs": docs,
        "batch_rows": int(info.get("batch_rows", 0)),
        "load": {
            "rows": docs,
            "load_us": load_us,
            "rows_per_s": docs / (load_us / 1_000_000),
        },
        "limit_query": aggregate_query_samples(query_samples_ns),
        "notes": "NoSQLite million-row benchmark; staged txn batches; warm SELECT _id FROM users LIMIT 64; full fetch timed",
    }


def run_nosqlite_case(root: Path, docs: int, batch_rows: int, query_iters: int) -> dict:
    compile_runner(root)
    env = os.environ.copy()
    env["NOSQLITE_MILLION_BENCH_DOCS"] = str(docs)
    env["NOSQLITE_MILLION_BENCH_BATCH_ROWS"] = str(batch_rows)
    env["NOSQLITE_MILLION_BENCH_QUERY_ITERS"] = str(query_iters)

    proc = subprocess.Popen(
        ["bash", "-lc", f"ulimit -s 262144 && exec {RUNNER_BIN}"],
        cwd=root,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    peak_kib = 0
    while proc.poll() is None:
        peak_kib = max(peak_kib, bench_common.sample_peak_rss_kib(proc.pid))
        time.sleep(0.05)
    stdout, stderr = proc.communicate()
    peak_kib = max(peak_kib, bench_common.sample_peak_rss_kib(proc.pid))
    if proc.returncode != 0:
        raise RuntimeError(
            f"nosqlite million benchmark failed: rc={proc.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}"
        )
    result = parse_nosqlite_output(stdout, docs)
    result["peak_memory_kib"] = peak_kib
    return result


def run_sqlite_case(root: Path, docs: int, batch_rows: int, query_iters: int) -> dict:
    cmd = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--sqlite-child",
        "--docs",
        str(docs),
        "--batch-rows",
        str(batch_rows),
        "--query-iters",
        str(query_iters),
    ]
    proc = subprocess.Popen(
        cmd,
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    peak_kib = 0
    while proc.poll() is None:
        peak_kib = max(peak_kib, bench_common.sample_peak_rss_kib(proc.pid))
        time.sleep(0.05)
    stdout, stderr = proc.communicate()
    peak_kib = max(peak_kib, bench_common.sample_peak_rss_kib(proc.pid))
    if proc.returncode != 0:
        raise RuntimeError(f"sqlite million benchmark failed: rc={proc.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}")
    result = json.loads(stdout.strip().splitlines()[-1])
    result["peak_memory_kib"] = peak_kib
    return result


def ratio_text(ns_value: float, sq_value: float, lower_is_better: bool) -> str:
    if ns_value <= 0 or sq_value <= 0:
        return "n/a"
    if lower_is_better:
        if ns_value < sq_value:
            return f"NoSQLite faster x{sq_value / ns_value:.2f}"
        return f"SQLite faster x{ns_value / sq_value:.2f}"
    if ns_value > sq_value:
        return f"NoSQLite faster x{ns_value / sq_value:.2f}"
    return f"SQLite faster x{sq_value / ns_value:.2f}"


def write_markdown(path: Path, docs: int, batch_rows: int, query_iters: int, ns: dict, sq: dict) -> None:
    lines = [
        "# NoSQLite vs SQLite 百万条性能对比",
        "",
        f"日期：{time.strftime('%Y-%m-%d')}",
        "",
        "本报告聚焦百万条记录量级下的装载与查询性能对比。",
        "",
        "## 运行口径",
        "",
        f"- 数据集记录数：`{docs}`",
        f"- 每批提交记录数：`{batch_rows}`",
        f"- query 迭代数：`{query_iters}`",
        f"- Python：`{platform.python_version()}`",
        f"- SQLite：`{sqlite3.sqlite_version}`",
        f"- SQLite JSON1：`{'available' if sqlite_json1_available() else 'missing'}`",
        f"- CPU：`{cpu_model()}`",
        f"- Kernel：`{kernel_version()}`",
        "- 数据文档：`{\"n\": <id>, \"bucket\": <id % 100>, \"active\": <bool>}`",
        "- 查询口径：`SELECT _id FROM users LIMIT 64` / `SELECT id FROM users LIMIT 64`",
        "- limit_query 计时范围：从开始执行查询到完整取回 64 行结果，两侧统一口径。",
        "- NoSQLite 这里先比较“批量写入后同进程 warm query”，不包含 recovery/open 延迟。",
        "",
        "## 摘要",
        "",
        "| case | NoSQLite | SQLite | 对比 |",
        "| --- | ---: | ---: | --- |",
        f"| bulk_load rows/s | {ns['load']['rows_per_s']:.2f} | {sq['load']['rows_per_s']:.2f} | {ratio_text(ns['load']['rows_per_s'], sq['load']['rows_per_s'], False)} |",
        f"| limit_query p50 us | {format_us(ns['limit_query']['p50_us'])} | {format_us(sq['limit_query']['p50_us'])} | {ratio_text(ns['limit_query']['p50_ns'], sq['limit_query']['p50_ns'], True)} |",
        f"| limit_query p95 us | {format_us(ns['limit_query']['p95_us'])} | {format_us(sq['limit_query']['p95_us'])} | {ratio_text(ns['limit_query']['p95_ns'], sq['limit_query']['p95_ns'], True)} |",
        "",
        "## 原始指标",
        "",
        "| engine | load s | load rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        f"| nosqlite | {ns['load']['load_us'] / 1_000_000:.2f} | {ns['load']['rows_per_s']:.2f} | {format_us(ns['limit_query']['p50_us'])} | {format_us(ns['limit_query']['p95_us'])} | {ns['limit_query']['qps']:.2f} | {ns['peak_memory_kib']} | {ns['notes']} |",
        f"| sqlite | {sq['load']['load_us'] / 1_000_000:.2f} | {sq['load']['rows_per_s']:.2f} | {format_us(sq['limit_query']['p50_us'])} | {format_us(sq['limit_query']['p95_us'])} | {sq['limit_query']['qps']:.2f} | {sq['peak_memory_kib']} | {sq['notes']} |",
        "",
        "## 复现命令",
        "",
        "```bash",
        "python3 nosqlite/benchmark_sqlite_compare_million.py",
        "```",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare NoSQLite and SQLite at one million rows.")
    parser.add_argument("--docs", type=int, default=1_000_000)
    parser.add_argument("--batch-rows", type=int, default=48_000)
    parser.add_argument("--query-iters", type=int, default=100)
    parser.add_argument("--write-markdown", default="docs/nosqlite-sqlite-million-compare.md")
    parser.add_argument("--write-json", default="docs/nosqlite-sqlite-million-compare.json")
    parser.add_argument("--sqlite-child", action="store_true")
    args = parser.parse_args()

    if not sqlite_json1_available():
        raise SystemExit("SQLite JSON1 is required for this comparison benchmark")
    if args.docs <= 0 or args.batch_rows <= 0 or args.query_iters <= 0:
        raise SystemExit("all numeric arguments must be positive")

    if args.sqlite_child:
        return run_sqlite_child(args.docs, args.batch_rows, args.query_iters)

    root = Path(__file__).resolve().parent.parent
    nosqlite_result = run_nosqlite_case(root, args.docs, args.batch_rows, args.query_iters)
    sqlite_result = run_sqlite_case(root, args.docs, args.batch_rows, args.query_iters)

    markdown_path = root / args.write_markdown
    json_path = root / args.write_json
    write_markdown(markdown_path, args.docs, args.batch_rows, args.query_iters, nosqlite_result, sqlite_result)
    json_path.write_text(
        json.dumps(
            {
                "docs": args.docs,
                "batch_rows": args.batch_rows,
                "query_iters": args.query_iters,
                "python_version": platform.python_version(),
                "sqlite_version": sqlite3.sqlite_version,
                "sqlite_json1": sqlite_json1_available(),
                "nosqlite": nosqlite_result,
                "sqlite": sqlite_result,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(
        f"MILLION_COMPARE_RESULT load_rows_per_s_nosqlite={nosqlite_result['load']['rows_per_s']:.2f} "
        f"load_rows_per_s_sqlite={sqlite_result['load']['rows_per_s']:.2f}"
    )
    print(f"MILLION_COMPARE_REPORT markdown={args.write_markdown} json={args.write_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
