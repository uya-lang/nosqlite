#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

run_uya_test() {
    local file="$1"
    echo "DOD_TEST $file"
    ./uya/bin/uya "$file" >/tmp/nosqlite_dod_compile.log 2>&1
    .uyacache/a.out >/tmp/nosqlite_dod_run.log 2>&1
}

run_uya_test "nosqlite/tests/core/test_core_foundation.uya"
run_uya_test "nosqlite/tests/doc/test_docblob_basics.uya"
run_uya_test "nosqlite/tests/doc/test_docblob_codec.uya"
run_uya_test "nosqlite/tests/doc/test_docblob_path.uya"
run_uya_test "nosqlite/tests/sql/test_sql_parser.uya"
run_uya_test "nosqlite/tests/plan/test_binder_planner.uya"
run_uya_test "nosqlite/tests/exec/test_exec_runtime.uya"
run_uya_test "nosqlite/tests/exec/test_phase12_features.uya"
run_uya_test "nosqlite/tests/exec/test_phase12_async.uya"
run_uya_test "nosqlite/tests/storage/test_phase13_format_upgrade.uya"
run_uya_test "nosqlite/tests/sql/test_phase14_typed_sql.uya"
run_uya_test "nosqlite/tests/storage/test_storage_page_basics.uya"
run_uya_test "nosqlite/tests/storage/test_storage_pager_runtime.uya"
run_uya_test "nosqlite/tests/storage/test_storage_slotted_page_runtime.uya"
run_uya_test "nosqlite/tests/storage/test_storage_wal_runtime.uya"
run_uya_test "nosqlite/tests/storage/test_catalog_basics.uya"
run_uya_test "nosqlite/tests/storage/test_index_btree.uya"
run_uya_test "nosqlite/tests/storage/test_phase11_stability.uya"
run_uya_test "nosqlite/tests/exec/test_stress_runtime.uya"

bash nosqlite/tests/verify_phase12_5_async_boundary.sh >/tmp/nosqlite_dod_phase12_5.log 2>&1
bash nosqlite/tests/verify_phase14_typed_sql_errors.sh >/tmp/nosqlite_dod_phase14.log 2>&1

python3 - <<'PY'
import json
from pathlib import Path

required = {
    "primary_lookup",
    "seq_scan_filter",
    "durable_insert",
    "dirty_wal_recovery_open",
    "long_query_concurrent_commit",
}
data = json.loads(Path("docs/nosqlite-benchmark-v0.json").read_text())
seen = {}
for item in data.get("results", []):
    name = item.get("case_name")
    metrics = item.get("metrics", {})
    if name in required:
        seen[name] = metrics.get("floor_status")

missing = sorted(required - set(seen))
failed = sorted(name for name, status in seen.items() if status != "pass")
if missing or failed:
    raise SystemExit(f"benchmark floor check failed: missing={missing} failed={failed}")
PY

rm -f /tmp/nosqlite_dod_compile.log /tmp/nosqlite_dod_run.log \
    /tmp/nosqlite_dod_phase12_5.log /tmp/nosqlite_dod_phase14.log

echo "definition of done verification ok"
