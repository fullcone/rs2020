#!/bin/sh
# Build a Redstone B2-style TFTP FIT image from the current rootfs tarball.
#
# This keeps the hardware-tested FIT shape used by the live TFTP bring-up:
# uncompressed kernel payload, gzip-compressed cpio initramfs included as a
# raw ramdisk blob, and the accton_as5610_52x FIT configuration name.

set -eu

TOPDIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTDIR="$TOPDIR/output"
IMAGE_DIR="$OUTDIR/images"
FIT_NAME=${1:-uImage-b2-phytool.itb}
KERNEL_BIN=${REDSTONE_TFTP_KERNEL_BIN:-$IMAGE_DIR/b2-origphy-nopci0-work/kernel.bin}
ROOTFS_TAR=${REDSTONE_TFTP_ROOTFS_TAR:-$OUTDIR/rootfs/rootfs.tar}
DTS=${REDSTONE_TFTP_DTS:-$TOPDIR/kernel/dts/redstone-stage1.dts}

case "$FIT_NAME" in
*.itb) ;;
*) FIT_NAME="$FIT_NAME.itb" ;;
esac

FIT_STEM=${FIT_NAME%.itb}
WORK="$IMAGE_DIR/$FIT_STEM-work"
FIT_OUT="$IMAGE_DIR/$FIT_NAME"

require_file() {
    if [ ! -f "$1" ]; then
        echo "ERROR: required file not found: $1" >&2
        exit 1
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $1" >&2
        exit 1
    fi
}

require_cmd cpio
require_cmd dtc
require_cmd gzip
require_cmd md5sum
require_cmd mkimage
require_cmd sha256sum
require_cmd tar
require_file "$KERNEL_BIN"
require_file "$ROOTFS_TAR"
require_file "$DTS"

case "$WORK" in
"$IMAGE_DIR"/*) ;;
*)
    echo "ERROR: refusing to clean unexpected work directory: $WORK" >&2
    exit 1
    ;;
esac

rm -rf "$WORK"
mkdir -p "$WORK/root"

cp "$KERNEL_BIN" "$WORK/kernel.bin"
dtc -I dts -O dtb -o "$WORK/redstone-stage1-b2.dtb" "$DTS"
tar -xf "$ROOTFS_TAR" -C "$WORK/root"

if [ ! -e "$WORK/root/init" ]; then
    ln -s sbin/init "$WORK/root/init"
fi

(
    cd "$WORK/root"
    find . -print | LC_ALL=C sort | cpio -o -H newc 2>/dev/null | gzip -9 > ../initramfs.cpio
)

cat > "$WORK/$FIT_STEM.its" <<'ITS'
/dts-v1/;

/ {
    description = "PowerPC kernel, initramfs and FDT blobs";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "PowerPC Kernel";
            data = /incbin/("kernel.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };

        initramfs {
            description = "B2 phytool: Buildroot rootfs + Redstone SGMII capture tools";
            data = /incbin/("initramfs.cpio");
            type = "ramdisk";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
        };

        accton_as5610_52x_dtb {
            description = "stage1 dtb (orig PHY, serial1 alias, pci0 disabled)";
            data = /incbin/("redstone-stage1-b2.dtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };

    configurations {
        default = "accton_as5610_52x";

        accton_as5610_52x {
            description = "EdgeNOS for Redstone";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "accton_as5610_52x_dtb";
        };
    };
};
ITS

(
    cd "$WORK"
    mkimage -f "$FIT_STEM.its" "$FIT_OUT"
)

md5sum "$FIT_OUT" > "$FIT_OUT.md5"
sha256sum "$FIT_OUT" > "$FIT_OUT.sha256"

echo "Built: $FIT_OUT"
ls -lh "$FIT_OUT" "$WORK/initramfs.cpio" "$WORK/redstone-stage1-b2.dtb"
