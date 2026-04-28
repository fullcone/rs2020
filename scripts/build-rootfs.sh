#!/bin/bash
# build-rootfs.sh - Build root filesystem using Buildroot
set -e

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
BRVER="2023.02.9"
if [ -n "${EDGENOS_BUILDROOT_WORKDIR:-}" ]; then
    BRWORK="$EDGENOS_BUILDROOT_WORKDIR"
else
    if [ -z "${HOME:-}" ]; then
        echo "ERROR: HOME is not set. Set EDGENOS_BUILDROOT_WORKDIR to a Linux filesystem path."
        exit 1
    fi
    BRWORK="${XDG_CACHE_HOME:-$HOME/.cache}/edgenos/buildroot"
fi
BRSRC="$BRWORK/buildroot-$BRVER"
OUTDIR="$TOPDIR/output"
JOBS=$(nproc)
EDGENOS_BOARD="${EDGENOS_BOARD:-as5610-52x}"
. "$TOPDIR/scripts/board-env.sh"
export EDGENOS_BOARD EDGENOS_BOARD_LABEL

# Buildroot rejects PATH entries with whitespace. WSL can inherit Windows PATH
# entries such as "Program Files", so keep a deterministic Linux tool PATH.
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

download() {
    echo "==> Buildroot workdir: $BRSRC"

    if [ -d "$BRSRC" ]; then
        echo "Buildroot source already present at $BRSRC"
        return
    fi

    mkdir -p "$TOPDIR/build" "$BRWORK"
    local URL="https://buildroot.org/downloads/buildroot-${BRVER}.tar.xz"
    local TARBALL="$TOPDIR/build/buildroot-${BRVER}.tar.xz"
    local TMPDIR="$BRWORK/.buildroot-${BRVER}.tmp"

    if [ ! -f "$TARBALL" ]; then
        echo "==> Downloading Buildroot $BRVER..."
        wget -q --show-progress -O "$TARBALL" "$URL"
    fi

    echo "==> Extracting Buildroot..."
    rm -rf "$TMPDIR"
    mkdir -p "$TMPDIR"
    tar -xf "$TARBALL" -C "$TMPDIR"
    mv "$TMPDIR/buildroot-$BRVER" "$BRSRC"
    rm -rf "$TMPDIR"
}

build() {
    if [ ! -d "$BRSRC" ]; then
        echo "ERROR: Buildroot source not found. Run '$0 download' first."
        exit 1
    fi

    # Generate a defconfig for this checkout. The source defconfig keeps the
    # Docker-era /build paths documented, but direct WSL builds need real paths.
    sed \
        -e "s|^BR2_ROOTFS_OVERLAY=.*|BR2_ROOTFS_OVERLAY=\"$TOPDIR/config/rootfs/overlay\"|" \
        -e "s|^BR2_ROOTFS_POST_BUILD_SCRIPT=.*|BR2_ROOTFS_POST_BUILD_SCRIPT=\"$TOPDIR/config/rootfs/post-build.sh\"|" \
        -e "s|^BR2_TARGET_GENERIC_ISSUE=.*|BR2_TARGET_GENERIC_ISSUE=\"EdgeNOS for $EDGENOS_BOARD_LABEL\"|" \
        "$TOPDIR/config/rootfs/buildroot_defconfig" \
        > "$BRSRC/configs/edgenos_defconfig"

    echo "==> Configuring Buildroot..."
    make -C "$BRSRC" edgenos_defconfig

    echo "==> Building rootfs (this takes a while)..."
    make -C "$BRSRC" -j$JOBS

    mkdir -p "$OUTDIR/rootfs"
    cp "$BRSRC/output/images/rootfs.squashfs" "$OUTDIR/rootfs/" 2>/dev/null || true
    cp "$BRSRC/output/images/rootfs.tar" "$OUTDIR/rootfs/" 2>/dev/null || true

    echo "==> Base rootfs build complete"
}

assemble() {
    echo "==> Assembling final rootfs..."

    local STAGING="$OUTDIR/rootfs/staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"

    # Extract base rootfs
    if [ -f "$OUTDIR/rootfs/rootfs.tar" ]; then
        tar -xf "$OUTDIR/rootfs/rootfs.tar" -C "$STAGING"
    else
        echo "ERROR: Base rootfs not found. Run '$0 build' first."
        exit 1
    fi

    # Install kernel modules
    if [ -d "$OUTDIR/kernel/modules" ]; then
        echo "  Installing kernel modules..."
        cp -a "$OUTDIR/kernel/modules/lib/modules" "$STAGING/lib/"
    fi

    # Install platform kernel modules
    mkdir -p "$STAGING/lib/modules/extra"
    find "$TOPDIR/platform" -name "*.ko" -exec cp {} "$STAGING/lib/modules/extra/" \;
    find "$TOPDIR/asic/bde" -name "*.ko" -exec cp {} "$STAGING/lib/modules/extra/" \;

    # Install switchd
    if [ -f "$TOPDIR/asic/switchd/switchd" ]; then
        echo "  Installing switchd..."
        install -D -m 755 "$TOPDIR/asic/switchd/switchd" "$STAGING/usr/sbin/switchd"
    fi

    # Install OpenMDK shared libs
    find "$TOPDIR/output/sdk" -name "*.so*" -exec cp {} "$STAGING/usr/lib/" \; 2>/dev/null || true

    # Install ASIC config files
    mkdir -p "$STAGING/etc/switchd"
    cp "$TOPDIR/config/bcm/"* "$STAGING/etc/switchd/" 2>/dev/null || true

    # Apply rootfs overlay
    if [ -d "$TOPDIR/config/rootfs/overlay" ]; then
        echo "  Applying rootfs overlay..."
        cp -a "$TOPDIR/config/rootfs/overlay/"* "$STAGING/"
    fi

    for script in \
        etc/init.d/S20edgenos \
        usr/sbin/platform-init.sh \
        usr/sbin/switchd-init \
        usr/sbin/redstone-stage1-capture
    do
        [ -f "$STAGING/$script" ] && chmod 755 "$STAGING/$script"
    done

    # Select board-specific runtime defaults.
    mkdir -p "$STAGING/etc/edgenos"
    printf '%s\n' "$EDGENOS_BOARD" > "$STAGING/etc/edgenos/board"

    # Create final squashfs
    echo "  Creating squashfs image..."
    mkdir -p "$OUTDIR/images"
    mksquashfs "$STAGING" "$OUTDIR/images/rootfs.sqsh" \
        -comp xz -noappend -all-root

    echo "==> Final rootfs assembled: $OUTDIR/images/rootfs.sqsh"
    du -sh "$OUTDIR/images/rootfs.sqsh"
}

case "${1:-}" in
    download) download ;;
    build)    build ;;
    assemble) assemble ;;
    *)
        echo "Usage: $0 {download|build|assemble}"
        exit 1
        ;;
esac
