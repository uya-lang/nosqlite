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


def aggregate_write_case(rows: int, elapsed_us_total: int) -> dict:
    return {
        "rows": rows,
        "op_us": elapsed_us_total,
        "rows_per_s": rows / (elapsed_us_total / 1_000_000),
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
    age = 18 + (doc_id % 41)
    active = "true" if doc_id % 2 == 0 else "false"
    return f'{{"n":{doc_id},"bucket":{bucket},"age":{age},"active":{active}}}'


BULK_UPDATE_AGE = 30


def sqlite_load_docs(conn: sqlite3.Connection, docs: int, batch_rows: int) -> None:
    inserted = 0
    while inserted < docs:
        current_batch = min(batch_rows, docs - inserted)
        params = [
            (doc_id, build_json_doc(doc_id))
            for doc_id in range(inserted + 1, inserted + current_batch + 1)
        ]
        conn.execute("BEGIN")
        try:
            conn.executemany("INSERT INTO users(id, doc) VALUES (?, ?)", params)
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
        inserted += current_batch


def sqlite_prepare_loaded_db(path: Path, docs: int, batch_rows: int) -> sqlite3.Connection:
    cleanup_sqlite_path(path)
    conn = sqlite_connect(path)
    sqlite_create_schema(conn)
    sqlite_load_docs(conn, docs, batch_rows)
    return conn


def sqlite_run_delete_case(conn: sqlite3.Connection, docs: int, batch_rows: int, reverse: bool) -> int:
    start_ns = time.perf_counter_ns()
    deleted = 0
    while deleted < docs:
        current_batch = min(batch_rows, docs - deleted)
        if reverse:
            batch_end_exclusive = docs - deleted + 1
            batch_start = batch_end_exclusive - current_batch
        else:
            batch_start = deleted + 1
            batch_end_exclusive = batch_start + current_batch
        conn.execute("BEGIN")
        try:
            conn.execute(
                "DELETE FROM users WHERE id >= ? AND id < ?",
                (batch_start, batch_end_exclusive),
            )
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
        deleted += current_batch
    return elapsed_us(start_ns)


def run_sqlite_case_inline(docs: int, batch_rows: int, query_iters: int) -> dict:
    path = Path(tempfile.gettempdir()) / f"nosqlite_sqlite_compare_million_{os.getpid()}.db"
    load_notes = "SQLite JSON1; journal_mode=WAL; synchronous=FULL; full fetch timed"
    query_notes = "SQLite JSON1; journal_mode=WAL; synchronous=FULL; warm SELECT id FROM users LIMIT 64; full fetch timed"
    update_notes = (
        "SQLite JSON1; fresh preloaded million-row dataset; durable BEGIN/COMMIT range batches; "
        "UPDATE users SET doc = json_set(doc, '$.age', ?) WHERE id >= ? AND id < ?"
    )
    logical_delete_notes = (
        "SQLite JSON1 reference; fresh preloaded million-row dataset; durable head-to-tail range DELETE; "
        "physical row delete semantics"
    )
    physical_delete_notes = (
        "SQLite JSON1; fresh preloaded million-row dataset; durable tail-to-head range DELETE; "
        "physical row delete semantics"
    )

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
    finally:
        conn.close()
        cleanup_sqlite_path(path)

    update_conn = sqlite_prepare_loaded_db(path, docs, batch_rows)
    try:
        start_ns = time.perf_counter_ns()
        updated = 0
        while updated < docs:
            current_batch = min(batch_rows, docs - updated)
            batch_start = updated + 1
            batch_end_exclusive = batch_start + current_batch
            update_conn.execute("BEGIN")
            try:
                update_conn.execute(
                    "UPDATE users SET doc = json_set(doc, '$.age', ?) WHERE id >= ? AND id < ?",
                    (BULK_UPDATE_AGE, batch_start, batch_end_exclusive),
                )
                update_conn.execute("COMMIT")
            except Exception:
                update_conn.execute("ROLLBACK")
                raise
            updated += current_batch
        update_us = elapsed_us(start_ns)

        updated_row = update_conn.execute(
            "SELECT id FROM users WHERE json_extract(doc, '$.age') = ? LIMIT 1",
            (BULK_UPDATE_AGE,),
        ).fetchone()
        if updated_row is None:
            raise RuntimeError("sqlite bulk update verification failed: no updated row found")
        stale_row = update_conn.execute(
            "SELECT id FROM users WHERE json_extract(doc, '$.age') != ? LIMIT 1",
            (BULK_UPDATE_AGE,),
        ).fetchone()
        if stale_row is not None:
            raise RuntimeError("sqlite bulk update verification failed: found stale age value")
    finally:
        update_conn.close()
        cleanup_sqlite_path(path)

    logical_delete_conn = sqlite_prepare_loaded_db(path, docs, batch_rows)
    try:
        logical_delete_us = sqlite_run_delete_case(logical_delete_conn, docs, batch_rows, reverse=False)
        remaining = logical_delete_conn.execute("SELECT id FROM users LIMIT 1").fetchone()
        if remaining is not None:
            raise RuntimeError("sqlite logical delete verification failed: expected empty table")
    finally:
        logical_delete_conn.close()
        cleanup_sqlite_path(path)

    physical_delete_conn = sqlite_prepare_loaded_db(path, docs, batch_rows)
    try:
        physical_delete_us = sqlite_run_delete_case(physical_delete_conn, docs, batch_rows, reverse=True)
        remaining = physical_delete_conn.execute("SELECT id FROM users LIMIT 1").fetchone()
        if remaining is not None:
            raise RuntimeError("sqlite physical delete verification failed: expected empty table")
    finally:
        physical_delete_conn.close()
        cleanup_sqlite_path(path)

    return {
        "engine": "sqlite",
        "docs": docs,
        "batch_rows": batch_rows,
        "load": {
            "rows": docs,
            "load_us": load_us,
            "rows_per_s": docs / (load_us / 1_000_000),
            "notes": load_notes,
        },
        "limit_query": {
            **aggregate_query_samples(query_samples_ns),
            "notes": query_notes,
        },
        "bulk_update": {
            **aggregate_write_case(docs, update_us),
            "notes": update_notes,
        },
        "logical_delete": {
            **aggregate_write_case(docs, logical_delete_us),
            "notes": logical_delete_notes,
        },
        "physical_delete": {
            **aggregate_write_case(docs, physical_delete_us),
            "notes": physical_delete_notes,
        },
        "notes": "SQLite JSON1 million-row benchmark",
    }


def run_sqlite_child(docs: int, batch_rows: int, query_iters: int) -> int:
    result = run_sqlite_case_inline(docs, batch_rows, query_iters)
    print(json.dumps(result, separators=(",", ":")))
    return 0


def parse_nosqlite_output(stdout: str, docs: int) -> dict:
    result_us: dict[str, int] = {}
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
            case_name = payload.get("case")
            if case_name:
                result_us[case_name] = int(payload["us"])
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

    load_us = result_us.get("bulk_load", 0)
    update_us = result_us.get("bulk_update", 0)
    logical_delete_us = result_us.get("logical_delete", 0)
    physical_delete_us = result_us.get("physical_delete", 0)
    if load_us <= 0 or update_us <= 0 or logical_delete_us <= 0 or physical_delete_us <= 0 or not query_samples_ns:
        raise RuntimeError(f"nosqlite million benchmark output incomplete:\n{stdout}")

    return {
        "engine": "nosqlite",
        "docs": docs,
        "batch_rows": int(info.get("batch_rows", 0)),
        "load": {
            "rows": docs,
            "load_us": load_us,
            "rows_per_s": docs / (load_us / 1_000_000),
            "notes": "NoSQLite million-row benchmark; staged txn batches; direct JSON insert helper; durable commit timed",
        },
        "limit_query": {
            **aggregate_query_samples(query_samples_ns),
            "notes": "NoSQLite million-row benchmark; staged txn batches; warm SELECT _id FROM users LIMIT 64; full fetch timed",
        },
        "bulk_update": {
            **aggregate_write_case(docs, update_us),
            "notes": "NoSQLite million-row benchmark; fresh preloaded dataset; durable range batches; UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end",
        },
        "logical_delete": {
            **aggregate_write_case(docs, logical_delete_us),
            "notes": "NoSQLite million-row benchmark; fresh preloaded dataset; durable head-to-tail prefix delete; "
            "commits deleted-through metadata boundary; logical delete semantics",
        },
        "physical_delete": {
            **aggregate_write_case(docs, physical_delete_us),
            "notes": "NoSQLite million-row benchmark; fresh preloaded dataset; durable tail-to-head range delete; "
            "prefix logical delete fast path intentionally bypassed to force physical page updates",
        },
        "notes": "NoSQLite million-row benchmark",
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
        "本报告聚焦百万条记录量级下的装载、查询、批量更新，以及区分 logical delete / physical delete 后的删除性能对比。",
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
        "- 数据文档：`{\"n\": <id>, \"bucket\": <id % 100>, \"age\": <18 + (id % 41)>, \"active\": <bool>}`",
        "- 查询口径：`SELECT _id FROM users LIMIT 64` / `SELECT id FROM users LIMIT 64`",
        "- 更新口径：fresh preload 后按 `batch_rows` 分段执行 durable range update；NoSQLite 执行 `UPDATE users SET $.age = 30 WHERE _id >= start AND _id < end`，SQLite 执行 `UPDATE users SET doc = json_set(doc, '$.age', 30) WHERE id >= start AND id < end`。",
        "- `logical_delete` 口径：fresh preload 后按 `batch_rows` 头到尾执行 durable range delete；NoSQLite 会命中 prefix metadata delete 快路径，SQLite 仍执行物理 DELETE，因此该项只用于能力说明，不作为公平主结论。",
        "- `physical_delete` 口径：fresh preload 后按 `batch_rows` 尾到头执行 durable range delete；两侧都执行 `DELETE ... WHERE id >= start AND id < end`，同时显式避开 NoSQLite prefix logical delete 快路径，作为公平 delete 主对比。",
        "- limit_query 计时范围：从开始执行查询到完整取回 64 行结果，两侧统一口径。",
        "- 更新、logical_delete、physical_delete 各自使用独立 fresh preload 数据集，预装载不计入该 case 计时，避免 load/query cache 污染后续结果。",
        "",
        "## 摘要",
        "",
        "| case | NoSQLite | SQLite | 对比 |",
        "| --- | ---: | ---: | --- |",
        f"| bulk_load rows/s | {ns['load']['rows_per_s']:.2f} | {sq['load']['rows_per_s']:.2f} | {ratio_text(ns['load']['rows_per_s'], sq['load']['rows_per_s'], False)} |",
        f"| limit_query p50 us | {format_us(ns['limit_query']['p50_us'])} | {format_us(sq['limit_query']['p50_us'])} | {ratio_text(ns['limit_query']['p50_ns'], sq['limit_query']['p50_ns'], True)} |",
        f"| limit_query p95 us | {format_us(ns['limit_query']['p95_us'])} | {format_us(sq['limit_query']['p95_us'])} | {ratio_text(ns['limit_query']['p95_ns'], sq['limit_query']['p95_ns'], True)} |",
        f"| bulk_update rows/s | {ns['bulk_update']['rows_per_s']:.2f} | {sq['bulk_update']['rows_per_s']:.2f} | {ratio_text(ns['bulk_update']['rows_per_s'], sq['bulk_update']['rows_per_s'], False)} |",
        f"| physical_delete rows/s | {ns['physical_delete']['rows_per_s']:.2f} | {sq['physical_delete']['rows_per_s']:.2f} | {ratio_text(ns['physical_delete']['rows_per_s'], sq['physical_delete']['rows_per_s'], False)} |",
        "",
        "## Delete 语义拆分",
        "",
        "| case | NoSQLite | SQLite | 说明 |",
        "| --- | ---: | ---: | --- |",
        f"| logical_delete rows/s | {ns['logical_delete']['rows_per_s']:.2f} | {sq['logical_delete']['rows_per_s']:.2f} | 非同口径。NoSQLite 为 durable logical prefix delete，SQLite 仍是 physical DELETE，仅作参考。 |",
        f"| physical_delete rows/s | {ns['physical_delete']['rows_per_s']:.2f} | {sq['physical_delete']['rows_per_s']:.2f} | 公平主口径。两侧都按尾到头分段删除，显式避开 NoSQLite prefix logical delete 快路径。 |",
        "",
        "## 原始指标",
        "",
        "| engine | load s | load rows/s | update s | update rows/s | physical_delete s | physical_delete rows/s | query p50 us | query p95 us | query qps | peak KiB | notes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        f"| nosqlite | {ns['load']['load_us'] / 1_000_000:.2f} | {ns['load']['rows_per_s']:.2f} | {ns['bulk_update']['op_us'] / 1_000_000:.2f} | {ns['bulk_update']['rows_per_s']:.2f} | {ns['physical_delete']['op_us'] / 1_000_000:.2f} | {ns['physical_delete']['rows_per_s']:.2f} | {format_us(ns['limit_query']['p50_us'])} | {format_us(ns['limit_query']['p95_us'])} | {ns['limit_query']['qps']:.2f} | {ns['peak_memory_kib']} | {ns['bulk_update']['notes']}; {ns['physical_delete']['notes']} |",
        f"| sqlite | {sq['load']['load_us'] / 1_000_000:.2f} | {sq['load']['rows_per_s']:.2f} | {sq['bulk_update']['op_us'] / 1_000_000:.2f} | {sq['bulk_update']['rows_per_s']:.2f} | {sq['physical_delete']['op_us'] / 1_000_000:.2f} | {sq['physical_delete']['rows_per_s']:.2f} | {format_us(sq['limit_query']['p50_us'])} | {format_us(sq['limit_query']['p95_us'])} | {sq['limit_query']['qps']:.2f} | {sq['peak_memory_kib']} | {sq['bulk_update']['notes']}; {sq['physical_delete']['notes']} |",
        "",
        "## Delete 明细",
        "",
        "| engine | logical_delete s | logical_delete rows/s | physical_delete s | physical_delete rows/s | notes |",
        "| --- | ---: | ---: | ---: | ---: | --- |",
        f"| nosqlite | {ns['logical_delete']['op_us'] / 1_000_000:.2f} | {ns['logical_delete']['rows_per_s']:.2f} | {ns['physical_delete']['op_us'] / 1_000_000:.2f} | {ns['physical_delete']['rows_per_s']:.2f} | {ns['logical_delete']['notes']}; {ns['physical_delete']['notes']} |",
        f"| sqlite | {sq['logical_delete']['op_us'] / 1_000_000:.2f} | {sq['logical_delete']['rows_per_s']:.2f} | {sq['physical_delete']['op_us'] / 1_000_000:.2f} | {sq['physical_delete']['rows_per_s']:.2f} | {sq['logical_delete']['notes']}; {sq['physical_delete']['notes']} |",
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
        f"load_rows_per_s_sqlite={sqlite_result['load']['rows_per_s']:.2f} "
        f"bulk_update_rows_per_s_nosqlite={nosqlite_result['bulk_update']['rows_per_s']:.2f} "
        f"bulk_update_rows_per_s_sqlite={sqlite_result['bulk_update']['rows_per_s']:.2f} "
        f"logical_delete_rows_per_s_nosqlite={nosqlite_result['logical_delete']['rows_per_s']:.2f} "
        f"logical_delete_rows_per_s_sqlite={sqlite_result['logical_delete']['rows_per_s']:.2f} "
        f"physical_delete_rows_per_s_nosqlite={nosqlite_result['physical_delete']['rows_per_s']:.2f} "
        f"physical_delete_rows_per_s_sqlite={sqlite_result['physical_delete']['rows_per_s']:.2f}"
    )
    print(f"MILLION_COMPARE_REPORT markdown={args.write_markdown} json={args.write_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
