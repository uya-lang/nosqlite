#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

COMPILER="$ROOT/bin/uya"
LINKER="$ROOT/tests/link_cimports_posix.sh"
export UYA_ROOT="${ROOT}/lib/"

mkdir -p "$TMP/option_dep"

cat >"$TMP/option_dep/option_dep.uya" <<'EOF'
use std.core.option.Option;

export struct Event {
    kind: i32,
    value: i32,
}

export fn make_event(kind: i32, value: i32) Event {
    return Event{ kind: kind, value: value };
}

export fn maybe_event(kind: i32) Option<Event> {
    if kind < 0 {
        return Option<Event>.None();
    }
    return Option<Event>.Some(make_event(kind, kind + 1));
}
EOF

cat >"$TMP/option_main.uya" <<'EOF'
use option_dep.Event;
use option_dep.maybe_event;
use std.core.option.Option;
use std.testing.assert_eq_i32;
use std.testing.test_suite_begin;
use std.testing.test_suite_end;
use std.testing.run_test;

fn test_cross_module_option_struct() !void {
    const evt: Option<Event> = maybe_event(4);
    var out: i32 = -1;
    match evt {
        .Some(v) => { out = v.value; },
        .None(_) => { out = -1; },
    };
    try assert_eq_i32(out, 5);
}

export fn main() i32 {
    test_suite_begin("GUI Fixlist Codegen");
    run_test("cross module option struct", test_cross_module_option_struct);
    return test_suite_end();
}
EOF

"$COMPILER" --c99 --nostdlib "$TMP/option_dep/option_dep.uya" "$TMP/option_main.uya" -o "$TMP/option_struct.c"
CC=gcc "$LINKER" "$TMP/option_struct.c" "$TMP/option_struct"
"$TMP/option_struct" >/dev/null

"$COMPILER" build "$ROOT/tests/test_option_struct.uya" --split-c-dir "$TMP/split" -o "$TMP/split_option" --c99
"$TMP/split_option" >/dev/null

"$COMPILER" build "$ROOT/tests/test_async_future_void_codegen.uya" --no-split-c -o "$TMP/async_future_void" --c99
"$TMP/async_future_void" >/dev/null

"$COMPILER" build "$ROOT/tests/test_async_future_void_codegen.uya" --split-c-dir "$TMP/async_future_void_split" -o "$TMP/async_future_void_split_bin" --c99
"$TMP/async_future_void_split_bin" >/dev/null

"$COMPILER" build "$ROOT/tests/test_generic_async_function_codegen.uya" --no-split-c -o "$TMP/generic_async_function" --c99
"$TMP/generic_async_function" >/dev/null

"$COMPILER" build "$ROOT/tests/test_method_call_in_callback_codegen.uya" --no-split-c -o "$TMP/method_call_in_callback" --c99
"$TMP/method_call_in_callback" >/dev/null

"$COMPILER" --c99 --nostdlib "$ROOT/tests/test_const_receiver_codegen.uya" -o "$TMP/const_receiver.c"
gcc --std=c99 -Werror=discarded-qualifiers -c "$TMP/const_receiver.c" -o "$TMP/const_receiver.o"

"$COMPILER" --c99 --nostdlib "$ROOT/tests/test_interface_global_init.uya" -o "$TMP/interface_global.c"
CC=gcc "$LINKER" "$TMP/interface_global.c" "$TMP/interface_global"
"$TMP/interface_global" >/dev/null

"$COMPILER" --c99 --nostdlib "$ROOT/tests/test_interface_field_init.uya" -o "$TMP/interface_field.c"
CC=gcc "$LINKER" "$TMP/interface_field.c" "$TMP/interface_field"
"$TMP/interface_field" >/dev/null

mkdir -p "$TMP/enum_a" "$TMP/enum_b"

cat >"$TMP/enum_a/text_align.uya" <<'EOF'
export enum TextAlign {
    Left,
    Right,
}
EOF

cat >"$TMP/enum_b/text_align.uya" <<'EOF'
export enum TextAlign {
    Top,
    Bottom,
}
EOF

cat >"$TMP/enum_main.uya" <<'EOF'
use enum_a.text_align.TextAlign as ATextAlign;
use enum_b.text_align.TextAlign as BTextAlign;
use std.testing.assert_eq_i32;
use std.testing.test_suite_begin;
use std.testing.test_suite_end;
use std.testing.run_test;

fn test_cross_module_enum_name_collision() !void {
    const a: ATextAlign = ATextAlign.Right;
    const b: BTextAlign = BTextAlign.Bottom;
    try assert_eq_i32(a as i32, 1);
    try assert_eq_i32(b as i32, 1);
}

export fn main() i32 {
    test_suite_begin("GUI Fixlist Enum");
    run_test("cross module enum collision", test_cross_module_enum_name_collision);
    return test_suite_end();
}
EOF

"$COMPILER" --c99 --nostdlib \
    "$TMP/enum_a/text_align.uya" \
    "$TMP/enum_b/text_align.uya" \
    "$TMP/enum_main.uya" \
    -o "$TMP/enum_collision.c"
CC=gcc "$LINKER" "$TMP/enum_collision.c" "$TMP/enum_collision"
"$TMP/enum_collision" >/dev/null

cat >"$TMP/driver_min.uya" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

mkdir -p "$TMP/driver_project"

(
    cd "$TMP/driver_project"
    "$COMPILER" build "$TMP/driver_min.uya" --no-split-c -o build/app --c99
    ./build/app >/dev/null
)

(
    cd "$TMP/driver_project"
    "$COMPILER" build "$TMP/driver_min.uya" --split-c-dir .uyacache -o build/app_split --c99
    ./build/app_split >/dev/null
)

echo "verify_gui_fixlist_codegen: ok"
