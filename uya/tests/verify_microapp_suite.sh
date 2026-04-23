#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SCRIPTS=(
    "tests/verify_microapp_mode_gate.sh"
    "tests/verify_microapp_mmu_codegen.sh"
    "tests/verify_microapp_loader_generic.sh"
    "tests/verify_microapp_syscall_codegen.sh"
    "tests/verify_microapp_image_contracts.sh"
    "tests/verify_microapp_pobj_manifest.sh"
    "tests/verify_microapp_pack_image.sh"
    "tests/verify_microapp_build_uapp.sh"
    "tests/verify_microapp_uapp_compat.sh"
    "tests/verify_microapp_profile_cli.sh"
    "tests/verify_microapp_profile_default_resolution.sh"
    "tests/verify_microapp_profile_example_matrix.sh"
    "tests/verify_microapp_macos_profile_guard.sh"
    "tests/verify_microapp_macos_object_extract.sh"
    "tests/verify_microapp_macos_arm64_hosted_runtime.sh"
    "tests/verify_microapp_aarch64_object_extract.sh"
    "tests/verify_microapp_portable_sources.sh"
    "tests/verify_microapp_example_boundary.sh"
    "tests/verify_microapp_example_sources_runtime.sh"
    "tests/verify_microapp_example_codegen.sh"
    "tests/verify_microapp_host_api_diagnostics.sh"
    "tests/verify_microapp_alloc_yield_runtime.sh"
    "tests/verify_microapp_time_runtime.sh"
    "tests/verify_microapp_bss_manifest.sh"
    "tests/verify_microapp_bss_runtime.sh"
    "tests/verify_microapp_reloc_runtime.sh"
    "tests/verify_microapp_reloc_data_runtime.sh"
    "tests/verify_microapp_exit_code_runtime.sh"
    "tests/verify_microapp_fault_runtime.sh"
    "tests/verify_microapp_trap_bridge_result.sh"
    "tests/verify_microapp_trap_runtime.sh"
    "tests/verify_microapp_aarch64_hosted_runtime.sh"
    "tests/verify_microapp_loader_unwired_profile.sh"
    "tests/verify_microapp_recovery_update.sh"
)

for rel in "${SCRIPTS[@]}"; do
    echo "==> $(basename "$rel")"
    env -u CC \
        -u CC_DRIVER \
        -u CC_TARGET_FLAGS \
        -u CFLAGS \
        -u LDFLAGS \
        -u HOST_OS \
        -u HOST_ARCH \
        -u TARGET_OS \
        -u TARGET_ARCH \
        -u TARGET_TRIPLE \
        -u TOOLCHAIN \
        -u UYA_TEST_JOBS \
        "$ROOT_DIR/$rel"
done

echo "microapp suite ok"
