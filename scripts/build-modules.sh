#!/bin/sh
# build-modules.sh - Build board support kernel modules against the EdgeNOS kernel
set -e

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$TOPDIR/scripts/board-env.sh"

: "${EDGENOS_KERNEL_VERSION:=5.10.224}"
: "${KSRC:=$TOPDIR/build/linux-$EDGENOS_KERNEL_VERSION}"
: "${ARCH:=powerpc}"
: "${CROSS_COMPILE:=powerpc-linux-gnu-}"

MODULE_DIRS="
asic/bde
platform/cpld
platform/retimer
"

EXPECTED_MODULES="
asic/bde/linux-kernel-bde.ko
asic/bde/linux-user-bde.ko
platform/cpld/accton_as5610_52x_cpld.ko
platform/retimer/retimer_class.ko
platform/retimer/ds100df410.ko
"

if [ ! -d "$KSRC" ]; then
    echo "ERROR: kernel source not found at $KSRC"
    echo "Run: EDGENOS_BOARD=$EDGENOS_BOARD ./scripts/build-kernel.sh download"
    echo "Then: EDGENOS_BOARD=$EDGENOS_BOARD ./scripts/build-kernel.sh build"
    exit 1
fi

if [ ! -f "$KSRC/.config" ]; then
    echo "ERROR: kernel .config not found at $KSRC/.config"
    echo "Run the kernel build before building external modules."
    exit 1
fi

run_make() {
    dir="$1"
    target="$2"
    echo "==> ${target:-modules}: $dir"
    make -C "$KSRC" M="$TOPDIR/$dir" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" ${target:-modules}
}

case "${1:-build}" in
    build)
        for dir in $MODULE_DIRS; do
            run_make "$dir" modules
        done

        missing=0
        for mod in $EXPECTED_MODULES; do
            if [ ! -f "$TOPDIR/$mod" ]; then
                echo "ERROR: expected module missing: $mod"
                missing=1
            fi
        done
        [ "$missing" -eq 0 ] || exit 1

        echo "==> External modules built for $EDGENOS_BOARD_LABEL"
        for mod in $EXPECTED_MODULES; do
            ls -lh "$TOPDIR/$mod"
        done
        ;;
    clean)
        for dir in $MODULE_DIRS; do
            run_make "$dir" clean
        done
        ;;
    *)
        echo "Usage: $0 {build|clean}"
        exit 1
        ;;
esac
