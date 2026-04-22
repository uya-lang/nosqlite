#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <output.c> <output.bin> [extra_c_file]" >&2
    exit 2
fi

output_file=$1
exe_file=$2
extra_c_file=${3-}
sidecar_file="${output_file}imports.sh"
link_log_file="${exe_file}.link.log"
cc_bin=${CC:-gcc}

rm -f "$link_log_file"

set -- "$cc_bin" --std=c99 -nostartfiles -no-pie "$output_file"
if [ -n "$extra_c_file" ]; then
    set -- "$@" "$extra_c_file"
fi

if [ -f "$sidecar_file" ]; then
    # shellcheck disable=SC1090
    . "$sidecar_file"
    ci=0
    while [ "$ci" -lt "${UYA_CIMPORT_COUNT:-0}" ]; do
        src_var="UYA_CIMPORT_SRC_${ci}"
        cflag_count_var="UYA_CIMPORT_CFLAGC_${ci}"
        src_path="${!src_var}"
        cflag_count="${!cflag_count_var:-0}"
        obj_path="${exe_file}.cimport.${ci}.o"

        set -- "$cc_bin" --std=c99 -c
        cj=0
        while [ "$cj" -lt "$cflag_count" ]; do
            cflag_var="UYA_CIMPORT_CFLAG_${ci}_${cj}"
            cflag_token="${!cflag_var}"
            set -- "$@" "$cflag_token"
            cj=$((cj + 1))
        done
        set -- "$@" "$src_path" -o "$obj_path"
        "$@" >/dev/null 2>>"$link_log_file" || exit 1

        set -- "$cc_bin" --std=c99 -nostartfiles -no-pie "$output_file"
        if [ -n "$extra_c_file" ]; then
            set -- "$@" "$extra_c_file"
        fi
        ck=0
        while [ "$ck" -le "$ci" ]; do
            set -- "$@" "${exe_file}.cimport.${ck}.o"
            ck=$((ck + 1))
        done
        ci=$((ci + 1))
    done

    ldflag_count=${UYA_CIMPORT_LDFLAGC:-0}
    li=0
    while [ "$li" -lt "$ldflag_count" ]; do
        ldflag_var="UYA_CIMPORT_LDFLAG_${li}"
        ldflag_token="${!ldflag_var}"
        set -- "$@" "$ldflag_token"
        li=$((li + 1))
    done
fi

set -- "$@" -o "$exe_file"
"$@" >/dev/null 2>>"$link_log_file" || exit 1
rm -f "$link_log_file"
