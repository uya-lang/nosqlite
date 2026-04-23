#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya"
OUT_C="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.c)"
OUT_POBJ="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.pobj)"
OUT_UAPP="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.uapp)"
C_LOG="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.c.log)"
POBJ_LOG="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.pobj.log)"
UAPP_LOG="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.uapp.log)"
RUN_LOG="$(mktemp /tmp/verify_microapp_macos_profile.XXXXXX.run.log)"

cleanup() {
    rm -f "$OUT_C" "$OUT_POBJ" "$OUT_UAPP" "$C_LOG" "$POBJ_LOG" "$UAPP_LOG" "$RUN_LOG"
}
trap cleanup EXIT

dump_log_and_fail() {
    local title="$1"
    local path="$2"
    echo "✗ $title"
    if [ -f "$path" ]; then
        echo "--- $path ---"
        cat "$path"
    fi
    exit 1
}

"$ROOT_DIR/bin/uya" build --app microapp --microapp-profile macos_arm64_hardvm \
    "$SOURCE" -o "$OUT_C" >"$C_LOG" 2>&1
grep -q '信息：microapp active profile=macos_arm64_hardvm' "$C_LOG" || dump_log_and_fail "macos profile 输出 .c 未命中 profile" "$C_LOG"

set +e
"$ROOT_DIR/bin/uya" build --app microapp --microapp-profile macos_arm64_hardvm \
    "$SOURCE" -o "$OUT_POBJ" >"$POBJ_LOG" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
    dump_log_and_fail "macos_arm64_hardvm 不应静默产出 .pobj" "$POBJ_LOG"
fi
grep -q "错误: microapp macos arm64 目标 gcc 未产出可识别的 Mach-O 对象文件" "$POBJ_LOG" \
    || dump_log_and_fail "macos_arm64_hardvm .pobj 未输出明确 Mach-O 诊断" "$POBJ_LOG"

set +e
"$ROOT_DIR/bin/uya" build --app microapp --microapp-profile macos_arm64_hardvm \
    "$SOURCE" -o "$OUT_UAPP" >"$UAPP_LOG" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
    dump_log_and_fail "macos_arm64_hardvm 不应静默产出 .uapp" "$UAPP_LOG"
fi
grep -q "错误: microapp macos arm64 目标 gcc 未产出可识别的 Mach-O 对象文件" "$UAPP_LOG" \
    || dump_log_and_fail "macos_arm64_hardvm .uapp 未输出明确 Mach-O 诊断" "$UAPP_LOG"

set +e
"$ROOT_DIR/bin/uya" run --app microapp --microapp-profile macos_arm64_hardvm \
    "$SOURCE" >"$RUN_LOG" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
    dump_log_and_fail "macos_arm64_hardvm 不应静默执行 run" "$RUN_LOG"
fi
grep -q "错误: microapp profile 'macos_arm64_hardvm' 当前尚未接线 run --app microapp 运行时" "$RUN_LOG" \
    || dump_log_and_fail "macos_arm64_hardvm run 未输出明确运行时诊断" "$RUN_LOG"

echo "microapp macos profile guard ok"
