#!/bin/sh
# check-redstone-image.sh - Verify generated Redstone stage-1 rootfs contents
set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_OPENBCM_INIT_PROBE=${REQUIRE_OPENBCM_INIT_PROBE:-0}
MODE=staging
STAGING="$TOPDIR/output/rootfs/staging"
SQUASHFS=
EXTRACT_DIR=

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 [--staging DIR|DIR]
       $0 --squashfs FILE
EOF
    exit 1
}

cleanup() {
    if [ -n "$EXTRACT_DIR" ]; then
        rm -rf "$EXTRACT_DIR"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --staging)
            [ $# -ge 2 ] || usage
            MODE=staging
            STAGING=$2
            shift 2
            ;;
        --squashfs)
            [ $# -ge 2 ] || usage
            MODE=squashfs
            SQUASHFS=$2
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            fail "unknown option: $1"
            ;;
        *)
            [ $# -eq 1 ] || usage
            MODE=staging
            STAGING=$1
            shift
            ;;
    esac
done

if [ "$MODE" = "squashfs" ]; then
    [ -f "$SQUASHFS" ] || fail "rootfs squashfs image not found: $SQUASHFS"
    command -v unsquashfs >/dev/null 2>&1 || fail "unsquashfs not found"
    EXTRACT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/redstone-rootfs.XXXXXX")
    trap cleanup EXIT HUP INT TERM
    unsquashfs -q -d "$EXTRACT_DIR/rootfs" "$SQUASHFS" >/dev/null || \
        fail "failed to extract rootfs squashfs image: $SQUASHFS"
    STAGING="$EXTRACT_DIR/rootfs"
fi

check_file() {
    [ -f "$STAGING/$1" ] || fail "missing file: $1"
}

check_exec() {
    [ -x "$STAGING/$1" ] || fail "missing executable: $1"
}

check_module() {
    [ -f "$STAGING/lib/modules/extra/$1" ] || fail "missing module: lib/modules/extra/$1"
}

[ -d "$STAGING" ] || fail "rootfs staging directory not found: $STAGING"

check_file etc/edgenos/board
grep -qx redstone "$STAGING/etc/edgenos/board" || fail "etc/edgenos/board is not redstone"

check_exec etc/init.d/S20edgenos
check_exec usr/sbin/platform-init.sh
check_exec usr/sbin/switchd-init
check_exec usr/sbin/redstone-stage1-capture
check_exec usr/sbin/redstone-stage1-validate
check_exec usr/sbin/redstone-stage1-bench-run
check_exec usr/sbin/switchd

case "$REQUIRE_OPENBCM_INIT_PROBE" in
    1|yes|true|TRUE|on|ON)
        REQUIRE_OPENBCM_INIT_PROBE=1
        ;;
    0|no|false|FALSE|off|OFF|"")
        REQUIRE_OPENBCM_INIT_PROBE=0
        ;;
    *)
        fail "invalid REQUIRE_OPENBCM_INIT_PROBE=$REQUIRE_OPENBCM_INIT_PROBE"
        ;;
esac

if [ "$REQUIRE_OPENBCM_INIT_PROBE" = "1" ]; then
    check_exec usr/sbin/redstone-openbcm-init-probe
    check_file usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest
    grep -qx "sdk_baseline=openbcm-6.5.27" \
        "$STAGING/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest" || \
        fail "OpenBCM init probe manifest does not identify sdk_baseline=openbcm-6.5.27"
elif [ -e "$STAGING/usr/sbin/redstone-openbcm-init-probe" ]; then
    check_exec usr/sbin/redstone-openbcm-init-probe
    if [ -f "$STAGING/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest" ]; then
        grep -qx "sdk_baseline=openbcm-6.5.27" \
            "$STAGING/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest" || \
            fail "OpenBCM init probe manifest does not identify sdk_baseline=openbcm-6.5.27"
    fi
fi

check_file etc/switchd/redstone-stage1.bcm
grep -q "portmap_52" "$STAGING/etc/switchd/redstone-stage1.bcm" || \
    fail "redstone-stage1.bcm does not contain the 52-port map"
check_file etc/switchd/redstone-original-active-sdk.manifest
grep -q "^generated_config_portmap_count=61$" \
    "$STAGING/etc/switchd/redstone-original-active-sdk.manifest" || \
    fail "original-active SDK reference manifest does not record 61 port maps"

check_module linux-kernel-bde.ko
check_module linux-user-bde.ko
check_module accton_as5610_52x_cpld.ko
check_module retimer_class.ko
check_module ds100df410.ko

echo "PASS: Redstone generated image contains switchd, BDE, platform modules, validation tools, bench runner, and board config"
