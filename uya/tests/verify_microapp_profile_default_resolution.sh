#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_C="$(mktemp /tmp/verify_microapp_profile_default.XXXXXX.c)"
BUILD_LOG="$(mktemp /tmp/verify_microapp_profile_default.XXXXXX.build.log)"

cleanup() {
    rm -f "$OUT_C" "$BUILD_LOG"
}
trap cleanup EXIT

env -u MICROAPP_TARGET_PROFILE -u MICROAPP_TARGET_ARCH \
    TARGET_OS=macos TARGET_ARCH=arm64 \
    "$ROOT_DIR/bin/uya" build --app microapp \
    examples/microapp/microcontainer_hello_source.uya \
    -o "$OUT_C" >"$BUILD_LOG" 2>&1

grep -q '信息：microapp active profile=macos_arm64_hardvm, bridge=call_gate, target_os=macos, 目标架构=aarch64' "$BUILD_LOG"
test -s "$OUT_C"

echo "microapp profile default resolution ok"
