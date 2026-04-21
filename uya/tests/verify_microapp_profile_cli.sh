#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POBJ="$(mktemp /tmp/verify_microapp_profile_cli.XXXXXX.pobj)"
INSPECT_LOG="$(mktemp /tmp/verify_microapp_profile_cli.XXXXXX.log)"
HELP_LOG="$(mktemp /tmp/verify_microapp_profile_help.XXXXXX.log)"

cleanup() {
    rm -f "$POBJ" "$INSPECT_LOG" "$HELP_LOG"
}
trap cleanup EXIT

MICROAPP_TARGET_PROFILE=rv32_baremetal_softvm \
TARGET_GCC=x86_64-linux-gnu-gcc \
MICROAPP_TARGET_ARCH=x86_64 \
"$ROOT_DIR/bin/uya" build --app microapp --microapp-profile linux_x86_64_hardvm examples/microapp/microcontainer_hello_source.uya -o "$POBJ" >/tmp/verify_microapp_profile_cli_build.log 2>&1

"$ROOT_DIR/bin/uya" inspect-image "$POBJ" >"$INSPECT_LOG" 2>&1

grep -q '^kind=pobj$' "$INSPECT_LOG"
grep -q '^target_arch=x86_64$' "$INSPECT_LOG"
grep -q '^profile=linux_x86_64_hardvm$' "$INSPECT_LOG"
grep -q '^bridge=call_gate$' "$INSPECT_LOG"

"$ROOT_DIR/bin/uya" --help >"$HELP_LOG" 2>&1 || true
grep -q 'MICROAPP_TARGET_PROFILE=linux_x86_64_hardvm' "$HELP_LOG"
grep -q 'TARGET_OS/TARGET_ARCH  未显式指定 profile 时' "$HELP_LOG"
grep -q '默认 profile 推导优先级：--microapp-profile > MICROAPP_TARGET_PROFILE' "$HELP_LOG"

echo "microapp profile cli ok"
