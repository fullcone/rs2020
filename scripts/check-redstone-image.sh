#!/bin/sh
# check-redstone-image.sh - Verify generated Redstone stage-1 rootfs contents
set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${1:-$TOPDIR/output/rootfs/staging}"

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
check_exec usr/sbin/switchd

check_file etc/switchd/redstone-stage1.bcm
grep -q "portmap_52" "$STAGING/etc/switchd/redstone-stage1.bcm" || \
    fail "redstone-stage1.bcm does not contain the 52-port map"

check_module linux-kernel-bde.ko
check_module linux-user-bde.ko
check_module accton_as5610_52x_cpld.ko
check_module retimer_class.ko
check_module ds100df410.ko

echo "PASS: Redstone generated image staging contains switchd, BDE, platform modules, and board config"
