#!/bin/sh
# Source-tree preflight for the Redstone OpenBCM userland SDK init path.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENBCM_VERSION="${OPENBCM_VERSION:-6.5.27}"
OPENBCM_SDK_DIR="${OPENBCM_SDK_DIR:-$TOPDIR/build/openbcm/OpenBCM/sdk-$OPENBCM_VERSION}"
FAILURES=0

ok() {
    printf 'ok: %s\n' "$*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf 'fail: %s\n' "$*" >&2
}

check_file() {
    rel=$1

    if [ -f "$OPENBCM_SDK_DIR/$rel" ]; then
        ok "file exists: $rel"
    else
        fail "missing file: $rel"
    fi
}

check_grep() {
    pattern=$1
    rel=$2
    desc=$3

    if [ -f "$OPENBCM_SDK_DIR/$rel" ] &&
        grep -Eq "$pattern" "$OPENBCM_SDK_DIR/$rel"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

printf 'Redstone OpenBCM userland init source preflight\n'
printf '  OpenBCM SDK: %s\n' "$OPENBCM_SDK_DIR"
printf '  note: source/API check only; this does not load hardware or prove offload\n\n'

check_file "include/soc/devids.h"
check_file "src/soc/common/cm.c"
check_file "src/soc/common/feature.c"
check_file "src/soc/esw/drv.c"
check_file "systems/bde/linux/include/linux-bde.h"
check_file "systems/bde/linux/user/linux-user-bde.c"
check_file "systems/bde/linux/kernel/linux-kernel-bde.c"
check_file "systems/linux/user/opennsa_ut/demo_opennsa_init.c"
check_file "systems/linux/user/opennsa_ut/Makefile"
check_file "include/bcm/init.h"
check_file "include/bcm/l2.h"
check_file "include/bcm/vlan.h"
check_file "include/bcm/port.h"

check_grep '#define[[:space:]]+BCM56846_DEVICE_ID[[:space:]]+0xb846' \
    "include/soc/devids.h" \
    "BCM56846 device ID is declared as 0xb846"
check_grep '#define[[:space:]]+BCM56846_A0_REV_ID' \
    "include/soc/devids.h" \
    "BCM56846 A0 revision ID is declared"
check_grep '#define[[:space:]]+BCM56846_A1_REV_ID' \
    "include/soc/devids.h" \
    "BCM56846 A1 revision ID is declared"
check_grep 'BCM56846_DEVICE_ID,[[:space:]]*BCM56846_A0_REV_ID' \
    "src/soc/common/cm.c" \
    "SOC CM device table includes BCM56846 A0"
check_grep 'BCM56846_DEVICE_ID,[[:space:]]*BCM56846_A1_REV_ID' \
    "src/soc/common/cm.c" \
    "SOC CM device table includes BCM56846 A1"
check_grep 'dev_id[[:space:]]*==[[:space:]]*BCM56846_DEVICE_ID' \
    "src/soc/common/feature.c" \
    "SOC feature gating references BCM56846"
check_grep 'dev_id[[:space:]]*==[[:space:]]*BCM56846_DEVICE_ID' \
    "src/soc/esw/drv.c" \
    "ESW driver path references BCM56846"

check_grep 'BROADCOM_VENDOR_ID,[[:space:]]*BCM56846_DEVICE_ID' \
    "systems/bde/linux/kernel/linux-kernel-bde.c" \
    "Linux kernel BDE PCI table includes Broadcom BCM56846"
check_grep 'LINUX_KERNEL_BDE_NAME' \
    "systems/bde/linux/kernel/linux-kernel-bde.c" \
    "Linux kernel BDE references kernel BDE name macro"
check_grep '#define[[:space:]]+LINUX_KERNEL_BDE_NAME[[:space:]]+"linux-kernel-bde"' \
    "systems/bde/linux/include/linux-bde.h" \
    "Linux BDE public header names linux-kernel-bde"
check_grep '#define[[:space:]]+LINUX_USER_BDE_NAME[[:space:]]+"linux-user-bde"' \
    "systems/bde/linux/include/linux-bde.h" \
    "Linux BDE public header names linux-user-bde"
check_grep 'extern int linux_bde_create' \
    "systems/bde/linux/include/linux-bde.h" \
    "Linux BDE public header exports linux_bde_create"
check_grep 'LINUX_USER_BDE_NAME' \
    "systems/bde/linux/user/linux-user-bde.c" \
    "Linux user BDE source references user BDE device name"
check_grep 'LINUX_KERNEL_BDE_NAME' \
    "systems/bde/linux/user/linux-user-bde.c" \
    "Linux user BDE source references kernel BDE device name"
check_grep '^linux_bde_create' \
    "systems/bde/linux/user/linux-user-bde.c" \
    "Linux user BDE implements linux_bde_create"
check_grep '^linux_bde_create' \
    "systems/bde/linux/kernel/linux-kernel-bde.c" \
    "Linux kernel BDE implements linux_bde_create"

check_grep 'bde_create' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo has BDE create wrapper"
check_grep 'linux_bde_create' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo creates Linux BDE"
check_grep 'soc_attach' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo reaches soc_attach"
check_grep 'bcm_attach' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo reaches bcm_attach"
check_grep 'bcm_init' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo reaches bcm_init"
check_grep 'linux_bde_destroy' \
    "systems/linux/user/opennsa_ut/demo_opennsa_init.c" \
    "OpenNSA demo has Linux BDE cleanup path"
check_grep 'demo_opennsa_init' \
    "systems/linux/user/opennsa_ut/Makefile" \
    "OpenNSA userland Makefile builds demo init program"
check_grep 'KERNEL_BDE_LOCAL[[:space:]]*:=[[:space:]]*linux-kernel-bde' \
    "systems/linux/user/opennsa_ut/Makefile" \
    "OpenNSA userland Makefile links local kernel BDE object"
check_grep 'USER_BDE_LOCAL[[:space:]]*:=[[:space:]]*linux-user-bde' \
    "systems/linux/user/opennsa_ut/Makefile" \
    "OpenNSA userland Makefile links local user BDE object"
check_grep 'libopennsa' \
    "systems/linux/user/opennsa_ut/Makefile" \
    "OpenNSA userland Makefile builds OpenNSA library"

check_grep 'extern int bcm_init' \
    "include/bcm/init.h" \
    "OpenBCM public init API exports bcm_init"
check_grep 'extern int bcm_attach' \
    "include/bcm/init.h" \
    "OpenBCM public init API exports bcm_attach"
check_grep 'extern int bcm_l2_addr_add' \
    "include/bcm/l2.h" \
    "OpenBCM public L2 API exports bcm_l2_addr_add"
check_grep 'extern int bcm_vlan_create' \
    "include/bcm/vlan.h" \
    "OpenBCM public VLAN API exports bcm_vlan_create"
check_grep 'extern int bcm_port_enable_set' \
    "include/bcm/port.h" \
    "OpenBCM public port API exports bcm_port_enable_set"

printf '\n'
if [ "$FAILURES" -ne 0 ]; then
    printf 'OpenBCM userland init preflight failed: %s failure(s)\n' \
        "$FAILURES" >&2
    exit 1
fi

printf 'OpenBCM userland init source preflight passed\n'
printf 'Next hardware gate: BDE smoke must load on Redstone and enumerate BCM56846 before any SDK init/offload claim.\n'
