#!/bin/sh
# check-redstone-image.sh - Verify generated Redstone stage-1 rootfs contents
set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${1:-$TOPDIR/output/rootfs/staging}"
REQUIRE_OPENBCM_INIT_PROBE=${REQUIRE_OPENBCM_INIT_PROBE:-0}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

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

check_module linux-kernel-bde.ko
check_module linux-user-bde.ko
check_module accton_as5610_52x_cpld.ko
check_module retimer_class.ko
check_module ds100df410.ko

echo "PASS: Redstone generated image staging contains switchd, BDE, platform modules, validation tools, and board config"
