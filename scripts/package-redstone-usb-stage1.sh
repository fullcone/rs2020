#!/bin/sh
# Build a non-destructive Redstone USB stage-1 boot/capture image.
#
# The output is a raw USB disk image for first hardware capture. It does not
# flash internal storage, does not run ONIE install, and does not save U-Boot
# environment. The layout follows the locally verified R0678 U-Boot path:
# FAT16 boot partition first, ext2 capture/material partition second.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
BOARD="${EDGENOS_BOARD:-redstone}"
EDGENOS_BOARD="$BOARD"
export EDGENOS_BOARD
. "$TOPDIR/scripts/board-env.sh"

IMAGE="${REDSTONE_USB_STAGE1_IMAGE:-"$TOPDIR/output/images/redstone-usb-stage1-boot-capture.img"}"
WORKDIR="${REDSTONE_USB_STAGE1_WORKDIR:-"$TOPDIR/output/redstone-usb-stage1-work"}"

SECTOR_SIZE=512
IMAGE_BYTES="${REDSTONE_USB_STAGE1_BYTES:-4037017600}"
BOOT_START="${REDSTONE_USB_STAGE1_BOOT_START:-2048}"
BOOT_SECTORS="${REDSTONE_USB_STAGE1_BOOT_SECTORS:-522240}"
DATA_START="${REDSTONE_USB_STAGE1_DATA_START:-524288}"
BOOT_LABEL="${REDSTONE_USB_STAGE1_BOOT_LABEL:-REDBOOT}"
DATA_LABEL="${REDSTONE_USB_STAGE1_DATA_LABEL:-REDCF}"
FIT_CONFIG="${EDGENOS_FIT_CONFIG:-accton_as5610_52x}"

FIT_IMAGE="$TOPDIR/output/images/uImage-powerpc.itb"
ROOTFS_SQSH="$TOPDIR/output/images/rootfs.sqsh"
INSTALLER_IMAGE="$TOPDIR/output/images/$EDGENOS_IMAGE_NAME"
DTB_IMAGE="$TOPDIR/output/kernel/$EDGENOS_DTS_BASENAME.dtb"
KERNEL_UIMAGE="$TOPDIR/output/kernel/uImage"
ROOTFS_UBOOT="$TOPDIR/output/images/rootfs.ext2.gz.uboot"
HANDOFF_TARBALL="$TOPDIR/output/redstone-stage1-hardware-handoff.tar.gz"
HANDOFF_DIR="$TOPDIR/output/redstone-handoff"

BOOT_OFFSET=$((BOOT_START * SECTOR_SIZE))
BOOT_BYTES=$((BOOT_SECTORS * SECTOR_SIZE))
BOOT_END=$((BOOT_START + BOOT_SECTORS))
DATA_OFFSET=$((DATA_START * SECTOR_SIZE))
TOTAL_SECTORS=$((IMAGE_BYTES / SECTOR_SIZE))
DATA_SECTORS=$((TOTAL_SECTORS - DATA_START))
DATA_BYTES=$((IMAGE_BYTES - DATA_OFFSET))
DATA_BLOCKS_4K=$((DATA_BYTES / 4096))

BOOT_MNT="$WORKDIR/mnt-boot"
DATA_MNT="$WORKDIR/mnt-data"
BOOT_MOUNTED=0
DATA_MOUNTED=0

usage() {
    cat <<'USAGE'
usage: EDGENOS_BOARD=redstone scripts/package-redstone-usb-stage1.sh MODE

Modes:
  check       Validate inputs and host tools without writing an image.
  image       Build output/images/redstone-usb-stage1-boot-capture.img.
  print-env   Print resolved image parameters.

Environment:
  REDSTONE_USB_STAGE1_IMAGE        output raw disk image path
  REDSTONE_USB_STAGE1_BYTES        image byte size, default 4037017600
  REDSTONE_USB_STAGE1_BOOT_START   FAT16 partition start sector, default 2048
  REDSTONE_USB_STAGE1_BOOT_SECTORS FAT16 partition sectors, default 522240
  REDSTONE_USB_STAGE1_DATA_START   ext2 partition start sector, default 524288

The image mode mounts loop partitions and usually must run as root, for example:
  sudo EDGENOS_BOARD=redstone scripts/package-redstone-usb-stage1.sh image
USAGE
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'warn: %s\n' "$*" >&2
}

info() {
    printf '%s\n' "$*"
}

require_tool() {
    tool=$1
    if ! command -v "$tool" >/dev/null 2>&1; then
        fail "missing required host tool: $tool"
    fi
}

find_fat_mkfs() {
    if command -v mkfs.vfat >/dev/null 2>&1; then
        printf '%s\n' mkfs.vfat
        return
    fi
    if command -v mkfs.fat >/dev/null 2>&1; then
        printf '%s\n' mkfs.fat
        return
    fi
    fail "missing required host tool: mkfs.vfat or mkfs.fat"
}

require_file() {
    path=$1
    desc=$2
    if [ ! -f "$path" ]; then
        fail "missing $desc: $path"
    fi
}

copy_if_file() {
    src=$1
    dst=$2
    if [ -f "$src" ]; then
        cp "$src" "$dst"
    else
        warn "optional file not present, skipped: $src"
    fi
}

cleanup() {
    if [ "$DATA_MOUNTED" -eq 1 ]; then
        umount "$DATA_MNT" >/dev/null 2>&1 || true
    fi
    if [ "$BOOT_MOUNTED" -eq 1 ]; then
        umount "$BOOT_MNT" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT INT TERM

check_layout() {
    if [ "$EDGENOS_BOARD" != "redstone" ]; then
        fail "expected EDGENOS_BOARD=redstone, got $EDGENOS_BOARD"
    fi
    if [ "$EDGENOS_DTS_BASENAME" != "redstone-stage1" ]; then
        fail "expected redstone-stage1 DTB basename, got $EDGENOS_DTS_BASENAME"
    fi
    if [ $((IMAGE_BYTES % SECTOR_SIZE)) -ne 0 ]; then
        fail "image byte size must be sector aligned: $IMAGE_BYTES"
    fi
    if [ "$BOOT_END" -gt "$DATA_START" ]; then
        fail "FAT16 boot partition overlaps data partition"
    fi
    if [ "$DATA_SECTORS" -le 0 ]; then
        fail "image is too small for data partition"
    fi
    if [ $((DATA_BYTES % 4096)) -ne 0 ]; then
        fail "data partition size must be 4096-byte aligned for mkfs.ext2"
    fi
    case "$IMAGE" in
        "$TOPDIR"/output/images/*) ;;
        *) fail "refusing output image outside output/images: $IMAGE" ;;
    esac
    case "$WORKDIR" in
        "$TOPDIR"/output/*) ;;
        *) fail "refusing work directory outside output/: $WORKDIR" ;;
    esac
}

check_artifacts() {
    require_file "$FIT_IMAGE" "Redstone FIT image"
    require_file "$ROOTFS_SQSH" "packed rootfs.sqsh"
    require_file "$INSTALLER_IMAGE" "Redstone ONIE-style installer payload"
    require_file "$DTB_IMAGE" "Redstone DTB"
    require_file "$KERNEL_UIMAGE" "kernel uImage inspection alias"
    require_file "$TOPDIR/scripts/package-redstone-hardware-handoff.sh" "handoff packager"
}

check_tools() {
    require_tool sfdisk
    require_tool mkfs.ext2
    require_tool mount
    require_tool umount
    require_tool truncate
    require_tool sha256sum
    require_tool md5sum
    require_tool find
    require_tool sort
    require_tool wc
    require_tool tar
    MKFS_FAT=$(find_fat_mkfs)
    if ! "$MKFS_FAT" --help 2>&1 | grep -q -- '--offset'; then
        fail "$MKFS_FAT does not advertise --offset support"
    fi
}

print_env() {
    cat <<EOF
board=$EDGENOS_BOARD
image=$IMAGE
image_bytes=$IMAGE_BYTES
total_sectors=$TOTAL_SECTORS
boot_start=$BOOT_START
boot_sectors=$BOOT_SECTORS
boot_label=$BOOT_LABEL
data_start=$DATA_START
data_sectors=$DATA_SECTORS
data_label=$DATA_LABEL
fit_image=$FIT_IMAGE
fit_config=$FIT_CONFIG
dtb_image=$DTB_IMAGE
rootfs_squashfs=$ROOTFS_SQSH
installer_payload=$INSTALLER_IMAGE
handoff_tarball=$HANDOFF_TARBALL
EOF
}

write_readme() {
    dest=$1
    cat > "$dest/USB_STAGE1_README.txt" <<EOF
Redstone USB stage-1 boot/capture image

Purpose:
  External first-boot capture for Redstone stage 1.

Non-destructive policy:
  - Do not overwrite internal flash, NAND, NOR, or local disks.
  - Do not run saveenv while proving this path.
  - Do not run onie-nos-install from this image.
  - Return the generated capture or validation bundle plus the full serial log.

Partition layout:
  - Partition 1: FAT16 type 0x06, label $BOOT_LABEL, U-Boot boot files.
  - Partition 2: ext2 type 0x83, label $DATA_LABEL, capture material and handoff files.

Temporary U-Boot commands for the FIT image:
  usb stop
  usb reset
  usb storage
  fatls usb 0:1 /
  fatload usb 0:1 1000000 uImage-powerpc.itb
  bootm 1000000#$FIT_CONFIG

Compatibility files:
  /uImage and /p2020rdb.dtb are copied as inspection aliases for the legacy
  R0678 split-boot command shape. Prefer the FIT command above for this
  EdgeNOS stage-1 image.

After boot:
  cat /etc/edgenos/board
  redstone-stage1-bench-run --capture-only

Strict one-port validation after the bench link is connected:
  REDSTONE_IFACE=swpN
  REDSTONE_LOCAL_CIDR=192.0.2.1/24
  REDSTONE_PEER=192.0.2.2
  redstone-stage1-bench-run --iface "\$REDSTONE_IFACE" --local-cidr "\$REDSTONE_LOCAL_CIDR" --peer "\$REDSTONE_PEER"
EOF
}

write_manifest() {
    root=$1
    manifest=$2
    (
        cd "$root"
        find . -type f ! -name MANIFEST.txt | sort | while IFS= read -r path; do
            bytes=$(wc -c < "$path" | tr -d ' ')
            hash=$(sha256sum "$path" | awk '{print $1}')
            printf '%s  %s  %s\n' "$hash" "$bytes" "${path#./}"
        done
    ) > "$manifest"
}

prepare_workdir() {
    rm -rf "$WORKDIR"
    mkdir -p "$BOOT_MNT" "$DATA_MNT" "$TOPDIR/output/images"
}

build_handoff() {
    info "==> Regenerating Redstone hardware handoff package"
    EDGENOS_BOARD=redstone sh "$TOPDIR/scripts/package-redstone-hardware-handoff.sh"
    require_file "$HANDOFF_TARBALL" "generated Redstone hardware handoff tarball"
}

write_partition_table() {
    info "==> Creating raw image and DOS partition table"
    rm -f "$IMAGE" "$IMAGE.sha256" "$IMAGE.md5" \
        "$IMAGE.fdisk.txt" "$IMAGE.boot-files.txt" "$IMAGE.data-files.txt"
    truncate -s "$IMAGE_BYTES" "$IMAGE"
    cat > "$WORKDIR/partition.sfdisk" <<EOF
label: dos
unit: sectors

start=$BOOT_START, size=$BOOT_SECTORS, type=6, bootable
start=$DATA_START, type=83
EOF
    sfdisk "$IMAGE" < "$WORKDIR/partition.sfdisk" >/dev/null
}

make_filesystems() {
    MKFS_FAT=$(find_fat_mkfs)
    info "==> Formatting partition 1 as FAT16 label $BOOT_LABEL"
    "$MKFS_FAT" -F 16 -n "$BOOT_LABEL" --offset="$BOOT_START" "$IMAGE" $((BOOT_SECTORS / 2)) >/dev/null
    info "==> Formatting partition 2 as ext2 label $DATA_LABEL"
    mkfs.ext2 -q -F -b 4096 -L "$DATA_LABEL" -E offset="$DATA_OFFSET" "$IMAGE" "$DATA_BLOCKS_4K"
}

mount_partitions() {
    info "==> Mounting image partitions"
    mount -o loop,offset="$BOOT_OFFSET",sizelimit="$BOOT_BYTES" -t vfat "$IMAGE" "$BOOT_MNT"
    BOOT_MOUNTED=1
    mount -o loop,offset="$DATA_OFFSET",sizelimit="$DATA_BYTES" -t ext2 "$IMAGE" "$DATA_MNT"
    DATA_MOUNTED=1
}

populate_boot_partition() {
    info "==> Populating FAT16 boot partition"
    mkdir -p "$BOOT_MNT/boot"
    cp "$FIT_IMAGE" "$BOOT_MNT/uImage-powerpc.itb"
    cp "$FIT_IMAGE" "$BOOT_MNT/uImage.itb"
    cp "$FIT_IMAGE" "$BOOT_MNT/boot/uImage-powerpc.itb"
    cp "$FIT_IMAGE" "$BOOT_MNT/boot/uImage.itb"
    cp "$KERNEL_UIMAGE" "$BOOT_MNT/uImage"
    cp "$KERNEL_UIMAGE" "$BOOT_MNT/boot/uImage"
    cp "$DTB_IMAGE" "$BOOT_MNT/redstone-stage1.dtb"
    cp "$DTB_IMAGE" "$BOOT_MNT/p2020rdb.dtb"
    cp "$DTB_IMAGE" "$BOOT_MNT/boot/redstone-stage1.dtb"
    cp "$DTB_IMAGE" "$BOOT_MNT/boot/p2020rdb.dtb"
    copy_if_file "$ROOTFS_UBOOT" "$BOOT_MNT/rootfs.ext2.gz.uboot"
    copy_if_file "$ROOTFS_UBOOT" "$BOOT_MNT/boot/rootfs.ext2.gz.uboot"
    write_readme "$BOOT_MNT"
    write_manifest "$BOOT_MNT" "$BOOT_MNT/MANIFEST.txt"
}

populate_data_partition() {
    info "==> Populating ext2 capture/material partition"
    mkdir -p "$DATA_MNT/images" "$DATA_MNT/handoff" "$DATA_MNT/docs" "$DATA_MNT/host-tools"
    cp "$FIT_IMAGE" "$DATA_MNT/images/uImage-powerpc.itb"
    cp "$ROOTFS_SQSH" "$DATA_MNT/images/rootfs.sqsh"
    cp "$INSTALLER_IMAGE" "$DATA_MNT/images/$EDGENOS_IMAGE_NAME"
    cp "$DTB_IMAGE" "$DATA_MNT/images/$EDGENOS_DTS_BASENAME.dtb"
    cp "$HANDOFF_TARBALL" "$DATA_MNT/handoff/redstone-stage1-hardware-handoff.tar.gz"
    copy_if_file "$HANDOFF_DIR/RUNBOOK.md" "$DATA_MNT/handoff/RUNBOOK.md"
    copy_if_file "$HANDOFF_DIR/MANIFEST.txt" "$DATA_MNT/handoff/MANIFEST.txt"
    copy_if_file "$HANDOFF_DIR/host-tools/analyze-redstone-handoff-capture.sh" \
        "$DATA_MNT/host-tools/analyze-redstone-handoff-capture.sh"
    copy_if_file "$HANDOFF_DIR/host-tools/verify-redstone-hardware-handoff.sh" \
        "$DATA_MNT/host-tools/verify-redstone-hardware-handoff.sh"
    cp "$TOPDIR/docs/redstone_stage1_plan.md" "$DATA_MNT/docs/redstone_stage1_plan.md"
    cp "$TOPDIR/docs/redstone_progress.md" "$DATA_MNT/docs/redstone_progress.md"
    write_readme "$DATA_MNT"
    write_manifest "$DATA_MNT" "$DATA_MNT/MANIFEST.txt"
}

record_lists() {
    info "==> Recording partition file inventories"
    (
        cd "$BOOT_MNT"
        find . -type f | sort
    ) > "$IMAGE.boot-files.txt"
    (
        cd "$DATA_MNT"
        find . -type f | sort
    ) > "$IMAGE.data-files.txt"
}

finalize_image() {
    sync
    cleanup
    BOOT_MOUNTED=0
    DATA_MOUNTED=0
    if command -v fdisk >/dev/null 2>&1; then
        info "==> Recording image partition table"
        fdisk -l "$IMAGE" > "$IMAGE.fdisk.txt" || true
    fi
    info "==> Hashing raw image; this can take a minute on drvfs-backed WSL paths"
    sha256sum "$IMAGE" > "$IMAGE.sha256"
    md5sum "$IMAGE" > "$IMAGE.md5"
    info "==> Wrote $IMAGE"
    info "==> Wrote $IMAGE.sha256"
    info "==> Wrote $IMAGE.md5"
    info "==> Wrote $IMAGE.boot-files.txt"
    info "==> Wrote $IMAGE.data-files.txt"
}

check_mode() {
    check_layout
    check_artifacts
    check_tools
    print_env
    info "PASS: Redstone USB stage-1 inputs and host tools are present."
    if [ ! -f "$HANDOFF_TARBALL" ]; then
        warn "handoff tarball is not present yet; image mode will regenerate it"
    fi
}

image_mode() {
    check_layout
    check_artifacts
    check_tools
    if [ "$(id -u)" -ne 0 ]; then
        fail "image mode requires root because it mounts loop partitions; run with sudo"
    fi
    prepare_workdir
    build_handoff
    write_partition_table
    make_filesystems
    mount_partitions
    populate_boot_partition
    populate_data_partition
    record_lists
    finalize_image
}

mode="${1:-check}"
case "$mode" in
    check)
        check_mode
        ;;
    image)
        image_mode
        ;;
    print-env)
        check_layout
        print_env
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
