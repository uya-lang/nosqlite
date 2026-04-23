#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

run_static_error() {
    local file="$1"
    local expected="$2"

    ./uya/bin/uya "$file" >"$TMP_OUT" 2>&1

    if .uyacache/a.out >>"$TMP_OUT" 2>&1; then
        echo "expected static validation failure for $file"
        exit 1
    fi

    if ! rg -q "$expected" "$TMP_OUT"; then
        echo "static validation failure for $file did not contain expected message: $expected"
        cat "$TMP_OUT"
        exit 1
    fi
}

run_static_error "nosqlite/tests/sql/error_phase14_typed_sql_missing_field.uya" "typed_sql: field not declared in static schema"
run_static_error "nosqlite/tests/sql/error_phase14_typed_sql_type_mismatch.uya" "typed_sql: expression type mismatch against static schema"
run_static_error "nosqlite/tests/sql/error_phase14_typed_sql_collection_mismatch.uya" "typed_sql: collection not declared in static schema"

echo "phase14 typed_sql static-error checks ok"
