#!/bin/sh
# Source-tree preflight for the Redstone stage-1 build path.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
BOARD="${1:-${EDGENOS_BOARD:-redstone}}"
FAILURES=0
WARNINGS=0

ok() {
    printf 'ok: %s\n' "$*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf 'warn: %s\n' "$*" >&2
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf 'fail: %s\n' "$*" >&2
}

check_file() {
    rel=$1
    if [ -f "$TOPDIR/$rel" ]; then
        ok "file exists: $rel"
    else
        fail "missing file: $rel"
    fi
}

check_grep() {
    pattern=$1
    rel=$2
    desc=$3

    if grep -Eq -- "$pattern" "$TOPDIR/$rel"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

check_no_regex() {
    pattern=$1
    rel=$2
    desc=$3

    if grep -Eq -- "$pattern" "$TOPDIR/$rel"; then
        fail "$desc"
    else
        ok "$desc"
    fi
}

LOOSE_BCM56846_SOURCE_RE='(grep[[:space:]].*-[^[:space:]]*E|has_text|file_has_text).*(14e4[.][*]|(^|[^[:alnum:]_:])b846([^[:alnum:]_]|$)|(^|[^[:alnum:]_:])56846([^[:alnum:]_]|$))'

check_alias() {
    alias=$1
    result=$(
        TOPDIR="$TOPDIR" EDGENOS_BOARD="$alias" sh -c '
            . "$TOPDIR/scripts/board-env.sh"
            printf "%s|%s|%s\n" "$EDGENOS_BOARD" "$EDGENOS_DTS_BASENAME" "$EDGENOS_IMAGE_NAME"
        '
    )

    case "$result" in
        redstone\|redstone-stage1\|edgenos-redstone-stage1.bin)
            ok "board alias $alias resolves to Redstone stage-1 artifacts"
            ;;
        *)
            fail "board alias $alias resolved unexpectedly: $result"
            ;;
    esac
}

EDGENOS_BOARD="$BOARD"
export EDGENOS_BOARD
. "$TOPDIR/scripts/board-env.sh"

printf 'Redstone stage-1 preflight\n'
printf '  requested board: %s\n' "$BOARD"
printf '  normalized board: %s\n' "$EDGENOS_BOARD"
printf '  DTS source: %s\n' "$EDGENOS_DTS_SOURCE"
printf '  DTB basename: %s\n' "$EDGENOS_DTS_BASENAME"
printf '  image name: %s\n\n' "$EDGENOS_IMAGE_NAME"

if [ "$EDGENOS_BOARD" != "redstone" ]; then
    fail "expected Redstone board selection, got $EDGENOS_BOARD"
fi
if [ "$EDGENOS_DTS_BASENAME" != "redstone-stage1" ]; then
    fail "expected redstone-stage1 DTB basename, got $EDGENOS_DTS_BASENAME"
fi
if [ "$EDGENOS_IMAGE_NAME" != "edgenos-redstone-stage1.bin" ]; then
    fail "expected Redstone image name, got $EDGENOS_IMAGE_NAME"
fi

for alias in redstone rs2020 r0678; do
    check_alias "$alias"
done

check_file "$EDGENOS_DTS_SOURCE"
check_file "$EDGENOS_KERNEL_DEFCONFIG"
check_file "config/bcm/redstone-stage1.bcm"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-capture"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-validate"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run"
check_file "config/rootfs/overlay/usr/sbin/switchd-init"
check_file "config/rootfs/overlay/etc/init.d/S20edgenos"
check_file "config/rootfs/overlay/etc/systemd/system/switchd.service"
check_file "scripts/build-rootfs.sh"
check_file "scripts/build-kernel.sh"
check_file "scripts/build-installer.sh"
check_file "scripts/build-modules.sh"
check_file "scripts/build-all.sh"
check_file "scripts/check-redstone-image.sh"
check_file "scripts/package-redstone-hardware-handoff.sh"
check_file "scripts/package-redstone-usb-stage1.sh"
check_file "scripts/verify-redstone-hardware-handoff.sh"
check_file "scripts/prepare-redstone-bench-note.sh"
check_file "scripts/analyze-redstone-stage1-evidence.sh"
check_file "scripts/analyze-redstone-handoff-capture.sh"
check_file "scripts/analyze-redstone-platform-inventory.sh"
check_file "scripts/analyze-redstone-openbcm-bde-smoke.sh"
check_file "scripts/prepare-openbcm.sh"
check_file "scripts/build-openbcm-bde.sh"
check_file "scripts/redstone-openbcm-bde-smoke.sh"
check_file "scripts/check-openbcm-userland-init.sh"
check_file "scripts/build-openbcm-init-probe.sh"
check_file "scripts/install-openbcm-init-probe.sh"
check_file "asic/openbcm-init/redstone-openbcm-init-probe.c"
check_file "docs/redstone_bench_result_template.md"
check_file "docs/redstone_stage1_plan.md"
check_file "docs/redstone_progress.md"

check_grep 'redstone-stage1\.bcm' "config/rootfs/overlay/usr/sbin/switchd-init" \
    "switchd-init references Redstone stage-1 config"
check_grep 'BR2_powerpc_e500v2=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 e500v2 CPU selection"
check_grep 'BR2_TOOLCHAIN_BUILDROOT_GLIBC=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 glibc"
check_grep 'BR2_INIT_SYSTEMD=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 systemd"
check_grep 'if \[ "\$EDGENOS_BOARD" = "redstone" \]' "scripts/build-rootfs.sh" \
    "build-rootfs gates Redstone rootfs defconfig overrides on selected board"
check_grep 'BR2_powerpc_8548=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone P2020/e500v2 SPE CPU in generated defconfig"
check_grep 'BR2_powerpc_SPE=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone SPE ABI in generated defconfig"
check_grep 'BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone uClibc in generated defconfig"
check_grep 'BR2_INIT_BUSYBOX=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone BusyBox init in generated defconfig"
check_grep 'defconfig\)' "scripts/build-rootfs.sh" \
    "build-rootfs can generate defconfig without running a full Buildroot build"
check_grep 'switchd-init start' "config/rootfs/overlay/etc/init.d/S20edgenos" \
    "BusyBox init starts switchd through switchd-init"
check_grep 'start-foreground' "config/rootfs/overlay/etc/systemd/system/switchd.service" \
    "switchd service uses switchd-init foreground path"
check_grep 'config/rootfs/overlay' "scripts/build-rootfs.sh" \
    "build-rootfs applies the rootfs overlay"
check_grep 'install-openbcm-init-probe\.sh' "scripts/build-rootfs.sh" \
    "build-rootfs installs optional Redstone OpenBCM init probe"
check_grep 'redstone-stage1-bench-run' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone bench runner executable mode"
check_grep 'install-openbcm-init-probe\.sh' "config/rootfs/post-build.sh" \
    "Buildroot post-build installs optional Redstone OpenBCM init probe"
check_grep 'config/rootfs/overlay' "scripts/build-all.sh" \
    "build-all applies the rootfs overlay"
check_grep 'install-openbcm-init-probe\.sh' "scripts/build-all.sh" \
    "build-all installs required Redstone OpenBCM init probe before squashfs packing"
check_grep '--squashfs' "scripts/check-redstone-image.sh" \
    "image checker can verify packed rootfs.sqsh contents"
check_grep 'redstone-stage1-bench-run' "scripts/check-redstone-image.sh" \
    "image checker requires the Redstone bench runner"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/build-installer.sh" \
    "build-installer checks Redstone rootfs.sqsh before packaging"
check_grep 'REQUIRE_OPENBCM_INIT_PROBE="\$\{REQUIRE_OPENBCM_INIT_PROBE:-0\}"' \
    "scripts/build-installer.sh" \
    "build-installer keeps OpenBCM init probe optional by default"
check_no_regex 'REQUIRE_OPENBCM_INIT_PROBE="\$\{REQUIRE_OPENBCM_INIT_PROBE:-1\}"' \
    "scripts/build-installer.sh" \
    "build-installer does not force OpenBCM init probe in default image builds"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/build-all.sh" \
    "build-all checks Redstone rootfs.sqsh before packaging"
check_grep 'redstone-stage1-hardware-handoff\.tar\.gz' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package writes a stable tarball name"
check_grep 'First Hardware Boot Policy' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook starts with a non-destructive first-boot policy"
check_grep 'Do not overwrite internal flash' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook blocks first-run internal flash writes"
check_grep 'not a raw USB disk image' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook distinguishes ONIE payload from raw USB images"
check_grep 'package-redstone-usb-stage1\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook points to the USB stage-1 image builder"
check_grep 'redstone-usb-stage1-boot-capture\.img' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder writes a stable raw image name"
check_grep 'FAT16 type 0x06' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder documents FAT16 U-Boot partition"
check_grep 'type=6, bootable' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder creates bootable FAT16 partition"
check_grep 'Do not run saveenv' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder preserves U-Boot environment"
check_grep 'fatload usb 0:1 1000000 uImage-powerpc\.itb' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder readme uses FIT boot from FAT"
check_grep 'bootm 1000000#\$FIT_CONFIG' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder readme boots the selected FIT config"
check_grep 'Optional ONIE Install' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook keeps ONIE install optional after external boot proof"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package verifies packed rootfs.sqsh"
check_grep 'verify-redstone-hardware-handoff\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles host manifest verifier"
check_grep 'analyze-redstone-handoff-capture\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles combined host capture analyzer"
check_grep 'host-tools/analyze-redstone-platform-inventory\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the platform inventory analyzer"
check_grep 'bench-results/REDSTONE-BENCH-RESULT-TEMPLATE\.md' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the bench result template"
check_grep 'host-tools/prepare-redstone-bench-note\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the bench note helper"
check_grep 'prepare-redstone-bench-note\.sh[[:space:]]+[.]' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook uses the bench note helper"
check_grep 'REDSTONE_RESULT_DIR' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook writes per-run bench notes outside the verified package"
check_no_regex 'cp[[:space:]]+bench-results/REDSTONE-BENCH-RESULT-TEMPLATE[.]md[[:space:]]+bench-results/' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook does not add per-run notes into the verified package"
check_grep 'refusing to write bench notes inside the manifest-verified handoff directory' \
    "scripts/prepare-redstone-bench-note.sh" \
    "bench note helper refuses handoff-internal result paths"
check_grep 'bench-results/REDSTONE-BENCH-RESULT-TEMPLATE\.md' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the bench result template"
check_grep 'host-tools/analyze-redstone-handoff-capture\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the combined host capture analyzer"
check_grep 'host-tools/analyze-redstone-platform-inventory\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the platform inventory analyzer"
check_grep 'host-tools/prepare-redstone-bench-note\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the bench note helper"
check_grep 'analyze-redstone-handoff-capture\.sh[[:space:]]+[.][[:space:]]+PATH_TO_VALIDATION_BUNDLE_OR_DIR' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook verifies handoff and validation bundle through one host command"
check_grep 'Stage-1 accepted: yes/no' \
    "docs/redstone_bench_result_template.md" \
    "bench result template records the stage-1 acceptance decision"
check_grep 'Strict validation bundle or directory' \
    "docs/redstone_bench_result_template.md" \
    "bench result template records strict validation evidence"
check_grep 'First Hardware Run Order' \
    "docs/redstone_stage1_plan.md" \
    "stage plan documents first hardware run order"
check_grep 'redstone_usb_uboot_fat_general4g\.img' \
    "docs/redstone_stage1_plan.md" \
    "stage plan references the known-good R0678 recovery USB artifact"
check_grep 'edgenos-redstone-stage1\.bin.*ONIE-style installer payload' \
    "docs/redstone_stage1_plan.md" \
    "stage plan distinguishes the EdgeNOS ONIE payload from raw USB images"
check_grep 'A Redstone USB stage-1 package is a separate deliverable' \
    "docs/redstone_stage1_plan.md" \
    "stage plan keeps the future USB stage-1 package as a separate non-destructive deliverable"
check_grep 'redstone-usb-stage1-boot-capture\.img' \
    "docs/redstone_stage1_plan.md" \
    "stage plan documents the Redstone USB stage-1 raw image path"
check_grep 'verify-redstone-hardware-handoff\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the handoff verifier"
check_grep 'analyze-redstone-stage1-evidence\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the stage-1 evidence analyzer"
check_grep 'analyze-redstone-platform-inventory\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the platform inventory analyzer"
check_grep 'VERIFY_TOOL="\$SCRIPT_DIR/verify-redstone-hardware-handoff\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent verifier"
check_grep 'ANALYZE_TOOL="\$SCRIPT_DIR/analyze-redstone-stage1-evidence\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent evidence analyzer"
check_grep 'PLATFORM_TOOL="\$SCRIPT_DIR/analyze-redstone-platform-inventory\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent platform analyzer"
check_grep 'sh "[$]ANALYZE_TOOL" --strict' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer enforces strict capture analysis"
check_grep 'sh "[$]PLATFORM_TOOL"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs platform inventory after strict analysis"
check_no_regex 'HANDOFF_ROOT|host-tools/verify-redstone-hardware-handoff\.sh|host-tools/analyze-redstone-stage1-evidence\.sh|host-tools/analyze-redstone-platform-inventory\.sh|tar[[:space:]]+-xzf.*HANDOFF' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer avoids executing tools from handoff payloads"
check_grep 'redstone-stage1-bench-run --capture-only' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook includes first-boot capture"
check_grep 'Validation bundle:' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator emits a host-transfer validation bundle path"
check_grep 'capture-evidence' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator embeds capture evidence under its validation output"
check_grep 'Redstone stage-1 capture written to' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator parses the capture evidence path for bundling"
check_grep 'validation bundle' \
    "Makefile" \
    "Makefile documents validation bundle handoff analysis"
check_grep 'not[[:space:]]+stage-1[[:space:]]+acceptance' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook marks smoke capture as non-acceptance"
check_grep 'REDSTONE_IFACE=swpN' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook declares strict interface placeholder"
check_grep 'REDSTONE_PEER=192\.0\.2\.2' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook declares strict peer placeholder"
check_grep 'redstone-stage1-bench-run --iface' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook uses the bench runner for strict acceptance"
check_grep '--local-cidr "\\[$]REDSTONE_LOCAL_CIDR"' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook has the bench runner configure the local CIDR"
check_grep 'redstone-openbcm-bde-smoke\.sh --strict --capture' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook includes BDE smoke capture"
check_grep 'i-accept-hardware-reset-risk' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook keeps init probe exec reset-risk gated"
check_grep 'bundle' "scripts/build-openbcm-bde.sh" \
    "OpenBCM BDE helper can bundle hardware-load artifacts"
check_grep 'redstone-openbcm-bde-smoke\.sh' "scripts/build-openbcm-bde.sh" \
    "OpenBCM BDE bundle includes the hardware smoke helper"
check_grep '14e4:b846' "scripts/redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke helper requires exact BCM56846 PCI ID"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "scripts/redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke helper avoids vendorless lspci matches"
check_grep '14e4:b846' "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "Redstone validator checks exact BCM56846 PCI ID"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "Redstone validator avoids vendorless lspci matches"
check_grep 'has_exact_bcm56846_pci_evidence' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer requires exact BCM56846 PCI ID evidence"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer avoids vendorless PCI ID text matches"
check_grep 'capture-summary\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks expanded capture summary"
check_grep 'run_metadata\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks expanded run metadata"
check_grep 'pci_driver_details\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks PCI driver detail capture"
check_grep 'net_counters\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks net counter capture"
check_grep 'i2c_devices\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks passive I2C topology capture"
check_grep 'openbcm-userland-check' "Makefile" \
    "Makefile exposes OpenBCM userland init source check"
check_grep 'openbcm-bde-smoke-analyze' "Makefile" \
    "Makefile exposes OpenBCM BDE smoke evidence analyzer"
check_grep 'openbcm-init-probe' "Makefile" \
    "Makefile exposes Redstone OpenBCM init probe gate targets"
check_grep 'redstone-handoff' "Makefile" \
    "Makefile exposes Redstone hardware handoff package target"
check_grep 'redstone-handoff-verify' "Makefile" \
    "Makefile exposes Redstone hardware handoff verification target"
check_grep 'redstone-handoff-analyze' "Makefile" \
    "Makefile exposes combined Redstone handoff and capture analysis target"
check_grep 'redstone-platform-inventory-analyze' "Makefile" \
    "Makefile exposes Redstone platform inventory analysis target"
check_grep 'redstone-usb-stage1-check' "Makefile" \
    "Makefile exposes Redstone USB stage-1 prerequisite check target"
check_grep 'redstone-usb-stage1' "Makefile" \
    "Makefile exposes Redstone USB stage-1 image target"
check_grep 'manifest has [$]entry_count file entries' "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier checks manifest entries"
check_grep 'sha256 mismatch' "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier checks file hashes"
check_grep 'loaded OpenBCM linux-kernel-bde.*ko from bundle' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires kernel bundle-load proof"
check_grep 'loaded OpenBCM linux-user-bde.*ko from bundle' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires user bundle-load proof"
check_grep '14e4:b846' "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires exact BCM56846 PCI ID"
check_grep 'vendor=0x14e4.*device=0xb846' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer accepts exact BCM56846 sysfs IDs"
check_grep 'BCM56846_DEVICE_ID' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks BCM56846 source coverage"
check_grep 'bcm_attach' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks SDK attach path"
check_grep 'bcm_l2_addr_add' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks L2 API path"
check_grep '14e4:b846' "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe gates exact BCM56846 PCI ID"
check_grep 'i-accept-hardware-reset-risk' \
    "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe requires explicit hardware reset risk acknowledgement"
check_grep 'BCM_CONFIG_FILE' "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe sets BCM_CONFIG_FILE before demo init execution"
check_grep 'sdk_baseline=openbcm-6\.5\.27' "scripts/build-openbcm-init-probe.sh" \
    "OpenBCM init probe manifest records SDK baseline"
check_grep 'redstone-openbcm-init-probe --dry-run' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records OpenBCM init probe dry-run evidence"
check_grep 'Usage: redstone-stage1-capture \[--scan-i2c\] \[--verbose\]' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture supports verbose progress output for hardware runs"
check_grep 'REDSTONE_CAPTURE_VERBOSE' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture supports a verbose environment override"
check_grep 'run_metadata\.txt' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture writes run metadata for handoff correlation"
check_grep 'capture-summary\.txt' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture writes a top-level triage summary"
check_grep 'capture_shell command_inventory' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records command availability"
check_grep 'capture_shell pci_driver_details' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records PCI driver and resource details"
check_grep 'capture_shell net_counters' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records net counters and ethtool diagnostics"
check_grep 'capture_shell modinfo_bringup' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records module metadata for bring-up drivers"
check_grep 'capture_shell i2c_devices' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records passive I2C device topology"
check_grep 'sys_class_thermal' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records thermal sysfs evidence"
check_grep 'sys_bus_platform_devices' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records platform bus sysfs evidence"
check_grep 'redstone-openbcm-init-probe --dry-run' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator records OpenBCM init probe dry-run evidence"
check_grep 'redstone-stage1-capture --verbose' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator captures verbose hardware diagnostics"
check_grep 'strict requires --iface swpN' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode requires explicit front-panel interface"
check_grep 'strict requires --peer IP' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode requires ping peer"
check_grep 'strict --iface must be a swpN front-panel interface' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode rejects non-swp interface targets"
check_grep 'run_validate --iface "[$]IFACE" --peer "[$]PEER" --ping-count "[$]PING_COUNT" --strict --capture' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner invokes strict validation with capture"
check_grep 'redstone-stage1-validate "[$]@"' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner routes validation through the live validator"
check_grep 'Return validation bundle to the host' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner prints the host-transfer validation bundle path"
check_grep 'analyze-redstone-handoff-capture\.sh' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner prints the combined host analysis command"
check_grep 'REDSTONE_BENCH_VALIDATE_LOG' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner exposes validation log override for diagnostics"
check_grep '--local-cidr' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner supports local CIDR setup"
check_grep 'redstone-openbcm-bde-smoke\.sh' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner can locate the optional OpenBCM BDE smoke helper"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner does not invoke reset-risk init probe exec path"
check_grep 'REQUIRE_OPENBCM_INIT_PROBE' "scripts/check-redstone-image.sh" \
    "image checker can enforce OpenBCM init probe packaging"

portmaps=$(grep -Ec '^portmap_[0-9]+=' "$TOPDIR/config/bcm/redstone-stage1.bcm" || true)
if [ "$portmaps" -eq 52 ]; then
    ok "Redstone port map has 52 front-panel entries"
else
    fail "Redstone port map has $portmaps entries, expected 52"
fi

if command -v sh >/dev/null 2>&1; then
    for script in \
        scripts/board-env.sh \
        scripts/build-rootfs.sh \
        scripts/build-kernel.sh \
        scripts/build-installer.sh \
        scripts/build-modules.sh \
        scripts/build-all.sh \
        scripts/check-redstone-image.sh \
        scripts/package-redstone-hardware-handoff.sh \
        scripts/package-redstone-usb-stage1.sh \
        scripts/verify-redstone-hardware-handoff.sh \
        scripts/prepare-redstone-bench-note.sh \
        scripts/analyze-redstone-stage1-evidence.sh \
        scripts/analyze-redstone-handoff-capture.sh \
        scripts/analyze-redstone-platform-inventory.sh \
        scripts/analyze-redstone-openbcm-bde-smoke.sh \
        scripts/prepare-openbcm.sh \
        scripts/build-openbcm-bde.sh \
        scripts/redstone-openbcm-bde-smoke.sh \
        scripts/check-openbcm-userland-init.sh \
        scripts/build-openbcm-init-probe.sh \
        scripts/install-openbcm-init-probe.sh \
        config/rootfs/post-build.sh \
        config/rootfs/overlay/etc/init.d/S20edgenos \
        config/rootfs/overlay/usr/sbin/redstone-stage1-capture \
        config/rootfs/overlay/usr/sbin/redstone-stage1-validate \
        config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run \
        config/rootfs/overlay/usr/sbin/switchd-init
    do
        if sh -n "$TOPDIR/$script"; then
            ok "shell syntax: $script"
        else
            fail "shell syntax failed: $script"
        fi
    done
fi

if command -v dtc >/dev/null 2>&1; then
    tmp_dtb=$(mktemp)
    if dtc -I dts -O dtb -o "$tmp_dtb" "$TOPDIR/$EDGENOS_DTS_SOURCE"; then
        ok "DTS compiles with dtc: $EDGENOS_DTS_SOURCE"
    else
        fail "DTS compile failed: $EDGENOS_DTS_SOURCE"
    fi
    rm -f "$tmp_dtb"
else
    warn "dtc unavailable; skipped DTS compile check"
fi

if command -v git >/dev/null 2>&1; then
    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-redstone-stage1.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-redstone-stage1.sh is tracked executable"
    else
        fail "check-redstone-stage1.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-modules.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-modules.sh is tracked executable"
    else
        fail "build-modules.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-redstone-image.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-redstone-image.sh is tracked executable"
    else
        fail "check-redstone-image.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/package-redstone-hardware-handoff.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "package-redstone-hardware-handoff.sh is tracked executable"
    else
        fail "package-redstone-hardware-handoff.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/package-redstone-usb-stage1.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "package-redstone-usb-stage1.sh is tracked executable"
    else
        fail "package-redstone-usb-stage1.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/verify-redstone-hardware-handoff.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "verify-redstone-hardware-handoff.sh is tracked executable"
    else
        fail "verify-redstone-hardware-handoff.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/prepare-redstone-bench-note.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "prepare-redstone-bench-note.sh is tracked executable"
    else
        fail "prepare-redstone-bench-note.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-stage1-evidence.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-stage1-evidence.sh is tracked executable"
    else
        fail "analyze-redstone-stage1-evidence.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-handoff-capture.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-handoff-capture.sh is tracked executable"
    else
        fail "analyze-redstone-handoff-capture.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-platform-inventory.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-platform-inventory.sh is tracked executable"
    else
        fail "analyze-redstone-platform-inventory.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-openbcm-bde-smoke.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-openbcm-bde-smoke.sh is tracked executable"
    else
        fail "analyze-redstone-openbcm-bde-smoke.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/prepare-openbcm.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "prepare-openbcm.sh is tracked executable"
    else
        fail "prepare-openbcm.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-openbcm-bde.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-openbcm-bde.sh is tracked executable"
    else
        fail "build-openbcm-bde.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/redstone-openbcm-bde-smoke.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-openbcm-bde-smoke.sh is tracked executable"
    else
        fail "redstone-openbcm-bde-smoke.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-openbcm-userland-init.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-openbcm-userland-init.sh is tracked executable"
    else
        fail "check-openbcm-userland-init.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-openbcm-init-probe.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-openbcm-init-probe.sh is tracked executable"
    else
        fail "build-openbcm-init-probe.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/install-openbcm-init-probe.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "install-openbcm-init-probe.sh is tracked executable"
    else
        fail "install-openbcm-init-probe.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-capture |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-capture is tracked executable"
    else
        fail "redstone-stage1-capture git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-validate |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-validate is tracked executable"
    else
        fail "redstone-stage1-validate git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-bench-run is tracked executable"
    else
        fail "redstone-stage1-bench-run git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/etc/init.d/S20edgenos |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "S20edgenos is tracked executable"
    else
        fail "S20edgenos git mode is ${mode:-missing}, expected 100755"
    fi
else
    warn "git unavailable; skipped executable-mode check"
fi

printf '\n'
if [ "$FAILURES" -ne 0 ]; then
    printf 'Redstone stage-1 preflight failed: %s failure(s), %s warning(s)\n' \
        "$FAILURES" "$WARNINGS" >&2
    exit 1
fi

printf 'Redstone stage-1 preflight passed: %s warning(s)\n' "$WARNINGS"
