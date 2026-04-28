#!/bin/bash
# build-sdk.sh - Build OpenMDK libraries for switchd.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/.." && pwd)}"
OPENMDK="${OPENMDK:-$TOPDIR/asic/openmdk}"
CROSS="${CROSS:-powerpc-linux-gnu-}"
OUTDIR="${OUTDIR:-$TOPDIR/output/sdk}"
JOBS="${JOBS:-$(nproc)}"
MDK_INIT="$TOPDIR/asic/mdk-init"

if [ ! -d "$OPENMDK" ]; then
    echo "ERROR: OpenMDK not found at $OPENMDK"
    echo "Clone it with: git clone --depth 1 https://github.com/Broadcom-Network-Switching-Software/OpenMDK.git asic/openmdk"
    exit 1
fi

echo "==> Building OpenMDK libraries into $OUTDIR"
echo "    CROSS_COMPILE=${CROSS}"

for target in cdk phy bmd libbde; do
    echo "==> Building $target"
    make -C "$MDK_INIT" \
        CROSS_COMPILE="$CROSS" \
        MDK="$OPENMDK" \
        BLDDIR="$OUTDIR" \
        "$target" \
        -j"$JOBS"
done

echo "==> OpenMDK libraries built"
find "$OUTDIR" -maxdepth 2 -type f -name "*.a" | sort
