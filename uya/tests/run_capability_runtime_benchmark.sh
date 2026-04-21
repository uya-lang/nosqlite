#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
OUT_C="$TEST_DIR/build/bench_capability_runtime.c"
OUT_BIN="$TEST_DIR/build/bench_capability_runtime"
COMPARE_SCRIPT="$TEST_DIR/compare_capability_runtime_benchmark.py"
BASELINE_PATH=""
INVOKE_DIR="$(pwd)"
REGRESSION_THRESHOLD_PCT="5.0"
MIN_REGRESSION_US="2"
FAIL_ON_REGRESSION="0"
FAIL_METRICS="latency_us,p99_invoke_us,failure_count,timeout_count"
IGNORE_METRICS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --baseline)
            if [[ $# -lt 2 ]]; then
                echo "missing value for --baseline" >&2
                exit 1
            fi
            BASELINE_PATH="$2"
            shift 2
            ;;
        --regression-threshold-pct)
            if [[ $# -lt 2 ]]; then
                echo "missing value for --regression-threshold-pct" >&2
                exit 1
            fi
            REGRESSION_THRESHOLD_PCT="$2"
            shift 2
            ;;
        --min-regression-us)
            if [[ $# -lt 2 ]]; then
                echo "missing value for --min-regression-us" >&2
                exit 1
            fi
            MIN_REGRESSION_US="$2"
            shift 2
            ;;
        --fail-on-regression)
            FAIL_ON_REGRESSION="1"
            shift
            ;;
        --fail-metrics)
            if [[ $# -lt 2 ]]; then
                echo "missing value for --fail-metrics" >&2
                exit 1
            fi
            FAIL_METRICS="$2"
            shift 2
            ;;
        --ignore-metrics)
            if [[ $# -lt 2 ]]; then
                echo "missing value for --ignore-metrics" >&2
                exit 1
            fi
            IGNORE_METRICS="$2"
            shift 2
            ;;
        *)
            echo "usage: $0 [--baseline <path-to-json-or-csv>] [--regression-threshold-pct <pct>] [--min-regression-us <us>] [--fail-on-regression] [--fail-metrics <csv>] [--ignore-metrics <csv>]" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$BASELINE_PATH" && "$BASELINE_PATH" != /* ]]; then
    BASELINE_PATH="$INVOKE_DIR/$BASELINE_PATH"
fi

mkdir -p "$TEST_DIR/build"

cd "$TEST_DIR"
"$ROOT_DIR/bin/uya" --c99 --nostdlib bench_capability_runtime.uya -o "$OUT_C"
gcc --std=c99 -nostdlib -static -no-pie "$OUT_C" -o "$OUT_BIN" -lgcc
"$OUT_BIN"

if [[ -n "$BASELINE_PATH" ]]; then
    compare_args=(
        --baseline "$BASELINE_PATH"
        --sample-json "$TEST_DIR/build/capability_runtime_benchmark.json"
        --sample-csv "$TEST_DIR/build/capability_runtime_benchmark.csv"
        --out-json "$TEST_DIR/build/capability_runtime_benchmark_compare.json"
        --out-csv "$TEST_DIR/build/capability_runtime_benchmark_compare.csv"
        --regression-threshold-pct "$REGRESSION_THRESHOLD_PCT"
        --min-regression-us "$MIN_REGRESSION_US"
        --fail-metrics "$FAIL_METRICS"
    )
    if [[ -n "$IGNORE_METRICS" ]]; then
        compare_args+=(--ignore-metrics "$IGNORE_METRICS")
    fi
    if [[ "$FAIL_ON_REGRESSION" == "1" ]]; then
        compare_args+=(--fail-on-regression)
    fi
    python3 "$COMPARE_SCRIPT" \
        "${compare_args[@]}"
fi
