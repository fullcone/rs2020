#!/bin/bash
# build-kernel.sh - Download and build Linux kernel for the selected board
set -e

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$TOPDIR/scripts/board-env.sh"
KVER="5.10.224"
KSRC="$TOPDIR/build/linux-$KVER"
CROSS="powerpc-linux-gnu-"
ARCH="powerpc"
OUTDIR="$TOPDIR/output"
JOBS=$(nproc)

install_dts() {
    # Copy our selected device tree into the kernel tree.
    local DTS_SRC="$TOPDIR/$EDGENOS_DTS_SOURCE"
    local DTS_DST="$KSRC/arch/powerpc/boot/dts/${EDGENOS_DTS_BASENAME}.dts"
    local DTS_MAKE="$KSRC/arch/powerpc/boot/dts/Makefile"

    if [ ! -f "$DTS_SRC" ]; then
        echo "ERROR: selected DTS not found: $DTS_SRC"
        exit 1
    fi

    echo "==> Installing ${EDGENOS_BOARD_LABEL} device tree as ${EDGENOS_DTS_BASENAME}.dts..."
    cp "$DTS_SRC" "$DTS_DST"
    if ! grep -q "${EDGENOS_DTS_BASENAME}.dtb" "$DTS_MAKE" 2>/dev/null; then
        echo "dtb-\$(CONFIG_PPC_85xx) += ${EDGENOS_DTS_BASENAME}.dtb" >> "$DTS_MAKE"
    fi
}

download() {
    if [ -d "$KSRC" ]; then
        echo "Kernel source already present at $KSRC"
        install_dts
        return
    fi

    mkdir -p "$TOPDIR/build"
    local MAJOR=$(echo "$KVER" | cut -d. -f1)
    local URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KVER}.tar.xz"
    local TARBALL="$TOPDIR/build/linux-${KVER}.tar.xz"

    if [ ! -f "$TARBALL" ]; then
        echo "==> Downloading Linux $KVER..."
        wget -q --show-progress -O "$TARBALL" "$URL"
    fi

    echo "==> Extracting kernel source..."
    tar -xf "$TARBALL" -C "$TOPDIR/build/"

    # Apply patches
    if [ -d "$TOPDIR/kernel/patches" ]; then
        echo "==> Applying kernel patches..."
        for p in "$TOPDIR/kernel/patches"/*.patch; do
            [ -f "$p" ] || continue
            echo "  Applying $(basename "$p")..."
            (cd "$KSRC" && patch -p1 < "$p")
        done
    fi

    install_dts
}

build() {
    if [ ! -d "$KSRC" ]; then
        echo "ERROR: Kernel source not found. Run '$0 download' first."
        exit 1
    fi

    install_dts

    # Copy defconfig if .config doesn't exist
    if [ ! -f "$KSRC/.config" ]; then
        cp "$TOPDIR/$EDGENOS_KERNEL_DEFCONFIG" "$KSRC/.config"
        make -C "$KSRC" ARCH=$ARCH CROSS_COMPILE=$CROSS olddefconfig
    fi

    echo "==> Building kernel (${JOBS} jobs)..."
    make -C "$KSRC" ARCH=$ARCH CROSS_COMPILE=$CROSS -j$JOBS \
        uImage dtbs modules

    # Collect outputs
    mkdir -p "$OUTDIR/kernel"
    cp "$KSRC/arch/powerpc/boot/uImage" "$OUTDIR/kernel/"
    cp "$KSRC/arch/powerpc/boot/dts/${EDGENOS_DTS_BASENAME}.dtb" "$OUTDIR/kernel/" 2>/dev/null || true
    cp "$KSRC/vmlinux" "$OUTDIR/kernel/"

    # Install modules to staging dir
    mkdir -p "$OUTDIR/kernel/modules"
    make -C "$KSRC" ARCH=$ARCH CROSS_COMPILE=$CROSS \
        INSTALL_MOD_PATH="$OUTDIR/kernel/modules" modules_install

    echo "==> Kernel build complete"
    echo "  uImage: $OUTDIR/kernel/uImage"
    echo "  DTB:    $OUTDIR/kernel/${EDGENOS_DTS_BASENAME}.dtb"
}

case "${1:-}" in
    download) download ;;
    build)    build ;;
    *)
        echo "Usage: $0 {download|build}"
        exit 1
        ;;
esac
