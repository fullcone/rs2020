#!/bin/sh
# package-redstone-hardware-handoff.sh - Collect Redstone stage-1 bench files.
set -eu

TOPDIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
EDGENOS_BOARD=${EDGENOS_BOARD:-redstone}
export EDGENOS_BOARD
. "$TOPDIR/scripts/board-env.sh"

OUTDIR=${REDSTONE_HANDOFF_OUTDIR:-"$TOPDIR/output/redstone-handoff"}
PACKAGE=${REDSTONE_HANDOFF_PACKAGE:-"$TOPDIR/output/redstone-stage1-hardware-handoff.tar.gz"}
IMAGE_DIR="$TOPDIR/output/images"
KERNEL_DIR="$TOPDIR/output/kernel"
BDE_DIR="$TOPDIR/output/openbcm-bde"
INIT_DIR="$TOPDIR/output/openbcm-init"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 [package|print-env]

Environment:
  EDGENOS_BOARD              must resolve to redstone
  REDSTONE_HANDOFF_OUTDIR    output directory, default output/redstone-handoff
  REDSTONE_HANDOFF_PACKAGE   tarball path, default output/redstone-stage1-hardware-handoff.tar.gz
EOF
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing required file: $1"
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        fail "sha256sum or shasum is required to write the handoff manifest"
    fi
}

file_size() {
    wc -c < "$1" | tr -d ' '
}

copy_file() {
    src=$1
    dst=$2
    require_file "$src"
    cp -p "$src" "$dst"
}

safe_prepare_outdir() {
    top_real=$(cd "$TOPDIR" && pwd -P)
    output_real=$(cd "$TOPDIR/output" && pwd -P)
    out_parent=$(dirname "$OUTDIR")
    out_base=$(basename "$OUTDIR")

    mkdir -p "$out_parent"
    out_parent_real=$(cd "$out_parent" && pwd -P)
    out_real="$out_parent_real/$out_base"

    case "$out_real" in
        "$output_real"/*)
            ;;
        *)
            fail "handoff output directory must stay under $top_real/output: $OUTDIR"
            ;;
    esac

    rm -rf "$out_real"
    mkdir -p \
        "$out_real/bench-results" \
        "$out_real/images" \
        "$out_real/openbcm-bde" \
        "$out_real/openbcm-init" \
        "$out_real/host-tools"
    OUTDIR=$out_real
}

write_runbook() {
    git_head=$1
    generated_utc=$2

    cat > "$OUTDIR/RUNBOOK.md" <<EOF
# Redstone Stage-1 Hardware Handoff

Generated at: $generated_utc
Git head: $git_head

This package is for the stage-1 acceptance target only: boot, BCM56846
detection, one front-panel link up, and one ping through the ASIC. It does not
prove L3 routing, ACL, ECMP, or full hardware offload.

## Files

- images/$EDGENOS_IMAGE_NAME
- images/rootfs.sqsh
- images/$EDGENOS_DTS_BASENAME.dtb
- openbcm-bde/linux-kernel-bde.ko
- openbcm-bde/linux-user-bde.ko
- openbcm-bde/redstone-openbcm-bde-smoke.sh
- openbcm-bde/redstone-openbcm-bde.manifest
- openbcm-init/redstone-openbcm-init-probe
- openbcm-init/redstone-openbcm-init-probe.manifest
- host-tools/analyze-redstone-stage1-evidence.sh
- host-tools/analyze-redstone-handoff-capture.sh
- host-tools/analyze-redstone-platform-inventory.sh
- host-tools/verify-redstone-hardware-handoff.sh
- host-tools/prepare-redstone-bench-note.sh
- bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md

## First Hardware Boot Policy

Do not overwrite internal flash, NAND, NOR, or saved U-Boot environment during
the first Redstone stage-1 hardware run. First prove the serial console,
temporary external boot path, BCM56846 PCIe evidence, one front-panel link, and
one peer ping. Keep the known-good R0678 recovery USB available before changing
anything persistent.

This package contains images/$EDGENOS_IMAGE_NAME. That file is an ONIE-style
installer payload, not a raw USB disk image. It should not be written directly
to a USB stick for the Redstone U-Boot 2009.11 path. The existing R0678
General UDisk 4G recovery image is an old-system USB recovery artifact, not the
Redstone EdgeNOS stage-1 image.

To build the separate non-destructive Redstone USB stage-1 boot/capture raw
disk image from the source tree, run:

EDGENOS_BOARD=redstone make redstone-usb-stage1-check
sudo EDGENOS_BOARD=redstone make redstone-usb-stage1
EDGENOS_BOARD=redstone make redstone-usb-stage1-verify

The Makefile target invokes scripts/package-redstone-usb-stage1.sh, which can
also be run directly from the tree. It writes
output/images/redstone-usb-stage1-boot-capture.img plus hash, fdisk, boot-file,
and data-file sidecars. The USB image uses the verified R0678 shape: partition 1
is FAT16 type 0x06 label REDBOOT for U-Boot files; partition 2 is ext2 type
0x83 label REDCF for capture material and handoff files. It is still external
boot/capture media only and does not flash internal storage.

The redstone-usb-stage1-verify target is host-side and read-only. It checks the
raw image size, hash sidecars, fdisk sidecar, and FAT/data file inventories
before any Windows guarded-write step.

Use temporary U-Boot commands first and do not run saveenv until manual external
boot succeeds:

usb stop
usb reset
usb storage
fatls usb 0:1 /

Temporary USB boot command shape for the verified R0678 recovery layout:

usb stop
usb reset
usb storage
fatls usb 0:1 /
fatload usb 0:1 1000000 uImage-powerpc.itb
bootm 1000000#accton_as5610_52x

Legacy split-boot command shape from the verified R0678 recovery layout:

usb stop
usb reset
setenv bootargs root=/dev/ram rw console=ttyS0,115200 ramdisk_size=3000000 cache-sram-size=0x10000
fatload usb 0:1 1000000 uImage
fatload usb 0:1 c00000 p2020rdb.dtb
fatload usb 0:1 2000000 rootfs.ext2.gz.uboot
bootm 1000000 2000000 c00000

After the system boots, collect capture-only diagnostics and return the printed
bundle or evidence path plus the full serial console log before attempting any
persistent install.

## Optional ONIE Install

Use this only if the hardware is intentionally booted into ONIE and the bench
operator has decided to perform a persistent install after the external boot
capture proves the stage-1 path:

onie-nos-install http://SERVER/$EDGENOS_IMAGE_NAME

## First Boot Capture

cat /etc/edgenos/board
redstone-stage1-bench-run --capture-only

The capture above writes an evidence directory and, when tar is available, a
validation bundle. It is useful for inventory and smoke triage, but it is not stage-1 acceptance.
The embedded capture is verbose and includes a top-level capture-summary.txt,
run metadata, command availability, full and focused dmesg, PCI driver/resource
details, BCM/BDE module metadata, BDE device nodes, switchd service/journal
state, netdev counters, ethtool output, passive I2C topology, DT properties,
and EEPROM/CPLD/hwmon/thermal/LED/platform sysfs snapshots.

If you need a standalone diagnostic package without the validator wrapper:

redstone-stage1-capture --verbose

Run active I2C bus scans only on a bench system where probing every detected
bus is acceptable:

redstone-stage1-capture --verbose --scan-i2c

Strict acceptance requires an explicit Redstone front-panel interface and an
actual peer IP on the bench link:

REDSTONE_IFACE=swpN
REDSTONE_LOCAL_CIDR=192.0.2.1/24
REDSTONE_PEER=192.0.2.2

redstone-stage1-bench-run --iface "\$REDSTONE_IFACE" --local-cidr "\$REDSTONE_LOCAL_CIDR" --peer "\$REDSTONE_PEER"

The bench runner preserves the validator output and then prints the returned
validation bundle or evidence directory path together with the host analysis
command below.

## Host Analysis

Use the validation bundle or evidence directory printed by the strict validation
run. This verifies the handoff, checks strict stage-1 acceptance evidence, and
prints a Redstone DTS/platform inventory matrix for follow-up work:

./host-tools/analyze-redstone-handoff-capture.sh . PATH_TO_VALIDATION_BUNDLE_OR_DIR

## Bench Result Note

Create one completed result note per hardware run outside this verified handoff
directory and keep it with the returned validation bundle and console log:

./host-tools/prepare-redstone-bench-note.sh . "\${REDSTONE_RESULT_DIR:-../redstone-bench-results}"

Do not write per-run notes into this handoff directory. The manifest verifier
rejects files that are not listed in MANIFEST.txt. The helper above refuses
destinations inside this handoff directory.

## Optional OpenBCM BDE Smoke

Run this only on the Redstone bench system:

cd openbcm-bde
./redstone-openbcm-bde-smoke.sh --strict --capture

## Reset-Risk-Gated Init Probe

Run the dry-run path first:

redstone-openbcm-init-probe --dry-run

Only after BDE smoke evidence succeeds on Redstone, run the exec path in an
accepted reset-risk bench session:

redstone-openbcm-init-probe --exec --i-accept-hardware-reset-risk
EOF
}

write_manifest() {
    manifest=$OUTDIR/MANIFEST.txt
    git_head=$1
    generated_utc=$2

    {
        echo "board=$EDGENOS_BOARD"
        echo "image_name=$EDGENOS_IMAGE_NAME"
        echo "dtb_name=$EDGENOS_DTS_BASENAME.dtb"
        echo "git_head=$git_head"
        echo "generated_utc=$generated_utc"
        echo ""
        echo "files:"
    } > "$manifest"

    find "$OUTDIR" -type f ! -name MANIFEST.txt | sort | while IFS= read -r path; do
        rel=${path#"$OUTDIR"/}
        size=$(file_size "$path")
        sha=$(sha256_file "$path")
        printf '%s  bytes=%s  sha256=%s\n' "$rel" "$size" "$sha" >> "$manifest"
    done
}

package() {
    [ "$EDGENOS_BOARD" = "redstone" ] || \
        fail "EDGENOS_BOARD must resolve to redstone, got $EDGENOS_BOARD"

    require_file "$IMAGE_DIR/$EDGENOS_IMAGE_NAME"
    require_file "$IMAGE_DIR/rootfs.sqsh"
    require_file "$KERNEL_DIR/$EDGENOS_DTS_BASENAME.dtb"
    require_file "$BDE_DIR/linux-kernel-bde.ko"
    require_file "$BDE_DIR/linux-user-bde.ko"
    require_file "$BDE_DIR/redstone-openbcm-bde-smoke.sh"
    require_file "$BDE_DIR/redstone-openbcm-bde.manifest"
    require_file "$INIT_DIR/redstone-openbcm-init-probe"
    require_file "$INIT_DIR/redstone-openbcm-init-probe.manifest"
    require_file "$TOPDIR/scripts/analyze-redstone-stage1-evidence.sh"
    require_file "$TOPDIR/scripts/analyze-redstone-handoff-capture.sh"
    require_file "$TOPDIR/scripts/analyze-redstone-platform-inventory.sh"
    require_file "$TOPDIR/scripts/verify-redstone-hardware-handoff.sh"
    require_file "$TOPDIR/scripts/prepare-redstone-bench-note.sh"
    require_file "$TOPDIR/docs/redstone_bench_result_template.md"

    REQUIRE_OPENBCM_INIT_PROBE=1 \
        "$TOPDIR/scripts/check-redstone-image.sh" --squashfs "$IMAGE_DIR/rootfs.sqsh"

    safe_prepare_outdir

    copy_file "$IMAGE_DIR/$EDGENOS_IMAGE_NAME" "$OUTDIR/images/$EDGENOS_IMAGE_NAME"
    copy_file "$IMAGE_DIR/rootfs.sqsh" "$OUTDIR/images/rootfs.sqsh"
    copy_file "$KERNEL_DIR/$EDGENOS_DTS_BASENAME.dtb" "$OUTDIR/images/$EDGENOS_DTS_BASENAME.dtb"
    copy_file "$BDE_DIR/linux-kernel-bde.ko" "$OUTDIR/openbcm-bde/linux-kernel-bde.ko"
    copy_file "$BDE_DIR/linux-user-bde.ko" "$OUTDIR/openbcm-bde/linux-user-bde.ko"
    copy_file "$BDE_DIR/redstone-openbcm-bde-smoke.sh" "$OUTDIR/openbcm-bde/redstone-openbcm-bde-smoke.sh"
    copy_file "$BDE_DIR/redstone-openbcm-bde.manifest" "$OUTDIR/openbcm-bde/redstone-openbcm-bde.manifest"
    copy_file "$INIT_DIR/redstone-openbcm-init-probe" "$OUTDIR/openbcm-init/redstone-openbcm-init-probe"
    copy_file "$INIT_DIR/redstone-openbcm-init-probe.manifest" "$OUTDIR/openbcm-init/redstone-openbcm-init-probe.manifest"
    copy_file "$TOPDIR/scripts/analyze-redstone-stage1-evidence.sh" \
        "$OUTDIR/host-tools/analyze-redstone-stage1-evidence.sh"
    copy_file "$TOPDIR/scripts/analyze-redstone-handoff-capture.sh" \
        "$OUTDIR/host-tools/analyze-redstone-handoff-capture.sh"
    copy_file "$TOPDIR/scripts/analyze-redstone-platform-inventory.sh" \
        "$OUTDIR/host-tools/analyze-redstone-platform-inventory.sh"
    copy_file "$TOPDIR/scripts/verify-redstone-hardware-handoff.sh" \
        "$OUTDIR/host-tools/verify-redstone-hardware-handoff.sh"
    copy_file "$TOPDIR/scripts/prepare-redstone-bench-note.sh" \
        "$OUTDIR/host-tools/prepare-redstone-bench-note.sh"
    copy_file "$TOPDIR/docs/redstone_bench_result_template.md" \
        "$OUTDIR/bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md"

    git_head=unknown
    if command -v git >/dev/null 2>&1; then
        git_head=$(git -C "$TOPDIR" rev-parse HEAD 2>/dev/null || echo unknown)
    fi
    generated_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    write_runbook "$git_head" "$generated_utc"
    write_manifest "$git_head" "$generated_utc"

    package_parent=$(dirname "$PACKAGE")
    package_base=$(basename "$PACKAGE")
    mkdir -p "$package_parent"
    package_parent_real=$(cd "$package_parent" && pwd -P)
    out_parent_real=$(cd "$(dirname "$OUTDIR")" && pwd -P)
    out_base=$(basename "$OUTDIR")

    tar -C "$out_parent_real" -czf "$package_parent_real/$package_base" "$out_base"

    echo "PASS: wrote Redstone hardware handoff directory: $OUTDIR"
    echo "PASS: wrote Redstone hardware handoff package: $package_parent_real/$package_base"
}

case "${1:-package}" in
    package)
        package
        ;;
    print-env)
        printf 'EDGENOS_BOARD=%s\n' "$EDGENOS_BOARD"
        printf 'EDGENOS_IMAGE_NAME=%s\n' "$EDGENOS_IMAGE_NAME"
        printf 'EDGENOS_DTS_BASENAME=%s\n' "$EDGENOS_DTS_BASENAME"
        printf 'OUTDIR=%s\n' "$OUTDIR"
        printf 'PACKAGE=%s\n' "$PACKAGE"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        fail "unknown command: $1"
        ;;
esac
