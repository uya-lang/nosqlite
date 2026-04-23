#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

matches="$(rg -n "@async_fn" nosqlite/lib || true)"

if [ -n "$matches" ]; then
    bad_matches="$(printf '%s\n' "$matches" | rg -v '^nosqlite/lib/api/db_async\.uya:' || true)"
    if [ -n "$bad_matches" ]; then
        echo "unexpected @async_fn usage outside lib/api/db_async.uya"
        printf '%s\n' "$bad_matches"
        exit 1
    fi
fi

if ! printf '%s\n' "$matches" | rg -q '^nosqlite/lib/api/db_async\.uya:'; then
    echo "expected lib/api/db_async.uya to contain the Phase 12.5 async shell"
    exit 1
fi

echo "phase12.5 async boundary ok"
