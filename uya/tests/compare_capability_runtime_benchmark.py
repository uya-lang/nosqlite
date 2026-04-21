#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path


PERF_METRICS = (
    "latency_us",
    "install_us",
    "activate_us",
    "first_invoke_us",
    "avg_invoke_us",
    "p99_invoke_us",
)
COUNT_METRICS = ("failure_count", "timeout_count")
ALL_METRICS = PERF_METRICS + COUNT_METRICS


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--sample-json", required=True)
    parser.add_argument("--sample-csv", required=True)
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-csv", required=True)
    parser.add_argument("--regression-threshold-pct", type=float, default=5.0)
    parser.add_argument("--min-regression-us", type=int, default=2)
    parser.add_argument("--fail-on-regression", action="store_true")
    parser.add_argument("--fail-metrics", default="latency_us,p99_invoke_us,failure_count,timeout_count")
    parser.add_argument("--ignore-metrics", default="")
    return parser.parse_args()


def parse_metric_list(text: str) -> set[str]:
    metrics = set()
    for item in text.split(","):
        name = item.strip()
        if name:
            metrics.add(name)
    return metrics


def resolve_failure_metrics(fail_metrics_text: str, ignore_metrics_text: str) -> set[str]:
    fail_metrics = parse_metric_list(fail_metrics_text)
    ignore_metrics = parse_metric_list(ignore_metrics_text)
    unknown_metrics = (fail_metrics | ignore_metrics) - set(ALL_METRICS)
    if unknown_metrics:
        names = ", ".join(sorted(unknown_metrics))
        raise ValueError(f"unknown metrics: {names}")
    return fail_metrics - ignore_metrics


def load_rows(path: Path) -> list[dict]:
    suffix = path.suffix.lower()
    if suffix == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        rows = data.get("results", [])
        if not isinstance(rows, list):
            raise ValueError(f"invalid results array in {path}")
        return rows
    if suffix == ".csv":
        with path.open("r", encoding="utf-8", newline="") as fp:
            return list(csv.DictReader(fp))
    raise ValueError(f"unsupported baseline format: {path}")


def normalize_int(value) -> int:
    if value is None or value == "":
        return 0
    if isinstance(value, bool):
        return 1 if value else 0
    return int(value)


def normalize_rows(rows: list[dict]) -> dict[tuple[str, str], dict]:
    normalized = {}
    for row in rows:
        backend = str(row["backend"])
        case = str(row["case"])
        item = {
            "backend": backend,
            "case": case,
            "status_ok": normalize_int(row.get("status_ok", 0)),
        }
        for metric in ALL_METRICS:
            item[metric] = normalize_int(row.get(metric, 0))
        normalized[(backend, case)] = item
    return normalized


def diff_metric(baseline_value: int, sample_value: int) -> tuple[str, float | None]:
    if baseline_value == sample_value:
        return "stable", 0.0
    if baseline_value == 0:
        if sample_value == 0:
            return "stable", 0.0
        return "regression", None
    delta_pct = ((sample_value - baseline_value) * 100.0) / baseline_value
    if delta_pct > 0.0:
        return "regression", delta_pct
    return "improvement", delta_pct


def is_threshold_exceeded(
    metric: str,
    baseline_value: int,
    sample_value: int,
    delta_pct: float | None,
    regression_threshold_pct: float,
    min_regression_us: int,
) -> bool:
    delta_abs = sample_value - baseline_value
    if metric in PERF_METRICS:
        if delta_abs < min_regression_us:
            return False
        if delta_pct is None:
            return True
        return delta_pct >= regression_threshold_pct
    if metric in COUNT_METRICS:
        if delta_abs <= 0:
            return False
        if delta_pct is None:
            return True
        return delta_pct >= regression_threshold_pct
    return False


def build_compare_rows(
    baseline_rows: dict[tuple[str, str], dict],
    sample_rows: dict[tuple[str, str], dict],
    regression_threshold_pct: float,
    min_regression_us: int,
    failure_metrics: set[str],
) -> list[dict]:
    compare_rows = []
    for key in sorted(sample_rows):
        sample = sample_rows[key]
        baseline = baseline_rows.get(key)
        if baseline is None:
            compare_rows.append(
                {
                    "backend": sample["backend"],
                    "case": sample["case"],
                    "metric": "row",
                    "baseline": "",
                    "sample": "",
                    "delta_pct": "",
                    "trend": "new_case",
                    "status_change": "",
                    "monitored_for_failure": "0",
                }
            )
            continue

        status_change = ""
        if baseline["status_ok"] != sample["status_ok"]:
            status_change = f"{baseline['status_ok']}->{sample['status_ok']}"

        for metric in ALL_METRICS:
            trend, delta_pct = diff_metric(baseline[metric], sample[metric])
            exceeds_threshold = trend == "regression" and is_threshold_exceeded(
                metric,
                baseline[metric],
                sample[metric],
                delta_pct,
                regression_threshold_pct,
                min_regression_us,
            )
            compare_rows.append(
                {
                    "backend": sample["backend"],
                    "case": sample["case"],
                    "metric": metric,
                    "baseline": baseline[metric],
                    "sample": sample[metric],
                    "delta_pct": "" if delta_pct is None else f"{delta_pct:.2f}",
                    "trend": trend,
                    "exceeds_threshold": "1" if exceeds_threshold else "0",
                    "monitored_for_failure": "1" if metric in failure_metrics else "0",
                    "status_change": status_change,
                }
            )
    for key in sorted(baseline_rows):
        if key in sample_rows:
            continue
        baseline = baseline_rows[key]
        compare_rows.append(
            {
                "backend": baseline["backend"],
                "case": baseline["case"],
                "metric": "row",
                "baseline": "",
                "sample": "",
                "delta_pct": "",
                "trend": "removed_case",
                "exceeds_threshold": "0",
                "monitored_for_failure": "0",
                "status_change": "",
            }
        )
    return compare_rows


def write_compare_json(
    path: Path,
    baseline_path: Path,
    sample_json: Path,
    rows: list[dict],
    regression_threshold_pct: float,
    min_regression_us: int,
    failure_metrics: set[str],
) -> None:
    payload = {
        "baseline_path": str(baseline_path),
        "sample_path": str(sample_json),
        "regression_threshold_pct": regression_threshold_pct,
        "min_regression_us": min_regression_us,
        "failure_metrics": sorted(failure_metrics),
        "comparisons": rows,
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_compare_csv(path: Path, rows: list[dict]) -> None:
    fields = ["backend", "case", "metric", "baseline", "sample", "delta_pct", "trend", "exceeds_threshold", "monitored_for_failure", "status_change"]
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def print_summary(rows: list[dict], out_json: Path, out_csv: Path) -> None:
    for row in rows:
        if row["metric"] == "row":
            print(
                f"capability_compare: backend={row['backend']} case={row['case']} trend={row['trend']}"
            )
            continue
        delta = row["delta_pct"]
        delta_text = "n/a"
        if delta != "":
            delta_text = f"{delta}%"
        line = (
            f"capability_compare: backend={row['backend']} case={row['case']} "
            f"metric={row['metric']} baseline={row['baseline']} sample={row['sample']} "
            f"delta_pct={delta_text} trend={row['trend']} exceeds_threshold={row['exceeds_threshold']} monitored_for_failure={row['monitored_for_failure']}"
        )
        if row["status_change"]:
            line += f" status_ok={row['status_change']}"
        print(line)
    print(f"capability_compare_export: csv={out_csv} json={out_json}")


def collect_hard_regressions(rows: list[dict]) -> list[dict]:
    hard_regressions = []
    for row in rows:
        if row["metric"] == "row":
            continue
        if row["trend"] == "regression" and row["exceeds_threshold"] == "1" and row["monitored_for_failure"] == "1":
            hard_regressions.append(row)
    return hard_regressions


def main() -> int:
    args = parse_args()
    baseline_path = Path(args.baseline)
    sample_json = Path(args.sample_json)
    sample_csv = Path(args.sample_csv)
    out_json = Path(args.out_json)
    out_csv = Path(args.out_csv)
    failure_metrics = resolve_failure_metrics(args.fail_metrics, args.ignore_metrics)

    baseline_rows = normalize_rows(load_rows(baseline_path))
    sample_rows = normalize_rows(load_rows(sample_json if sample_json.suffix.lower() == ".json" else sample_csv))
    compare_rows = build_compare_rows(
        baseline_rows,
        sample_rows,
        args.regression_threshold_pct,
        args.min_regression_us,
        failure_metrics,
    )
    write_compare_json(
        out_json,
        baseline_path,
        sample_json,
        compare_rows,
        args.regression_threshold_pct,
        args.min_regression_us,
        failure_metrics,
    )
    write_compare_csv(out_csv, compare_rows)
    print_summary(compare_rows, out_json, out_csv)
    hard_regressions = collect_hard_regressions(compare_rows)
    if args.fail_on_regression and hard_regressions:
        print(
            "capability_compare_fail: "
            f"regression_count={len(hard_regressions)} "
            f"fail_metrics={','.join(sorted(failure_metrics))}"
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
