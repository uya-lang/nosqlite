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

import benchmark_phase11 as nosqlite_bench


SQLITE_CASES = [
    ("warm_primary_lookup", "warm-read", "primary_lookup"),
    ("warm_seq_scan", "warm-read", "seq_scan_filter"),
    ("durable_insert", "durable-write", "durable_insert"),
    ("dirty_wal_recovery_open", "recovery", "dirty_wal_recovery_open"),
    ("long_query_concurrent_commit", "durable-write", "long_query_concurrent_commit"),
]


def sqlite_json1_available() -> bool:
    conn = sqlite3.connect(":memory:")
    try:
        row = conn.execute("select json_extract('{\"a\":2}', '$.a')").fetchone()
        return row is not None and row[0] == 2
    except sqlite3.DatabaseError:
        return False
    finally:
        conn.close()


def build_json_doc(doc_id: int, target_bytes: int) -> str:
    age = 12 + ((doc_id * 11) % 15)
    prefix = (
        f'{{"name":"user-{doc_id}","age":{age},"active":true,'
        f'"address":{{"city":"bench-city"}},"tags":["warm","bench"],"bio":"'
    )
    suffix = '"}'
    payload_target = max(target_bytes, len(prefix) + len(suffix))
    pad_len = payload_target - len(prefix) - len(suffix)
    bio = "".join(chr(97 + ((doc_id + i) % 26)) for i in range(pad_len))
    return prefix + bio + suffix


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


def sqlite_insert_doc(conn: sqlite3.Connection, doc_id: int, avg_doc_bytes: int) -> None:
    conn.execute(
        "INSERT INTO users(id, doc) VALUES (?, ?)",
        (doc_id, build_json_doc(doc_id, avg_doc_bytes)),
    )


def sqlite_prepare_db(path: Path, docs: int, avg_doc_bytes: int) -> None:
    cleanup_sqlite_path(path)
    conn = sqlite_connect(path)
    try:
        sqlite_create_schema(conn)
        for doc_id in range(1, docs + 1):
            sqlite_insert_doc(conn, doc_id, avg_doc_bytes)
    finally:
        conn.close()


def sqlite_prepare_dirty_wal(path: Path, docs: int, avg_doc_bytes: int) -> sqlite3.Connection:
    cleanup_sqlite_path(path)
    conn = sqlite_connect(path)
    sqlite_create_schema(conn)
    conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    conn.execute("BEGIN")
    for doc_id in range(1, docs + 1):
        sqlite_insert_doc(conn, doc_id, avg_doc_bytes)
    conn.execute("COMMIT")
    return conn


def elapsed_us(start_ns: int) -> int:
    return max(1, (time.perf_counter_ns() - start_ns) // 1000)


def percentile(values: list[int], pct: int) -> int:
    return nosqlite_bench.percentile(values, pct)


def aggregate_samples(samples: list[dict], peak_memory_kib: int, effective_iterations: int, notes: str) -> dict:
    samples_us = [int(sample["us"]) for sample in samples]
    ratio_samples = [int(sample["ratio_pct"]) for sample in samples if "ratio_pct" in sample]
    docs_total = sum(int(sample["docs"]) for sample in samples)
    bytes_total = sum(int(sample["bytes"]) for sample in samples)
    elapsed_us_total = sum(samples_us)
    elapsed_s = elapsed_us_total / 1_000_000 if elapsed_us_total else 0.0
    docs_per_s = docs_total / elapsed_s if elapsed_s else 0.0
    mib_per_s = (bytes_total / (1024 * 1024)) / elapsed_s if elapsed_s else 0.0
    return {
        "effective_iterations": effective_iterations,
        "samples": len(samples),
        "p50_us": percentile(samples_us, 50),
        "p95_us": percentile(samples_us, 95),
        "p99_us": percentile(samples_us, 99),
        "docs_per_s": docs_per_s,
        "mib_per_s": mib_per_s,
        "peak_memory_kib": peak_memory_kib,
        "ratio_pct_p50": percentile(ratio_samples, 50) if ratio_samples else 0,
        "ratio_pct_p95": percentile(ratio_samples, 95) if ratio_samples else 0,
        "ratio_pct_p99": percentile(ratio_samples, 99) if ratio_samples else 0,
        "notes": notes,
    }


def sqlite_temp_path(case_env: str) -> Path:
    return Path(tempfile.gettempdir()) / f"nosqlite_sqlite_compare_{case_env}_{os.getpid()}.db"


def run_sqlite_case_inline(case_env: str, docs: int, avg_doc_bytes: int, iterations: int) -> dict:
    path = sqlite_temp_path(case_env)
    samples: list[dict] = []
    effective_iterations = iterations
    notes = "SQLite JSON1 baseline: id INTEGER PRIMARY KEY, doc JSON TEXT, WAL, synchronous=FULL"

    if case_env == "warm_primary_lookup":
        sqlite_prepare_db(path, docs, avg_doc_bytes)
        conn = sqlite_connect(path)
        try:
            for warm_id in range(1, docs + 1):
                conn.execute(
                    "SELECT id, json_extract(doc, '$.name') FROM users WHERE id = ? LIMIT 1",
                    (warm_id,),
                ).fetchall()
            for i in range(iterations):
                target_id = (i % docs) + 1
                start_ns = time.perf_counter_ns()
                rows = conn.execute(
                    "SELECT id, json_extract(doc, '$.name') FROM users WHERE id = ? LIMIT 1",
                    (target_id,),
                ).fetchall()
                us = elapsed_us(start_ns)
                if len(rows) != 1:
                    raise RuntimeError("sqlite primary lookup returned unexpected row count")
                samples.append({"us": us, "docs": 1, "bytes": avg_doc_bytes})
        finally:
            conn.close()
            cleanup_sqlite_path(path)
    elif case_env == "warm_seq_scan":
        sqlite_prepare_db(path, docs, avg_doc_bytes)
        conn = sqlite_connect(path)
        try:
            conn.execute(
                "SELECT id FROM users WHERE json_extract(doc, '$.age') >= 18 LIMIT 64"
            ).fetchall()
            for _ in range(iterations):
                start_ns = time.perf_counter_ns()
                rows = conn.execute(
                    "SELECT id FROM users WHERE json_extract(doc, '$.age') >= 18 LIMIT 64"
                ).fetchall()
                us = elapsed_us(start_ns)
                if len(rows) == 0:
                    raise RuntimeError("sqlite seq scan returned no rows")
                samples.append({"us": us, "docs": docs, "bytes": docs * avg_doc_bytes})
        finally:
            conn.close()
            cleanup_sqlite_path(path)
    elif case_env == "durable_insert":
        effective_iterations = min(iterations, docs)
        cleanup_sqlite_path(path)
        conn = sqlite_connect(path)
        try:
            sqlite_create_schema(conn)
            for i in range(effective_iterations):
                start_ns = time.perf_counter_ns()
                sqlite_insert_doc(conn, i + 1, avg_doc_bytes)
                us = elapsed_us(start_ns)
                samples.append({"us": us, "docs": 1, "bytes": avg_doc_bytes})
        finally:
            conn.close()
            cleanup_sqlite_path(path)
    elif case_env == "dirty_wal_recovery_open":
        try:
            for _ in range(iterations):
                keeper = sqlite_prepare_dirty_wal(path, docs, avg_doc_bytes)
                try:
                    wal_path = Path(str(path) + "-wal")
                    if not wal_path.exists() or wal_path.stat().st_size == 0:
                        raise RuntimeError("sqlite dirty WAL case failed to preserve a WAL file")
                    start_ns = time.perf_counter_ns()
                    conn = sqlite_connect(path)
                    try:
                        count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
                    finally:
                        conn.close()
                    us = elapsed_us(start_ns)
                    if count != docs:
                        raise RuntimeError("sqlite dirty WAL recovery open saw unexpected row count")
                    samples.append({"us": us, "docs": docs, "bytes": docs * avg_doc_bytes})
                finally:
                    keeper.close()
                    cleanup_sqlite_path(path)
        finally:
            cleanup_sqlite_path(path)
        notes += "; each sample checkpoints the base store, then keeps the writer connection open with one dirty WAL txn until the measured reopen"
    elif case_env == "long_query_concurrent_commit":
        effective_iterations = iterations
        for i in range(iterations):
            sqlite_prepare_db(path, 1, avg_doc_bytes)
            baseline = sqlite_connect(path)
            try:
                start_ns = time.perf_counter_ns()
                sqlite_insert_doc(baseline, 2, avg_doc_bytes)
                baseline_us = elapsed_us(start_ns)
            finally:
                baseline.close()
                cleanup_sqlite_path(path)

            sqlite_prepare_db(path, 1, avg_doc_bytes)
            reader = sqlite_connect(path)
            writer = sqlite_connect(path)
            try:
                reader.execute("BEGIN")
                cursor = reader.execute("SELECT id FROM users LIMIT 64")
                first = cursor.fetchone()
                if first is None:
                    raise RuntimeError("sqlite reader returned no first row")
                start_ns = time.perf_counter_ns()
                sqlite_insert_doc(writer, 2, avg_doc_bytes)
                concurrent_us = elapsed_us(start_ns)
                ratio_pct = (baseline_us * 100) // concurrent_us if concurrent_us else 0
                samples.append({
                    "us": concurrent_us,
                    "docs": 1,
                    "bytes": avg_doc_bytes,
                    "ratio_pct": ratio_pct,
                })
            finally:
                reader.execute("ROLLBACK")
                reader.close()
                writer.close()
                cleanup_sqlite_path(path)
        notes += "; writer measured while a read transaction is pinned"
    else:
        raise RuntimeError(f"unknown sqlite benchmark case: {case_env}")

    return aggregate_samples(samples, 0, effective_iterations, notes)


def run_sqlite_child(case_env: str, docs: int, avg_doc_bytes: int, iterations: int) -> int:
    metrics = run_sqlite_case_inline(case_env, docs, avg_doc_bytes, iterations)
    print(json.dumps(metrics, separators=(",", ":")))
    return 0


def run_sqlite_case(root: Path, case_env: str, docs: int, avg_doc_bytes: int, iterations: int) -> dict:
    cmd = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--sqlite-child",
        case_env,
        "--docs",
        str(docs),
        "--avg-doc-bytes",
        str(avg_doc_bytes),
        "--iterations",
        str(iterations),
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
        peak_kib = max(peak_kib, nosqlite_bench.sample_peak_rss_kib(proc.pid))
        time.sleep(0.01)
    stdout, stderr = proc.communicate()
    peak_kib = max(peak_kib, nosqlite_bench.sample_peak_rss_kib(proc.pid))
    if proc.returncode != 0:
        raise RuntimeError(f"sqlite benchmark case {case_env} failed: rc={proc.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}")
    metrics = json.loads(stdout.strip().splitlines()[-1])
    metrics["peak_memory_kib"] = peak_kib
    return metrics


def compact_metrics(metrics: dict) -> dict:
    keys = [
        "effective_iterations",
        "samples",
        "p50_us",
        "p95_us",
        "p99_us",
        "docs_per_s",
        "mib_per_s",
        "peak_memory_kib",
        "ratio_pct_p50",
        "ratio_pct_p95",
        "ratio_pct_p99",
        "notes",
    ]
    result = {key: metrics.get(key, 0) for key in keys}
    for key in ["floor_status", "target_status", "stretch_status"]:
        if key in metrics:
            result[key] = metrics[key]
    return result


def run_nosqlite_cases(root: Path, docs: int, avg_doc_bytes: int, iterations: int) -> list[dict]:
    nosqlite_bench.compile_runner(root)
    results = []
    for runner_case, mode, case_name in nosqlite_bench.CASES:
        metrics = nosqlite_bench.run_case(root, runner_case, docs, avg_doc_bytes, iterations)
        results.append({
            "engine": "nosqlite",
            "runner_case": runner_case,
            "benchmark_mode": mode,
            "case_name": case_name,
            "metrics": compact_metrics(metrics),
        })
    return results


def run_sqlite_cases(root: Path, docs: int, avg_doc_bytes: int, iterations: int) -> list[dict]:
    results = []
    for runner_case, mode, case_name in SQLITE_CASES:
        metrics = run_sqlite_case(root, runner_case, docs, avg_doc_bytes, iterations)
        results.append({
            "engine": "sqlite",
            "runner_case": runner_case,
            "benchmark_mode": mode,
            "case_name": case_name,
            "metrics": compact_metrics(metrics),
        })
    return results


def format_ratio(nosqlite_p50: int, sqlite_p50: int) -> str:
    if nosqlite_p50 <= 0 or sqlite_p50 <= 0:
        return "n/a"
    if nosqlite_p50 >= sqlite_p50:
        return f"SQLite faster x{nosqlite_p50 / sqlite_p50:.2f}"
    return f"NoSQLite faster x{sqlite_p50 / nosqlite_p50:.2f}"


def by_engine_case(results: list[dict]) -> dict[tuple[str, str], dict]:
    return {(item["engine"], item["case_name"]): item for item in results}


def write_markdown(path: Path, docs: int, avg_doc_bytes: int, iterations: int, results: list[dict]) -> None:
    indexed = by_engine_case(results)
    lines = [
        "# NoSQLite vs SQLite 对比 Benchmark",
        "",
        f"日期：{time.strftime('%Y-%m-%d')}",
        "",
        "本报告用于把 NoSQLite v1.7.0 的 v0 原型 benchmark 与 SQLite JSON1 做同机横向校准。",
        "",
        "## 运行口径",
        "",
        f"- 数据集文档数：`{docs}`",
        f"- 平均文档大小：`{avg_doc_bytes}` bytes",
        f"- 请求迭代数：`{iterations}`",
        f"- Python：`{platform.python_version()}`",
        f"- SQLite：`{sqlite3.sqlite_version}`",
        f"- SQLite JSON1：`{'available' if sqlite_json1_available() else 'missing'}`",
        "- SQLite 表结构：`users(id INTEGER PRIMARY KEY, doc TEXT CHECK(json_valid(doc)))`",
        "- SQLite durable 配置：`journal_mode=WAL`，`synchronous=FULL`",
        "- NoSQLite 口径：复用 `nosqlite/benchmark_phase11.py` 的 Uya C runner（`-O2` 重链接）与 v0 原型数据集",
        "- warm-read 口径：计时前先执行一次未计时 warmup；primary lookup 会预热本轮会访问到的主键集合",
        "- 对比摘要中的 recovery case 固定使用 `dirty_wal_recovery_open`；NoSQLite 的 `recovery_open_with_auto_checkpoint` 只保留在原始指标里做补充观察",
        "",
        f"这不是生产级性能宣判：SQLite 是成熟 C 实现，NoSQLite 当前是 Uya/C v0 原型，且 benchmark 仍使用 `{docs}` 文档小规模原型数据集。本报告主要用于给后续优化建立参照物。",
        "",
        "## 摘要",
        "",
        "| case | mode | NoSQLite p50 us | SQLite p50 us | p50 对比 | NoSQLite p95 us | SQLite p95 us |",
        "| --- | --- | ---: | ---: | --- | ---: | ---: |",
    ]
    for _, mode, case_name in SQLITE_CASES:
        ns = indexed[("nosqlite", case_name)]["metrics"]
        sq = indexed[("sqlite", case_name)]["metrics"]
        lines.append(
            f"| {case_name} | {mode} | {ns['p50_us']} | {sq['p50_us']} | "
            f"{format_ratio(ns['p50_us'], sq['p50_us'])} | {ns['p95_us']} | {sq['p95_us']} |"
        )

    lines.extend([
        "",
        "## 原始指标",
        "",
        "| engine | case | mode | iters | p50 us | p95 us | p99 us | docs/s | MiB/s | peak KiB | notes |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ])
    for item in results:
        metrics = item["metrics"]
        lines.append(
            f"| {item['engine']} | {item['case_name']} | {item['benchmark_mode']} | "
            f"{metrics['effective_iterations']} | {metrics['p50_us']} | {metrics['p95_us']} | "
            f"{metrics['p99_us']} | {metrics['docs_per_s']:.2f} | {metrics['mib_per_s']:.2f} | "
            f"{metrics['peak_memory_kib']} | {metrics['notes']} |"
        )

    lines.extend([
        "",
        "## 解释边界",
        "",
        "- NoSQLite 的 primary lookup 走通用 SQL parser/binder/planner/executor，并用主键 B+Tree 定位 row slot；SQLite 走 `INTEGER PRIMARY KEY`。",
        "- NoSQLite 的 seq scan 走通用 `$.age` 谓词执行；SQLite 使用 `json_extract(doc, '$.age')`。",
        "- NoSQLite durable commit 使用 WAL `fdatasync` 作为提交边界，数据页/meta 页延迟到 recovery/checkpoint 物化；这不是跳过持久化。",
        "- NoSQLite recovery 在完整校验并回放 WAL 后执行真实 checkpoint（同步 DB、写 checkpoint meta、截断 WAL）；原始指标里额外保留 `recovery_open_with_auto_checkpoint`，用于观察 recovery 触发的后续 reopen 快路径。",
        "- SQLite 的 dirty WAL case 先 checkpoint schema base，再用一个事务写入全部样本并保持 writer 连接不关闭，确保 prepare 结束后仍保留一条 dirty WAL txn；样本仍包含 connect、WAL/同步 PRAGMA 设置和一次 `COUNT(*)` 读。",
        "- long query concurrent commit 在 SQLite 侧用两个连接和显式 read transaction 固定 reader snapshot。",
        "- durable/recovery p95 保留首个冷 fdatasync/checkpoint 样本，没有剔除慢样本。",
        "- SQLite peak RSS 是独立 Python 子进程级采样，包含 Python 解释器和 sqlite3 绑定开销。",
        "",
        "## 复现命令",
        "",
        "```bash",
        "python3 nosqlite/benchmark_sqlite_compare.py",
        "```",
    ])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare NoSQLite v0 prototype benchmark cases against SQLite JSON1.")
    parser.add_argument("--docs", type=int, default=3)
    parser.add_argument("--avg-doc-bytes", type=int, default=1024)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--write-markdown", default="docs/nosqlite-sqlite-compare.md")
    parser.add_argument("--write-json", default="docs/nosqlite-sqlite-compare.json")
    parser.add_argument("--sqlite-child", choices=[case[0] for case in SQLITE_CASES])
    args = parser.parse_args()

    if args.docs <= 0:
        raise SystemExit("--docs must be positive")
    if args.avg_doc_bytes < 64:
        raise SystemExit("--avg-doc-bytes must be at least 64")
    if args.iterations <= 0:
        raise SystemExit("--iterations must be positive")
    if not sqlite_json1_available():
        raise SystemExit("SQLite JSON1 is required for this comparison benchmark")

    if args.sqlite_child:
        return run_sqlite_child(args.sqlite_child, args.docs, args.avg_doc_bytes, args.iterations)

    root = Path(__file__).resolve().parent.parent
    results = []
    results.extend(run_nosqlite_cases(root, args.docs, args.avg_doc_bytes, args.iterations))
    results.extend(run_sqlite_cases(root, args.docs, args.avg_doc_bytes, args.iterations))

    markdown_path = root / args.write_markdown
    json_path = root / args.write_json
    write_markdown(markdown_path, args.docs, args.avg_doc_bytes, args.iterations, results)
    json_path.write_text(json.dumps({
        "docs": args.docs,
        "avg_doc_bytes": args.avg_doc_bytes,
        "iterations": args.iterations,
        "python_version": platform.python_version(),
        "sqlite_version": sqlite3.sqlite_version,
        "sqlite_json1": sqlite_json1_available(),
        "results": results,
    }, indent=2), encoding="utf-8")

    for item in results:
        metrics = item["metrics"]
        print(
            f"COMPARE_RESULT engine={item['engine']} case_name={item['case_name']} "
            f"mode={item['benchmark_mode']} p50_us={metrics['p50_us']} "
            f"p95_us={metrics['p95_us']} docs_per_s={metrics['docs_per_s']:.2f} "
            f"peak_memory_kib={metrics['peak_memory_kib']}"
        )
    print(f"COMPARE_REPORT markdown={args.write_markdown} json={args.write_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
