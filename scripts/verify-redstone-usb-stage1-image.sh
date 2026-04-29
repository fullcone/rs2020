#!/bin/sh
# Verify the generated non-destructive Redstone USB stage-1 raw image.
#
# This host-side verifier is read-only: it checks the raw image, hash sidecars,
# fdisk summary, and partition file inventories without mounting the image or
# writing to any USB device.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
BOARD="${EDGENOS_BOARD:-redstone}"
EDGENOS_BOARD="$BOARD"
export EDGENOS_BOARD
. "$TOPDIR/scripts/board-env.sh"

IMAGE="${1:-${REDSTONE_USB_STAGE1_IMAGE:-"$TOPDIR/output/images/redstone-usb-stage1-boot-capture.img"}}"
EXPECTED_BYTES="${REDSTONE_USB_STAGE1_BYTES:-4037017600}"
SECTOR_SIZE=512
BOOT_START="${REDSTONE_USB_STAGE1_BOOT_START:-2048}"
BOOT_SECTORS="${REDSTONE_USB_STAGE1_BOOT_SECTORS:-522240}"
DATA_START="${REDSTONE_USB_STAGE1_DATA_START:-524288}"
BOOT_LABEL="${REDSTONE_USB_STAGE1_BOOT_LABEL:-REDBOOT}"
DATA_LABEL="${REDSTONE_USB_STAGE1_DATA_LABEL:-REDCF}"
FIT_CONFIG="${REDSTONE_USB_STAGE1_FIT_CONFIG:-accton_as5610_52x}"

FAILURES=0
WARNINGS=0
PASSES=0

ok() {
    PASSES=$((PASSES + 1))
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

usage() {
    cat <<'USAGE'
usage: EDGENOS_BOARD=redstone scripts/verify-redstone-usb-stage1-image.sh [IMAGE]

Verifies the generated Redstone USB stage-1 raw image sidecars without mounting
the image or writing any USB device.
USAGE
}

file_size() {
    wc -c < "$1" | tr -d '[:space:]'
}

require_file() {
    path=$1
    desc=$2

    if [ -s "$path" ]; then
        ok "$desc exists: $path"
    else
        fail "$desc missing or empty: $path"
    fi
}

require_text() {
    pattern=$1
    path=$2
    desc=$3

    if [ ! -f "$path" ]; then
        fail "$desc: missing input $path"
        return
    fi

    if grep -Eq -- "$pattern" "$path"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

require_list_entry() {
    entry=$1
    path=$2
    desc=$3

    if [ ! -f "$path" ]; then
        fail "$desc: missing input $path"
        return
    fi

    if grep -Fxq -- "$entry" "$path"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

verify_hash() {
    tool=$1
    sidecar=$2
    desc=$3
    mismatch=$4

    if ! command -v "$tool" >/dev/null 2>&1; then
        fail "$tool unavailable; cannot verify $desc sidecar"
        return
    fi

    if [ ! -f "$sidecar" ]; then
        fail "$desc sidecar missing: $sidecar"
        return
    fi

    if "$tool" -c "$sidecar" >/dev/null 2>&1; then
        ok "$desc matches sidecar"
    else
        fail "$mismatch"
    fi
}

case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
esac

printf 'Redstone USB stage-1 image verification\n'
printf '  requested board: %s\n' "$BOARD"
printf '  normalized board: %s\n' "$EDGENOS_BOARD"
printf '  image: %s\n' "$IMAGE"
printf '  expected bytes: %s\n' "$EXPECTED_BYTES"
printf '  expected boot label: %s\n' "$BOOT_LABEL"
printf '  expected data label: %s\n' "$DATA_LABEL"
printf '  expected FIT config: %s\n\n' "$FIT_CONFIG"

if [ "$EDGENOS_BOARD" = "redstone" ]; then
    ok "board selector is Redstone"
else
    fail "expected EDGENOS_BOARD=redstone, got $EDGENOS_BOARD"
fi

if [ "$EDGENOS_DTS_BASENAME" = "redstone-stage1" ]; then
    ok "Redstone DTB basename selected"
else
    fail "expected DTB basename redstone-stage1, got $EDGENOS_DTS_BASENAME"
fi

if [ "$EDGENOS_IMAGE_NAME" = "edgenos-redstone-stage1.bin" ]; then
    ok "Redstone installer payload name selected"
else
    fail "expected image payload edgenos-redstone-stage1.bin, got $EDGENOS_IMAGE_NAME"
fi

require_file "$IMAGE" "raw USB stage-1 image"
for suffix in sha256 md5 fdisk.txt boot-files.txt data-files.txt; do
    require_file "$IMAGE.$suffix" "$suffix sidecar"
done

if [ -f "$IMAGE" ]; then
    actual_bytes=$(file_size "$IMAGE")
    if [ "$actual_bytes" = "$EXPECTED_BYTES" ]; then
        ok "raw image size is $EXPECTED_BYTES bytes"
    else
        fail "raw image size is $actual_bytes bytes, expected $EXPECTED_BYTES"
    fi
fi

verify_hash sha256sum "$IMAGE.sha256" "sha256" "sha256 mismatch for raw USB stage-1 image"
verify_hash md5sum "$IMAGE.md5" "md5" "md5 mismatch for raw USB stage-1 image"

image_sectors=$((EXPECTED_BYTES / SECTOR_SIZE))
boot_end=$((BOOT_START + BOOT_SECTORS - 1))
data_end=$((image_sectors - 1))
data_sectors=$((image_sectors - DATA_START))

fdisk_sidecar="$IMAGE.fdisk.txt"
require_text 'Disklabel type:[[:space:]]+dos' "$fdisk_sidecar" \
    "fdisk sidecar records DOS partition table"
require_text "[[:space:]][*][[:space:]]+$BOOT_START[[:space:]]+$boot_end[[:space:]]+$BOOT_SECTORS[[:space:]].* 6[[:space:]]+FAT16" "$fdisk_sidecar" \
    "fdisk sidecar records bootable FAT16 type 0x06 partition"
require_text "[[:space:]]$DATA_START[[:space:]]+$data_end[[:space:]]+$data_sectors[[:space:]].*83[[:space:]]+Linux" "$fdisk_sidecar" \
    "fdisk sidecar records Linux/ext2 data partition"

boot_list="$IMAGE.boot-files.txt"
for entry in \
    ./uImage-powerpc.itb \
    ./uImage.itb \
    ./boot/uImage-powerpc.itb \
    ./boot/uImage.itb \
    ./uImage \
    ./boot/uImage \
    ./redstone-stage1.dtb \
    ./p2020rdb.dtb \
    ./USB_STAGE1_README.txt \
    ./MANIFEST.txt
do
    require_list_entry "$entry" "$boot_list" \
        "FAT inventory includes $entry"
done

data_list="$IMAGE.data-files.txt"
for entry in \
    ./images/uImage-powerpc.itb \
    ./images/rootfs.sqsh \
    "./images/$EDGENOS_IMAGE_NAME" \
    ./images/redstone-stage1.dtb \
    ./handoff/redstone-stage1-hardware-handoff.tar.gz \
    ./handoff/RUNBOOK.md \
    ./handoff/MANIFEST.txt \
    ./host-tools/analyze-redstone-handoff-capture.sh \
    ./host-tools/verify-redstone-hardware-handoff.sh \
    ./docs/redstone_stage1_plan.md \
    ./docs/redstone_progress.md \
    ./USB_STAGE1_README.txt \
    ./MANIFEST.txt
do
    require_list_entry "$entry" "$data_list" \
        "data inventory includes $entry"
done

printf '\n'
if [ "$FAILURES" -ne 0 ]; then
    printf 'Redstone USB stage-1 image verification failed: %s pass, %s warning(s), %s failure(s)\n' \
        "$PASSES" "$WARNINGS" "$FAILURES" >&2
    exit 1
fi

printf 'Redstone USB stage-1 image verification passed: %s pass, %s warning(s), %s failure(s)\n' \
    "$PASSES" "$WARNINGS" "$FAILURES"
